// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "solmate/test/utils/mocks/MockERC4626.sol";

import "./BaseFuseTest.sol";

contract NewFuseFeeDistributor is FuseFeeDistributor {
  function upgraded() public pure returns (bool) {
    return true;
  }
}

contract NewFusePoolDirectory is FusePoolDirectory {
  function upgraded() public pure returns (bool) {
    return true;
  }
}

contract UpgradesTest is BaseFuseTest {
  function testFuseFeeDistributorUpgrade() public skipUnsuportedChain {
    vm.expectRevert();
    NewFuseFeeDistributor(payable(fuseFeeDistributor)).upgraded();

    NewFuseFeeDistributor newFuseFeeDistributor = new NewFuseFeeDistributor();

    fuseFeeDistributor.upgradeTo(address(newFuseFeeDistributor));

    assertTrue(NewFuseFeeDistributor(payable(fuseFeeDistributor)).upgraded());
  }

  function testFusePoolDirectoryUpgrade() public skipUnsuportedChain {
    vm.expectRevert();
    NewFusePoolDirectory(address(fusePoolDirectory)).upgraded();

    NewFusePoolDirectory newFusePoolDirectory = new NewFusePoolDirectory();

    fusePoolDirectory.upgradeTo(address(newFusePoolDirectory));

    assertTrue(NewFusePoolDirectory(address(fusePoolDirectory)).upgraded());
  }

  function testFuseFeeDistributorUpgradeByAnyone() public skipUnsuportedChain {
    NewFuseFeeDistributor newFuseFeeDistributor = new NewFuseFeeDistributor();

    vm.startPrank(makeAddr("user"));
    vm.expectRevert(bytes("Ownable: caller is not the owner"));
    fuseFeeDistributor.upgradeTo(address(newFuseFeeDistributor));
  }

  function testFusePoolDirectoryUpgradeByAnyone() public skipUnsuportedChain {
    NewFusePoolDirectory newFusePoolDirectory = new NewFusePoolDirectory();

    vm.startPrank(makeAddr("user"));
    vm.expectRevert(bytes("Ownable: caller is not the owner"));
    fusePoolDirectory.upgradeTo(address(newFusePoolDirectory));
  }
}
