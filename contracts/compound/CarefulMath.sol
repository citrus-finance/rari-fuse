// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

/**
 * @title Careful Math
 * @author Compound
 * @notice Derived from OpenZeppelin's SafeMath library
 *         https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/math/SafeMath.sol
 */
contract CarefulMath {
  uint256 internal constant MAX_UINT256 = 2 ** 256 - 1;

  /**
   * @dev Possible error codes that we can return
   */
  enum MathError {
    NO_ERROR,
    DIVISION_BY_ZERO,
    INTEGER_OVERFLOW,
    INTEGER_UNDERFLOW
  }

  /**
   * @dev Multiplies two numbers, returns an error on overflow.
   */
  function mulUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
    if (a == 0) {
      return (MathError.NO_ERROR, 0);
    }

    uint256 c = a * b;

    if (c / a != b) {
      return (MathError.INTEGER_OVERFLOW, 0);
    } else {
      return (MathError.NO_ERROR, c);
    }
  }

  /**
   * @dev Integer division of two numbers, truncating the quotient.
   */
  function divUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
    if (b == 0) {
      return (MathError.DIVISION_BY_ZERO, 0);
    }

    return (MathError.NO_ERROR, a / b);
  }

  /**
   * @dev Subtracts two numbers, returns an error on overflow (i.e. if subtrahend is greater than minuend).
   */
  function subUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
    if (b <= a) {
      return (MathError.NO_ERROR, a - b);
    } else {
      return (MathError.INTEGER_UNDERFLOW, 0);
    }
  }

  /**
   * @dev Adds two numbers, returns an error on overflow.
   */
  function addUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
    uint256 c = a + b;

    if (c >= a) {
      return (MathError.NO_ERROR, c);
    } else {
      return (MathError.INTEGER_OVERFLOW, 0);
    }
  }

  /**
   * @dev add a and b and then subtract c
   */
  function addThenSubUInt(uint256 a, uint256 b, uint256 c) internal pure returns (MathError, uint256) {
    (MathError err0, uint256 sum) = addUInt(a, b);

    if (err0 != MathError.NO_ERROR) {
      return (err0, 0);
    }

    return subUInt(sum, c);
  }

  // Copied from: https://github.com/transmissions11/solmate/blob/fadb2e2778adbf01c80275bfb99e5c14969d964b/src/utils/FixedPointMathLib.sol#L28-L30
  function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
    return mulDivUp(x, 1e18, y); // Equivalent to (x * WAD) / y rounded up.
  }

  function mulDivUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z) {
    /// @solidity memory-safe-assembly
    assembly {
      // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
      if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
        revert(0, 0)
      }

      // If x * y modulo the denominator is strictly greater than 0,
      // 1 is added to round up the division of x * y by the denominator.
      z := add(gt(mod(mul(x, y), denominator), 0), div(mul(x, y), denominator))
    }
  }
}
