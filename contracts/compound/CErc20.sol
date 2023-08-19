// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts/contracts/utils/Address.sol";

import "./IERC4626.sol";
import "./CToken.sol";

interface PauseGuardianComptroller {
  function pauseGuardian() external pure returns (address);
}

/**
 * @title Compound's CErc20 Contract
 * @notice CTokens which wrap an EIP-20 underlying
 * @dev This contract should not to be deployed on its own; instead, deploy `CErc20Delegator` (proxy contract) and `CErc20Delegate` (logic/implementation contract).
 * @author Compound
 */
contract CErc20 is CToken, CErc20Interface {
  /**
   * @notice Initialize the new money market
   * @param underlying_ The address of the underlying asset
   * @param comptroller_ The address of the Comptroller
   * @param fuseAdmin_ The FuseFeeDistributor contract address.
   * @param interestRateModel_ The address of the interest rate model
   * @param name_ ERC-20 name of this token
   * @param symbol_ ERC-20 symbol of this token
   */
  function initialize(
    address underlying_,
    ComptrollerInterface comptroller_,
    address payable fuseAdmin_,
    InterestRateModel interestRateModel_,
    string memory name_,
    string memory symbol_,
    uint256 reserveFactorMantissa_,
    uint256 adminFeeMantissa_
  ) public {
    // CToken initialize does the bulk of the work
    uint256 initialExchangeRateMantissa_ = 0.2e18;
    uint8 decimals_ = EIP20Interface(underlying_).decimals();
    super.initialize(
      comptroller_,
      fuseAdmin_,
      interestRateModel_,
      initialExchangeRateMantissa_,
      name_,
      symbol_,
      decimals_,
      reserveFactorMantissa_,
      adminFeeMantissa_
    );

    // Set underlying and sanity check it
    underlying = underlying_;
    EIP20Interface(underlying).totalSupply();
  }

  /*** ERC4626 Interface */

  function asset() public view returns (address) {
    return underlying;
  }

  function deposit(uint256 assets, address receiver) public virtual returns (uint256) {
    accrueInterest();

    (uint256 err, uint256 actualAssets) = mintInternal(assets, receiver);
    if (err != uint256(Error.NO_ERROR)) {
      revert();
    }

    return previewDeposit(actualAssets);
  }

  function mint(uint256 shares, address receiver) public virtual returns (uint256) {
    accrueInterest();

    uint256 assets = previewMint(shares);
    (uint256 err, uint256 actualMintAmount) = mintInternal(assets, receiver);
    if (err != uint256(Error.NO_ERROR)) {
      revert();
    }

    return actualMintAmount;
  }

  function withdraw(uint256 assets, address receiver, address owner) public virtual returns (uint256 shares) {
    accrueInterest();

    shares = previewWithdraw(assets);

    uint256 err = redeemUnderlyingInternal(assets, receiver, owner);
    if (err != uint256(Error.NO_ERROR)) {
      revert();
    }
  }

  function redeem(uint256 shares, address receiver, address owner) public virtual returns (uint256 assets) {
    accrueInterest();

    assets = previewRedeem(shares);

    uint256 err = redeemInternal(shares, receiver, owner);
    if (err != uint256(Error.NO_ERROR)) {
      revert();
    }
  }

  function totalAssets() public view virtual returns (uint256) {
    /* Remember the initial timestamp */
    uint256 currentTimestamp = block.timestamp;

    /* Read the previous values out of storage */
    uint256 cashPrior = getCashPrior();

    if (currentTimestamp == accrualTimestamp) {
      (MathError mathErr, uint256 cashPlusBorrowsMinusReserves) = addThenSubUInt(
        cashPrior,
        totalBorrows,
        add_(totalReserves, add_(totalAdminFees, totalFuseFees))
      );
      if (mathErr != MathError.NO_ERROR) {
        revert BalanceCalculationFailed();
      }

      return cashPlusBorrowsMinusReserves;
    }

    /* Calculate the current borrow interest rate */
    uint256 borrowRateMantissa = interestRateModel.getBorrowRate(
      cashPrior,
      totalBorrows,
      add_(totalReserves, add_(totalAdminFees, totalFuseFees))
    );

    if (borrowRateMantissa > borrowRateMaxMantissa) {
      revert BorrowRateAbsurdlyHigh();
    }

    /* Calculate the number of seconds elapsed since the last accrual */
    (MathError mathErr, uint256 secondDelta) = subUInt(currentTimestamp, accrualTimestamp);
    if (mathErr != MathError.NO_ERROR) {
      revert TimestampDeltaCalculationFailed();
    }

    Exp memory simpleInterestFactor = mul_(Exp({ mantissa: borrowRateMantissa }), secondDelta);
    uint256 interestAccumulated = mul_ScalarTruncate(simpleInterestFactor, totalBorrows);
    uint256 totalBorrowsNew = add_(interestAccumulated, totalBorrows);
    uint256 totalReservesNew = mul_ScalarTruncateAddUInt(
      Exp({ mantissa: reserveFactorMantissa }),
      interestAccumulated,
      totalReserves
    );
    uint256 totalFuseFeesNew = mul_ScalarTruncateAddUInt(
      Exp({ mantissa: fuseFeeMantissa }),
      interestAccumulated,
      totalFuseFees
    );
    uint256 totalAdminFeesNew = mul_ScalarTruncateAddUInt(
      Exp({ mantissa: adminFeeMantissa }),
      interestAccumulated,
      totalAdminFees
    );
    uint256 cashPlusBorrowsMinusReserves;

    (mathErr, cashPlusBorrowsMinusReserves) = addThenSubUInt(
      cashPrior,
      totalBorrowsNew,
      add_(totalReservesNew, add_(totalAdminFeesNew, totalFuseFeesNew))
    );
    if (mathErr != MathError.NO_ERROR) {
      revert BalanceCalculationFailed();
    }

    return cashPlusBorrowsMinusReserves;
  }

  function convertToShares(uint256 assets) public view virtual returns (uint256) {
    uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

    uint256 exchangeRate = supply == 0 ? initialExchangeRateMantissa : ((totalAssets() * 1e18) / supply);

    return (1e18 * assets) / exchangeRate;
  }

  function convertToAssets(uint256 shares) public view virtual returns (uint256) {
    uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

    uint256 exchangeRate = supply == 0 ? initialExchangeRateMantissa : ((1e18 * totalAssets()) / supply);

    return (shares * exchangeRate) / 1e18;
  }

  function previewDeposit(uint256 assets) public view virtual returns (uint256) {
    return convertToShares(assets);
  }

  function previewMint(uint256 shares) public view virtual returns (uint256) {
    uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

    uint256 exchangeRate = supply == 0 ? initialExchangeRateMantissa : ((1e18 * totalAssets()) / supply);

    return mulWadUp(shares, exchangeRate);
  }

  function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
    uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

    uint256 exchangeRate = supply == 0 ? initialExchangeRateMantissa : ((totalAssets() * 1e18) / supply);

    return divWadUp(assets, exchangeRate);
  }

  function previewRedeem(uint256 shares) public view virtual returns (uint256) {
    return convertToAssets(shares);
  }

  function maxDeposit(address) public view virtual returns (uint256) {
    uint256 supplyCap = comptroller.getSupplyCap(address(this));
    uint256 assets = totalAssets();

    if (assets >= supplyCap) {
      return 0;
    }

    return supplyCap - assets - 1;
  }

  function maxMint(address receiver) public view virtual returns (uint256) {
    return convertToShares(maxDeposit(receiver));
  }

  function maxWithdraw(address owner) public view virtual returns (uint256) {
    return convertToAssets(accountTokens[owner]);
  }

  function maxRedeem(address owner) public view virtual returns (uint256) {
    return accountTokens[owner];
  }

  /*** User Interface ***/

  /**
   * @notice Sender supplies assets into the market and receives cTokens in exchange
   * @dev Accrues interest whether or not the operation succeeds, unless reverted
   * @param mintAmount The amount of the underlying asset to supply
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function mint(uint256 mintAmount) external override returns (uint256) {
    (uint256 err, ) = mintInternal(mintAmount, msg.sender);
    return err;
  }

  /**
   * @notice Sender redeems cTokens in exchange for the underlying asset
   * @dev Accrues interest whether or not the operation succeeds, unless reverted
   * @param redeemTokens The number of cTokens to redeem into underlying
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function redeem(uint256 redeemTokens) external override returns (uint256) {
    return redeemInternal(redeemTokens, msg.sender, msg.sender);
  }

  /**
   * @notice Sender redeems cTokens in exchange for a specified amount of underlying asset
   * @dev Accrues interest whether or not the operation succeeds, unless reverted
   * @param redeemAmount The amount of underlying to redeem
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function redeemUnderlying(uint256 redeemAmount) external override returns (uint256) {
    return redeemUnderlyingInternal(redeemAmount, msg.sender, msg.sender);
  }

  /**
   * @notice Sender borrows assets from the protocol to their own address
   * @param borrowAmount The amount of the underlying asset to borrow
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function borrow(uint256 borrowAmount) external override returns (uint256) {
    return borrowInternal(borrowAmount, msg.sender, msg.sender);
  }

  /**
   * @notice Sender borrows assets from the protocol on behalf of the borrower
   * @param borrowAmount The amount of the underlying asset to borrow
   * @param borrower The borrower
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function borrowBehalf(uint256 borrowAmount, address borrower) external returns (uint256) {
    return borrowInternal(borrowAmount, borrower, borrower);
  }

  /**
   * @notice Sender borrows assets from the protocol on behalf of the borrower
   * @param borrowAmount The amount of the underlying asset to borrow
   * @param receiver The address that will receive the borrowed funds
   * @param borrower The borrower
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function borrowBehalf(uint256 borrowAmount, address receiver, address borrower) external returns (uint256) {
    return borrowInternal(borrowAmount, receiver, borrower);
  }

  /**
   * @notice Sender repays their own borrow
   * @param repayAmount The amount to repay
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function repayBorrow(uint256 repayAmount) external override returns (uint256) {
    (uint256 err, ) = repayBorrowInternal(repayAmount);
    return err;
  }

  /**
   * @notice Sender repays a borrow belonging to borrower
   * @param borrower the account with the debt being payed off
   * @param repayAmount The amount to repay
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function repayBorrowBehalf(address borrower, uint256 repayAmount) external override returns (uint256) {
    (uint256 err, ) = repayBorrowBehalfInternal(borrower, repayAmount);
    return err;
  }

  /**
   * @notice The sender liquidates the borrowers collateral.
   *  The collateral seized is transferred to the liquidator.
   * @param borrower The borrower of this cToken to be liquidated
   * @param repayAmount The amount of the underlying borrowed asset to repay
   * @param cTokenCollateral The market in which to seize collateral from the borrower
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function liquidateBorrow(
    address borrower,
    uint256 repayAmount,
    CTokenInterface cTokenCollateral
  ) external override returns (uint256) {
    (uint256 err, ) = liquidateBorrowInternal(borrower, repayAmount, cTokenCollateral);
    return err;
  }

  /**
   * @notice Admin call to set vault for market
   * @param newVault The address of the new vault
   */
  function setVault(address newVault) external {
    if (
      !hasAdminRights() &&
      (msg.sender != PauseGuardianComptroller(address(comptroller)).pauseGuardian() || newVault != address(0))
    ) {
      revert Unauthorized();
    }

    if (newVault != address(0) && !Address.isContract(newVault)) {
      revert InvalidVault();
    }

    if (vault != address(0)) {
      IERC4626 _vault = IERC4626(vault);
      uint shares = _vault.balanceOf(address(this));
      if (shares != 0) {
        _vault.redeem(shares, address(this), address(this));
      }
    }

    if (newVault != address(0)) {
      EIP20Interface token = EIP20Interface(underlying);
      uint tokenBalance = token.balanceOf(address(this));
      token.approve(newVault, type(uint256).max);
      if (tokenBalance > 0) {
        IERC4626(newVault).deposit(tokenBalance, address(this));
      }
    }

    emit NewVault(vault, newVault);
    vault = newVault;
  }

  /*** Safe Token ***/

  /**
   * @notice Gets balance of this contract in terms of the underlying
   * @dev This excludes the value of the current message, if any
   * @return The quantity of underlying tokens owned by this contract
   */
  function getCashPrior() internal view virtual override returns (uint256) {
    if (vault != address(0)) {
      IERC4626 _vault = IERC4626(vault);
      return _vault.convertToAssets(_vault.balanceOf(address(this)));
    }

    EIP20Interface token = EIP20Interface(underlying);
    return token.balanceOf(address(this));
  }

  /**
   * @dev Similar to EIP20 transfer, except it handles a False result from `transferFrom` and reverts in that case.
   *      This will revert due to insufficient balance or insufficient allowance.
   *      This function returns the actual amount received,
   *      which may be less than `amount` if there is a fee attached to the transfer.
   *
   *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
   *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
   */
  function doTransferIn(address from, uint256 amount) internal virtual override returns (uint256) {
    uint256 balanceBefore = EIP20Interface(underlying).balanceOf(address(this));
    _callOptionalReturn(
      abi.encodeWithSelector(EIP20NonStandardInterface(underlying).transferFrom.selector, from, address(this), amount),
      "TOKEN_TRANSFER_IN_FAILED"
    );

    // Calculate the amount that was *actually* transferred
    uint256 balanceAfter = EIP20Interface(underlying).balanceOf(address(this));
    if (balanceAfter < balanceBefore) {
      revert TokenTransferInOverflow();
    }

    // Transfer all the tokens to vault if one is set
    if (vault != address(0)) {
      IERC4626(vault).deposit(amount, address(this));
    }

    return balanceAfter - balanceBefore; // underflow already checked above, just subtract
  }

  /**
   * @dev Similar to EIP20 transfer, except it handles a False success from `transfer` and returns an explanatory
   *      error code rather than reverting. If caller has not called checked protocol's balance, this may revert due to
   *      insufficient cash held in this contract. If caller has checked protocol's balance prior to this call, and verified
   *      it is >= amount, this should not revert in normal conditions.
   *
   *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
   *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
   */
  function doTransferOut(address to, uint256 amount) internal virtual override {
    if (vault == address(0)) {
      _callOptionalReturn(
        abi.encodeWithSelector(EIP20NonStandardInterface(underlying).transfer.selector, to, amount),
        "TOKEN_TRANSFER_OUT_FAILED"
      );
    } else {
      IERC4626(vault).withdraw(amount, to, address(this));
    }
  }

  /**
   * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
   * on the return value: the return value is optional (but if data is returned, it must not be false).
   * @param data The call data (encoded using abi.encode or one of its variants).
   * @param errorMessage The revert string to return on failure.
   */
  function _callOptionalReturn(bytes memory data, string memory errorMessage) internal {
    bytes memory returndata = _functionCall(underlying, data, errorMessage);
    if (returndata.length > 0) require(abi.decode(returndata, (bool)), errorMessage);
  }
}
