pragma solidity ^0.8.0;

import "../multiProxy/MultiProxy.sol";
import "../multiProxy/MultiProxy.sol";
import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../interfaces/IVault.sol";

abstract contract VaultBase {

  struct Position {
    uint256 size;
    uint256 collateral;
    uint256 averagePrice;
    uint256 entryFundingRate;
    uint256 reserveAmount;
    int256 realisedPnl;
    uint256 lastIncreasedTime;
  }

  uint256 public constant BASIS_POINTS_DIVISOR = 10000;
  uint256 public constant FUNDING_RATE_PRECISION = 1000000;
  uint256 public constant PRICE_PRECISION = 10 ** 30;
  uint256 public constant MIN_LEVERAGE = 10000; // 1x
  uint256 public constant USDG_DECIMALS = 18;
  uint256 public constant MAX_FEE_BASIS_POINTS = 500; // 5%
  uint256 public constant MAX_LIQUIDATION_FEE_USD = 100 * PRICE_PRECISION; // 100 USD
  uint256 public constant MIN_FUNDING_RATE_INTERVAL = 1 hours;
  uint256 public constant MAX_FUNDING_RATE_FACTOR = 10000; // 1%

  bool public isInitialized;
  bool public isSwapEnabled = true;
  bool public isLeverageEnabled = true;

  IVaultUtils public vaultUtils;

  address public errorController;

  address public router;
  address public priceFeed;

  address public usdg;
  address public gov;

  uint256 public whitelistedTokenCount;

  uint256 public maxLeverage = 50 * 10000; // 50x

  uint256 public liquidationFeeUsd;
  uint256 public taxBasisPoints = 50; // 0.5%
  uint256 public stableTaxBasisPoints = 20; // 0.2%
  uint256 public mintBurnFeeBasisPoints = 30; // 0.3%
  uint256 public swapFeeBasisPoints = 30; // 0.3%
  uint256 public stableSwapFeeBasisPoints = 4; // 0.04%
  uint256 public marginFeeBasisPoints = 10; // 0.1%

  uint256 public minProfitTime;
  bool public hasDynamicFees = false;

  uint256 public fundingInterval = 8 hours;
  uint256 public fundingRateFactor;
  uint256 public stableFundingRateFactor;
  uint256 public totalTokenWeights;

  bool public includeAmmPrice = true;
  bool public useSwapPricing = false;

  bool public inManagerMode = false;
  bool public inPrivateLiquidationMode = false;

  uint256 public maxGasPrice;

  mapping (address => mapping (address => bool)) public approvedRouters;
  mapping (address => bool) public isLiquidator;
  mapping (address => bool) public isManager;

  address[] public allWhitelistedTokens;

  mapping (address => bool) public whitelistedTokens;
  mapping (address => uint256) public tokenDecimals;
  mapping (address => uint256) public minProfitBasisPoints;
  mapping (address => bool) public stableTokens;
  mapping (address => bool) public shortableTokens;

  // tokenBalances is used only to determine _transferIn values
  mapping (address => uint256) public tokenBalances;

  // tokenWeights allows customisation of index composition
  mapping (address => uint256) public tokenWeights;

  // usdgAmounts tracks the amount of USDG debt for each whitelisted token
  mapping (address => uint256) public usdgAmounts;

  // maxUsdgAmounts allows setting a max amount of USDG debt for a token
  mapping (address => uint256) public maxUsdgAmounts;

  // poolAmounts tracks the number of received tokens that can be used for leverage
  // this is tracked separately from tokenBalances to exclude funds that are deposited as margin collateral
  mapping (address => uint256) public poolAmounts;

  // reservedAmounts tracks the number of tokens reserved for open leverage positions
  mapping (address => uint256) public reservedAmounts;

  // bufferAmounts allows specification of an amount to exclude from swaps
  // this can be used to ensure a certain amount of liquidity is available for leverage positions
  mapping (address => uint256) public bufferAmounts;

  // guaranteedUsd tracks the amount of USD that is "guaranteed" by opened leverage positions
  // this value is used to calculate the redemption values for selling of USDG
  // this is an estimated amount, it is possible for the actual guaranteed value to be lower
  // in the case of sudden price decreases, the guaranteed value should be corrected
  // after liquidations are carried out
  mapping (address => uint256) public guaranteedUsd;

  // cumulativeFundingRates tracks the funding rates based on utilization
  mapping (address => uint256) public cumulativeFundingRates;
  // lastFundingTimes tracks the last time funding was updated for a token
  mapping (address => uint256) public lastFundingTimes;

  // positions tracks all open positions
  mapping (bytes32 => Position) public positions;

  // feeReserves tracks the amount of fees per token
  mapping (address => uint256) public feeReserves;

  mapping (address => uint256) public globalShortSizes;
  mapping (address => uint256) public globalShortAveragePrices;
  mapping (address => uint256) public maxGlobalShortSizes;

  mapping (uint256 => string) public errors;

  // once the parameters are verified to be working correctly,
  // gov should be set to a timelock contract or a governance contract
  constructor() {
    gov = msg.sender;
  }

  function _validate(bool _condition, uint256 _errorCode) public view {
    require(_condition, errors[_errorCode]);
  }

  // we have this validation as a function instead of a modifier to reduce contract size
  function _onlyGov() public view {
    _validate(msg.sender == gov, 53);
  }

  // tokenBalances

  function _transferIn(address _token) private returns (uint256) {
    uint256 prevBalance = tokenBalances[_token];
    uint256 nextBalance = IERC20(_token).balanceOf(address(this));
    tokenBalances[_token] = nextBalance;

    return nextBalance - prevBalance;
  }

  function _transferOut(address _token, uint256 _amount, address _receiver) private {
    IERC20(_token).safeTransfer(_receiver, _amount);
    tokenBalances[_token] = IERC20(_token).balanceOf(address(this));
  }

  function _updateTokenBalance(address _token) private {
    uint256 nextBalance = IERC20(_token).balanceOf(address(this));
    tokenBalances[_token] = nextBalance;
  }

  function _increasePoolAmount(address _token, uint256 _amount) private {
    poolAmounts[_token] = poolAmounts[_token] + _amount;
    uint256 balance = IERC20(_token).balanceOf(address(this));
    _validate(poolAmounts[_token] <= balance, 49);
    emit IncreasePoolAmount(_token, _amount);
  }

  function _decreasePoolAmount(address _token, uint256 _amount) private {
    poolAmounts[_token] = poolAmounts[_token] - _amount;
    _validate(reservedAmounts[_token] <= poolAmounts[_token], 50);
    emit DecreasePoolAmount(_token, _amount);
  }

  function updateCumulativeFundingRate(address _collateralToken, address _indexToken) public {
    bool shouldUpdate = vaultUtils.updateCumulativeFundingRate(_collateralToken, _indexToken);
    if (!shouldUpdate) {
      return;
    }

    if (lastFundingTimes[_collateralToken] == 0) {
      lastFundingTimes[_collateralToken] = block.timestamp.div(fundingInterval).mul(fundingInterval);
      return;
    }

    if (lastFundingTimes[_collateralToken].add(fundingInterval) > block.timestamp) {
      return;
    }

    uint256 fundingRate = getNextFundingRate(_collateralToken);
    cumulativeFundingRates[_collateralToken] = cumulativeFundingRates[_collateralToken].add(fundingRate);
    lastFundingTimes[_collateralToken] = block.timestamp.div(fundingInterval).mul(fundingInterval);

    emit UpdateFundingRate(_collateralToken, cumulativeFundingRates[_collateralToken]);
  }

  function getNextFundingRate(address _token) public override view returns (uint256) {
    if (lastFundingTimes[_token].add(fundingInterval) > block.timestamp) { return 0; }

    uint256 intervals = block.timestamp.sub(lastFundingTimes[_token]).div(fundingInterval);
    uint256 poolAmount = poolAmounts[_token];
    if (poolAmount == 0) { return 0; }

    uint256 _fundingRateFactor = stableTokens[_token] ? stableFundingRateFactor : fundingRateFactor;
    return _fundingRateFactor.mul(reservedAmounts[_token]).mul(intervals).div(poolAmount);
  }

}
