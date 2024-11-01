
# In-Depth Analysis of the Kondux Staking Smart Contract

  

## Introduction

  

The Kondux Staking Smart Contract is a sophisticated Solidity-based Ethereum smart contract that enables users to stake KNDX ERC20 tokens and receive HELIX ERC20 tokens as a representation of their stake. The contract is designed to provide users with rewards based on their staked amount, time duration, and additional boosts from holding specific NFTs. It incorporates features like compounding, early unstaking penalties, and dynamic reward calculations.

  

This analysis provides an in-depth examination of the contract's architecture, functions, data structures, and programming nuances. It aims to give developers and programmers a comprehensive understanding of how the contract operates, highlighting key mechanisms, security considerations, and best practices employed.

  

---

  

## Table of Contents

  

- [In-Depth Analysis of the Kondux Staking Smart Contract](#in-depth-analysis-of-the-kondux-staking-smart-contract)
  - [Introduction](#introduction)
  - [Table of Contents](#table-of-contents)
  - [1. Data Structures and State Variables](#1-data-structures-and-state-variables)
    - [**1.1 Staker Struct**](#11-staker-struct)
    - [**1.2 Mappings and Arrays**](#12-mappings-and-arrays)
    - [**1.3 External Contract Interfaces**](#13-external-contract-interfaces)
  - [2. Modifiers and Access Control](#2-modifiers-and-access-control)
    - [**2.1 Authority Pattern**](#21-authority-pattern)
    - [**2.2 User Authorization**](#22-user-authorization)
  - [3. Staking Mechanisms](#3-staking-mechanisms)
    - [**3.1 Deposit Function**](#31-deposit-function)
      - [**Function Signature:**](#function-signature)
      - [**Process Overview:**](#process-overview)
      - [**Code Snippet:**](#code-snippet)
  - [4. Reward Calculation Mechanisms](#4-reward-calculation-mechanisms)
    - [**4.1 Reward Calculation Logic**](#41-reward-calculation-logic)
      - [**Function Signature:**](#function-signature-1)
      - [**Process Overview:**](#process-overview-1)
      - [**Code Snippet:**](#code-snippet-1)
    - [**4.2 Boost Calculation Functions**](#42-boost-calculation-functions)
      - [**a. Founder's NFT Boost**](#a-founders-nft-boost)
      - [**b. kNFT Boosts**](#b-knft-boosts)
      - [**c. Timelock Category Boost**](#c-timelock-category-boost)
  - [5. NFT Integration for Boosts](#5-nft-integration-for-boosts)
    - [**5.1 kNFT Boost Calculation**](#51-knft-boost-calculation)
      - [**Function Signature:**](#function-signature-2)
      - [**Process Overview:**](#process-overview-2)
      - [**Key Nuances:**](#key-nuances)
    - [**5.2 Founder's NFT Integration**](#52-founders-nft-integration)
  - [6. Compounding and Claiming Rewards](#6-compounding-and-claiming-rewards)
    - [**6.1 Compounding Rewards**](#61-compounding-rewards)
      - [**Function Signature:**](#function-signature-3)
      - [**Process Overview:**](#process-overview-3)
      - [**Key Nuances:**](#key-nuances-1)
    - [**6.2 Claiming Rewards**](#62-claiming-rewards)
      - [**Function Signature:**](#function-signature-4)
      - [**Process Overview:**](#process-overview-4)
      - [**Key Nuances:**](#key-nuances-2)
  - [7. Unstaking and Early Withdrawal Penalties](#7-unstaking-and-early-withdrawal-penalties)
    - [**7.1 Standard Unstaking**](#71-standard-unstaking)
      - [**Function Signature:**](#function-signature-5)
      - [**Process Overview:**](#process-overview-5)
    - [**7.2 Early Unstaking**](#72-early-unstaking)
      - [**Penalty Calculation:**](#penalty-calculation)
      - [**Function Signature:**](#function-signature-6)
      - [**Process Overview:**](#process-overview-6)
  - [8. Administrative and Configuration Functions](#8-administrative-and-configuration-functions)
    - [**8.1 Setting Parameters**](#81-setting-parameters)
      - [**Examples:**](#examples)
    - [**8.2 Adding New Staking Tokens**](#82-adding-new-staking-tokens)
      - [**Function Signature:**](#function-signature-7)
      - [**Process Overview:**](#process-overview-7)
  - [9. Getter Functions and User Interfaces](#9-getter-functions-and-user-interfaces)
  - [10. Internal Utility Functions](#10-internal-utility-functions)
  - [Handling Nuances and Best Practices](#handling-nuances-and-best-practices)
    - [**Decimals and Precision**](#decimals-and-precision)
    - [**External Contract Interactions**](#external-contract-interactions)
    - [**Security Considerations**](#security-considerations)
    - [**Event Emissions**](#event-emissions)
    - [**Extensibility and Flexibility**](#extensibility-and-flexibility)

  

---

  

## 1. Data Structures and State Variables

  

###  **1.1 Staker Struct**

  

The `Staker` struct is central to the contract's functionality. It stores information about each individual deposit made by a user.

  

```solidity

struct Staker {
    uint256 deposited; // Amount of tokens staked
    uint256 timeOfLastUpdate; // Timestamp of the last reward calculation
    uint256 unclaimedRewards; // Accumulated rewards not yet claimed or compounded
    uint256 lastDepositTime; // Timestamp of the initial deposit
    uint256 timelock; // Timestamp when the timelock expires
    uint8 timelockCategory; // Category of the timelock (e.g., 0 for 30 days)
    uint256 ratioERC20; // Ratio between HELIX and KNDX tokens
    address staker; // Address of the user who made the deposit
    address token; // Address of the staked token (KNDX)
}

```

  

**Key Considerations:**

  

-  **Timelock Mechanism:** The `timelock` and `timelockCategory` fields facilitate the implementation of locking periods, which affect reward boosts and early withdrawal penalties.

-  **Token Ratio:**  `ratioERC20` ensures the correct conversion between different tokens, accounting for decimal differences.

  

###  **1.2 Mappings and Arrays**

  

-  `mapping(uint256 => Staker) public userDeposits;`

- Maps a unique deposit ID to a `Staker` struct.

-  `mapping(address => uint256[]) public userDepositsIds;`

- Maps a user's address to an array of their deposit IDs.

  

**Additional Mappings:**

  

-  **Token Parameters:**

-  `mapping(address => uint256) public aprERC20;` (APR for each token)

-  `mapping(address => uint256) public withdrawalFeeERC20;` (Withdrawal fee for each token)

-  `mapping(address => uint256) public minStakeERC20;` (Minimum stake amount for each token)

-  `mapping(address => uint8) public decimalsERC20;` (Decimals for each token)

  

-  **Boost Parameters:**

-  `mapping(address => uint256) public foundersRewardBoostERC20;`

-  `mapping(address => uint256) public kNFTRewardBoostERC20;`

  

-  **Staking Totals:**

-  `mapping(address => uint256) public totalStaked;` (Total staked per token)

-  `mapping(address => mapping(address => uint256)) public userTotalStakedByCoin;`

  

-  **Reward Tracking:**

-  `mapping(address => uint256) public totalRewarded;` (Total rewards per token)

-  `mapping(address => mapping(address => uint256)) public userTotalRewardedByCoin;`

  

###  **1.3 External Contract Interfaces**

  

-  `IERC20 public helixERC20;` (HELIX token contract)

-  `IERC20 public konduxERC20;` (KNDX token contract)

-  `IERC721 public konduxERC721Founders;` (Founder's NFT contract)

-  `address public konduxERC721kNFT;` (kNFT contract address)

-  `ITreasury public treasury;` (Treasury contract for handling token transfers)

  

---

  

## 2. Modifiers and Access Control

  

###  **2.1 Authority Pattern**

  

The contract utilizes an `Authority` contract for role management, ensuring that only authorized addresses can perform certain actions.

  

-  `modifier onlyGovernor()`: Ensures that only the governor (admin) can execute specific functions.

  

```solidity

modifier onlyGovernor() {
    require(authority.isGovernor(msg.sender), "Not authorized");
    _;
}

```

  

###  **2.2 User Authorization**

  

-  **Ownership Checks:** Functions like `withdraw` and `calculateRewards` verify that the caller owns the deposit in question.

  

```solidity

require(msg.sender == userDeposits[_depositId].staker, "Not the deposit owner");

```

  

---

  

## 3. Staking Mechanisms

  

###  **3.1 Deposit Function**

  

####  **Function Signature:**

  

```solidity

function deposit(uint256 _amount, uint8 _timelockCategory, address _token) external nonReentrant {
    // Function body
}

```

  

####  **Process Overview:**

  

1.  **Validation:**

- Checks if the token is authorized for staking.

- Verifies that the amount is greater than or equal to the minimum stake.

- Ensures the user has enough balance and has approved the contract to spend their tokens.

  

2.  **Timelock Determination:**

- Calculates the timelock expiration based on the selected category.

- Timelock durations are predefined in a mapping.

  

3.  **Token Transfer:**

- Transfers the staked tokens from the user to the Treasury contract.

  

4.  **HELIX Token Minting:**

- Mints HELIX tokens to the user at the defined ratio (e.g., 10,000 HELIX per 1 KNDX).

- Adjusts for decimal differences between tokens.

  

5.  **Recording the Deposit:**

- Creates a new `Staker` struct and stores it in `userDeposits`.

- Updates `userDepositsIds` to include the new deposit ID.

  

6.  **Updating Totals:**

- Updates the total staked amounts for both the token and the user.

  

####  **Code Snippet:**

  

```solidity

require(authorizedERC20[_token], "Token not authorized");
require(_amount >= minStakeERC20[_token], "Amount below minimum stake");
  
uint256 lockDuration = timelockOptions[_timelockCategory];
uint256 timelockExpiration = block.timestamp + lockDuration;

konduxERC20.transferFrom(msg.sender, address(treasury), _amount);
  
uint256 helixAmount = (_amount * ratioERC20[_token]) / (10 ** decimalsERC20[_token]);
helixERC20.mint(msg.sender, helixAmount);
  
Staker memory newDeposit = Staker({
    deposited: _amount,
    timeOfLastUpdate: block.timestamp,
    unclaimedRewards: 0,
    lastDepositTime: block.timestamp,
    timelock: timelockExpiration,
    timelockCategory: _timelockCategory,
    ratioERC20: ratioERC20[_token],
    staker: msg.sender,
    token: _token
});

userDeposits[depositIdCounter] = newDeposit;
userDepositsIds[msg.sender].push(depositIdCounter);
depositIdCounter++;

```

  

**Key Nuances:**

  

-  **Decimals Handling:** The contract accounts for different decimals between KNDX and HELIX tokens to ensure accurate conversions.

-  **Reentrancy Guard:** Uses `nonReentrant` modifier to prevent reentrancy attacks during the deposit process.

  

---

  

## 4. Reward Calculation Mechanisms

  

###  **4.1 Reward Calculation Logic**

  

####  **Function Signature:**

  

```solidity

function calculateRewards(address _staker, uint _depositId) public view returns (uint256) {
    // Function body
}

```

  

####  **Process Overview:**

  

1.  **Ownership Verification:**

- Ensures that the caller is the owner of the deposit.

  

2.  **Time Calculation:**

- Calculates the time elapsed since the last update.

- If no time has elapsed, returns zero rewards.

  

3.  **Base Reward Calculation:**

- Determines the base reward using the formula:

  

$$ 
R_{\text{base}} = \left( \frac{D \times \text{APR} \times T_{\text{elapsed}}}{365 \times 24 \times 3600 \times 100} \right)
$$

  

Where:

  

- $( R_{\text{base}} )$ = Base Reward

- $( D )$ = Deposited Amount

- $( \text{APR} )$ = Annual Percentage Rate

- $( T_{\text{elapsed}} )$ = Time Elapsed (in seconds)

  

4.  **Boost Calculation:**

- Calculates the total boost percentage from:

- Founder's NFT

- Top 5 kNFTs

- Timelock category

- Adds these boosts to the base divisor.

  

5.  **Adjusted Reward Calculation:**

- Applies the total boost to the base reward:

  

$$
R_{\text{total}} = R_{\text{base}} \times \left(1 + \frac{B}{100}\right)
$$

  

Where:

  

- $( R_{\text{total}} )$ = Total Reward after applying boosts

- $( B )$ = Total Boost Percentage

  

6.  **Return Value:**

- Returns the total calculated rewards.

  

####  **Code Snippet:**

  

```solidity

Staker memory deposit = userDeposits[_depositId];

uint256 timeElapsed = block.timestamp - deposit.timeOfLastUpdate;
if (timeElapsed == 0) {
    return 0;
}
  
uint256 baseReward = (deposit.deposited * aprERC20[deposit.token] * timeElapsed) / (365 * 24 * 3600 * 100);
  
uint256 boostPercentage = calculateBoostPercentage(_staker, _depositId);
uint256 totalReward = (baseReward * (100 + boostPercentage)) / 100;
  
return totalReward;

```

  

**Key Nuances:**

  

-  **Time Units:** Uses seconds for `timeElapsed` and converts APR from annual to per-second basis.

-  **Scaling Factor:** Adjusts calculations to maintain precision.

-  **Boost Integration:** Boosts are dynamically calculated based on the user's holdings at the time of calculation.

  

###  **4.2 Boost Calculation Functions**

  

####  **a. Founder's NFT Boost**

  

```solidity

if (konduxERC721Founders.balanceOf(_staker) > 0) {
    boostPercentage += foundersRewardBoostERC20[deposit.token];
}

```

  

-  **Logic:** If the user holds at least one Founder's NFT, a fixed boost is added.

  

####  **b. kNFT Boosts**

  

```solidity

uint256 knftBoost = calculateKNFTBoostPercentage(_staker, _depositId);
boostPercentage += knftBoost;

```

  

-  **Logic:** Calculates boosts from the user's top 5 kNFTs based on their "bonus genes."

  

####  **c. Timelock Category Boost**

  

```solidity

if (deposit.timelockCategory > 0) {
    boostPercentage += timelockCategoryBoost[deposit.timelockCategory];
}

```

  

-  **Logic:** Adds a boost based on the selected timelock category.

  

---

  

## 5. NFT Integration for Boosts

  

###  **5.1 kNFT Boost Calculation**

  

####  **Function Signature:**

  

```solidity

function calculateKNFTBoostPercentage(address _staker, uint256 _stakeId) public view returns (uint256) {
    // Function body
}

```

  

####  **Process Overview:**

  

1.  **Retrieve kNFT Balance:**

- Gets the total number of kNFTs owned by the user.

  

2.  **Iterate Over kNFTs:**

- Loops through each kNFT to extract its boost value.

  

3.  **DNA Version Check:**

- Only considers kNFTs with allowed DNA versions.

  

4.  **Bonus Gene Extraction:**

- Reads the "bonus gene" from the kNFT's DNA using `readGen` function.

  

5.  **Top 5 Boosts Selection:**

- Maintains an array of the top 5 boosts and their corresponding kNFT IDs.

  

6.  **Total Boost Calculation:**

- Sums up the boosts from the top 5 kNFTs.

  

####  **Key Nuances:**

  

-  **Interaction with External Contract:** Reads genetic data from kNFTs using the `IKondux` interface.

-  **Data Validation:** Ensures that only kNFTs with allowed DNA versions and positive boosts are considered.

-  **Boost Limitation:** Only the top 5 boosts are considered to prevent excessive stacking.

  

###  **5.2 Founder's NFT Integration**

  

-  **Simple Check:** Uses `balanceOf` to determine if the user holds at least one Founder's NFT.

-  **Fixed Boost:** Adds a predefined boost percentage if the condition is met.

  

---

  

## 6. Compounding and Claiming Rewards

  

###  **6.1 Compounding Rewards**

  

####  **Function Signature:**

  

```solidity

function stakeRewards(uint _depositId) external nonReentrant {
    // Function body
}

```

  

####  **Process Overview:**

  

1.  **Ownership Verification:**

- Checks that the caller owns the deposit.

  

2.  **Reward Calculation:**

- Calculates both unclaimed and new rewards.

  

3.  **Compounding:**

- Adds the total rewards to the `deposited` amount.

- Resets `unclaimedRewards` to zero.

  

4.  **HELIX Token Minting:**

- Mints additional HELIX tokens corresponding to the compounded amount.

  

5.  **Updating State:**

- Updates `timeOfLastUpdate` to the current timestamp.

  

####  **Key Nuances:**

  

-  **Compounding Frequency:** Users can compound at any time, but doing so more frequently may result in higher gas costs.

-  **Timelock Independence:** Compounding is allowed even after the timelock period has ended.

  

###  **6.2 Claiming Rewards**

  

####  **Function Signature:**

  

```solidity

function claimRewards(uint _depositId) external nonReentrant {
    // Function body
}

```

  

####  **Process Overview:**

  

1.  **Ownership and Timelock Check:**

- Verifies that the caller owns the deposit and the timelock has expired.

  

2.  **Reward Calculation:**

- Calculates total rewards (unclaimed + new).

  

3.  **Fee Application:**

- Applies the withdrawal fee to the rewards.

  

4.  **Token Transfer:**

- Transfers the net rewards from the Treasury to the user.

  

5.  **State Update:**

- Resets `unclaimedRewards` and updates `timeOfLastUpdate`.

  

####  **Key Nuances:**

  

-  **Withdrawal Fee:** Ensures that a portion of the rewards is collected as a fee, benefiting the ecosystem or treasury.

-  **Allowance Checks:** Verifies that the Treasury contract has approved the staking contract to transfer tokens on its behalf.

  

---

  

## 7. Unstaking and Early Withdrawal Penalties

  

###  **7.1 Standard Unstaking**

  

####  **Function Signature:**

  

```solidity

function withdraw(uint256 _amount, uint _depositId) external nonReentrant {
    // Function body
}

```

  

####  **Process Overview:**

  

1.  **Ownership and Balance Verification:**

- Checks that the caller owns the deposit and has enough staked balance.

  

2.  **Timelock Verification:**

- Ensures the timelock period has expired.

  

3.  **Reward Calculation and Reset:**

- Calculates rewards and resets `unclaimedRewards`.

  

4.  **Fee Application:**

- Applies the withdrawal fee to the amount.

  

5.  **HELIX Token Burning:**

- Burns the corresponding amount of HELIX tokens.

  

6.  **Token Transfer:**

- Transfers the net amount of tokens back to the user from the Treasury.

  

7.  **State Update:**

- Updates the deposited amount and total staked amounts.

  

###  **7.2 Early Unstaking**

  

####  **Penalty Calculation:**

  

The early withdrawal penalty is calculated as follows:

  

$$
E = \left( \frac{A \times P \times T}{L \times  100} \right)
$$

  

Where:

  

-  \( E \) = Extra Fee (Penalty)

-  \( A \) = Amount being unstaked

-  \( P \) = Penalty Percentage (e.g., 10)

-  \( T \) = Time Left in the timelock period

-  \( L \) = Total Lock Duration

  

**Minimum Penalty Enforcement:**

  

If the calculated penalty \( E \) is less than 1% of the amount \( A \), a minimum penalty of 1% is applied:

  

$$
\text{If } E < \left( \frac{A \times  1}{100} \right), \quad \text{then } E = \left( \frac{A \times  1}{100} \right)
$$

  

####  **Function Signature:**

  

```solidity

function earlyUnstake(uint256 _amount, uint _depositId) external nonReentrant {
    // Function body
}

```

  

####  **Process Overview:**

  

1.  **Ownership and Balance Verification:**

- Ensure the caller owns the deposit and has sufficient staked balance.

  

2.  **Penalty Calculation:**

- Compute \( E \) using the formula above.

- Apply the minimum penalty if necessary.

  

3.  **Reward Loss:**

- Users forfeit any unclaimed rewards and boosts.

  

4.  **Fee Application:**

- Apply both the standard withdrawal fee and the early unstaking penalty \( E \).

  

5.  **HELIX Token Burning:**

- Burn the corresponding amount of HELIX tokens.

  

6.  **Token Transfer:**

- Transfer the net amount $( (A - \text{Withdrawal Fee} - E) )$ back to the user.

  

7.  **State Update:**

- Update deposited amounts and totals.

  

**Key Nuances:**

  

-  **Fair Penalty System:** The regressive penalty incentivizes users to adhere to their selected timelock durations.

-  **Boost Forfeiture:** Early unstaking results in the loss of any accumulated boosts, aligning with the contract's incentive mechanisms.

  

---

  

## 8. Administrative and Configuration Functions

  

###  **8.1 Setting Parameters**

  

The contract allows the governor to set and update various parameters.

  

####  **Examples:**

  

-  **Set APR:**

  

```solidity

function setAPR(uint256 _apr, address _token) external onlyGovernor {
    aprERC20[_token] = _apr;
    emit NewAPR(_apr, _token);
}

```

  

-  **Set Withdrawal Fee:**

  

```solidity

function setWithdrawalFee(uint256 _fee, address _token) external onlyGovernor {
    withdrawalFeeERC20[_token] = _fee;
    emit NewWithdrawalFee(_fee, _token);
}

```

  

-  **Authorize Tokens:**

  

```solidity

function setAuthorizedERC20(address _token, bool _authorized) external onlyGovernor {
    authorizedERC20[_token] = _authorized;
    emit NewAuthorizedERC20(_token, _authorized);
}

```

  

###  **8.2 Adding New Staking Tokens**

  

####  **Function Signature:**

  

```solidity

function addNewStakingToken(
    address _token,
    uint256 _apr,
    uint256 _compoundFreq,
    uint256 _withdrawalFee,
    uint256 _foundersRewardBoost,
    uint256 _kNFTRewardBoost,
    uint256 _ratio,
    uint256 _minStake
) external onlyGovernor {
    // Function body
}

```

  

####  **Process Overview:**

  

1.  **Validation:**

- Checks that the token address is valid and parameters are set appropriately.

  

2.  **Parameter Setting:**

- Sets all necessary parameters for the new token.

  

3.  **Authorization:**

- Authorizes the token for staking.

  

**Key Nuances:**

  

-  **Extensibility:** Allows the contract to support multiple tokens beyond KNDX.

  

---

  

## 9. Getter Functions and User Interfaces

  

The contract provides several public view functions to retrieve information:

  

-  **`getDepositInfo(uint _depositId)`**: Returns the staked amount and unclaimed rewards.

-  **`getTotalStaked(address _token)`**: Returns the total staked amount for a token.

-  **`calculateKNFTBoostPercentage(address _staker, uint256 _stakeId)`**: Calculates the kNFT boost percentage.

-  **`getDepositDetails(address _staker, uint _stakeId)`**: Aggregates various details about a deposit.

  

**Key Nuances:**

  

-  **Transparency:** Facilitates frontend integration by providing necessary data for user interfaces.

-  **User-Friendly:** Allows users to query their staking status and potential rewards.

  

---

  

## 10. Internal Utility Functions

  

These functions perform internal state updates and calculations:

  

-  **Total Staked Amount Updates:**

  

```solidity

function _addTotalStakedAmount(uint256 _amount, address _token, address _user) internal {
    totalStaked[_token] += _amount;
    userTotalStakedByCoin[_token][_user] += _amount;
}

```

  

-  **Total Rewarded Amount Updates:**

  

```solidity

function _addTotalRewardedAmount(uint256 _amount, address _token, address _user) internal {
    totalRewarded[_token] += _amount;
    userTotalRewardedByCoin[_token][_user] += _amount;
}

```

  

-  **Withdrawal Fees Tracking:**

  

```solidity

function _addTotalWithdrawalFees(uint256 _amount, address _token) internal {
    totalWithdrawalFees[_token] += _amount;
}

```

  

**Key Nuances:**

  

-  **State Consistency:** Ensures that global and user-specific totals remain accurate.

-  **Internal Access:** These functions are `internal`, preventing external access and maintaining encapsulation.

  

---

  

## Handling Nuances and Best Practices

  

###  **Decimals and Precision**

  

-  **Token Decimals:** The contract accounts for varying decimals between tokens by retrieving decimals via `IERC20Metadata(_token).decimals()`.

-  **Scaling Factors:** Uses factors like `1e18` to maintain precision during mathematical operations.

  

###  **External Contract Interactions**

  

-  **Interfaces:** Utilizes interfaces like `IERC20`, `IERC721`, `IKondux` for interacting with external contracts.

-  **Allowance Checks:** Verifies that the Treasury or other contracts have approved necessary token transfers.

  

###  **Security Considerations**

  

-  **Reentrancy Guards:** Implements `nonReentrant` modifiers on state-changing functions to prevent reentrancy attacks.

-  **Ownership and Access Control:** Ensures that only authorized users can perform certain actions.

-  **Input Validation:** Checks inputs for validity, such as non-zero addresses and acceptable parameter ranges.

  

###  **Event Emissions**

  

-  **Transparency:** Emits events like `NewAPR`, `Deposit`, `Withdraw` to enable off-chain monitoring and frontend updates.

  

###  **Extensibility and Flexibility**

  

-  **Dynamic Parameter Configuration:** Allows the governor to adjust parameters as needed, adapting to changing requirements.

-  **Support for Multiple Tokens:** Designed to handle multiple staking tokens with individualized settings.

  
