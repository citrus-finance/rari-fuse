// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./BaseFuseTest.sol";

contract PoolTest is BaseFuseTest {
  function testDeposit() public skipUnsuportedChain {
    deal(address(tokenOne), address(this), 1e18);

    assertEq(tokenOneMarket.balanceOf(address(this)), 0);

    tokenOne.approve(address(tokenOneMarket), 1e18);
    tokenOneMarket.mint(1e18);

    assertEq(tokenOneMarket.balanceOf(address(this)), 5e18);
    assertEq(tokenOneMarket.balanceOfUnderlying(address(this)), 1e18);
    assertEq(tokenOneMarket.getCash(), 1e18);
  }

  function testBorrow() public skipUnsuportedChain {
    uint256 tokenOneDepositAmount = getAmountOfTokenOne(1000);
    uint256 tokenTwoBorrowAmount = getAmountOfTokenTwo(100);

    addLiquidity(tokenTwo, getAmountOfTokenTwo(1_000_000));

    deal(address(tokenOne), address(this), tokenOneDepositAmount);

    tokenOne.approve(address(tokenOneMarket), tokenOneDepositAmount);
    tokenOneMarket.mint(tokenOneDepositAmount);
    comptroller.enterMarkets(toArray(address(tokenOneMarket)));
    assertEq(tokenTwoMarket.borrow(tokenTwoBorrowAmount), 0);

    assertEq(tokenTwo.balanceOf(address(this)), tokenTwoBorrowAmount);
    assertEq(tokenTwoMarket.borrowBalanceCurrent(address(this)), tokenTwoBorrowAmount);

    skip(60_000);

    // HACK: don't invert, order is essentials
    assertEq(
      (tokenTwoMarket.totalAssets() * 1e18) / tokenTwoMarket.totalSupply(),
      tokenTwoMarket.exchangeRateCurrent()
    );
  }

  function testDepositRedeemMax() public skipUnsuportedChain {
    deal(address(tokenOne), address(this), tokenOneMarket.maxDeposit(address(this)));

    tokenOne.approve(address(tokenOneMarket), tokenOneMarket.maxDeposit(address(this)));
    tokenOneMarket.mint(tokenOneMarket.maxDeposit(address(this)));
    tokenOneMarket.redeemUnderlying(tokenOneMarket.maxDeposit(address(this)));

    assertEq(tokenOne.balanceOf(address(this)), tokenOneMarket.maxDeposit(address(this)));
  }

  function testERC4626Mint() public skipUnsuportedChain {
    deal(address(tokenOne), address(this), 10e18);

    tokenOne.approve(address(tokenOneMarket), 10e18);
    tokenOneMarket.deposit(10e18, address(this));

    tokenOneMarket.redeem(tokenOneMarket.balanceOf(address(this)), address(this), address(this));

    assertEq(tokenOne.balanceOf(address(this)), 10e18);
  }

  function testMintRedeemPrecision() public skipUnsuportedChain {
    uint256 amount = 1e18;
    uint256 yield = 100e18 + 10;

    address user1 = makeAddr("user1");
    vm.startPrank(user1);

    deal(address(tokenOne), user1, amount);
    tokenOne.approve(address(tokenOneMarket), amount);
    tokenOneMarket.mint(amount);

    vm.stopPrank();

    address user2 = makeAddr("user2");
    vm.startPrank(user2);

    deal(address(tokenOne), user2, amount);

    tokenOne.approve(address(tokenOneMarket), amount);
    tokenOneMarket.mint(amount);

    vm.stopPrank();

    // Add extra cash to the market so exchange rate lose some precision
    deal(address(tokenOne), address(this), yield);
    tokenOne.transfer(address(tokenOneMarket), yield);

    vm.startPrank(user2);

    // Redeem all
    tokenOneMarket.redeemUnderlying(amount);
    tokenOneMarket.redeem(tokenOneMarket.balanceOf(user2));

    // if user2 manage to get more token than the amount remaning in the market, something went wrong
    assertApproxLeAbs(tokenOne.balanceOf(user2), tokenOneMarket.getCash(), 0);
  }

  function testRedeemOnBehalf() public skipUnsuportedChain {
    uint256 tokenOneDepositAmount = getAmountOfTokenOne(1_000);

    addLiquidity(tokenTwo, getAmountOfTokenTwo(1_000_000));

    address user = makeAddr("user");
    deal(address(tokenOne), user, tokenOneDepositAmount);

    vm.prank(user);
    tokenOne.approve(address(this), tokenOneDepositAmount);

    tokenOne.transferFrom(user, address(this), tokenOneDepositAmount);
    tokenOne.approve(address(tokenOneMarket), tokenOneDepositAmount);
    tokenOneMarket.deposit(tokenOneDepositAmount, user);

    vm.prank(user);
    tokenOneMarket.approve(address(this), tokenOneDepositAmount * 10);

    tokenOneMarket.withdraw(tokenOneDepositAmount, user, user);

    assertEq(tokenOne.balanceOf(user), tokenOneDepositAmount);
  }

  function testBorrowOnBehalf() public skipUnsuportedChain {
    uint256 tokenOneDepositAmount = getAmountOfTokenOne(1_000);
    uint256 tokenTwoBorrowAmount = getAmountOfTokenTwo(100);

    addLiquidity(tokenTwo, getAmountOfTokenTwo(1_000_000));

    address user = makeAddr("user");
    deal(address(tokenOne), user, tokenOneDepositAmount);

    vm.prank(user);
    tokenOne.approve(address(this), tokenOneDepositAmount);

    tokenOne.transferFrom(user, address(this), tokenOneDepositAmount);
    tokenOne.approve(address(tokenOneMarket), tokenOneDepositAmount);
    tokenOneMarket.deposit(tokenOneDepositAmount, user);

    vm.prank(user);
    tokenOneMarket.approve(address(this), 1);
    vm.prank(user);
    tokenTwoMarket.approve(address(this), tokenTwoBorrowAmount * 10);

    comptroller.enterMarketsBehalf(toArray(address(tokenOneMarket)), user);
    tokenTwoMarket.borrowBehalf(tokenTwoBorrowAmount, user, user);

    assertEq(tokenTwo.balanceOf(user), tokenTwoBorrowAmount);
  }

  function testBorrowOnBehalfWithoutApproval() public skipUnsuportedChain {
    uint256 tokenOneDepositAmount = getAmountOfTokenOne(1_000);
    uint256 tokenTwoBorrowAmount = getAmountOfTokenTwo(100);

    addLiquidity(tokenTwo, getAmountOfTokenTwo(1_000_000));

    address user = makeAddr("user");
    deal(address(tokenOne), user, tokenOneDepositAmount);

    vm.prank(user);
    tokenOne.approve(address(this), tokenOneDepositAmount);

    tokenOne.transferFrom(user, address(this), tokenOneDepositAmount);
    tokenOne.approve(address(tokenOneMarket), tokenOneDepositAmount);
    tokenOneMarket.deposit(tokenOneDepositAmount, user);

    vm.prank(user);
    tokenOneMarket.approve(address(this), 1);

    comptroller.enterMarketsBehalf(toArray(address(tokenOneMarket)), user);

    vm.expectRevert();
    tokenTwoMarket.borrowBehalf(tokenTwoBorrowAmount, user, user);
  }

  function testEnterMarketBehalfWithoutApproval() public skipUnsuportedChain {
    uint256 tokenOneDepositAmount = getAmountOfTokenOne(1_000);
    uint256 tokenTwoBorrowAmount = getAmountOfTokenTwo(100);

    addLiquidity(tokenTwo, getAmountOfTokenTwo(1_000_000));

    address user = makeAddr("user");
    deal(address(tokenOne), user, tokenOneDepositAmount);

    vm.prank(user);
    tokenOne.approve(address(this), tokenOneDepositAmount);

    tokenOne.transferFrom(user, address(this), tokenOneDepositAmount);
    tokenOne.approve(address(tokenOneMarket), tokenOneDepositAmount);
    tokenOneMarket.deposit(tokenOneDepositAmount, user);

    vm.prank(user);
    tokenTwoMarket.approve(address(this), tokenTwoBorrowAmount * 10);

    vm.expectRevert();
    comptroller.enterMarketsBehalf(toArray(address(tokenOneMarket)), user);
  }

  function testCannotRedeemOnBehalf() public skipUnsuportedChain {
    uint256 tokenOneDepositAmount = getAmountOfTokenOne(1_000);

    addLiquidity(tokenTwo, getAmountOfTokenTwo(1_000_000));

    address user = makeAddr("user");
    deal(address(tokenOne), user, tokenOneDepositAmount);

    vm.prank(user);
    tokenOne.approve(address(this), tokenOneDepositAmount);

    tokenOne.transferFrom(user, address(this), tokenOneDepositAmount);
    tokenOne.approve(address(tokenOneMarket), tokenOneDepositAmount);
    tokenOneMarket.deposit(tokenOneDepositAmount, user);

    vm.expectRevert();
    tokenOneMarket.withdraw(tokenOneDepositAmount, user, user);
  }

  // Copied from: https://github.com/a16z/erc4626-tests/blob/8b1d7c2ac248c33c3506b1bff8321758943c5e11/ERC4626.prop.sol#L391-L403
  function assertApproxLeAbs(uint a, uint b, uint maxDelta) internal {
    if (!(a <= b)) {
      uint dt = a - b;
      if (dt > maxDelta) {
        emit log("Error: a <=~ b not satisfied [uint]");
        emit log_named_uint("   Value a", a);
        emit log_named_uint("   Value b", b);
        emit log_named_uint(" Max Delta", maxDelta);
        emit log_named_uint("     Delta", dt);
        fail();
      }
    }
  }
}
