import { BigNumber, BigNumberish, providers } from "ethers";

import JumpRateModel from "./irm/JumpRateModel";
import DAIInterestRateModelV2 from "./irm/DAIInterestRateModelV2";
import WhitePaperInterestRateModel from "./irm/WhitePaperInterestRateModel";
import { FuseBase } from ".";

export type GConstructor<T = {}> = new (...args: any[]) => T;
export type FuseBaseConstructor = GConstructor<FuseBase>;

export type MinifiedContracts = {
  [key: string]: {
    abi?: any;
    bin?: any;
  };
};

export type MinifiedCompoundContracts = {
  [key: string]: {
    abi?: any;
    bytecode?: any;
  };
};

export type MinifiedOraclesContracts = MinifiedCompoundContracts;

export interface InterestRateModel {
  init(
    interestRateModelAddress: string,
    assetAddress: string,
    provider: providers.Web3Provider | providers.JsonRpcProvider
  ): Promise<void>;

  _init(
    interestRateModelAddress: string,
    reserveFactorMantissa: BigNumberish,
    adminFeeMantissa: BigNumberish,
    fuseFeeMantissa: BigNumberish,
    provider: providers.Web3Provider | providers.JsonRpcProvider
  ): Promise<void>;

  __init(
    baseRatePerSecond: BigNumberish,
    multiplierPerSecond: BigNumberish,
    jumpMultiplierPerSecond: BigNumberish,
    kink: BigNumberish,
    reserveFactorMantissa: BigNumberish,
    adminFeeMantissa: BigNumberish,
    fuseFeeMantissa: BigNumberish
  ): Promise<void>;

  getBorrowRate(utilizationRate: BigNumber): BigNumber;

  getSupplyRate(utilizationRate: BigNumber): BigNumber;
}
export type Artifact = {
  abi: any;
  bytecode: {
    object: string;
    sourceMap: string;
    linkReferences: any;
  };
  deployedBytecode: {
    object: string;
    sourceMap: string;
    linkReferences: any;
  };
};

export type Artifacts = {
  [contractName: string]: Artifact;
};

export type ChainDeployment = {
  [contractName: string]: {
    abi: any;
    address: string;
  };
};

export type InterestRateModelType = JumpRateModel | DAIInterestRateModelV2 | WhitePaperInterestRateModel;

export type cERC20Conf = {
  delegateContractName?: any;
  underlying: string; // underlying ERC20
  comptroller: string; // Address of the comptroller
  fuseFeeDistributor: string;
  interestRateModel: string; // Address of the IRM
  initialExchangeRateMantissa?: BigNumber; // Initial exchange rate scaled by 1e18
  name: string; // ERC20 name of this token
  symbol: string; // ERC20 Symbol
  decimals: number; // decimal precision
  admin: string; // Address of the admin
  collateralFactor: number;
  reserveFactor: number;
  adminFee: number;
  bypassPriceFeedCheck: boolean;
};

export type OracleConf = {
  anchorPeriod?: any;
  tokenConfigs?: any;
  canAdminOverwrite?: any;
  isPublic?: any;
  maxSecondsBeforePriceIsStale?: any;
  chainlinkPriceOracle?: any;
  secondaryPriceOracle?: any;
  reporter?: any;
  anchorMantissa?: any;
  isSecure?: any;
  useRootOracle?: any;
  underlyings?: any;
  sushiswap?: any;
  oracles?: any;
  admin?: any;
  rootOracle?: any;
  uniswapV2Factory?: any;
  baseToken?: any;
  uniswapV3Factory?: any;
  feeTier?: any;
  defaultOracle?: any;
};

export type InterestRateModelParams = {
  baseRatePerYear?: string;
  multiplierPerYear?: string;
  jumpMultiplierPerYear?: string;
  kink?: string;
};

export type InterestRateModelConf = {
  interestRateModel?: string;
  interestRateModelParams?: InterestRateModelParams;
};

export interface FuseAsset {
  cToken: string;

  borrowBalance: BigNumber;
  supplyBalance: BigNumber;
  liquidity: BigNumber;

  membership: boolean;

  underlyingName: string;
  underlyingSymbol: string;
  underlyingToken: string;
  underlyingDecimals: BigNumber;
  underlyingPrice: BigNumber;
  underlyingBalance: BigNumber;

  collateralFactor: BigNumber;
  reserveFactor: BigNumber;

  adminFee: BigNumber;
  fuseFee: BigNumber;

  borrowRatePerSecond: BigNumber;
  supplyRatePerSecond: BigNumber;

  totalBorrow: BigNumber;
  totalSupply: BigNumber;
}

export interface USDPricedFuseAsset extends FuseAsset {
  supplyBalanceUSD: number;
  borrowBalanceUSD: number;

  totalSupplyUSD: number;
  totalBorrowUSD: number;

  liquidityUSD: number;

  isPaused: boolean;
  isSupplyPaused: boolean;
}

export interface FusePoolData {
  id: number;
  assets: USDPricedFuseAsset[];
  creator: string;
  comptroller: string;
  name: string;
  totalLiquidityUSD: number;
  totalSuppliedUSD: number;
  totalBorrowedUSD: number;
  totalSupplyBalanceUSD: number;
  totalBorrowBalanceUSD: number;
  blockPosted: BigNumber;
  timestampPosted: BigNumber;
  underlyingTokens: string[];
  underlyingSymbols: string[];
  whitelistedAdmin: boolean;
}

export interface FusePool {
  name: string;
  creator: string;
  comptroller: string;
  blockPosted: number;
  timestampPosted: number;
}
