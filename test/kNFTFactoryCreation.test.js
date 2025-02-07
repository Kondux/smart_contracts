const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers, network } = require("hardhat");
const { expect } = require("chai");

// Existing, deployed contract addresses on your forked mainnet:
const AUTHORITY_ADDRESS = "0x6A005c11217863c4e300Ce009c5Ddc7e1672150A";
const TREASURY_ADDRESS  = "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E";
const ADMIN_ADDRESS     = "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2";

describe("kNFTFactory - Contract Creation Tests (Using Existing Authority/Treasury)", function () {
  /**
   * @dev This fixture:
   *  1. Connects to the existing Authority at AUTHORITY_ADDRESS
   *  2. Connects to the existing Treasury at TREASURY_ADDRESS
   *  3. Deploys a new kNFTFactory referencing the existing Authority
   *  4. Impersonates ADMIN_ADDRESS (an admin) to configure roles if needed
   */
  async function deployFactoryWithExistingAuthority() {
    // Get the signers and contracts we need to interact with
    const [hreSigner] = await ethers.getSigners();
    console.log("Hardhat Signer Address: %s", await hreSigner.getAddress());

    // 1) Connect to existing Authority
    //    We'll grab the ABI from Hardhat artifacts.
    //    Alternatively, you can pass a minimal ABI since we're mainly calling read/write methods we know exist.
    const AuthorityFactory = await ethers.getContractFactory("Authority");
    const authorityAbi = AuthorityFactory.interface;
    const authority = new ethers.Contract(AUTHORITY_ADDRESS, authorityAbi.fragments, ethers.provider);

    // 2) Connect to existing Treasury
    const TreasuryFactory = await ethers.getContractFactory("Treasury");
    const treasuryAbi = TreasuryFactory.interface;
    const treasury = new ethers.Contract(TREASURY_ADDRESS, treasuryAbi.fragments, ethers.provider);

    // 3) Deploy kNFTFactory (with a local deployer as default)
    const [localDeployer] = await ethers.getSigners();
    const kNFTFactory = await ethers.getContractFactory("kNFTFactory", localDeployer);
    const factory = await kNFTFactory.deploy(AUTHORITY_ADDRESS);
    await factory.waitForDeployment();
    console.log("kNFTFactory deployed at %s", await factory.getAddress());

    // get the factory's admin FACTORY_ADMIN_ROLE from OZ AccessControl role
    const factoryAdminRole = await factory.isFactoryAdmin(await localDeployer.getAddress());
    console.log("Is Local Deployer a Factory Admin: %s", factoryAdminRole);    

    expect(factoryAdminRole).to.be.true;
    
    // 4) Impersonate the on-chain admin to configure roles on the new factory
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ADMIN_ADDRESS],
    });
    const adminSigner = await ethers.getSigner(ADMIN_ADDRESS);

    // Set the factory's admin role to the admin granting role FACTORY_ADMIN_ROLE
    await factory.connect(localDeployer).grantRole(await factory.FACTORY_ADMIN_ROLE(), ADMIN_ADDRESS);

    const isAdmin = await factory.isFactoryAdmin(ADMIN_ADDRESS);
    expect(isAdmin).to.be.true;
    console.log("Is Admin a Factory Admin: %s", isAdmin);

    // Optionally fund ADMIN_ADDRESS if it needs ETH for transaction gas
    const [funder] = await ethers.getSigners();
    await funder.sendTransaction({
      to: ADMIN_ADDRESS,
      value: ethers.parseEther("3.0"),
    });

    // Return references for the tests
    return {
      authority,
      treasury,
      factory,
      adminSigner,
      localDeployer,
      hreSigner
    };
  }

  // --------------------------------------------------------------------
  // TESTS
  // --------------------------------------------------------------------

  it("Should connect to existing Authority, Treasury, and deploy kNFTFactory", async function () {
    const { authority, treasury, factory } = await loadFixture(deployFactoryWithExistingAuthority);

    // Confirm addresses
    expect(await authority.getAddress()).to.equal(AUTHORITY_ADDRESS);
    expect(await treasury.getAddress()).to.equal(TREASURY_ADDRESS);
    expect(await factory.getAddress()).to.properAddress;
  });

  it("Should create a new Kondux contract if factory is active", async function () {
    const { factory, adminSigner, localDeployer } = await loadFixture(deployFactoryWithExistingAuthority);

    // By default, isFactoryActive = true and isFeeEnabled = false
    const tx = await factory.connect(adminSigner).createKondux("MyKonduxNFT", "MKN");
    const receipt = await tx.wait();

    // Parse logs to find kNFTDeployed event
    const event = receipt.logs
      .map((log) => {
        try {
          return factory.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((parsed) => parsed && parsed.name === "kNFTDeployed");

    expect(event, "Expected kNFTDeployed event not found").to.exist;
    expect(event.args.admin).to.equal(adminSigner.address, "Should be the admin");

    const newKonduxAddress = event.args.newkNFT;
    expect(newKonduxAddress).to.properAddress;
  });

  it("Should revert if factory is inactive", async function () {
    const { factory, adminSigner, localDeployer } = await loadFixture(deployFactoryWithExistingAuthority);

    // Turn off factory
    await factory.connect(localDeployer).setFactoryActive(false);

    // Attempt creation
    await expect(
      factory.connect(localDeployer).createKondux("InactiveNFT", "INFT")
    ).to.be.revertedWith("Factory is not active");
  });

  it("Should charge fees if isFeeEnabled = true and caller not whitelisted", async function () {
    const { factory, adminSigner, localDeployer } = await loadFixture(deployFactoryWithExistingAuthority);

    // Setup: get a fresh wallet caller for createKondux 
    const [admin, caller] = await ethers.getSigners();

    // 1) Enable fee
    await factory.connect(adminSigner).setFeeEnabled(true);
    await factory.connect(adminSigner).setCreationFee(ethers.parseEther("0.05"));

    // caller is not whitelisted => must pay
    await expect(
      factory.connect(caller).createKondux("FeeNFT", "FNFT") // no value
    ).to.be.revertedWith("Insufficient ETH for creation fee");

    // Provide correct fee
    const tx = await factory.connect(caller).createKondux("PaidNFT", "PNFT", {
      value: ethers.parseEther("0.05"),
    });
    const receipt = await tx.wait();

    const event = receipt.logs
      .map((log) => {
        try {
          return factory.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((parsed) => parsed && parsed.name === "kNFTDeployed");
    expect(event, "kNFTDeployed event not found").to.exist;
    expect(event.args.admin).to.equal(await caller.getAddress());
  });

  it("Should allow whitelisted user to create with no fee", async function () {
    const { factory, adminSigner, localDeployer } = await loadFixture(deployFactoryWithExistingAuthority);

    // Enable fee
    await factory.connect(adminSigner).setFeeEnabled(true);
    await factory.connect(adminSigner).setCreationFee(ethers.parseEther("0.05"));

    // Whitelist localDeployer
    await factory.connect(adminSigner).setFreeCreator(localDeployer.address, true);

    // Should succeed with zero ETH
    const tx = await factory.connect(localDeployer).createKondux("FreeNFT", "FRN");
    const receipt = await tx.wait();

    const event = receipt.logs
      .map((log) => {
        try {
          return factory.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((parsed) => parsed && parsed.name === "kNFTDeployed");
    expect(event, "kNFTDeployed event not found").to.exist;
    expect(event.args.admin).to.equal(localDeployer.address);
  });

  it("Should respect isRestricted = true", async function () {
    const { factory, adminSigner, localDeployer } = await loadFixture(deployFactoryWithExistingAuthority);

    // Setup: get a fresh wallet caller for createKondux
    const [_, caller] = await ethers.getSigners();

    // Restrict creation
    await factory.connect(adminSigner).setRestricted(true);

    // localDeployer does NOT have FACTORY_ADMIN_ROLE
    await expect(
      factory.connect(caller).createKondux("RestrictedNFT", "RFT")
    ).to.be.revertedWith("Not factory admin");

    // adminSigner does have FACTORY_ADMIN_ROLE
    const tx = await factory.connect(adminSigner).createKondux("AdminNFT", "ANFT");
    const receipt = await tx.wait();

    const event = receipt.logs
      .map((log) => {
        try {
          return factory.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((parsed) => parsed && parsed.name === "kNFTDeployed");
    expect(event, "kNFTDeployed event not found").to.exist;
  });
});
