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
  }
}
