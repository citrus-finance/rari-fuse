pragma solidity >=0.8.0;

/// @notice Minimal ERC4626 tokenized Vault interface. See https://eips.ethereum.org/EIPS/eip-4626
/// Bsased on: https://github.com/Rari-Capital/solmate/blob/main/src/mixins/ERC4626.sol
interface IERC4626 {
  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

  event Withdraw(
    address indexed caller,
    address indexed receiver,
    address indexed owner,
    uint256 assets,
    uint256 shares
  );

  function deposit(uint256 assets, address receiver) external returns (uint256 shares);

  function mint(uint256 shares, address receiver) external returns (uint256 assets);

  function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

  function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

  function totalAssets() external view returns (uint256);

  function convertToShares(uint256 assets) external view returns (uint256);

  function convertToAssets(uint256 shares) external view returns (uint256);

  function previewDeposit(uint256 assets) external view returns (uint256);

  function previewMint(uint256 shares) external view returns (uint256);

  function previewWithdraw(uint256 assets) external view returns (uint256);

  function previewRedeem(uint256 shares) external view returns (uint256);

  function maxDeposit(address) external view returns (uint256);

  function maxMint(address) external view returns (uint256);

  function maxWithdraw(address owner) external view returns (uint256);

  function maxRedeem(address owner) external view returns (uint256);

  // ERC-20

  function approve(address _spender, uint256 amount) external returns (bool);

  function balanceOf(address _owner) external view returns (uint256);
}
