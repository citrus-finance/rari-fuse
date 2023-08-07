// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "solmate/test/utils/mocks/MockERC4626.sol";

import "./BaseFuseTest.sol";

contract VaultTest is BaseFuseTest {
  function testDepositWithVault() public skipUnsuportedChain {
    deal(address(tokenOne), address(this), 1e18);

    MockERC4626 vault = new MockERC4626(tokenOne, "Vault", "V");
    tokenOneMarket.setVault(address(vault));

    tokenOne.approve(address(tokenOneMarket), 1e18);
    tokenOneMarket.mint(1e18);

    assertEq(tokenOneMarket.getCash(), 1e18);
    assertEq(vault.totalAssets(), 1e18);
  }

  function testSettingVault() public skipUnsuportedChain {
    deal(address(tokenOne), address(this), 1e18);

    MockERC4626 vault = new MockERC4626(tokenOne, "Vault", "V");

    assertEq(tokenOneMarket.getCash(), 0);
    assertEq(tokenOne.balanceOf(address(tokenOneMarket)), 0);
    assertEq(vault.totalAssets(), 0);

    tokenOne.approve(address(tokenOneMarket), 1e18);
    tokenOneMarket.mint(1e18);

    assertEq(tokenOneMarket.getCash(), 1e18);
    assertEq(tokenOne.balanceOf(address(tokenOneMarket)), 1e18);
    assertEq(vault.totalAssets(), 0);

    tokenOneMarket.setVault(address(vault));

    assertEq(tokenOneMarket.getCash(), 1e18);
    assertEq(tokenOne.balanceOf(address(tokenOneMarket)), 0);
    assertEq(vault.totalAssets(), 1e18);
  }

  function testUnsettingVault() public skipUnsuportedChain {
    deal(address(tokenOne), address(this), 1e18);

    MockERC4626 vault = new MockERC4626(tokenOne, "Vault", "V");
    tokenOneMarket.setVault(address(vault));

    assertEq(tokenOneMarket.getCash(), 0);
    assertEq(tokenOne.balanceOf(address(tokenOneMarket)), 0);
    assertEq(vault.totalAssets(), 0);

    tokenOne.approve(address(tokenOneMarket), 1e18);
    tokenOneMarket.mint(1e18);

    assertEq(tokenOneMarket.getCash(), 1e18);
    assertEq(tokenOne.balanceOf(address(tokenOneMarket)), 0);
    assertEq(vault.totalAssets(), 1e18);

    tokenOneMarket.setVault(address(0));

    assertEq(tokenOneMarket.getCash(), 1e18);
    assertEq(tokenOne.balanceOf(address(tokenOneMarket)), 1e18);
    assertEq(vault.totalAssets(), 0);
  }

  function testGuardianCannotSetVault() public skipUnsuportedChain {
    address guardian = makeAddr("Guardian");

    comptroller._setPauseGuardian(guardian);

    MockERC4626 vault = new MockERC4626(tokenOne, "Vault", "V");

    vm.expectRevert(CTokenInterface.Unauthorized.selector);
    vm.prank(guardian);
    tokenOneMarket.setVault(address(vault));
  }

  function testGuardianCanUnsetVault() public skipUnsuportedChain {
    address guardian = makeAddr("Guardian");

    comptroller._setPauseGuardian(guardian);

    MockERC4626 vault = new MockERC4626(tokenOne, "Vault", "V");
    tokenOneMarket.setVault(address(vault));

    assertEq(tokenOneMarket.vault(), address(vault));

    vm.prank(guardian);
    tokenOneMarket.setVault(address(0));

    assertEq(tokenOneMarket.vault(), address(0));
  }
}
