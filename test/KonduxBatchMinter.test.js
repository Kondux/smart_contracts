const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers, network }   = require("hardhat");
const { expect }            = require("chai");

/* -------------------------------------------------------------------------- */
/* helpers                                                                    */
/* -------------------------------------------------------------------------- */

/** keccak256(abi.encodePacked(uint256[])) ‑ replicates solidity side */
function hashDnas(dnas) {
  const packed = ethers.concat(
    dnas.map((v) => ethers.toBeHex(v, 32))   // 32‑byte big‑endian words
  );
  return ethers.keccak256(packed);
}

/** build & sign the EIP‑712 authorisation */
async function signAuth({
  signer, verifyingContract, chainId,
  recipient, dnas, nonce, deadline, priceWei
}) {
  const domain = {
    name             : "Kondux kNFT",
    version          : "1",
    chainId,
    verifyingContract
  };
  const types = {
    MintAuthorisation: [
      { name: "recipient",  type: "address" },
      { name: "dnasHash",   type: "bytes32" },
      { name: "nonce",      type: "uint256" },
      { name: "deadline",   type: "uint256" },
      { name: "priceWei",   type: "uint256" }
    ]
  };
  const value = {
    recipient,
    dnasHash : hashDnas(dnas),
    nonce,
    deadline,
    priceWei
  };
  return signer.signTypedData(domain, types, value);
}

 /**
   * Utility: build a consecutive DNA array `[base, base+1, …]`
   */
  function buildDnas(count, base = 1) {
    return Array.from({ length: count }, (_, i) => base + i);
  }

  /**
   * Mint `qty` NFTs in *one* tx and assert supply / balances.
   * Uses priceWei = 0 to avoid hitting value limits.
   */
  async function mintBatch({ batch, kondux, signer, recipient, qty }) {
    const dnas      = buildDnas(qty);
    const priceWei  = 0n;
    const nonce     = Number(await batch.mintNonces(recipient.address));
    const deadline  = (await time.latest()) + 3600;

    const sig = await signAuth({
      signer,
      verifyingContract: await batch.getAddress(),
      chainId : (await ethers.provider.getNetwork()).chainId,
      recipient: recipient.address,
      dnas,
      nonce,
      deadline,
      priceWei
    });

    const supplyBefore = await kondux.totalSupply();
    const userBalanceBefore = await kondux.balanceOf(recipient.address);

    await batch.connect(recipient).mintBatchWithSignature(
      recipient.address, dnas, deadline, priceWei, nonce, sig, { value: priceWei }
    );

    expect(await kondux.totalSupply())
      .to.equal(supplyBefore + BigInt(qty));
    expect(await kondux.balanceOf(recipient.address))
      .to.equal(userBalanceBefore + BigInt(qty));
  }

/**
 * Deploy a clone through the KonduxBeaconFactory and return its address.
 *
 * @param factory   Deployed KonduxBeaconFactory contract
 * @param initArgs  Plain argument list for initialize(...)
 * @param signer    Signer that calls the factory
 */
async function deployCloneThroughFactory(factory, initArgs, signer) {
  /* ------------------------------------------------------------- */
  /* 1. encode the initialise() calldata                           */
  /* ------------------------------------------------------------- */
  const initIface = new ethers.Interface([
    "function initialize(string,string,address,address,address,address,address,uint256)"
  ]);

  // If the caller passed an *empty* array, skip initialization
  const initData = (initArgs.length === 0)
    ? "0x"
    : initIface.encodeFunctionData("initialize", initArgs);


  /* ------------------------------------------------------------- */
  /* 2. send the transaction                                       */
  /* ------------------------------------------------------------- */
  const tx   = await factory.connect(signer).deployClone(initData);
  const rcpt = await tx.wait();

  /* ------------------------------------------------------------- */
  /* 3a. fast path – parse logs in the receipt                     */
  /* ------------------------------------------------------------- */
  for (const log of rcpt.logs) {
    try {
      const parsed = factory.interface.parseLog(log);
      if (parsed.name === "CloneDeployed") return parsed.args.proxy;
    } catch { /* not emitted by the factory – ignore */ }
  }

  /* ------------------------------------------------------------- */
  /* 3b. fallback – query events from chain                        */
  /* ------------------------------------------------------------- */
  const evt = await factory.queryFilter(
    factory.filters.CloneDeployed(null, signer.address),
    rcpt.blockNumber,
    rcpt.blockNumber
  );

  if (evt.length > 0) return evt[0].args.proxy;

  throw new Error("Clone address not found; neither logs nor queryFilter returned a match");
}



describe("Kondux Batch Minter - Full Test Suite", function () {

  /**
   * Deploys KonduxImplementation (logic V1) *and* KonduxBeaconFactory,
   * then mints an initial clone that the rest of the test‑suite treats as
   * “the Kondux contract under test”.
   *
   * Returns an object with
   *   – kondux           : the first BeaconProxy clone (already initialised)
   *   – factory          : KonduxBeaconFactory
   *   – beacon           : UpgradeableBeacon
   *   – all the signers / constants you already used
   */
  async function deployKonduxFixture() {
    // --- Signers ---
    const [deployer, admin, minter, dnaModifier, user1, user2, treasurySigner] =
      await ethers.getSigners();

    /* ---- 1. deploy first implementation (logic V1) -------------------- */

    const Impl = await ethers.getContractFactory("KonduxImplementation");
    const impl = await Impl.deploy();
    await impl.waitForDeployment();

    /* ---- 2. deploy factory + beacon ----------------------------------- */

    const Factory = await ethers.getContractFactory("KonduxBeaconFactory");
    const factory = await Factory.deploy(await impl.getAddress());          // constructor arg
    await factory.waitForDeployment();
    const beacon = await ethers.getContractAt(
      "UpgradeableBeacon",
      await factory.beacon()
    );

    // If needed for fork-testing, you can impersonate real mainnet addresses like so:
    // const FOUNDER_PASS_HOLDER = "0x1234..."; // some real address that owns a founder pass
    // await network.provider.request({
    //   method: "hardhat_impersonateAccount",
    //   params: [FOUNDER_PASS_HOLDER],
    // });
    // const founderPassHolder = await ethers.getSigner(FOUNDER_PASS_HOLDER);
    // Then fund it if needed, etc.

    // 3. Mock addresses (replace with real addresses on a mainnet fork) ---
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

    // --- Grant roles to test accounts ---
    // By default, the deployer has DEFAULT_ADMIN_ROLE, MINTER_ROLE, DNA_MODIFIER_ROLE, but
    // you can explicitly set them if you want to test role management thoroughly.
    // Let's revoke from deployer and give them to the 'admin' for demonstration:
    // await kondux.revokeRole(await kondux.DEFAULT_ADMIN_ROLE(), deployer.address);
    // await kondux.revokeRole(await kondux.MINTER_ROLE(), deployer.address);
    // await kondux.revokeRole(await kondux.DNA_MODIFIER_ROLE(), deployer.address);

    /* ---- 5. deploy the first *uninitialised* clone via the factory ---- */
    const cloneAddr = await deployCloneThroughFactory(factory, [], deployer); // <- [] !!

    const kondux = await ethers.getContractAt("KonduxImplementation", cloneAddr);

    /* ---- 6. now initialise from an EOA that should become admin -------- */
    await kondux.connect(deployer).initialize(
      "KonduxNFT",
      "kNFT",
      uniswapV2Pair,
      WETH,
      KNDX,
      FOUNDERSPASS_ADDRESS,
      konduxTreasury,
      0                // maxSupply
    );
    
    // ---- Batch Minter Setup ----

    /* 1 ▸ deploy AuthorityMock (vault = treasurySigner) */
    const Authority = await ethers.getContractFactory("AuthorityMock");
    const authority = await Authority.deploy(konduxTreasury);
    await authority.waitForDeployment();

    /* 2 ▸ deploy KonduxBatchMinter */
    const Batch = await ethers.getContractFactory("KonduxBatchMinter");
    const batch = await Batch.deploy(await kondux.getAddress(), await authority.getAddress());
    await batch.waitForDeployment();

    // Grant to 'admin'
    await kondux.grantRole(await kondux.DEFAULT_ADMIN_ROLE(), admin.address);
    await kondux.grantRole(await kondux.MINTER_ROLE(), minter.address);
    await kondux.grantRole(await kondux.MINTER_ROLE(), await batch.getAddress());
    await kondux.grantRole(await kondux.DNA_MODIFIER_ROLE(), dnaModifier.address);

    const konduxAddress = await kondux.getAddress();

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
      factory,
      beacon,
      implV1: impl,
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
      founderPassHolder,
      impl,
      batch,
      authority
    };
  }

  /* ────────────────────────────────────────────────────────────────────── */
  /* 1. happy path                                                         */
  /* ────────────────────────────────────────────────────────────────────── */
  it("mints multiple NFTs & forwards ETH when signature is valid", async () => {
    const {
      batch, kondux, authority,
      deployer, user1
    } = await loadFixture(deployKonduxFixture);

    const dnas      = [111, 222, 333];
    const priceWei  = ethers.parseEther("0.05");
    const nonce     = 0;
    const deadline  = (await time.latest()) + 3600;           // +1 h

    /* signer with BATCH_MINTER_ROLE (deployer by default) */
    const sig = await signAuth({
      signer  : deployer,
      verifyingContract: await batch.getAddress(),
      chainId : (await ethers.provider.getNetwork()).chainId,
      recipient: user1.address,
      dnas,
      nonce,
      deadline,
      priceWei
    });

    const supplyBefore = await kondux.totalSupply();
    const vault        = await authority.vault();
    const balBefore    = await ethers.provider.getBalance(vault);

    const tx = await batch
      .connect(user1)
      .mintBatchWithSignature(
        user1.address,
        dnas,
        deadline,
        priceWei,
        nonce,
        sig,
        { value: priceWei }
      );

    await expect(tx)
      .to.emit(batch, "AuthorisedMint")
      .withArgs(deployer.address, user1.address, dnas, priceWei);

    expect(await kondux.totalSupply()).to.equal(supplyBefore + BigInt(dnas.length));
    expect(await kondux.balanceOf(user1.address)).to.equal(dnas.length);

    const balAfter = await ethers.provider.getBalance(vault);
    expect(balAfter - balBefore).to.equal(priceWei);

    expect(await batch.mintNonces(user1.address)).to.equal(1);
  });

  it("allows an admin to retarget the Kondux collection", async () => {
    const { batch, kondux, deployer, user1 } = await loadFixture(deployKonduxFixture);

    const MockKondux = await ethers.getContractFactory("MockKondux");
    const replacement = await MockKondux.deploy();
    await replacement.waitForDeployment();

    const replacementAddr = await replacement.getAddress();
    const originalAddr = await batch.kondux();
    const adminRole = await batch.DEFAULT_ADMIN_ROLE();

    await expect(batch.connect(user1).setKNFT(replacementAddr))
      .to.be.revertedWithCustomError(batch, "AccessControlUnauthorizedAccount")
      .withArgs(user1.address, adminRole);

    await expect(batch.connect(deployer).setKNFT(replacementAddr))
      .to.emit(batch, "KonduxTargetUpdated")
      .withArgs(originalAddr, replacementAddr);

    expect(await batch.kondux()).to.equal(replacementAddr);

    const dnas = [555];
    const price = 0n;
    const nonce = 0;
    const deadline = (await time.latest()) + 3600;

    const sig = await signAuth({
      signer: deployer,
      verifyingContract: await batch.getAddress(),
      chainId : (await ethers.provider.getNetwork()).chainId,
      recipient: user1.address,
      dnas,
      nonce,
      deadline,
      priceWei: price
    });

    await batch.connect(user1).mintBatchWithSignature(
      user1.address,
      dnas,
      deadline,
      price,
      nonce,
      sig,
      { value: price }
    );

    expect(await replacement.balanceOf(user1.address)).to.equal(1n);
    expect(await replacement.totalSupply()).to.equal(1n);
    expect(await kondux.balanceOf(user1.address)).to.equal(0);
  });

  /* ────────────────────────────────────────────────────────────────────── */
  /* 2. auth failures                                                      */
  /* ────────────────────────────────────────────────────────────────────── */
  it("reverts if signer lacks BATCH_MINTER_ROLE", async () => {
    const { batch, kondux, user1, user2, deployer } = await loadFixture(deployKonduxFixture);

    /* remove role from deployer, sign with user2 ------------------------ */
    await batch.connect(deployer).revokeRole(await batch.BATCH_MINTER_ROLE(), deployer.address);

    const dnas = [42];
    const price = 0n;
    const nonce = 0;
    const deadline = (await time.latest()) + 1000;

    const sig = await signAuth({
      signer  : user2,
      verifyingContract: await batch.getAddress(),
      chainId : (await ethers.provider.getNetwork()).chainId,
      recipient: user1.address,
      dnas, nonce, deadline, priceWei: price
    });

    await expect(
      batch.connect(user1).mintBatchWithSignature(
        user1.address, dnas, deadline, price, nonce, sig, { value: price }
      )
    ).to.be.revertedWith("kNFT: signer lacks BATCH_MINTER_ROLE");
  });

  it("reverts on expired deadline / wrong nonce / wrong ETH", async () => {
    const { batch, user1, deployer } = await loadFixture(deployKonduxFixture);

    const dnas      = [7];
    const priceWei  = ethers.parseEther("0.01");
    const nonce     = 0;
    const past      = (await time.latest()) - 10;

    /* expired ----------------------------------------- */
    const sig1 = await signAuth({
      signer: deployer,
      verifyingContract: await batch.getAddress(),
      chainId : (await ethers.provider.getNetwork()).chainId,
      recipient: user1.address,
      dnas, nonce, deadline: past, priceWei
    });
    await expect(
      batch.connect(user1).mintBatchWithSignature(
        user1.address, dnas, past, priceWei, nonce, sig1, { value: priceWei }
      )
    ).to.be.revertedWith("kNFT: auth expired");

    /* good deadline, but wrong ETH -------------------- */
    const deadline = (await time.latest()) + 1000;
    const sig2 = await signAuth({
      signer: deployer,
      verifyingContract: await batch.getAddress(),
      chainId : (await ethers.provider.getNetwork()).chainId,
      recipient: user1.address,
      dnas, nonce, deadline, priceWei
    });
    await expect(
      batch.connect(user1).mintBatchWithSignature(
        user1.address, dnas, deadline, priceWei, nonce, sig2, { value: 0 }
      )
    ).to.be.revertedWith("kNFT: wrong ETH");

    /* good ETH, but nonce already used --------------- */
    await batch.connect(user1).mintBatchWithSignature(
      user1.address, dnas, deadline, priceWei, nonce, sig2, { value: priceWei }
    );                                     // first succeeds

    const sig3 = await signAuth({
      signer: deployer,
      verifyingContract: await batch.getAddress(),
      chainId : (await ethers.provider.getNetwork()).chainId,
      recipient: user1.address,
      dnas, nonce, deadline, priceWei       // re‑using nonce 0
    });
    await expect(
      batch.connect(user1).mintBatchWithSignature(
        user1.address, dnas, deadline, priceWei, nonce, sig3, { value: priceWei }
      )
    ).to.be.revertedWith("kNFT: bad nonce");
  });

  /* ────────────────────────────────────────────────────────────────────── */
  /* 3. paused & vault zero                                                */
  /* ────────────────────────────────────────────────────────────────────── */
  it("respects pause switch", async () => {
    const { batch, deployer, user1 } = await loadFixture(deployKonduxFixture);

    await batch.connect(deployer).setPaused(true);
    expect(await batch.paused()).to.be.true;

    const dnas = [1];
    const price = 0n;
    const deadline = (await time.latest()) + 1000;
    const sig = await signAuth({
      signer: deployer,
      verifyingContract: await batch.getAddress(),
      chainId : (await ethers.provider.getNetwork()).chainId,
      recipient: user1.address,
      dnas, nonce: 0, deadline, priceWei: price
    });

    await expect(
      batch.connect(user1).mintBatchWithSignature(
        user1.address, dnas, deadline, price, 0, sig, { value: price }
      )
    ).to.be.revertedWith("kNFT: paused");
  });

  it("reverts if Authority returns zero vault", async () => {
    const {
      kondux, deployer, user1,
      /* we need a fresh Authority with zero vault: */ beacon
    } = await loadFixture(deployKonduxFixture);

    /* zero‑vault authority */
    const Authority = await ethers.getContractFactory("AuthorityMock");
    const authority = await Authority.deploy(ethers.ZeroAddress);
    await authority.waitForDeployment();

    /* batch minter */
    const Batch = await ethers.getContractFactory("KonduxBatchMinter");
    const batch  = await Batch.deploy(await kondux.getAddress(), await authority.getAddress());
    await batch.waitForDeployment();

    /* grant BATCH_MINTER_ROLE to the batch minter */
    await kondux.grantRole(await kondux.MINTER_ROLE(), await batch.getAddress());

    /* sign data */
    const dnas = [99];
    const priceWei = 0n;
    const deadline = (await time.latest()) + 1000;
    const sig = await signAuth({
      signer: deployer,
      verifyingContract: await batch.getAddress(),
      chainId : (await ethers.provider.getNetwork()).chainId,
      recipient: user1.address,
      dnas, nonce: 0, deadline, priceWei
    });

    await expect(
      batch.connect(user1).mintBatchWithSignature(
        user1.address, dnas, deadline, priceWei, 0, sig, { value: priceWei }
      )
    ).to.be.revertedWith("kNFT: vault zero");
  });

   it("mints 50 NFTs in a single authorised batch", async () => {
    const { batch, kondux, deployer, user1 } = await loadFixture(deployKonduxFixture);
    await mintBatch({ batch, kondux, signer: deployer, recipient: user1, qty: 50 });
  });

  it("mints 150 NFTs in one go (close to 30 M gas block‑limit)", async () => {
    const { batch, kondux, deployer, user1 } = await loadFixture(deployKonduxFixture);
    /* 150 × ≈200 k gas ≈ 30 M – should still fit on Hardhat */
    await mintBatch({ batch, kondux, signer: deployer, recipient: user1, qty: 150 });
  });

  it("mints 1 000 NFTs over ten consecutive batches of 100 each", async () => {
    const { batch, kondux, deployer, user1 } = await loadFixture(deployKonduxFixture);

    const batchIterations = 10; 

    for (let i = 0; i < batchIterations; i++) {
      await mintBatch({
        batch,
        kondux,
        signer   : deployer,
        recipient: user1,
        qty      : 100
      });
    }

    /* final sanity‑check */
    expect(await kondux.balanceOf(user1.address)).to.equal(100 * batchIterations);
  });

  it("reverts if attempting an *oversized* batch (e.g. 250) that exhausts block gas", async () => {
    const { batch, deployer, user1 } = await loadFixture(deployKonduxFixture);

    const dnas      = buildDnas(250);
    const priceWei  = 0n;
    const nonce     = 0;
    const deadline  = (await time.latest()) + 3600;

    const sig = await signAuth({
      signer: deployer,
      verifyingContract: await batch.getAddress(),
      chainId : (await ethers.provider.getNetwork()).chainId,
      recipient: user1.address,
      dnas, nonce, deadline, priceWei
    });

    /* Expect out‑of‑gas (or intrinsic gas too high) → generic revert       */
    await expect(
      batch.connect(user1).mintBatchWithSignature(
        user1.address, dnas, deadline, priceWei, nonce, sig, { value: priceWei }
      )
    ).to.be.reverted;
  });

  
});