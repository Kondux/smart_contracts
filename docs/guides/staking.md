# Staking

Staking Goerli address is [`0x107EAe6d788068b2B7891f9F0aBa10BB1201Fa8a`](https://goerli.etherscan.io/address/0x107EAe6d788068b2B7891f9F0aBa10BB1201Fa8a#code). At Etherscan you can find the ABI of the staking contract.

All deposits are sent to Treasury contract, at `0xefFDa63B1AF6B4033606368B7F3aA13E5BC91C26`. The Treasury contract is a simple contract that holds the tokens and distributes them to the staking contract. The Treasury contract interfaces with the staking contract. The Staking Conctract has approval to move funds. Treasury is managed by the Kondux Authority's DAO.

## Depositing

To deposit your tokens to the staking contract, you need to call the `deposit` function on the staking contract. It takes the amount of tokens to deposit as first argument, and the locktime category as second argument. The locktime category is an integer between 0 and 3, where 0 is the shortest locktime, and 3 is the longest locktime. The locktime categories are defined in the staking contract, and can be changed by the owner of the staking contract. 0 is 30 days, 1 is 90 days, 2 is 180 days, and 3 is 365 days. For the testnet there's a category 4, which is 2 minutes. 

Locktime of 30 days doesn't give any boost to rewards. Locktime of 90 days gives 1% more rewards. Locktime of 180 days gives 3% more rewards. Locktime of 365 days gives 9% more rewards. 

Before calling the `deposit` function, you need to approve the staking contract to spend your tokens. This is done by calling the `approve` function on the token contract, with the staking contract address as first argument, and the amount of tokens to approve as second argument.
```javascript
const stake = await staking.deposit(10_000_000, 1); // 10_000_000 units staked with locktime of 90 days
await stake.wait();
```

It emits "Stake" event, which contains the `id` of the stake, the `sender`, and the `amount` of tokens staked.

## Claiming rewards

To claim your rewards, you need to call the `claimRewards` function on the staking contract. This function will claim all rewards for all your staked tokens. The rewards are sent to your account. It takes the stake id as first argument. The stake id is the id of the stake you want to claim rewards for.

```javascript
const claimRewards = await staking.claimRewards(_stakeId);
await claimRewards.wait();
```

It emits "Reward" event, which contains the `sender`, and the `amount` of tokens claimed.

## Withdrawing

To withdraw your tokens, you need to call the `withdraw` function on the staking contract. It takes the amount of tokens to withdraw as first argument. The tokens will be sent to your account.

```javascript
const withdraw = await staking.withdraw(10_000_000, _stakeId);
await withdraw.wait();
```

It emits "Withdraw" event, which contains the `sender`, and the `amount` of tokens withdrawn.

## Withdraw All

To withdraw all your tokens, you need to call the `withdrawAll` function on the staking contract. The tokens will be sent to your account.

```javascript
const withdrawAll = await staking.withdrawAll();
await withdrawAll.wait();
```

It emits "WithdrawAll" event, which contains the `sender`, and the `amount` of tokens withdrawn.

## Restaking Rewards

To restake your rewards, you need to call the `stakeRewards` function on the staking contract. It takes the stake id as first argument. The stake id is the id of the stake you want to restake your rewards to. 

```javascript
const stakeRewards = await staking.stakeRewards(_stakeId);
await stakeRewards.wait();
```

It emits "Compound" event, which contains the `sender`, and the `amount` of tokens staked.

## Viewing rewards

To view your rewards, you need to call the `calculateRewards` function on the staking contract. It takes your account address as first argument. The function returns the amount of rewards in the staking contract for your account.

```javascript
const rewards = await staking.calculateRewards(account.address);
console.log(rewards.toString());
```

## Viewing staked tokens

To view your staked tokens, you need to call the `getStakedAmount` function on the staking contract. It takes your account address as first argument. The function returns the amount of staked tokens in the staking contract for your account.

```javascript
const stakedAmount = await staking.getStakedAmount(account.address);
console.log(stakedAmount.toString());
```

## Viewing current contract's rewards per hour

To view the current rewards per hour, you need to call the `getRewardsPerHour` function on the staking contract. The function returns the amount of rewards per hour.

```javascript
const rewardsPerHour = await staking.getRewardsPerHour();
console.log(rewardsPerHour.toString());
```

## Viewing current kNFT reward's boost

To view the current kNFT reward's boost, you need to call the `getkNFTRewardBoost` function on the staking contract. The function returns the amount of boost.

```javascript
const kNFTRewardBoost = await staking.getkNFTRewardBoost();
console.log(kNFTRewardBoost.toString());
```

## Viewing current Founder's reward's boost

To view the current Founder's reward's boost, you need to call the `getFoundersRewardBoost` function on the staking contract. The function returns the amount of boost.

```javascript
const foundersRewardBoost = await staking.getFoundersRewardBoost();
console.log(foundersRewardBoost.toString());
```

## Viewing minimum staking amount

To view the minimum staking amount, you need to call the `getMinStake` function on the staking contract. The function returns the minimum staking amount.

```javascript
const minStake = await staking.getMinStake();
console.log(minStake.toString());
```

## Viewing a user timelock category

To view a user's timelock category, you need to call the `getTimelockCategory` function on the staking contract. It takes your account address as first argument. The function returns the timelock category.

```javascript
const timelockCategory = await staking.getTimelockCategory(account.address);
console.log(timelockCategory.toString());
```

## Viewing a user's timelock end

To view a user's timelock end, you need to call the `getTimelock` function on the staking contract. It takes your account address as first argument. The function returns the timelock end in epoch time.

```javascript
const timelock = await staking.getTimelock(account.address);
console.log(timelock.toString());
```


## Viewing all user's stakes IDs

To view all user's stakes IDs, you need to call the `getDepositIds` function on the staking contract. It takes your account address as first argument. The function returns an array of stake IDs.

```javascript
const depositIds = await staking.getDepositIds(account.address);
console.log(depositIds.toString());
```





