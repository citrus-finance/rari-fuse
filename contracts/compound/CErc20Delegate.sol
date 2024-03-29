// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./CErc20.sol";
import "./CDelegateInterface.sol";

/**
 * @title Compound's CErc20Delegate Contract
 * @notice CTokens which wrap an EIP-20 underlying and are delegated to
 * @author Compound
 */
contract CErc20Delegate is CDelegateInterface, CErc20 {
  /**
   * @notice Construct an empty delegate
   */
  constructor() {}

  /**
   * @notice Called by the delegator on a delegate to initialize it for duty
   * @param data The encoded bytes data for any initialization
   */
  function _becomeImplementation(bytes calldata data) external virtual override {
    if (msg.sender != address(this) && !hasAdminRights()) {
      revert Unauthorized();
    }
  }

  /**
   * @notice Called by the delegator on a delegate to forfeit its responsibility
   */
  function _resignImplementation() internal virtual {
    // Shh -- we don't ever want this hook to be marked pure
    if (false) {
      implementation = address(0);
    }
  }

  /**
   * @dev Internal function to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation
   * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
   */
  function _setImplementationInternal(
    address implementation_,
    bool allowResign,
    bytes memory becomeImplementationData
  ) internal {
    // Check whitelist
    if (!IFuseFeeDistributor(fuseAdmin).cErc20DelegateWhitelist(implementation, implementation_, allowResign)) {
      revert ImplementationNotWhitelisted();
    }

    // Call _resignImplementation internally (this delegate's code)
    if (allowResign) _resignImplementation();

    // Get old implementation
    address oldImplementation = implementation;

    // Store new implementation
    implementation = implementation_;

    // Call _becomeImplementation externally (delegating to new delegate's code)
    _functionCall(
      address(this),
      abi.encodeWithSignature("_becomeImplementation(bytes)", becomeImplementationData),
      "!become"
    );

    // Emit event
    emit NewImplementation(oldImplementation, implementation);
  }

  /**
   * @notice Called by the admin to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation
   * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
   */
  function _setImplementationSafe(
    address implementation_,
    bool allowResign,
    bytes calldata becomeImplementationData
  ) external override {
    // Check admin rights
    if (!hasAdminRights()) {
      revert Unauthorized();
    }

    // Set implementation
    _setImplementationInternal(implementation_, allowResign, becomeImplementationData);
  }

  /**
   * @notice Function called before all delegator functions
   * @dev Checks comptroller.autoImplementation and upgrades the implementation if necessary
   */
  function _prepare() external payable override {
    if (msg.sender != address(this) && ComptrollerV3Storage(address(comptroller)).autoImplementation()) {
      (address latestCErc20Delegate, bool allowResign, bytes memory becomeImplementationData) = IFuseFeeDistributor(
        fuseAdmin
      ).latestCErc20Delegate(implementation);
      if (implementation != latestCErc20Delegate)
        _setImplementationInternal(latestCErc20Delegate, allowResign, becomeImplementationData);
    }
  }
}
