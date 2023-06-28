import { BigNumberish, BigNumber, Contract, utils } from "ethers";
import { Web3Provider } from "@ethersproject/providers";

import { InterestRateModel } from "../types";
import JumpRateModelArtifact from "../../../out/JumpRateModel.sol/JumpRateModel.json";
import CTokenInterfacesArtifact from "../../../out/CTokenInterfaces.sol/CTokenInterface.json";

export default class JumpRateModel implements InterestRateModel {
  static RUNTIME_BYTECODE_HASH = utils.keccak256(JumpRateModelArtifact.deployedBytecode.object);

  initialized: boolean | undefined;
  baseRatePerSecond: BigNumber | undefined;
  multiplierPerSecond: BigNumber | undefined;
  jumpMultiplierPerSecond: BigNumber | undefined;
  kink: BigNumber | undefined;
  reserveFactorMantissa: BigNumber | undefined;

  async init(interestRateModelAddress: string, assetAddress: string, provider: Web3Provider): Promise<void> {
    const jumpRateModelContract = new Contract(interestRateModelAddress, JumpRateModelArtifact.abi, provider);
    this.baseRatePerSecond = BigNumber.from(await jumpRateModelContract.callStatic.baseRatePerSecond());
    this.multiplierPerSecond = BigNumber.from(await jumpRateModelContract.callStatic.multiplierPerSecond());
    this.jumpMultiplierPerSecond = BigNumber.from(await jumpRateModelContract.callStatic.jumpMultiplierPerSecond());
    this.kink = BigNumber.from(await jumpRateModelContract.callStatic.kink());

    const cTokenContract = new Contract(assetAddress, CTokenInterfacesArtifact.abi, provider);
    this.reserveFactorMantissa = BigNumber.from(await cTokenContract.callStatic.reserveFactorMantissa());
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(
      BigNumber.from(await cTokenContract.callStatic.adminFeeMantissa())
    );
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(
      BigNumber.from(await cTokenContract.callStatic.fuseFeeMantissa())
    );
    this.initialized = true;
  }

  async _init(
    interestRateModelAddress: string,
    reserveFactorMantissa: BigNumberish,
    adminFeeMantissa: BigNumberish,
    fuseFeeMantissa: BigNumberish,
    provider: Web3Provider
  ): Promise<void> {
    const jumpRateModelContract = new Contract(interestRateModelAddress, JumpRateModelArtifact.abi, provider);
    this.baseRatePerSecond = BigNumber.from(await jumpRateModelContract.callStatic.baseRatePerSecond());
    this.multiplierPerSecond = BigNumber.from(await jumpRateModelContract.callStatic.multiplierPerSecond());
    this.jumpMultiplierPerSecond = BigNumber.from(await jumpRateModelContract.callStatic.jumpMultiplierPerSecond());
    this.kink = BigNumber.from(await jumpRateModelContract.callStatic.kink());

    this.reserveFactorMantissa = BigNumber.from(reserveFactorMantissa);
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(adminFeeMantissa));
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(fuseFeeMantissa));

    this.initialized = true;
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
    this.baseRatePerSecond = BigNumber.from(baseRatePerSecond);
    this.multiplierPerSecond = BigNumber.from(multiplierPerSecond);
    this.jumpMultiplierPerSecond = BigNumber.from(jumpMultiplierPerSecond);
    this.kink = BigNumber.from(kink);

    this.reserveFactorMantissa = BigNumber.from(reserveFactorMantissa);
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(adminFeeMantissa));
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(fuseFeeMantissa));

    this.initialized = true;
  }

  getBorrowRate(utilizationRate: BigNumber) {
    if (
      !this.initialized ||
      !this.kink ||
      !this.multiplierPerSecond ||
      !this.baseRatePerSecond ||
      !this.jumpMultiplierPerSecond
    )
      throw new Error("Interest rate model class not initialized.");
    if (utilizationRate.lte(this.kink)) {
      return utilizationRate.mul(this.multiplierPerSecond).div(utils.parseEther("1")).add(this.baseRatePerSecond);
    } else {
      const normalRate = this.kink.mul(this.multiplierPerSecond).div(utils.parseEther("1")).add(this.baseRatePerSecond);
      const excessUtil = utilizationRate.sub(this.kink);
      return excessUtil.mul(this.jumpMultiplierPerSecond).div(utils.parseEther("1")).add(normalRate);
    }
  }

  getSupplyRate(utilizationRate: BigNumber) {
    if (!this.initialized || !this.reserveFactorMantissa) throw new Error("Interest rate model class not initialized.");
    const oneMinusReserveFactor = utils.parseEther("1").sub(this.reserveFactorMantissa);
    const borrowRate = this.getBorrowRate(utilizationRate);
    const rateToPool = borrowRate.mul(oneMinusReserveFactor).div(utils.parseEther("1"));
    return utilizationRate.mul(rateToPool).div(utils.parseEther("1"));
  }
}
