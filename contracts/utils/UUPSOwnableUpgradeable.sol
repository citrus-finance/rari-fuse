// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { UUPSUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

contract UUPSOwnableUpgradeable is Initializable, UUPSUpgradeable {
  function __UUPSOwnableUpgradeable_init(address owner) internal onlyInitializing {
    _changeAdmin(owner);
  }

  /**
   * @dev Returns the address of the current owner.
   */
  function owner() public view returns (address) {
    return _getAdmin();
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Can only be called by the current owner.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    _changeAdmin(newOwner);
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(owner() == msg.sender, "Ownable: caller is not the owner");
    _;
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
