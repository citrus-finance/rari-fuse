// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./CToken.sol";

contract RewardsDistributorDelegatorStorage {
  /// @notice Administrator for this contract
  address public admin;

  /// @notice Pending administrator for this contract
  address public pendingAdmin;

  /// @notice Active brains of RewardsDistributor
  address public implementation;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[10] private __gap;
}

/**
 * @title Storage for RewardsDistributorDelegate
 * @notice For future upgrades, do not change RewardsDistributorDelegateStorageV1. Create a new
 * contract which implements RewardsDistributorDelegateStorageV1 and following the naming convention
 * RewardsDistributorDelegateStorageVX.
 */
contract RewardsDistributorDelegateStorageV1 is RewardsDistributorDelegatorStorage {
  /// @dev The token to reward (i.e., COMP)
  address public rewardToken;

  struct CompMarketState {
    // The market's last updated compBorrowIndex or compSupplyIndex
    uint216 index;
    // The block timestamp the index was last updated at
    uint40 timestamp;
  }

  /// @notice A list of all markets
  CToken[] public allMarkets;

  /// @notice The portion of compRate that each market currently receives
  mapping(address => uint256) public compSupplySpeeds;

  /// @notice The portion of compRate that each market currently receives
  mapping(address => uint256) public compBorrowSpeeds;

  /// @notice The COMP market supply state for each market
  mapping(address => CompMarketState) public compSupplyState;

  /// @notice The COMP market borrow state for each market
  mapping(address => CompMarketState) public compBorrowState;

  /// @notice The COMP borrow index for each market for each supplier as of the last time they accrued COMP
  mapping(address => mapping(address => uint256)) public compSupplierIndex;

  /// @notice The COMP borrow index for each market for each borrower as of the last time they accrued COMP
  mapping(address => mapping(address => uint256)) public compBorrowerIndex;

  /// @notice The COMP accrued but not yet transferred to each user
  mapping(address => uint256) public compAccrued;

  /// @notice The portion of COMP that each contributor receives per second
  mapping(address => uint256) public compContributorSpeeds;

  /// @notice Last timestamp at which a contributor's COMP rewards have been allocated
  mapping(address => uint256) public lastContributorTimestamp;
}
