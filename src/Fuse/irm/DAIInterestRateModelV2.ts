import JumpRateModel from "./JumpRateModel";
import { BigNumberish, Contract, BigNumber, utils } from "ethers";
import { Web3Provider } from "@ethersproject/providers";

import DAIInterestRateModelV2Artifact from "../../../out/DAIInterestRateModelV2.sol/DAIInterestRateModelV2.json";
import CTokenInterfacesArtifact from "../../../out/CTokenInterfaces.sol/CTokenInterface.json";

export default class DAIInterestRateModelV2 extends JumpRateModel {
  static RUNTIME_BYTECODE_HASH = utils.keccak256(DAIInterestRateModelV2Artifact.deployedBytecode.object);

  initialized: boolean | undefined;
  dsrPerSecond: BigNumber | undefined;
  cash: BigNumber | undefined;
  borrows: BigNumber | undefined;
  reserves: BigNumber | undefined;
  reserveFactorMantissa: BigNumber | undefined;

  async init(interestRateModelAddress: string, assetAddress: string, provider: any) {
    await super.init(interestRateModelAddress, assetAddress, provider);

    const interestRateContract = new Contract(interestRateModelAddress, DAIInterestRateModelV2Artifact.abi, provider);

    this.dsrPerSecond = BigNumber.from(await interestRateContract.callStatic.dsrPerSecond());

    const cTokenContract = new Contract(assetAddress, CTokenInterfacesArtifact.abi, provider);

    this.cash = BigNumber.from(await cTokenContract.callStatic.getCash());
    this.borrows = BigNumber.from(await cTokenContract.callStatic.totalBorrowsCurrent());
    this.reserves = BigNumber.from(await cTokenContract.callStatic.totalReserves());
  }

  async _init(
    interestRateModelAddress: string,
    reserveFactorMantissa: BigNumberish,
    adminFeeMantissa: BigNumberish,
    fuseFeeMantissa: BigNumberish,
    provider: Web3Provider
  ) {
    await super._init(interestRateModelAddress, reserveFactorMantissa, adminFeeMantissa, fuseFeeMantissa, provider);

    const interestRateContract = new Contract(interestRateModelAddress, DAIInterestRateModelV2Artifact.abi, provider);
    this.dsrPerSecond = BigNumber.from(await interestRateContract.callStatic.dsrPerSecond());
    this.cash = BigNumber.from(0);
    this.borrows = BigNumber.from(0);
    this.reserves = BigNumber.from(0);
  }

  async __init(
    baseRatePerSecond: BigNumberish,
    multiplierPerSecond: BigNumberish,
    jumpMultiplierPerSecond: BigNumberish,
    kink: BigNumberish,
    reserveFactorMantissa: BigNumberish,
    adminFeeMantissa: BigNumberish,
    fuseFeeMantissa: BigNumberish
  ) {
    await super.__init(
      baseRatePerSecond,
      multiplierPerSecond,
      jumpMultiplierPerSecond,
      kink,
      reserveFactorMantissa,
      adminFeeMantissa,
      fuseFeeMantissa
    );
    this.dsrPerSecond = BigNumber.from(0); // TODO: Make this work if DSR ever goes positive again
    this.cash = BigNumber.from(0);
    this.borrows = BigNumber.from(0);
    this.reserves = BigNumber.from(0);
  }

  getSupplyRate(utilizationRate: BigNumber) {
    if (!this.initialized || !this.cash || !this.borrows || !this.reserves || !this.dsrPerSecond)
      throw new Error("Interest rate model class not initialized.");

    // const protocolRate = super.getSupplyRate(utilizationRate, this.reserveFactorMantissa); //todo - do we need this
    const protocolRate = super.getSupplyRate(utilizationRate);
    const underlying = this.cash.add(this.borrows).sub(this.reserves);

    if (underlying.isZero()) {
      return protocolRate;
    } else {
      const cashRate = this.cash.mul(this.dsrPerSecond).div(underlying);
      return cashRate.add(protocolRate);
    }
  }
}
