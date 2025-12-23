const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers, network } = require("hardhat");
const { expect } = require("chai");

// Existing, deployed contract addresses on your forked mainnet:
const AUTHORITY_ADDRESS = "0x6A005c11217863c4e300Ce009c5Ddc7e1672150A";
const TREASURY_ADDRESS  = "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E";
const ADMIN_ADDRESS     = "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2";

describe("kNFTFactory - Contract Creation & kNFT (Kondux) Functionality Tests", function () {
  /**
   * @dev This fixture:
   *  1. Connects to the existing Authority at AUTHORITY_ADDRESS
   *  2. Connects to the existing Treasury at TREASURY_ADDRESS
   *  3. Deploys a new kNFTFactory referencing the existing Authority
   *  4. Impersonates ADMIN_ADDRESS (an admin) to configure roles if needed
   */
  async function deployFactoryWithExistingAuthority() {
    // 1) Connect to existing Authority
    const AuthorityFactory = await ethers.getContractFactory("Authority");
    const authorityAbi = AuthorityFactory.interface;
    const authority = new ethers.Contract(
      AUTHORITY_ADDRESS,
      authorityAbi.fragments,
      ethers.provider
    );

    // 2) Connect to existing Treasury (optional if you need direct calls)
    const TreasuryFactory = await ethers.getContractFactory("Treasury");
    const treasuryAbi = TreasuryFactory.interface;
    const treasury = new ethers.Contract(
      TREASURY_ADDRESS,
      treasuryAbi.fragments,
      ethers.provider
    );

    // 3) Deploy kNFTFactory (with local deployer)
    const [localDeployer] = await ethers.getSigners();
    const kNFTFactory = await ethers.getContractFactory("kNFTFactory", localDeployer);
    const factory = await kNFTFactory.deploy(AUTHORITY_ADDRESS);
    await factory.waitForDeployment();

    // 4) Impersonate ADMIN_ADDRESS to configure the factory
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [ADMIN_ADDRESS],
    });
    const adminSigner = await ethers.getSigner(ADMIN_ADDRESS);

    // Optionally fund the admin if needed (for forks)
    const [funder] = await ethers.getSigners();
    await funder.sendTransaction({
      to: ADMIN_ADDRESS,
      value: ethers.parseEther("3.0"),
    });

    // Grant FACTORY_ADMIN_ROLE to ADMIN_ADDRESS
    await factory
      .connect(localDeployer)
      .grantRole(await factory.FACTORY_ADMIN_ROLE(), ADMIN_ADDRESS);

    return {
      authority,
      treasury,
      factory,
      adminSigner,
      localDeployer,
    };
  }

  // --------------------------------------------------------------------
  // Factory Tests
  // --------------------------------------------------------------------

  it("Should connect to existing Authority, Treasury, and deploy kNFTFactory", async function () {
    const { authority, treasury, factory } = await loadFixture(deployFactoryWithExistingAuthority);

    // Confirm addresses
    expect(await authority.getAddress()).to.equal(AUTHORITY_ADDRESS);
    expect(await treasury.getAddress()).to.equal(TREASURY_ADDRESS);
    expect(await factory.getAddress()).to.properAddress;
  });

  it("Should create a new Kondux contract if factory is active", async function () {
    const { factory, adminSigner } = await loadFixture(deployFactoryWithExistingAuthority);

    const tx = await factory.connect(adminSigner).createKondux("MyKonduxNFT", "MKN");
    const receipt = await tx.wait();

    // Parse logs for kNFTDeployed event
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
    const { factory, adminSigner } = await loadFixture(deployFactoryWithExistingAuthority);

    // Turn off factory
    await factory.connect(adminSigner).setFactoryActive(false);

    // Attempt creation
    await expect(
      factory.connect(adminSigner).createKondux("InactiveNFT", "INFT")
    ).to.be.revertedWith("Factory is not active");
  });

  it("Should charge fees if isFeeEnabled = true and caller not whitelisted", async function () {
    const { factory, adminSigner, authority } = await loadFixture(deployFactoryWithExistingAuthority);

    // We need a new wallet to demonstrate paying fees
    const [_, feePayer] = await ethers.getSigners();

    // 1) Enable fee
    await factory.connect(adminSigner).setFeeEnabled(true);
    await factory.connect(adminSigner).setCreationFee(ethers.parseEther("0.05"));

    // localDeployer (or feePayer here) is not whitelisted => must pay
    await expect(
      factory.connect(feePayer).createKondux("FeeNFT", "FNFT") // no value
    ).to.be.revertedWith("Insufficient ETH for creation fee");

    // Get treasury address (from authority)
    const treasuryAddr = await authority.vault();
    const treasuryBalanceBefore = await ethers.provider.getBalance(treasuryAddr);

    // Provide correct fee
    const tx = await factory.connect(feePayer).createKondux("PaidNFT", "PNFT", {
      value: ethers.parseEther("0.05"),
    });
    const receipt = await tx.wait();

    // Confirm Treasury balance increased by fee
    const treasuryBalanceAfter = await ethers.provider.getBalance(treasuryAddr);
    const diff = treasuryBalanceAfter - treasuryBalanceBefore;
    expect(diff).to.equal(ethers.parseEther("0.05"), "Treasury should receive 0.05 ETH");

    // Confirm event
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
    expect(event.args.admin).to.equal(feePayer.address);
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

    // Check event
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
    const { factory, adminSigner } = await loadFixture(deployFactoryWithExistingAuthority);

    const [_, newUser] = await ethers.getSigners();

    // Restrict creation
    await factory.connect(adminSigner).setRestricted(true);

    // newUser does NOT have FACTORY_ADMIN_ROLE
    await expect(
      factory.connect(newUser).createKondux("RestrictedNFT", "RFT")
    ).to.be.revertedWith("Not factory admin");

    // adminSigner does have FACTORY_ADMIN_ROLE => should succeed
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

  // --------------------------------------------------------------------
  // Tests for the newly created Kondux contract
  // --------------------------------------------------------------------

  describe("Kondux (kNFT) Usage Tests", function () {
    async function createAndAttachKondux() {
      // Reuse the main fixture
      const { factory, adminSigner, localDeployer } = await loadFixture(deployFactoryWithExistingAuthority);

      // We'll have adminSigner create a new Kondux so that adminSigner is the admin on the contract
      const tx = await factory.connect(adminSigner).createKondux("TestKonduxNFT", "TKN");
      const receipt = await tx.wait();

      // Parse logs to find new Kondux address
      const event = receipt.logs
        .map((log) => {
          try {
            return factory.interface.parseLog(log);
          } catch {
            return null;
          }
        })
        .find((parsed) => parsed && parsed.name === "kNFTDeployed");

      const newKonduxAddress = event.args.newkNFT;

      // Attach
      const Kondux = await ethers.getContractFactory("Kondux");
      const knft = Kondux.attach(newKonduxAddress);

      return {
        factory,
        adminSigner,
        localDeployer,
        knft, // newly deployed Kondux
      };
    }

    it("Should allow admin to setBaseURI and read tokenURI", async function () {
      const { knft, adminSigner } = await createAndAttachKondux();
    
      // By default, baseURI is empty => tokenURI => ""
      // Now set base URI
      await knft.connect(adminSigner).setBaseURI("https://mytesturi.com/metadata/");
    
      // Mint a token so we can check tokenURI
      const mintTx = await knft.connect(adminSigner).safeMint(adminSigner.address, 12345);
      const receipt = await mintTx.wait();
    
      // Manually parse logs to find a "Transfer" event
      const parsedLogs = receipt.logs.map((log) => {
        try {
          return knft.interface.parseLog(log);
        } catch (err) {
          return null;
        }
      }).filter(Boolean);
    
      // We expect exactly one Transfer event from ERC721
      const transferLog = parsedLogs.find((l) => l.name === "Transfer");
      expect(transferLog, "No Transfer event found").to.exist;
      const tokenId = transferLog.args.tokenId;

      // Check tokenURI
      const uri = await knft.tokenURI(tokenId);
      expect(uri).to.equal(`https://mytesturi.com/metadata/${tokenId}`);
    });

    it("Should allow minted tokens and track DNA properly", async function () {
      const { knft, adminSigner } = await createAndAttachKondux();

      // Mint a token with some DNA
      const dnaValue = 5555;
      const tx = await knft.connect(adminSigner).safeMint(adminSigner.address, dnaValue);
      const receipt = await tx.wait();
      
      // parse logs => find "Transfer"
      const parsedLogs = receipt.logs
        .map((log) => {
          try {
            return knft.interface.parseLog(log);
          } catch (err) {
            return null;
          }
        })
        .filter(Boolean);

      const transferLog = parsedLogs.find((l) => l.name === "Transfer");
      if (!transferLog) {
        throw new Error("No Transfer event found in logs");
      }

      const tokenId = transferLog.args.tokenId;

      // Confirm dna was set
      const storedDNA = await knft.getDna(tokenId);
      expect(storedDNA).to.equal(dnaValue);

      // Also confirm the admin is the minter, so no revert
      expect(tokenId).to.be.gte(0); // minted
    });

    it("Should allow admin to setDna if they have DNA_MODIFIER_ROLE", async function () {
      const { knft, adminSigner } = await createAndAttachKondux();

      // Mint
      const initialDNA = 1234;
      const tx = await knft.connect(adminSigner).safeMint(adminSigner.address, initialDNA);
      const receipt = await tx.wait();

      // parse logs => "Transfer"
      const parsedLogs = receipt.logs
        .map((log) => {
          try {
            return knft.interface.parseLog(log);
          } catch (err) {
            return null;
          }
        })
        .filter(Boolean);

      const transferLog = parsedLogs.find((l) => l.name === "Transfer");
      if (!transferLog) {
        throw new Error("No Transfer event found");
      }

      const tokenId = transferLog.args.tokenId;
      
      // Now setDna to a new value
      const newDNA = 9999;
      await knft.connect(adminSigner).setDna(tokenId, newDNA);

      const storedDNA = await knft.getDna(tokenId);
      expect(storedDNA).to.equal(newDNA);
    });

    it("Should allow partial DNA modifications via writeGen and readGen", async function () {
      const { knft, adminSigner } = await createAndAttachKondux();

      // Mint with a large DNA
      const bigDNA = BigInt("0x11223344556677889900AABBCCDDEEFF11223344556677889900AABBCCDDEEFF");
      const dnaDecimal = bigDNA.toString(); 
      const tx = await knft.connect(adminSigner).safeMint(adminSigner.address, dnaDecimal);
      const receipt = await tx.wait();

      const parsedLogs = receipt.logs
        .map((log) => {
          try {
            return knft.interface.parseLog(log);
          } catch (err) {
            return null;
          }
        })
        .filter(Boolean);

      const transferLog = parsedLogs.find((l) => l.name === "Transfer");
      if (!transferLog) {
        throw new Error("No Transfer event found");
      }

      const tokenId = transferLog.args.tokenId;

      // Overwrite bytes in the DNA at [4..8) with 0xDEADBEEF
      const inputValue = BigInt("0xDEADBEEF");
      await knft.connect(adminSigner).writeGen(tokenId, inputValue, 4, 8);

      // readGen back
      const extracted = await knft.readGen(tokenId, 4, 8); // returns int256
      expect(extracted).to.equal(inputValue, "Extracted bytes do not match inputValue");
    });

    it("Should allow token burning and reflect supply changes", async function () {
      const { knft, adminSigner } = await createAndAttachKondux();

      // Mint a few tokens
      await knft.connect(adminSigner).safeMint(adminSigner.address, 11);
      await knft.connect(adminSigner).safeMint(adminSigner.address, 22);

      // Supply now 2
      let totalSupply = await knft.totalSupply();
      expect(totalSupply).to.equal(2);

      // Burn token #0
      await knft.connect(adminSigner).burn(0);

      totalSupply = await knft.totalSupply();
      expect(totalSupply).to.equal(1);

      // Burn token #1
      await knft.connect(adminSigner).burn(1);

      totalSupply = await knft.totalSupply();
      expect(totalSupply).to.equal(0);
    });

    describe("Free Minting Tests", function () {
      it("Should let the admin enable or disable freeMinting and emit an event", async function () {
        const { knft, adminSigner } = await createAndAttachKondux();

        // Initially false
        expect(await knft.freeMinting()).to.equal(false, "Should be false initially");

        // Enable free minting
        const enableTx = await knft.connect(adminSigner).setFreeMinting(true);
        await expect(enableTx)
          .to.emit(knft, "FreeMintingChanged")
          .withArgs(true);

        expect(await knft.freeMinting()).to.equal(true, "Should be true now");

        // Disable free minting
        const disableTx = await knft.connect(adminSigner).setFreeMinting(false);
        await expect(disableTx)
          .to.emit(knft, "FreeMintingChanged")
          .withArgs(false);

        expect(await knft.freeMinting()).to.equal(false, "Should be false now");
      });

      it("Should allow anyone to call safeMint if freeMinting = true", async function () {
        const { knft, adminSigner } = await createAndAttachKondux();
        const [_, randomUser] = await ethers.getSigners();

        // Enable free minting
        await knft.connect(adminSigner).setFreeMinting(true);

        // Now random user can call safeMint
        const dnaValue = 7777;
        const mintTx = await knft.connect(randomUser).safeMint(randomUser.address, dnaValue);
        const receipt = await mintTx.wait();

        // parse logs => find "Transfer"
        const parsedLogs = receipt.logs
          .map((log) => {
            try {
              return knft.interface.parseLog(log);
            } catch {
              return null;
            }
          })
          .filter(Boolean);

        const transferLog = parsedLogs.find((l) => l.name === "Transfer");
        expect(transferLog, "No Transfer event found").to.exist;

        const tokenId = transferLog.args.tokenId;
        const storedDNA = await knft.getDna(tokenId);
        expect(storedDNA).to.equal(dnaValue);
      });

      it("Should revert if freeMinting = false and caller does not have MINTER_ROLE", async function () {
        const { knft, adminSigner } = await createAndAttachKondux();
        const [_, randomUser] = await ethers.getSigners();

        // Ensure freeMinting is false
        await knft.connect(adminSigner).setFreeMinting(false);
        expect(await knft.freeMinting()).to.equal(false);

        // randomUser tries to mint
        await expect(
          knft.connect(randomUser).safeMint(randomUser.address, 9999)
        ).to.be.revertedWith("kNFT: only minter");
      });

      it("Should allow MINTER_ROLE to mint even if freeMinting is false", async function () {
        const { knft, adminSigner } = await createAndAttachKondux();

        // freeMinting is false by default
        expect(await knft.freeMinting()).to.equal(false);

        // adminSigner has MINTER_ROLE => can mint
        const dnaValue = 20202;
        const mintTx = await knft.connect(adminSigner).safeMint(adminSigner.address, dnaValue);
        const receipt = await mintTx.wait();

        const parsedLogs = receipt.logs.map((log) => {
          try {
            return knft.interface.parseLog(log);
          } catch {
            return null;
          }
        }).filter(Boolean);

        const transferLog = parsedLogs.find((l) => l.name === "Transfer");
        expect(transferLog).to.exist;

        const tokenId = transferLog.args.tokenId;
        const storedDNA = await knft.getDna(tokenId);
        expect(storedDNA).to.equal(dnaValue);
      });
    });
  });

});
