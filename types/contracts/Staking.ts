/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type {
  FunctionFragment,
  Result,
  EventFragment,
} from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
} from "../common";

export interface StakingInterface extends utils.Interface {
  functions: {
    "authority()": FunctionFragment;
    "calculateRewards(address)": FunctionFragment;
    "claimRewards()": FunctionFragment;
    "compoundFreq()": FunctionFragment;
    "compoundRewardsTimer(address)": FunctionFragment;
    "deposit(uint256)": FunctionFragment;
    "getDepositInfo(address)": FunctionFragment;
    "konduxERC20()": FunctionFragment;
    "minStake()": FunctionFragment;
    "rewardsPerHour()": FunctionFragment;
    "setAuthority(address)": FunctionFragment;
    "setCompFreq(uint256)": FunctionFragment;
    "setMinStake(uint256)": FunctionFragment;
    "setRewards(uint256)": FunctionFragment;
    "stakeRewards()": FunctionFragment;
    "withdraw(uint256)": FunctionFragment;
    "withdrawAll()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "authority"
      | "calculateRewards"
      | "claimRewards"
      | "compoundFreq"
      | "compoundRewardsTimer"
      | "deposit"
      | "getDepositInfo"
      | "konduxERC20"
      | "minStake"
      | "rewardsPerHour"
      | "setAuthority"
      | "setCompFreq"
      | "setMinStake"
      | "setRewards"
      | "stakeRewards"
      | "withdraw"
      | "withdrawAll"
  ): FunctionFragment;

  encodeFunctionData(functionFragment: "authority", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "calculateRewards",
    values: [string]
  ): string;
  encodeFunctionData(
    functionFragment: "claimRewards",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "compoundFreq",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "compoundRewardsTimer",
    values: [string]
  ): string;
  encodeFunctionData(
    functionFragment: "deposit",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "getDepositInfo",
    values: [string]
  ): string;
  encodeFunctionData(
    functionFragment: "konduxERC20",
    values?: undefined
  ): string;
  encodeFunctionData(functionFragment: "minStake", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "rewardsPerHour",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "setAuthority",
    values: [string]
  ): string;
  encodeFunctionData(
    functionFragment: "setCompFreq",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "setMinStake",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "setRewards",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "stakeRewards",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "withdraw",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "withdrawAll",
    values?: undefined
  ): string;

  decodeFunctionResult(functionFragment: "authority", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "calculateRewards",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "claimRewards",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "compoundFreq",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "compoundRewardsTimer",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "deposit", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "getDepositInfo",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "konduxERC20",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "minStake", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "rewardsPerHour",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setAuthority",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setCompFreq",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setMinStake",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "setRewards", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "stakeRewards",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "withdraw", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "withdrawAll",
    data: BytesLike
  ): Result;

  events: {
    "AuthorityUpdated(address)": EventFragment;
    "Compound(address,uint256)": EventFragment;
    "Reward(address,uint256)": EventFragment;
    "Stake(address,uint256)": EventFragment;
    "Unstake(address,uint256)": EventFragment;
    "Withdraw(address,uint256)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "AuthorityUpdated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Compound"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Reward"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Stake"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Unstake"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Withdraw"): EventFragment;
}

export interface AuthorityUpdatedEventObject {
  authority: string;
}
export type AuthorityUpdatedEvent = TypedEvent<
  [string],
  AuthorityUpdatedEventObject
>;

export type AuthorityUpdatedEventFilter =
  TypedEventFilter<AuthorityUpdatedEvent>;

export interface CompoundEventObject {
  staker: string;
  amount: BigNumber;
}
export type CompoundEvent = TypedEvent<
  [string, BigNumber],
  CompoundEventObject
>;

export type CompoundEventFilter = TypedEventFilter<CompoundEvent>;

export interface RewardEventObject {
  staker: string;
  amount: BigNumber;
}
export type RewardEvent = TypedEvent<[string, BigNumber], RewardEventObject>;

export type RewardEventFilter = TypedEventFilter<RewardEvent>;

export interface StakeEventObject {
  staker: string;
  amount: BigNumber;
}
export type StakeEvent = TypedEvent<[string, BigNumber], StakeEventObject>;

export type StakeEventFilter = TypedEventFilter<StakeEvent>;

export interface UnstakeEventObject {
  staker: string;
  amount: BigNumber;
}
export type UnstakeEvent = TypedEvent<[string, BigNumber], UnstakeEventObject>;

export type UnstakeEventFilter = TypedEventFilter<UnstakeEvent>;

export interface WithdrawEventObject {
  staker: string;
  amount: BigNumber;
}
export type WithdrawEvent = TypedEvent<
  [string, BigNumber],
  WithdrawEventObject
>;

export type WithdrawEventFilter = TypedEventFilter<WithdrawEvent>;

export interface Staking extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: StakingInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    authority(overrides?: CallOverrides): Promise<[string]>;

    calculateRewards(
      _staker: string,
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { rewards: BigNumber }>;

    claimRewards(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    compoundFreq(overrides?: CallOverrides): Promise<[BigNumber]>;

    compoundRewardsTimer(
      _user: string,
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { _timer: BigNumber }>;

    deposit(
      _amount: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    getDepositInfo(
      _user: string,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber] & { _stake: BigNumber; _rewards: BigNumber }
    >;

    konduxERC20(overrides?: CallOverrides): Promise<[string]>;

    minStake(overrides?: CallOverrides): Promise<[BigNumber]>;

    rewardsPerHour(overrides?: CallOverrides): Promise<[BigNumber]>;

    setAuthority(
      _newAuthority: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    setCompFreq(
      _compoundFreq: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    setMinStake(
      _minStake: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    setRewards(
      _rewardsPerHour: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    stakeRewards(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    withdraw(
      _amount: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    withdrawAll(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;
  };

  authority(overrides?: CallOverrides): Promise<string>;

  calculateRewards(
    _staker: string,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  claimRewards(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  compoundFreq(overrides?: CallOverrides): Promise<BigNumber>;

  compoundRewardsTimer(
    _user: string,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  deposit(
    _amount: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  getDepositInfo(
    _user: string,
    overrides?: CallOverrides
  ): Promise<
    [BigNumber, BigNumber] & { _stake: BigNumber; _rewards: BigNumber }
  >;

  konduxERC20(overrides?: CallOverrides): Promise<string>;

  minStake(overrides?: CallOverrides): Promise<BigNumber>;

  rewardsPerHour(overrides?: CallOverrides): Promise<BigNumber>;

  setAuthority(
    _newAuthority: string,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  setCompFreq(
    _compoundFreq: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  setMinStake(
    _minStake: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  setRewards(
    _rewardsPerHour: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  stakeRewards(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  withdraw(
    _amount: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  withdrawAll(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  callStatic: {
    authority(overrides?: CallOverrides): Promise<string>;

    calculateRewards(
      _staker: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    claimRewards(overrides?: CallOverrides): Promise<void>;

    compoundFreq(overrides?: CallOverrides): Promise<BigNumber>;

    compoundRewardsTimer(
      _user: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    deposit(_amount: BigNumberish, overrides?: CallOverrides): Promise<void>;

    getDepositInfo(
      _user: string,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber] & { _stake: BigNumber; _rewards: BigNumber }
    >;

    konduxERC20(overrides?: CallOverrides): Promise<string>;

    minStake(overrides?: CallOverrides): Promise<BigNumber>;

    rewardsPerHour(overrides?: CallOverrides): Promise<BigNumber>;

    setAuthority(
      _newAuthority: string,
      overrides?: CallOverrides
    ): Promise<void>;

    setCompFreq(
      _compoundFreq: BigNumberish,
      overrides?: CallOverrides
    ): Promise<void>;

    setMinStake(
      _minStake: BigNumberish,
      overrides?: CallOverrides
    ): Promise<void>;

    setRewards(
      _rewardsPerHour: BigNumberish,
      overrides?: CallOverrides
    ): Promise<void>;

    stakeRewards(overrides?: CallOverrides): Promise<void>;

    withdraw(_amount: BigNumberish, overrides?: CallOverrides): Promise<void>;

    withdrawAll(overrides?: CallOverrides): Promise<void>;
  };

  filters: {
    "AuthorityUpdated(address)"(authority?: null): AuthorityUpdatedEventFilter;
    AuthorityUpdated(authority?: null): AuthorityUpdatedEventFilter;

    "Compound(address,uint256)"(
      staker?: string | null,
      amount?: null
    ): CompoundEventFilter;
    Compound(staker?: string | null, amount?: null): CompoundEventFilter;

    "Reward(address,uint256)"(
      staker?: string | null,
      amount?: null
    ): RewardEventFilter;
    Reward(staker?: string | null, amount?: null): RewardEventFilter;

    "Stake(address,uint256)"(
      staker?: string | null,
      amount?: null
    ): StakeEventFilter;
    Stake(staker?: string | null, amount?: null): StakeEventFilter;

    "Unstake(address,uint256)"(
      staker?: string | null,
      amount?: null
    ): UnstakeEventFilter;
    Unstake(staker?: string | null, amount?: null): UnstakeEventFilter;

    "Withdraw(address,uint256)"(
      staker?: string | null,
      amount?: null
    ): WithdrawEventFilter;
    Withdraw(staker?: string | null, amount?: null): WithdrawEventFilter;
  };

  estimateGas: {
    authority(overrides?: CallOverrides): Promise<BigNumber>;

    calculateRewards(
      _staker: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    claimRewards(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    compoundFreq(overrides?: CallOverrides): Promise<BigNumber>;

    compoundRewardsTimer(
      _user: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    deposit(
      _amount: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    getDepositInfo(
      _user: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    konduxERC20(overrides?: CallOverrides): Promise<BigNumber>;

    minStake(overrides?: CallOverrides): Promise<BigNumber>;

    rewardsPerHour(overrides?: CallOverrides): Promise<BigNumber>;

    setAuthority(
      _newAuthority: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    setCompFreq(
      _compoundFreq: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    setMinStake(
      _minStake: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    setRewards(
      _rewardsPerHour: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    stakeRewards(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    withdraw(
      _amount: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    withdrawAll(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    authority(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    calculateRewards(
      _staker: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    claimRewards(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    compoundFreq(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    compoundRewardsTimer(
      _user: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    deposit(
      _amount: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    getDepositInfo(
      _user: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    konduxERC20(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    minStake(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    rewardsPerHour(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    setAuthority(
      _newAuthority: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    setCompFreq(
      _compoundFreq: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    setMinStake(
      _minStake: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    setRewards(
      _rewardsPerHour: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    stakeRewards(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    withdraw(
      _amount: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    withdrawAll(
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;
  };
}