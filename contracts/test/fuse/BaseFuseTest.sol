// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

import "../../compound/CToken.sol";
import "../../compound/CErc20Delegate.sol";
import "../../compound/JumpRateModel.sol";
import "../../oracles/MasterPriceOracle.sol";
import "../../oracles/default/SimplePriceOracle.sol";
import "../../FuseFeeDistributor.sol";
import "../../FusePoolDirectory.sol";

contract BaseFuseTest is Test {
  ERC20 public tokenOne;

  ERC20 public tokenTwo;

  ERC20 public stable;

  CErc20 public tokenOneMarket;

  CErc20 public tokenTwoMarket;

  CErc20 public stableMarket;

  FuseFeeDistributor public fuseFeeDistributor;

  FusePoolDirectory public fusePoolDirectory;

  MasterPriceOracle public priceOracle;

  SimplePriceOracle public simplePriceOracle;

  Comptroller public comptroller;

  InterestRateModel public interestRateModel;

  CErc20 public cERC20Impl;

  function setUp() public {
    if (block.chainid == 31337) {
      tokenOne = new MockERC20("Wrapped Ether", "WETH", 18);
      tokenTwo = new MockERC20("Wrapped BTC", "WBTC", 8);
      stable = new MockERC20("USD Coin", "USDC", 6);

      Comptroller comptrollerImpl = new Comptroller();
      cERC20Impl = new CErc20Delegate();

      fuseFeeDistributor = new FuseFeeDistributor();
      fuseFeeDistributor.initialize(address(this), 0.1e18, address(comptrollerImpl), address(cERC20Impl));

      address[] memory emptyAddresses = new address[](0);

      fusePoolDirectory = new FusePoolDirectory();
      fusePoolDirectory.initialize(address(this), address(fuseFeeDistributor), false, emptyAddresses);

      address[] memory emptyAddressArray = new address[](0);
      IPriceOracle[] memory emptyPriceOracleArray = new IPriceOracle[](0);

      priceOracle = new MasterPriceOracle();
      priceOracle.initialize(
        emptyAddressArray,
        emptyPriceOracleArray,
        IPriceOracle(address(0)),
        address(this),
        true,
        address(tokenOne)
      );

      simplePriceOracle = new SimplePriceOracle();

      IPriceOracle[] memory simplePriceOracles = new IPriceOracle[](1);
      simplePriceOracles[0] = IPriceOracle(address(simplePriceOracle));

      simplePriceOracle.setDirectPrice(address(tokenOne), 2_000e18);
      priceOracle.add(toArray(address(tokenOne)), simplePriceOracles);
      simplePriceOracle.setDirectPrice(address(tokenTwo), 30_000e18);
      priceOracle.add(toArray(address(tokenTwo)), simplePriceOracles);
      simplePriceOracle.setDirectPrice(address(stable), 1e18);
      priceOracle.add(toArray(address(stable)), simplePriceOracles);

      (, address _comptroller) = fusePoolDirectory.deployPool(
        "TEST",
        address(comptrollerImpl),
        abi.encode(address(fuseFeeDistributor)),
        false,
        0.5e18,
        1.1e18,
        address(priceOracle)
      );
      comptroller = Comptroller(_comptroller);
      Unitroller(payable(_comptroller))._acceptAdmin();

      interestRateModel = new JumpRateModel(0, 10e18, 0.8e18, 2e18);

      require(
        comptroller._deployMarket(
          false,
          abi.encode(
            address(tokenOne),
            address(comptroller),
            address(fuseFeeDistributor),
            address(interestRateModel),
            "Rari Wrapped Ether",
            "rWETH",
            address(cERC20Impl),
            bytes(""),
            0,
            0.1e18
          ),
          0.5e18
        ) == 0,
        "failed to deploy WETH"
      );
      require(
        comptroller._deployMarket(
          false,
          abi.encode(
            tokenTwo,
            address(comptroller),
            address(fuseFeeDistributor),
            address(interestRateModel),
            "rWBTC",
            "Rari Wrapped BTC",
            address(cERC20Impl),
            bytes(""),
            0,
            0.1e18
          ),
          0.5e18
        ) == 0,
        "failed to deploy WBTC"
      );
      require(
        comptroller._deployMarket(
          false,
          abi.encode(
            stable,
            address(comptroller),
            address(fuseFeeDistributor),
            address(interestRateModel),
            "rUSDC",
            "Rari USD Coin",
            address(cERC20Impl),
            bytes(""),
            0,
            0.2e18
          ),
          0.8e18
        ) == 0,
        "failed to deploy USDC"
      );

      tokenOneMarket = CErc20(address(comptroller.cTokensByUnderlying(address(tokenOne))));
      tokenTwoMarket = CErc20(address(comptroller.cTokensByUnderlying(address(tokenTwo))));
      stableMarket = CErc20(address(comptroller.cTokensByUnderlying(address(stable))));
    }
  }

  // NOTE: Should be moved to setUp once possible
  modifier skipUnsuportedChain() {
    if (isChainSupported(block.chainid)) {
      _;
    } else {
      vm.skip(true);
    }
  }

  function isChainSupported(uint256 chainId) public pure returns (bool) {
    return chainId == 31337;
  }

  function getAmountOfTokenOne(uint256 dollarAmount) public view returns (uint256) {
    return getAmountOfToken(tokenOne, dollarAmount);
  }

  function getAmountOfTokenTwo(uint256 dollarAmount) public view returns (uint256) {
    return getAmountOfToken(tokenTwo, dollarAmount);
  }

  function getAmountToStable(uint256 dollarAmount) public view returns (uint256) {
    return getAmountOfToken(stable, dollarAmount);
  }

  function getAmountOfToken(ERC20 token, uint256 dollarAmount) internal view returns (uint256) {
    return (dollarAmount * 10e18 * (10 ** token.decimals())) / priceOracle.price(address(token));
  }

  function addLiquidity(ERC20 token, uint256 amount) internal {
    address supplier = makeAddr("Supplier");

    CErc20 market = CErc20(address(comptroller.cTokensByUnderlying(address(token))));

    vm.startPrank(supplier);

    deal(address(token), supplier, amount);

    token.approve(address(market), type(uint256).max);
    market.mint(amount);

    vm.stopPrank();
  }

  function toArray(address addr) public pure returns (address[] memory arr) {
    arr = new address[](1);
    arr[0] = addr;
  }
}
