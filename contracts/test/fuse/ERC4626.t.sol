// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC4626Test } from "erc4626-tests/ERC4626.test.sol";

import "./BaseFuseTest.sol";

contract ERC4626StdTest is ERC4626Test, BaseFuseTest {
  function setUp() public override(ERC4626Test, BaseFuseTest) {
    BaseFuseTest.setUp();

    _underlying_ = address(tokenOne);
    _vault_ = address(tokenOneMarket);
    _delta_ = 11e18;
    _vaultMayBeEmpty = false;
    _unlimitedAmount = false;
  }

  // Copied from https://github.com/a16z/erc4626-tests/blob/8b1d7c2ac248c33c3506b1bff8321758943c5e11/ERC4626.test.sol#L50-L59
  // With capped yield
  function setUpYield(Init memory init) public override {
    if (init.yield >= 0) {
      // gain
      uint gain = uint(init.yield);
      vm.assume(gain < 1e59);

      try MockERC20(_underlying_).mint(_vault_, gain) {} catch {
        vm.assume(false);
      } // this can be replaced by calling yield generating functions if provided by the vault
    } else {
      // loss
      vm.assume(init.yield > type(int).min); // avoid overflow in conversion
      uint loss = uint(-1 * init.yield);
      try MockERC20(_underlying_).burn(_vault_, loss) {} catch {
        vm.assume(false);
      } // this can be replaced by calling yield generating functions if provided by the vault
    }
  }
}
