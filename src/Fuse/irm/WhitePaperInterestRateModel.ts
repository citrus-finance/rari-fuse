import { BigNumber, BigNumberish, constants, Contract, utils } from "ethers";
import { Web3Provider } from "@ethersproject/providers";

import { InterestRateModel } from "../types";
import WhitePaperInterestRateModelArtifact from "../../../out/WhitePaperInterestRateModel.sol/WhitePaperInterestRateModel.json";
import CTokenInterfacesArtifact from "../../../out/CTokenInterfaces.sol/CTokenInterface.json";

export default class WhitePaperInterestRateModel implements InterestRateModel {
  static RUNTIME_BYTECODE_HASH = utils.keccak256(WhitePaperInterestRateModelArtifact.deployedBytecode.object);

  initialized: boolean | undefined;
  baseRatePerSecond: BigNumber | undefined;
  multiplierPerSecond: BigNumber | undefined;
  reserveFactorMantissa: BigNumber | undefined;

  async init(interestRateModelAddress: string, assetAddress: string, provider: any) {
    const whitePaperModelContract = new Contract(
      interestRateModelAddress,
      WhitePaperInterestRateModelArtifact.abi,
      provider
    );

    this.baseRatePerSecond = BigNumber.from(await whitePaperModelContract.callStatic.baseRatePerSecond());
    this.multiplierPerSecond = BigNumber.from(await whitePaperModelContract.callStatic.multiplierPerSecond());

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
  ) {
    console.log(
      interestRateModelAddress,
      reserveFactorMantissa,
      adminFeeMantissa,
      fuseFeeMantissa,
      provider,
      "IRMMMMMM PARAMS WPIRM"
    );
    const whitePaperModelContract = new Contract(
      interestRateModelAddress,
      WhitePaperInterestRateModelArtifact.abi,
      provider
    );

    this.baseRatePerSecond = BigNumber.from(await whitePaperModelContract.callStatic.baseRatePerSecond());
    this.multiplierPerSecond = BigNumber.from(await whitePaperModelContract.callStatic.multiplierPerSecond());

    this.reserveFactorMantissa = BigNumber.from(reserveFactorMantissa);
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(adminFeeMantissa));
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(fuseFeeMantissa));

    this.initialized = true;
  }

  async __init(
    baseRatePerSecond: BigNumberish,
    multiplierPerSecond: BigNumberish,
    reserveFactorMantissa: BigNumberish,
    adminFeeMantissa: BigNumberish,
    fuseFeeMantissa: BigNumberish
  ) {
    this.baseRatePerSecond = BigNumber.from(baseRatePerSecond);
    this.multiplierPerSecond = BigNumber.from(multiplierPerSecond);

    this.reserveFactorMantissa = BigNumber.from(reserveFactorMantissa);
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(adminFeeMantissa));
    this.reserveFactorMantissa = this.reserveFactorMantissa.add(BigNumber.from(fuseFeeMantissa));
    this.initialized = true;
  }

  getBorrowRate(utilizationRate: BigNumber) {
    if (!this.initialized || !this.multiplierPerSecond || !this.baseRatePerSecond)
      throw new Error("Interest rate model class not initialized.");
    return utilizationRate.mul(this.multiplierPerSecond).div(constants.WeiPerEther).add(this.baseRatePerSecond);
  }

  getSupplyRate(utilizationRate: BigNumber): BigNumber {
    if (!this.initialized || !this.reserveFactorMantissa) throw new Error("Interest rate model class not initialized.");

    const oneMinusReserveFactor = constants.WeiPerEther.sub(this.reserveFactorMantissa);
    const borrowRate = this.getBorrowRate(utilizationRate);
    const rateToPool = borrowRate.mul(oneMinusReserveFactor).div(constants.WeiPerEther);
    return utilizationRate.mul(rateToPool).div(constants.WeiPerEther);
  }
}
