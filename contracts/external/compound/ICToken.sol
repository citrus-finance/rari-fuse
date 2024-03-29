// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0;

/**
 * @title Compound's CToken Contract
 * @notice Abstract base for CTokens
 * @author Compound
 */
interface ICToken {
  function admin() external view returns (address);

  function adminHasRights() external view returns (bool);

  function fuseAdminHasRights() external view returns (bool);

  function symbol() external view returns (string memory);

  function comptroller() external view returns (address);

  function adminFeeMantissa() external view returns (uint256);

  function fuseFeeMantissa() external view returns (uint256);

  function reserveFactorMantissa() external view returns (uint256);

  function totalReserves() external view returns (uint256);

  function totalAdminFees() external view returns (uint256);

  function totalFuseFees() external view returns (uint256);

  function isCToken() external view returns (bool);

  function isCEther() external view returns (bool);

  function balanceOf(address owner) external view returns (uint256);

  function balanceOfUnderlying(address owner) external returns (uint256);

  function borrowRatePerSecond() external view returns (uint256);

  function supplyRatePerSecond() external view returns (uint256);

  function totalBorrowsCurrent() external returns (uint256);

  function borrowBalanceStored(address account) external view returns (uint256);

  function exchangeRateCurrent() external view returns (uint256);

  function exchangeRateStored() external view returns (uint256);

  function getCash() external view returns (uint256);

  function redeem(uint256 redeemTokens) external returns (uint256);

  function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
}
