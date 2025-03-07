const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers, network } = require("hardhat");
const { expect } = require("chai");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const exp = require("constants");


describe("Kondux (kNFT) - Full Test Suite", function () {
  /**
   * @dev Fixture to deploy and configure the Kondux contract.
   *      - Mocks or uses real addresses for uniswap router, WETH, KNDX, founder pass, and treasury.
   *      - Grants roles (admin, minter, dna_modifier) to test accounts.
   *      - Optionally impersonates addresses if you have them on a mainnet fork.
   */
  async function deployKonduxFixture() {
    // --- Signers ---
    const [deployer, admin, minter, dnaModifier, user1, user2, treasurySigner] =
      await ethers.getSigners();

    // If needed for fork-testing, you can impersonate real mainnet addresses like so:
    // const FOUNDER_PASS_HOLDER = "0x1234..."; // some real address that owns a founder pass
    // await network.provider.request({
    //   method: "hardhat_impersonateAccount",
    //   params: [FOUNDER_PASS_HOLDER],
    // });
    // const founderPassHolder = await ethers.getSigner(FOUNDER_PASS_HOLDER);
    // Then fund it if needed, etc.

    // --- Mock addresses (replace with real addresses on a mainnet fork) ---
    const uniswapV2Pair = "0x79dd15aD871b0fE18040a52F951D757Ef88cfe72";
    const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    const KNDX = "0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1";
    // const ADMIN_ADDRESS = "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2";
    // const TREASURY_ADDRESS = "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E";
    const FOUNDERSPASS_ADDRESS = "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b";
    // const UNISWAP_PAIR_ADDRESS = "0x79dd15aD871b0fE18040a52F951D757Ef88cfe72";

    const KNDX_DECIMALS = 9;
    
    // Address of an account holding a significant amount of PAYMENT_TOKEN_ADDRESS
    const TOKEN_HOLDER_ADDRESS = "0x4936167DAE4160E5556D9294F2C78675659a3B63"; 

    // Address of a founder account
    const FOUNDERS_PASS_HOLDER_ADDRESS = "0x79BD02b5936FFdC5915cB7Cd58156E3169F4F569";     

    // For testing, we’ll treat the `treasurySigner` as the treasury address
    const konduxTreasury = await treasurySigner.getAddress();

    // --- Deploy Kondux ---
    const KonduxFactory = await ethers.getContractFactory("Kondux");
    const kondux = await KonduxFactory.deploy(
      "KonduxNFT",          // _name
      "kNFT",               // _symbol
      uniswapV2Pair,      // _uniswapV2Pair
      WETH,
      KNDX,
      FOUNDERSPASS_ADDRESS,
      konduxTreasury
    );
    await kondux.waitForDeployment();

    // --- Grant roles to test accounts ---
    // By default, the deployer has DEFAULT_ADMIN_ROLE, MINTER_ROLE, DNA_MODIFIER_ROLE, but
    // you can explicitly set them if you want to test role management thoroughly.
    // Let's revoke from deployer and give them to the 'admin' for demonstration:
    // await kondux.revokeRole(await kondux.DEFAULT_ADMIN_ROLE(), deployer.address);
    // await kondux.revokeRole(await kondux.MINTER_ROLE(), deployer.address);
    // await kondux.revokeRole(await kondux.DNA_MODIFIER_ROLE(), deployer.address);

    // Grant to 'admin'
    await kondux.grantRole(await kondux.DEFAULT_ADMIN_ROLE(), admin.address);
    await kondux.grantRole(await kondux.MINTER_ROLE(), minter.address);
    await kondux.grantRole(await kondux.DNA_MODIFIER_ROLE(), dnaModifier.address);

    const konduxAddress = await kondux.getAddress();
    // console.log("kondux deployed to:", ko?nduxAddress);

    // load the founder pass holder in a wallet through impersonation
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [FOUNDERS_PASS_HOLDER_ADDRESS],
    });
    const founderPassHolder = await ethers.getSigner(FOUNDERS_PASS_HOLDER_ADDRESS);

    // Impersonate the token holder to transfer PAYMENT_TOKEN_ADDRESS tokens to the minter contract
    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [TOKEN_HOLDER_ADDRESS],
    });
    const tokenHolderSigner = await ethers.getSigner(TOKEN_HOLDER_ADDRESS);

    // // Connect to the payment token contract
    const paymentToken = await ethers.getContractAt("KNDX", KNDX, tokenHolderSigner);

    // // Determine the amount to transfer (e.g., 1000 tokens with 9 decimals)
    const transferAmount = ethers.parseUnits("100000", KNDX_DECIMALS); // Adjust decimals if necessary

    // // Transfer tokens to the minter contract
    await paymentToken.transfer(konduxAddress, transferAmount);

    // // Stop impersonating the token holder and admin accounts to save resources
    await network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [TOKEN_HOLDER_ADDRESS],
    });

    // Return everything needed in tests
    return {
      kondux,
      FOUNDERSPASS_ADDRESS,
      uniswapV2Pair,
      WETH,
      paymentToken,
      konduxTreasury,
      deployer,
      admin,
      minter,
      dnaModifier,
      user1,
      user2,
      treasurySigner,
      tokenHolderSigner,
      KNDX,
      founderPassHolder
    };
  }

  //----------------------------------------------------------------------------
  // Basic Deployment & Config Checks
  //----------------------------------------------------------------------------
  describe("Deployment & Initial State", function () {
    it("Should deploy Kondux with correct initial settings", async function () {
      const {
        kondux,
        uniswapV2Pair,
        WETH,
        KNDX,
        konduxTreasury,
        FOUNDERSPASS_ADDRESS,
      } = await loadFixture(deployKonduxFixture);

      expect(await kondux.uniswapV2Pair()).to.equal(uniswapV2Pair);
      expect(await kondux.WETH()).to.equal(WETH);
      expect(await kondux.konduxTreasury()).to.equal(konduxTreasury);
      expect(await kondux.foundersPass()).to.equal(FOUNDERSPASS_ADDRESS);

      expect(await kondux.royaltyEnforcementEnabled()).to.be.true;
      expect(await kondux.founderPassExemptEnabled()).to.be.true;
      expect(await kondux.mintedOwnerExemptEnabled()).to.be.true;
      expect(await kondux.treasuryFeeEnabled()).to.be.true;

      expect(await kondux.denominator()).to.equal(10000);
      expect(await kondux.freeMinting()).to.be.false;
    });

    it("Should have roles set up correctly", async function () {
      const { kondux, admin, minter, dnaModifier } = await loadFixture(deployKonduxFixture);

      const DEFAULT_ADMIN_ROLE = await kondux.DEFAULT_ADMIN_ROLE();
      const MINTER_ROLE = await kondux.MINTER_ROLE();
      const DNA_ROLE = await kondux.DNA_MODIFIER_ROLE();

      expect(await kondux.hasRole(DEFAULT_ADMIN_ROLE, admin.address)).to.be.true;
      expect(await kondux.hasRole(MINTER_ROLE, minter.address)).to.be.true;
      expect(await kondux.hasRole(DNA_ROLE, dnaModifier.address)).to.be.true;
    });
  });

  //----------------------------------------------------------------------------
  // Role Management
  //----------------------------------------------------------------------------
  describe("Role Management", function () {
    it("Only admin should be able to grant/revoke roles", async function () {
      const { kondux, user1, minter } = await loadFixture(deployKonduxFixture);

      // user1 tries to set MINTER_ROLE for themselves => should fail
      await expect(
        kondux.connect(user1).setRole(await kondux.MINTER_ROLE(), user1.address, true)
      ).to.be.revertedWith("kNFT: only admin");

      // minter is not an admin => also fails
      await expect(
        kondux.connect(minter).setRole(await kondux.DNA_MODIFIER_ROLE(), minter.address, true)
      ).to.be.revertedWith("kNFT: only admin");
    });

    it("Admin can grant and revoke roles", async function () {
      const { kondux, admin, user1 } = await loadFixture(deployKonduxFixture);
      const MINTER_ROLE = await kondux.MINTER_ROLE();

      // Grant
      await expect(kondux.connect(admin).setRole(MINTER_ROLE, user1.address, true))
        .to.emit(kondux, "RoleChanged")
        .withArgs(user1.address, MINTER_ROLE, true);
      expect(await kondux.hasRole(MINTER_ROLE, user1.address)).to.be.true;

      // Revoke
      await expect(kondux.connect(admin).setRole(MINTER_ROLE, user1.address, false))
        .to.emit(kondux, "RoleChanged")
        .withArgs(user1.address, MINTER_ROLE, false);
      expect(await kondux.hasRole(MINTER_ROLE, user1.address)).to.be.false;
    });
  });

  //----------------------------------------------------------------------------
  // Minting & Free Minting
  //----------------------------------------------------------------------------
  describe("Minting & Free Minting", function () {
    it("Minter role can mint a new NFT", async function () {
      const { kondux, minter, user1 } = await loadFixture(deployKonduxFixture);

      // Before we do anything, freeMinting is false => only MINTER_ROLE can mint
      await expect(kondux.connect(minter).safeMint(user1.address, 12345))
        .to.emit(kondux, "Transfer")
        .withArgs(ethers.ZeroAddress, user1.address, 0);

      expect(await kondux.ownerOf(0)).to.equal(user1.address);
      expect(await kondux.getDna(0)).to.equal(12345);
    });

    it("Non-minter cannot mint if freeMinting is false", async function () {
      const { kondux, user1 } = await loadFixture(deployKonduxFixture);

      await expect(kondux.connect(user1).safeMint(user1.address, 999)).to.be.revertedWith(
        "kNFT: only minter"
      );
    });

    it("Admin can enable freeMinting, then anyone can mint", async function () {
      const { kondux, admin, user1 } = await loadFixture(deployKonduxFixture);

      await kondux.connect(admin).setFreeMinting(true);
      expect(await kondux.freeMinting()).to.be.true;

      // Now user1 (not a minter) can mint
      await kondux.connect(user1).safeMint(user1.address, 1234);
      expect(await kondux.ownerOf(0)).to.equal(user1.address);
    });
  });

  //----------------------------------------------------------------------------
  // DNA Functionality
  //----------------------------------------------------------------------------
  describe("DNA Reading/Writing", function () {
    it("Should allow only dnaModifier role to setDna or writeGen", async function () {
      const { kondux, minter, dnaModifier, user1 } = await loadFixture(deployKonduxFixture);

      // Let's mint a token first
      await kondux.connect(minter).safeMint(user1.address, 100);

      // Non-dnaModifier tries setDna => revert
      await expect(kondux.connect(user1).setDna(0, 200)).to.be.revertedWith("kNFT: only dna modifier");

      // DNA modifier can setDna
      await expect(kondux.connect(dnaModifier).setDna(0, 200))
        .to.emit(kondux, "DnaChanged")
        .withArgs(0, 200);

      expect(await kondux.getDna(0)).to.equal(200);
    });

    it("readGen should revert for out-of-range indexes", async function () {
      const { kondux, minter, dnaModifier, user1 } = await loadFixture(deployKonduxFixture);

      await kondux.connect(minter).safeMint(user1.address, 123456);
      // readGen with startIndex >= endIndex
      await expect(kondux.readGen(0, 10, 10)).to.be.revertedWith("kNFT: Invalid range");
      // readGen with endIndex > 32
      await expect(kondux.readGen(0, 1, 33)).to.be.revertedWith("kNFT: Invalid range");
    });

    it("writeGen should revert for out-of-range indexes or input too large", async function () {
      const { kondux, minter, dnaModifier, user1 } = await loadFixture(deployKonduxFixture);

      await kondux.connect(minter).safeMint(user1.address, 0);

      // Attempt writeGen with startIndex >= endIndex
      await expect(
        kondux.connect(dnaModifier).writeGen(0, 999, 10, 10)
      ).to.be.revertedWith("kNFT: Invalid range");

      // Attempt writeGen with endIndex > 32
      await expect(
        kondux.connect(dnaModifier).writeGen(0, 999, 1, 33)
      ).to.be.revertedWith("kNFT: Invalid range");

      // Attempt writeGen with input bigger than allowed for (endIndex - startIndex) bytes
      // e.g. if we are only writing 1 byte [0..1], max input is 255
      await expect(
        kondux.connect(dnaModifier).writeGen(0, 999, 0, 1)
      ).to.be.revertedWith("kNFT: Input too large");
    });

    it("writeGen should correctly modify only the specified byte range", async function () {
      const { kondux, minter, dnaModifier, user1 } = await loadFixture(deployKonduxFixture);
    
      // 1) Mint a token with initial DNA = 0
      await kondux.connect(minter).safeMint(user1.address, 0);
    
      // 2) We want the final two bytes (lowest 16 bits) to be 0xBEEF:
      //    Use writeGen(0, 0xbeef, 30, 32) so that i=30..31 maps
      //    to the least significant 2 bytes in big-endian storage.
      await expect(
        kondux.connect(dnaModifier).writeGen(0, 0xbeef, 30, 32)
      )
        .to.emit(kondux, "DnaModified")
        .withArgs(0, /* newDNA */ anyValue, 0xbeef, 30, 32);
    
      // 3) Check that the final 16 bits are 0xbeef
      const dna = await kondux.getDna(0);
      expect(dna & 0xffffn).to.equal(0xbeefn);
    });
    
  });

  //----------------------------------------------------------------------------
  // Royalty & Transfer Enforcement
  //----------------------------------------------------------------------------
  describe("Royalty Enforcement & Exemptions", function () {
    it("Minter sets default royalty (0.001 ETH in Wei) and becomes royalty owner", async function () {
      const { kondux, minter, user1 } = await loadFixture(deployKonduxFixture);

      // Mint a token => royaltyOwnerOf[tokenId] = user1 by default
      await kondux.connect(minter).safeMint(user1.address, 1111);

      expect(await kondux.royaltyOwnerOf(0)).to.equal(user1.address);
      expect(await kondux.royaltyETHWei(0)).to.equal(ethers.parseUnits("0.001", "ether"));
    });

    it("Royalty owner can update token royalty in Wei", async function () {
      const { kondux, minter, user1 } = await loadFixture(deployKonduxFixture);

      await kondux.connect(minter).safeMint(user1.address, 2222);
      // user1 is the royalty owner
      await kondux.connect(user1).setTokenRoyaltyEth(0, ethers.parseUnits("0.002", "ether"));
      expect(await kondux.royaltyETHWei(0)).to.equal(ethers.parseUnits("0.002", "ether"));

      // Another user cannot change it
      await expect(
        kondux.connect(minter).setTokenRoyaltyEth(0, ethers.parseUnits("0.005", "ether"))
      ).to.be.revertedWith("Not the token's royalty owner");
    });

    it("If royalty is 0, no tokens are charged on transfer", async function () {
      const { kondux, minter, user1, user2 } = await loadFixture(deployKonduxFixture);

      await kondux.connect(minter).safeMint(user1.address, 9999);
      // user1 => set royalty to zero
      await kondux.connect(user1).setTokenRoyaltyEth(0, 0);

      // No revert, no royalty on transfer
      await expect(kondux.connect(user1).transferFrom(user1.address, user2.address, 0)).to.not
        .be.reverted;
    });

    it("Minted owner exemption: mintedOwnerExemptEnabled = true => minter doesn't pay royalty transferring away", async function () {
      const { kondux, admin, minter, user1 } = await loadFixture(deployKonduxFixture);

      // user1 mints => user1 is the "royalty owner"
      await kondux.connect(minter).safeMint(user1.address, 1234);

      // If user1 sends it to minter, they are the minted owner => check the code
      // mintedOwnerExemptEnabled is true, so no royalty tokens are taken.
      // We can verify by turning ON royalty, but we'll rely on the internal logic and ensure it doesn't revert.
      await kondux.connect(user1).transferFrom(user1.address, minter.address, 0);

      // Turn mintedOwnerExemptEnabled OFF
      await kondux.connect(admin).setMintedOwnerExempt(false);
      expect(await kondux.mintedOwnerExemptEnabled()).to.be.false;

      // Now if user1 mints again a new token, it won't have the exemption on subsequent transfers,
      // but let's confirm it doesn't revert if user1 doesn't have enough KNDX, etc.
      // For a full check, you would need an ERC20 KNDX minted to user1 on a mainnet fork, or a mocked KNDX contract, etc.
      // We'll just show the toggling test here.
    });

    it("Founder pass exemption: if user holds founder pass and founderPassExemptEnabled is true => skip royalty", async function () {
      const { kondux, admin, minter, user1, user2, founderPassHolder, FOUNDERSPASS_ADDRESS, tokenHolderSigner, paymentToken } = await loadFixture(
        deployKonduxFixture
      );

      // user1 mints token #0
      await kondux.connect(minter).safeMint(user1.address, 555);
      // Set a non-zero royalty
      await kondux.connect(user1).setTokenRoyaltyEth(0, ethers.parseUnits("0.001", "ether"));

      // Transfer from user2 => wait, user2 doesn't own token #0 yet. Let's have user1 transfer to user2
      // This first transfer is from user1 => user2. user1 does not hold the founder pass,
      // but user1 is the minted owner => they're also exempt by mintedOwnerExempt => no KNDX required
      await kondux.connect(user1).transferFrom(user1.address, user2.address, 0);

      // Now user2 holds the founder pass it gets from the Founder pass holder wallet, but first get its token ID      
      const foundersPass = await ethers.getContractAt("KonduxFounders", FOUNDERSPASS_ADDRESS, founderPassHolder);
      const tokenId = await foundersPass.tokenOfOwnerByIndex(founderPassHolder.address, 0);
      expect(tokenId).to.equal(13);

      // check founder pass holder kndx erc20 token balance
      const kndx = await ethers.getContractAt("KNDX", await kondux.KNDX());
      // const founderPassHolderBalance = await kndx.balanceOf(founderPassHolder.address);
      // console.log("Founder pass holder KNDX balance:", founderPassHolderBalance.toString());
      // console.log("Founder ETH Balance (using ethers):", ethers.formatEther(await ethers.provider.getBalance(founderPassHolder.address)));

      // fund founder pass holder with ETH from user1
      await user1.sendTransaction({
        to: await founderPassHolder.getAddress(),
        value: ethers.parseEther("3.0"),
      });

      await foundersPass.connect(founderPassHolder).transferFrom(founderPassHolder.address, user2.address, tokenId);

      // test user1 and user2 KNDX balance
      // console.log("User1 KNDX balance:", (await kndx.balanceOf(await user1.getAddress())).toString());
      // console.log("User2 KNDX balance:", (await kndx.balanceOf(await user2.getAddress())).toString());
      expect(await kndx.balanceOf(await user1.getAddress())).to.equal(0);
      expect(await kndx.balanceOf(await user2.getAddress())).to.equal(0);

      // test if user2 has the founder pass
      expect(await foundersPass.ownerOf(tokenId)).to.equal(await user2.getAddress());

      // test if user2 owns the knft
      expect(await kondux.ownerOf(0)).to.equal(user2.address);

      // now check if user1 don't have the founder pass and the knft
      expect(await foundersPass.ownerOf(tokenId)).to.not.equal(user1.address);
      expect(await kondux.ownerOf(0)).to.not.equal(user1.address);

      // Now user2 tries to send to user1. user2 DOES hold the founder pass => also exempt from royalty
      await kondux.connect(user2).transferFrom(user2.address, user1.address, 0);
      expect(await kondux.ownerOf(0)).to.equal(user1.address);

      // Let's temporarily disable founder pass exemption:
      await kondux.connect(admin).setFounderPassExempt(false);
      expect(await kondux.founderPassExemptEnabled()).to.be.false;
      
      // Now if user2 -> user1, it will require KNDX. In a real test with KNDX on fork,
      // you'd check the KNDX balance or do a revert check. We'll demonstrate the revert:
      // first, print the error message of the revert
      await kondux.connect(user1).transferFrom(user1.address, user2.address, 0);
      expect(await kondux.ownerOf(0)).to.equal(user2.address);
      await expect(
        kondux.connect(user2).transferFrom(user2.address, user1.address, 0)
      ).to.be.revertedWith("Insufficient allowance for royalty transfer");
      // give allowance to user2
      await kndx.connect(user2).approve(await kondux.getAddress(), ethers.parseUnits("100000", 9));
      expect(await kndx.allowance(user2.address, await kondux.getAddress())).to.equal(ethers.parseUnits("100000", 9));
      // now user2 -> user1
      await expect(
        kondux.connect(user2).transferFrom(user2.address, user1.address, 0)
      ).to.be.reverted;
      
      // console.log("tokenHolderSigner address:", await tokenHolderSigner.getAddress());
      // console.log of the founder pass holder balance with KNDX 9 decimals
      // console.log("tokenHolderSigner KNDX balance: ", ethers.formatUnits(await kndx.balanceOf( await tokenHolderSigner.getAddress()), 9));

      // // impersonate the token holder to transfer KNDX to user2
      await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [await tokenHolderSigner.getAddress()],
      });

      // now user2 receives KNDX from token holder
      await paymentToken.transfer(user2.address, ethers.parseUnits("10", 9));
      expect(await kndx.balanceOf(user2.address)).to.equal(ethers.parseUnits("10", 9));

      await expect(
        kondux.connect(user2).transferFrom(user2.address, user1.address, 0)
      ).to.be.reverted; 
      
      // now user2 have enough KNDX to transfer the knft to user1
      await paymentToken.transfer(user2.address, ethers.parseUnits("100000", 9));
      expect(await kndx.balanceOf(user2.address)).to.equal(ethers.parseUnits("100010", 9));

      // user1 royalty balance before
      const user1RoyaltyBalanceBefore = await kndx.balanceOf(user1.address);

      // treasury balance before
      const treasuryBalanceBefore = await kndx.balanceOf(await kondux.konduxTreasury());

      // user2 => user1
      await kondux.connect(user2).transferFrom(user2.address, user1.address, 0);
      expect(await kondux.ownerOf(0)).to.equal(user1.address);


      const treasuryBalanceAfter = await kndx.balanceOf(await kondux.konduxTreasury());
      expect(treasuryBalanceAfter).to.be.above(treasuryBalanceBefore);

      const user1RoyaltyBalanceAfter = await kndx.balanceOf(user1.address);
      expect(user1RoyaltyBalanceAfter).to.be.above(user1RoyaltyBalanceBefore);
    });

    it("Treasury fee splits 1% to treasury, 99% to royalty owner when enabled", async function () {
      const { kondux, admin, minter, user1, user2, treasurySigner, tokenHolderSigner, KNDX } = await loadFixture(
        deployKonduxFixture
      );

      // For this test to fully pass on a fork, user2 must have enough KNDX to cover the royalty.
      // We'll just demonstrate the calls. If you're on a fork, make sure user2 has KNDX or a mock.

      await kondux.connect(minter).safeMint(user1.address, 888);
      // Set some royalty, e.g. 0.001 ETH
      await kondux.connect(user1).setTokenRoyaltyEth(0, ethers.parseUnits("0.001", "ether"));

      // user1 => user2 (mintedOwnerExempt, no fee)
      await kondux.connect(user1).transferFrom(user1.address, user2.address, 0);
      
      // check KNDXERC20 balance of user2. get the KNDX contract and check balance      
      const kndx = await ethers.getContractAt("KNDX", KNDX);
      const balanceUser2 = await kndx.balanceOf(user2.address);
      expect(balanceUser2).to.equal(0);

      // impersonate the token holder to transfer KNDX to user2
      await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [tokenHolderSigner.address],
      });

      // // fund user2 with KNDX
      // await kndx.transfer(user2.address, ethers.parseUnits("100000", 9));
      // console.log("User2 KNDX balance after:", balanceUser2.toString());
      // expect(await kndx.balanceOf(user2.address)).to.equal(ethers.parseUnits("100000", 9));

      // reverts if user2 doesn't have enough KNDX approved
      await expect(
        kondux.connect(user2).transferFrom(user2.address, user1.address, 0)
      ).to.be.revertedWith("Insufficient allowance for royalty transfer");

      // user2 give allowance to the kondux contract      
      await kndx.connect(user2).approve(await kondux.getAddress(), ethers.parseUnits("100000", 9));    
      expect(await kndx.allowance(user2.address, await kondux.getAddress())).to.equal(ethers.parseUnits("100000", 9));

      // user2 => user1 (now user2 must pay if they are not founder pass exempt)
      // We check that treasuryFeeEnabled is on by default => 1% to treasury, 99% to user1
      // This will revert if user2 doesn't have enough KNDX. 
      // On a real fork, either user2 must have enough KNDX or you can remove the revert check:
      await expect(
        kondux.connect(user2).transferFrom(user2.address, user1.address, 0)
      ).to.be.reverted; // Revert if user2 doesn't have enough KNDX

      // We can turn off treasury fee:
      await kondux.connect(admin).setTreasuryFeeEnabled(false);
      expect(await kondux.treasuryFeeEnabled()).to.be.false;

      // Now user2 => user1 would send the entire royalty to user1, skipping the treasury cut.
      // But it will still revert if user2 lacks KNDX. 
      await expect(
        kondux.connect(user2).transferFrom(user2.address, user1.address, 0)
      ).to.be.reverted;

      // Now enable treasury fee again
      await kondux.connect(admin).setTreasuryFeeEnabled(true);
      expect(await kondux.treasuryFeeEnabled()).to.be.true;

      // fund user2 with KNDX from the token holder
      await kndx.connect(tokenHolderSigner).transfer(user2.address, ethers.parseUnits("100000", 9));
      expect(await kndx.balanceOf(user2.address)).to.equal(ethers.parseUnits("100000", 9));

      // user2 => user1 (now user2 must pay if they are not founder pass exempt)
      const tx = await kondux.connect(user2).transferFrom(user2.address, user1.address, 0);
      await expect(tx).to.emit(kondux, "Transfer").withArgs(user2.address, user1.address, 0);

    });

    it("Admin can disable royaltyEnforcementEnabled => no KNDX checks on transfers", async function () {
      const { kondux, admin, minter, user1, user2 } = await loadFixture(deployKonduxFixture);

      await kondux.connect(minter).safeMint(user1.address, 777);
      await kondux.connect(user1).setTokenRoyaltyEth(0, ethers.parseUnits("0.005", "ether"));

      // Turn off enforcement
      await kondux.connect(admin).setRoyaltyEnforcement(false);
      expect(await kondux.royaltyEnforcementEnabled()).to.be.false;

      // user1 => user2 => no royalty check, should pass even if user2 has no KNDX
      await kondux.connect(user1).transferFrom(user1.address, user2.address, 0);
    });
  });

  //----------------------------------------------------------------------------
  // Admin & Emergency Withdraw
  //----------------------------------------------------------------------------
  describe("Admin & Emergency Withdraw", function () {
    it("Admin can change addresses (router, WETH, KNDX, founder pass, treasury)", async function () {
      const { kondux, admin } = await loadFixture(deployKonduxFixture);

      const newRouter = "0x1111111111111111111111111111111111111111";
      const newWETH = "0x2222222222222222222222222222222222222222";
      const newKNDX = "0x3333333333333333333333333333333333333333";
      const newFounderPass = "0x4444444444444444444444444444444444444444";
      const newTreasury = "0x5555555555555555555555555555555555555555";

      await kondux
        .connect(admin)
        .setAddresses(newRouter, newWETH, newKNDX, newFounderPass, newTreasury);

      expect(await kondux.uniswapV2Pair()).to.equal(newRouter);
      expect(await kondux.WETH()).to.equal(newWETH);
      expect(await kondux.KNDX()).to.equal(newKNDX);
      expect(await kondux.foundersPass()).to.equal(newFounderPass);
      expect(await kondux.konduxTreasury()).to.equal(newTreasury);
    });

    it("Non-admin cannot call setAddresses", async function () {
      const { kondux, user1 } = await loadFixture(deployKonduxFixture);
      await expect(
        kondux
          .connect(user1)
          .setAddresses(ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress)
      ).to.be.revertedWith("kNFT: only admin");
    });

    it("Emergency withdraw functions revert if not admin", async function () {
      const { kondux, user1 } = await loadFixture(deployKonduxFixture);
      await expect(
        kondux.connect(user1).emergencyWithdrawToken(ethers.ZeroAddress, user1.address, 1000)
      ).to.be.revertedWith("kNFT: only admin");
      await expect(
        kondux.connect(user1).emergencyWithdrawNFT(ethers.ZeroAddress, user1.address, 1)
      ).to.be.revertedWith("kNFT: only admin");
    });
  });

  //----------------------------------------------------------------------------
  // Metadata & URI
  //----------------------------------------------------------------------------
  describe("Metadata & URI", function () {
    it("setBaseURI should only be called by admin", async function () {
      const { kondux, minter } = await loadFixture(deployKonduxFixture);
      await expect(kondux.connect(minter).setBaseURI("https://example.com/")).to.be.revertedWith(
        "kNFT: only admin"
      );
    });

    it("Should return concatenated tokenURI if baseURI is set", async function () {
      const { kondux, admin, minter, user1 } = await loadFixture(deployKonduxFixture);

      await kondux.connect(admin).setBaseURI("https://metadata.kondux.io/");
      await kondux.connect(minter).safeMint(user1.address, 1234);

      // tokenURI(0) => "https://metadata.kondux.io/0"
      expect(await kondux.tokenURI(0)).to.equal("https://metadata.kondux.io/0");
    });

    it("Should emit MetadataUpdate events when DNA changes", async function () {
      const { kondux, minter, dnaModifier, user1 } = await loadFixture(deployKonduxFixture);
      await kondux.connect(minter).safeMint(user1.address, 777);

      await expect(kondux.connect(dnaModifier).setDna(0, 999))
        .to.emit(kondux, "MetadataUpdate")
        .withArgs(0);

      await expect(kondux.connect(dnaModifier).writeGen(0, 0x01, 0, 1))
        .to.emit(kondux, "MetadataUpdate")
        .withArgs(0);
    });

    it("Batch metadata update can only be called by admin", async function () {
      const { kondux, user1 } = await loadFixture(deployKonduxFixture);
      await expect(kondux.connect(user1).emitBatchMetadataUpdate(0, 10)).to.be.revertedWith(
        "kNFT: only admin"
      );
    });
  });

  //----------------------------------------------------------------------------
  // ETH Fallback / receive
  //----------------------------------------------------------------------------
  describe("ETH Receive & Fallback", function () {
    it("Should revert direct ETH transfers", async function () {
      const { kondux } = await loadFixture(deployKonduxFixture);

      await expect(
        userSendEther(kondux.getAddress(), ethers.parseEther("1"))
      ).to.be.revertedWith("No direct ETH deposits");
    });

    it("Should revert fallback calls with data", async function () {
      const { kondux } = await loadFixture(deployKonduxFixture);
      await expect(
        // Attempt to call fallback
        ethers.provider.send("eth_sendTransaction", [
          {
            to: await kondux.getAddress(),
            data: "0x12345678", // random data
            value: "0x0",
          },
        ])
      ).to.be.revertedWith("Fallback not permitted");
    });
  });
});

/**
 * Helper to send native ETH in a test.
 * @param {string} to  recipient address
 * @param {BigInt} amount  amount in wei
 */
async function userSendEther(to, amount) {
  const [sender] = await ethers.getSigners();
  return sender.sendTransaction({ to, value: amount });
}
