# Comprehensive Guide to the Kondux Staking Smart Contract

## Introduction

Welcome to the Kondux Staking Smart Contract—a cutting-edge decentralized finance (DeFi) platform that empowers you to maximize your earnings by staking your KNDX tokens and receiving HELIX tokens in return. This innovative staking system offers flexible locking periods, compound interest, and additional bonuses for NFT holders. Whether you're new to DeFi or an experienced investor, this guide will provide a detailed overview of how the Kondux Staking Smart Contract works and how you can optimize your staking strategy.

---

## Key Features and Rules

### **1. Token Staking**

- **Stakable Token:** KNDX ERC20 tokens.
- **Reward Token:** HELIX ERC20 tokens, minted upon staking.

### **2. Reward Ratio**

- **Exchange Rate:** For every **1 KNDX** staked, you receive **10,000 HELIX** tokens.

### **3. Minimum Stake Amount**

- **Minimum Stake:** **10,000,000 KNDX wei** (equivalent to **0.00000001 KNDX**).

### **4. Reward Calculation**

- **Base APR:** **25%** annual percentage rate.
- **Rewards per Hour:** Approximately **0.00285%**.
- **Compound Frequency:** Rewards can be compounded every **24 hours**.

### **5. Bonuses and Boosts**

#### **a. Founder's NFT Bonus**

- **Boost:** Holding at least one Founder's NFT grants a **10%** boost on rewards.

#### **b. kNFT Bonus**

- **Boost Range:** Each kNFT provides a boost ranging from **1% to 5%** based on its "bonus gene."
- **Stacking Limit:** Boosts from up to **5 kNFTs** are considered, focusing on those with the highest boosts.

#### **c. Locking Periods & Reward Boosts**

- **Locking Periods and Boosts:**
  - **30 days:** Standard rewards (**0%** boost).
  - **90 days:** **1%** reward boost.
  - **180 days:** **3%** reward boost.
  - **365 days:** **9%** reward boost.
  - **Testing Periods (for testing purposes only):**
    - **2 minutes:** **0%** reward boost.
    - **24 hours (1 day):** **50%** reward boost.
    - **48 hours (2 days):** **100%** reward boost.

### **6. Early Unstaking and Penalties**

- **Early Unstaking:** Allowed but incurs a regressive penalty.
- **Penalty Calculation:** Based on the time remaining in the locking period—the longer the remaining time, the higher the penalty.
- **Minimum Penalty:** If the calculated penalty is less than **1%**, a minimum of **1%** is applied.

### **7. Withdrawal Fee**

- **Standard Fee:** A **1%** withdrawal fee applies when unstaking after the locking period.

### **8. Helix Burning**

- **Requirement:** To withdraw KNDX, you must burn HELIX tokens at the same rate you received them (**10,000 HELIX** per **1 KNDX**).

---

## How the Staking Contract Works

### **1. Staking Tokens**

When you stake your KNDX tokens:

- **Function Invoked:** `deposit(uint256 _amount, uint8 _timelock, address _token)`
- **Process:**
  - Verify that KNDX is authorized for staking and you meet the minimum stake amount.
  - Check your KNDX balance and allowance.
  - Transfer your KNDX tokens to the Treasury contract.
  - Mint HELIX tokens to your wallet at the **10,000:1** ratio.
  - Record your staking details, including the amount, timelock, and boosts.

### **2. Calculating Rewards**

Your rewards are calculated based on:

- **Staked Amount:** The total KNDX you've staked.
- **Base APR:** **25%**.
- **Time Elapsed:** Since your last update or compounding.
- **Total Boost Percentage:** Sum of boosts from Founder's NFTs, kNFTs, and locking periods.

#### **Boost Calculation Details**

- **Founder's NFT Boost:**
  - **10%** boost if you hold at least one Founder's NFT.
- **kNFT Boosts:**
  - The contract identifies your top **5 kNFTs** based on their "bonus genes."
  - Boosts from these kNFTs are cumulative, up to a maximum of the sum of their boosts.
- **Locking Period Boost:**
  - Additional boosts based on the length of your selected locking period.

#### **Reward Formula**

The rewards are calculated using the following formula:

1. **Calculate Adjusted APR:**

   $$\text{Adjusted APR} = \text{Base APR} \times \left(1 + \frac{\text{Total Boost Percentage}}{100}\right)$$

2. **Calculate Rewards Earned:**

   $$\text{Rewards Earned} = \text{Staked Amount} \times \left( \frac{\text{Adjusted APR}}{365} \times \text{Days Staked} \right)$$

### **3. Compounding Rewards**

- **Function Invoked:** `stakeRewards(uint _depositId)`
- **Process:**
  - Calculate your unclaimed rewards.
  - Add rewards to your staked amount.
  - Mint additional HELIX tokens to represent the increased stake.
  - Update your staking records.

### **4. Claiming Rewards**

- **Function Invoked:** `claimRewards(uint _depositId)`
- **Conditions:** Timelock period must have ended.
- **Process:**
  - Calculate total rewards, including unclaimed rewards.
  - Apply the **1%** withdrawal fee.
  - Transfer net rewards to your wallet.
  - Reset unclaimed rewards to zero.

### **5. Unstaking Tokens**

- **Function Invoked:** `withdraw(uint256 _amount, uint _depositId)`
- **Conditions:** Timelock period must have ended.
- **Process:**
  - Deduct the withdrawal amount from your staked balance.
  - Calculate and reset unclaimed rewards.
  - Apply the **1%** withdrawal fee.
  - Burn the equivalent HELIX tokens.
  - Transfer net KNDX tokens back to your wallet.

### **6. Early Unstaking**

- **Function Invoked:** `earlyUnstake(uint256 _amount, uint _depositId)`
- **Conditions:** Timelock period has not ended.
- **Process:**
  - Calculate the early unstaking penalty based on time remaining.
  - Lose all accumulated boosts.
  - Apply both the standard withdrawal fee and the early unstaking penalty.
  - Burn the equivalent HELIX tokens.
  - Transfer net KNDX tokens back to your wallet.

---

## Step-by-Step Guide

### **Step 1: Prepare Your KNDX and HELIX Tokens**

- **Ensure Sufficient KNDX:** Verify you have at least the minimum stake amount in your wallet.
- **HELIX Tokens:** No need to acquire HELIX tokens upfront; they are minted upon staking.

#### **Step 1.1: Grant Approval for Staking Contract**

- **Approve Contract:** Authorize the staking contract to transfer your KNDX tokens.

### **Step 2: Connect Your Wallet**

- **Supported Wallets:** MetaMask, Trust Wallet, Ledger, etc.
- **Connect to Platform:** Access the Kondux Staking platform and connect your wallet.

### **Step 3: Choose Your Locking Period**

- **Select Duration:** Decide on a locking period that aligns with your investment strategy.
- **Consider Boosts:** Longer locking periods offer higher reward boosts.

### **Step 4: Stake Your KNDX Tokens**

- **Enter Amount:** Specify the number of KNDX tokens you wish to stake.
- **Confirm Transaction:** Approve the transaction in your wallet.
- **Receive HELIX Tokens:** You will receive HELIX tokens at the **10,000:1** ratio.

### **Step 5: Manage Your Staking Position**

- **Monitor Rewards:** Keep track of your accumulated rewards and boosts.
- **Compound Rewards:** Choose to compound your rewards every 24 hours for maximum earnings.

### **Step 6: Withdraw Your KNDX**

- **Check HELIX Balance:** Ensure you have enough HELIX tokens to burn upon withdrawal.
- **Initiate Withdrawal:** Use the `withdraw` function after the timelock period.
- **Be Aware of Fees:** A **1%** withdrawal fee applies.

### **Step 7: Optimize Your NFT Bonuses**

- **Acquire NFTs:** Obtain Founder's NFTs and kNFTs to enhance your rewards.
- **Hold in Wallet:** Simply holding these NFTs in your connected wallet activates the boosts.

### **Step 8: Stay Updated with Kondux Developments**

- **Follow Official Channels:** Stay informed about updates, new features, and community events.

### **Step 9: Participate in Community Governance**

- **Engage with Community:** Vote on proposals and contribute ideas to shape the platform's future.

### **Step 10: Track Your Staking Progress and Performance**

- **Review Regularly:** Analyze your earnings, reward boosts, and the impact of compounding.
- **Adjust Strategy:** Make changes to your staking approach to optimize earnings.

---

## APR Calculation and Examples for End Users

Understanding how your rewards are calculated helps you make informed decisions. Below are detailed examples illustrating different staking scenarios, simulating stakes of **10,000 KNDX** tokens under various conditions.

### **Basic APR Calculation**

- **Base APR:** 25% per year.
- **Proportional APR:** Adjusted based on the actual staking duration.

### **Boosts**

1. **Founder's NFT:**
   - **10%** boost if you hold at least one Founder's NFT.
2. **kNFTs:**
   - Boosts range from **1% to 5%** per kNFT.
   - Up to **5 kNFTs** can be stacked, considering the highest boosts.
3. **Locking Periods:**
   - **30 days:** **0%** boost.
   - **90 days:** **1%** boost.
   - **180 days:** **3%** boost.
   - **365 days:** **9%** boost.

**Note:** Rewards and boosts can only be claimed by those who lock their KNDX by staking it.

### **Example 1: No Boosts - Unstaking after 180 Days**

- **Staked Amount:** 10,000 KNDX
- **Boosts:** None
- **Staking Duration:** 180 days
- **Calculation:**
  - **APR for 180 days:**
    $$\text{APR} = 25\% \times \frac{180}{365} = 12.33\%$$
  - **Rewards Earned:**
    $$\text{Rewards} = 10,000 \times 12.33\% = 1,233 \text{ KNDX}$$

### **Example 2: Founder's NFT Boost - Unstaking after 180 Days**

- **Boosts:**
  - Founder's NFT: **10%**
- **Total Boost Percentage:** 10%
- **Adjusted APR:**
  $$\text{Adjusted APR} = 25\% \times \left(1 + 0.10\right) = 27.5\%$$
- **APR for 180 days:**
  $$\text{APR} = 27.5\% \times \frac{180}{365} = 13.56\%$$
- **Rewards Earned:**
  $$\text{Rewards} = 10,000 \times 13.56\% = 1,356 \text{ KNDX}$$

### **Example 3: kNFT Boosts - Unstaking after 180 Days with One kNFT of 3% Boost**

- **Boosts:**
  - One kNFT: **3%**
- **Total Boost Percentage:** 3%
- **Adjusted APR:**
  $$\text{Adjusted APR} = 25\% \times \left(1 + 0.03\right) = 25.75\%$$
- **APR for 180 days:**
  $$\text{APR} = 25.75\% \times \frac{180}{365} = 12.70\%$$
- **Rewards Earned:**
  $$\text{Rewards} = 10,000 \times 12.70\% = 1,270 \text{ KNDX}$$

### **Example 4: kNFT Boosts - Unstaking after 180 Days with Two kNFTs of 3% Boost Each**

- **Boosts:**
  - Two kNFTs at 3% each: **6%**
- **Total Boost Percentage:** 6%
- **Adjusted APR:**
  $$\text{Adjusted APR} = 25\% \times \left(1 + 0.06\right) = 26.5\%$$
- **APR for 180 days:**
  $$\text{APR} = 26.5\% \times \frac{180}{365} = 13.08\%$$
- **Rewards Earned:**
  $$\text{Rewards} = 10,000 \times 13.08\% = 1,308 \text{ KNDX}$$

### **Example 5: Locking Period Boost - Unstaking after 180 Days with a 180-Day Locking Period**

- **Boosts:**
  - Locking Period (180 days): **3%**
- **Total Boost Percentage:** 3%
- **Adjusted APR:**
  $$\text{Adjusted APR} = 25\% \times \left(1 + 0.03\right) = 25.75\%$$
- **APR for 180 days:**
  $$\text{APR} = 25.75\% \times \frac{180}{365} = 12.70\%$$
- **Rewards Earned:**
  $$\text{Rewards} = 10,000 \times 12.70\% = 1,270 \text{ KNDX}$$

### **Example 6: Combination of Boosts - Founder's NFT and 180-Day Locking Period**

- **Boosts:**
  - Founder's NFT: **10%**
  - Locking Period (180 days): **3%**
- **Total Boost Percentage:** 13%
- **Adjusted APR:**
  $$\text{Adjusted APR} = 25\% \times \left(1 + 0.13\right) = 28.25\%$$
- **APR for 180 days:**
  $$\text{APR} = 28.25\% \times \frac{180}{365} = 13.92\%$$
- **Rewards Earned:**
  $$\text{Rewards} = 10,000 \times 13.92\% = 1,392 \text{ KNDX}$$

### **Example 7: Combination of Boosts - Founder's NFT, One kNFT, and 180-Day Locking Period**

- **Boosts:**
  - Founder's NFT: **10%**
  - One kNFT at 3%: **3%**
  - Locking Period (180 days): **3%**
- **Total Boost Percentage:** 16%
- **Adjusted APR:**
  $$\text{Adjusted APR} = 25\% \times \left(1 + 0.16\right) = 29\%$$
- **APR for 180 days:**
  $$\text{APR} = 29\% \times \frac{180}{365} = 14.27\%$$
- **Rewards Earned:**
  $$\text{Rewards} = 10,000 \times 14.27\% = 1,427 \text{ KNDX}$$

### **Example 8: Combination of Boosts - Founder's NFT, Two kNFTs, and 180-Day Locking Period**

- **Boosts:**
  - Founder's NFT: **10%**
  - Two kNFTs at 3% each: **6%**
  - Locking Period (180 days): **3%**
- **Total Boost Percentage:** 19%
- **Adjusted APR:**
  $$\text{Adjusted APR} = 25\% \times \left(1 + 0.19\right) = 29.75\%$$
- **APR for 180 days:**
  $$\text{APR} = 29.75\% \times \frac{180}{365} = 14.68\%$$
- **Rewards Earned:**
  $$\text{Rewards} = 10,000 \times 14.68\% = 1,468 \text{ KNDX}$$

### **Example 9: Combination of Boosts - Founder's NFT, Three kNFTs, and 180-Day Locking Period**

- **Boosts:**
  - Founder's NFT: **10%**
  - Three kNFTs at 3% each: **9%**
  - Locking Period (180 days): **3%**
- **Total Boost Percentage:** 22%
- **Adjusted APR:**
  $$\text{Adjusted APR} = 25\% \times \left(1 + 0.22\right) = 30.5\%$$
- **APR for 180 days:**
  $$\text{APR} = 30.5\% \times \frac{180}{365} = 15.07\%$$
- **Rewards Earned:**
  $$\text{Rewards} = 10,000 \times 15.07\% = 1,507 \text{ KNDX}$$

### **Example 10: Combination of Boosts - Founder's NFT, Four kNFTs, and 180-Day Locking Period**

- **Boosts:**
  - Founder's NFT: **10%**
  - Four kNFTs at 3% each: **12%**
  - Locking Period (180 days): **3%**
- **Total Boost Percentage:** 25%
- **Adjusted APR:**
  $$\text{Adjusted APR} = 25\% \times \left(1 + 0.25\right) = 31.25\%$$
- **APR for 180 days:**
  $$\text{APR} = 31.25\% \times \frac{180}{365} = 15.41\%$$
- **Rewards Earned:**
  $$\text{Rewards} = 10,000 \times 15.41\% = 1,541 \text{ KNDX}$$

### **Example 11: Combination of Boosts - Founder's NFT, Five kNFTs, and 180-Day Locking Period**

- **Boosts:**
  - Founder's NFT: **10%**
  - Five kNFTs at 3% each: **15%**
  - Locking Period (180 days): **3%**
- **Total Boost Percentage:** 28%
- **Adjusted APR:**
  $$\text{Adjusted APR} = 25\% \times \left(1 + 0.28\right) = 32\%$$
- **APR for 180 days:**
  $$\text{APR} = 32\% \times \frac{180}{365} = 15.75\%$$
- **Rewards Earned:**
  $$\text{Rewards} = 10,000 \times 15.75\% = 1,575 \text{ KNDX}$$

### **Example 12: Early Unstaking after 120 Days from a 180-Day Locking Period with Multiple Boosts**

- **Boosts:** Lost due to early unstaking.
- **Staking Duration:** 120 days
- **Time Remaining:** 60 days (180 - 120)
- **Penalty Calculation:**
  - **Penalty Percentage:**
    $$10\% \times \left( \frac{60}{180} \right) = 3.33\%$$
- **Adjusted APR:**
  $$\text{Adjusted APR} = 25\%$$
- **APR for 120 days:**
  $$\text{APR} = 25\% \times \frac{120}{365} = 8.22\%$$
- **Final APR after Penalty:**
  $$\text{Final APR} = 8.22\% - 3.33\% = 4.89\%$$
- **Rewards Earned:**
  $$\text{Rewards} = 10,000 \times 4.89\% = 489 \text{ KNDX}$$

### **Example 13: Early Unstaking after 240 Days from a 365-Day Locking Period with Multiple Boosts**

- **Boosts:** Lost due to early unstaking.
- **Staking Duration:** 240 days
- **Time Remaining:** 125 days (365 - 240)
- **Penalty Calculation:**
  - **Penalty Percentage:**
    $$10\% \times \left( \frac{125}{365} \right) \approx 3.42\%$$
- **Adjusted APR:**
  $$\text{Adjusted APR} = 25\%$$
- **APR for 240 days:**
  $$\text{APR} = 25\% \times \frac{240}{365} = 16.44\%$$
- **Final APR after Penalty:**
  $$\text{Final APR} = 16.44\% - 3.42\% = 13.02\%$$
- **Rewards Earned:**
  $$\text{Rewards} = 10,000 \times 13.02\% = 1,302 \text{ KNDX}$$

### **Example 14: Early Unstaking after 45 Days from a 90-Day Locking Period with Multiple Boosts**

- **Boosts:** Lost due to early unstaking.
- **Staking Duration:** 45 days
- **Time Remaining:** 45 days (90 - 45)
- **Penalty Calculation:**
  - **Penalty Percentage:**
    $$10\% \times \left( \frac{45}{90} \right) = 5\%$$
- **Adjusted APR:**
  $$\text{Adjusted APR} = 25\%$$
- **APR for 45 days:**
  $$\text{APR} = 25\% \times \frac{45}{365} = 3.08\%$$
- **Final APR after Penalty:**
  $$\text{Final APR} = 3.08\% - 5\% = \text{Negative APR}$$
- **Outcome:** Since the penalty exceeds the earned rewards, you would incur a loss.

---

## Maximizing Your Earnings

### **1. Leverage NFT Bonuses**

- **Acquire High-Boost kNFTs:** Focus on kNFTs with higher boosts to maximize your total boost percentage.
- **Hold Multiple kNFTs:** Holding up to **5 kNFTs** allows you to stack boosts.

### **2. Choose Longer Locking Periods**

- **Higher Boosts:** Longer locking periods provide higher boosts, increasing your overall rewards.
- **Commitment Pays Off:** The **365-day** locking period offers the highest timelock boost of **9%**.

### **3. Regularly Compound Rewards**

- **Increase Staked Amount:** Compounding adds your rewards back into your staked amount.
- **Exponential Growth:** Over time, compounding can significantly increase your earnings.

### **4. Monitor Market Conditions**

- **Stay Informed:** Keep an eye on KNDX and HELIX token performance to make strategic decisions.
- **Optimal Timing:** Plan your staking and unstaking based on market trends.

### **5. Avoid Early Unstaking**

- **Penalties Reduce Earnings:** Early unstaking can lead to loss of boosts and additional penalties.
- **Plan Accordingly:** Choose a locking period you are comfortable with to avoid early withdrawal.

---

## Frequently Asked Questions (FAQs)

### **Q1: Can I stake tokens other than KNDX?**

- **Answer:** Currently, only KNDX ERC20 tokens are authorized for staking.

### **Q2: Do I need to acquire HELIX tokens before staking?**

- **Answer:** No, HELIX tokens are minted and issued to you upon staking your KNDX tokens.

### **Q3: What happens if I unstake before the locking period ends?**

- **Answer:** You will lose all accumulated boosts and incur an early unstaking penalty proportional to the remaining time in your locking period.

### **Q4: Is there a maximum limit to how much I can stake?**

- **Answer:** There is no specified maximum stake limit; you can stake as much as you wish, provided you meet the minimum stake amount.

### **Q5: Can I add more KNDX to an existing stake?**

- **Answer:** Yes, you can stake additional KNDX tokens at any time, which will be treated as a new deposit with its own locking period and boosts.

---

## Conclusion

The Kondux Staking Smart Contract offers a robust and flexible platform for maximizing your earnings through staking. By understanding the mechanics of staking, reward calculations, and the available boosts, you can tailor your strategy to align with your financial goals. Whether you're aiming for steady growth or leveraging boosts for higher returns, the Kondux ecosystem provides the tools and opportunities to enhance your DeFi experience.

**Ready to start staking?** Connect your wallet, choose your staking parameters, and watch your investment grow with the Kondux Staking Smart Contract!

---

## Stay Connected

- **Official Website:** [Kondux.io](https://kondux.io)
- **Social Media:** Follow Kondux on [Twitter](https://x.com/Kondux_KNDX), [Discord](https://discord.gg/pvmgMjtG), and [Telegram](https://t.me/konduxcommunity) for the latest news.

*Disclaimer: This guide is for informational purposes only and does not constitute financial advice. Always conduct your own research before engaging in any investment activities.*
