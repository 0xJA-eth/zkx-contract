pragma solidity ^0.8.0;

import "../multiProxy/MultiProxy.sol";
import "../multiProxy/MultiProxy.sol";
import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../interfaces/IVault.sol";
import "./VaultBase.sol";

contract Vault is ReentrancyGuard, MultiProxy, VaultBase {

  function initialize(
    address _router,
    address _usdg,
    address _priceFeed,
    uint256 _liquidationFeeUsd,
    uint256 _fundingRateFactor,
    uint256 _stableFundingRateFactor
  ) external {
    _onlyGov();
    _validate(!isInitialized, 1);
    isInitialized = true;

    router = _router;
    usdg = _usdg;
    priceFeed = _priceFeed;
    liquidationFeeUsd = _liquidationFeeUsd;
    fundingRateFactor = _fundingRateFactor;
    stableFundingRateFactor = _stableFundingRateFactor;
  }

  function setVaultUtils(IVaultUtils _vaultUtils) external {
    _onlyGov();
    vaultUtils = _vaultUtils;
  }

  function setErrorController(address _errorController) external {
    _onlyGov();
    errorController = _errorController;
  }

  function setError(uint256 _errorCode, string calldata _error) external override {
    require(msg.sender == errorController, "Vault: invalid errorController");
    errors[_errorCode] = _error;
  }

  function allWhitelistedTokensLength() external override view returns (uint256) {
    return allWhitelistedTokens.length;
  }

  function setInManagerMode(bool _inManagerMode) external override {
    _onlyGov();
    inManagerMode = _inManagerMode;
  }

  function setManager(address _manager, bool _isManager) external override {
    _onlyGov();
    isManager[_manager] = _isManager;
  }

  function setInPrivateLiquidationMode(bool _inPrivateLiquidationMode) external override {
    _onlyGov();
    inPrivateLiquidationMode = _inPrivateLiquidationMode;
  }

  function setLiquidator(address _liquidator, bool _isActive) external override {
    _onlyGov();
    isLiquidator[_liquidator] = _isActive;
  }

  function setIsSwapEnabled(bool _isSwapEnabled) external override {
    _onlyGov();
    isSwapEnabled = _isSwapEnabled;
  }

  function setIsLeverageEnabled(bool _isLeverageEnabled) external override {
    _onlyGov();
    isLeverageEnabled = _isLeverageEnabled;
  }

  function setMaxGasPrice(uint256 _maxGasPrice) external override {
    _onlyGov();
    maxGasPrice = _maxGasPrice;
  }

  function setGov(address _gov) external {
    _onlyGov();
    gov = _gov;
  }

  function setPriceFeed(address _priceFeed) external override {
    _onlyGov();
    priceFeed = _priceFeed;
  }

  function setMaxLeverage(uint256 _maxLeverage) external override {
    _onlyGov();
    _validate(_maxLeverage > MIN_LEVERAGE, 2);
    maxLeverage = _maxLeverage;
  }

  function setBufferAmount(address _token, uint256 _amount) external override {
    _onlyGov();
    bufferAmounts[_token] = _amount;
  }

  function setMaxGlobalShortSize(address _token, uint256 _amount) external override {
    _onlyGov();
    maxGlobalShortSizes[_token] = _amount;
  }

  function setFees(
    uint256 _taxBasisPoints,
    uint256 _stableTaxBasisPoints,
    uint256 _mintBurnFeeBasisPoints,
    uint256 _swapFeeBasisPoints,
    uint256 _stableSwapFeeBasisPoints,
    uint256 _marginFeeBasisPoints,
    uint256 _liquidationFeeUsd,
    uint256 _minProfitTime,
    bool _hasDynamicFees
  ) external override {
    _onlyGov();
    _validate(_taxBasisPoints <= MAX_FEE_BASIS_POINTS, 3);
    _validate(_stableTaxBasisPoints <= MAX_FEE_BASIS_POINTS, 4);
    _validate(_mintBurnFeeBasisPoints <= MAX_FEE_BASIS_POINTS, 5);
    _validate(_swapFeeBasisPoints <= MAX_FEE_BASIS_POINTS, 6);
    _validate(_stableSwapFeeBasisPoints <= MAX_FEE_BASIS_POINTS, 7);
    _validate(_marginFeeBasisPoints <= MAX_FEE_BASIS_POINTS, 8);
    _validate(_liquidationFeeUsd <= MAX_LIQUIDATION_FEE_USD, 9);
    taxBasisPoints = _taxBasisPoints;
    stableTaxBasisPoints = _stableTaxBasisPoints;
    mintBurnFeeBasisPoints = _mintBurnFeeBasisPoints;
    swapFeeBasisPoints = _swapFeeBasisPoints;
    stableSwapFeeBasisPoints = _stableSwapFeeBasisPoints;
    marginFeeBasisPoints = _marginFeeBasisPoints;
    liquidationFeeUsd = _liquidationFeeUsd;
    minProfitTime = _minProfitTime;
    hasDynamicFees = _hasDynamicFees;
  }

  function setFundingRate(uint256 _fundingInterval, uint256 _fundingRateFactor, uint256 _stableFundingRateFactor) external override {
    _onlyGov();
    _validate(_fundingInterval >= MIN_FUNDING_RATE_INTERVAL, 10);
    _validate(_fundingRateFactor <= MAX_FUNDING_RATE_FACTOR, 11);
    _validate(_stableFundingRateFactor <= MAX_FUNDING_RATE_FACTOR, 12);
    fundingInterval = _fundingInterval;
    fundingRateFactor = _fundingRateFactor;
    stableFundingRateFactor = _stableFundingRateFactor;
  }

  function setTokenConfig(
    address _token,
    uint256 _tokenDecimals,
    uint256 _tokenWeight,
    uint256 _minProfitBps,
    uint256 _maxUsdgAmount,
    bool _isStable,
    bool _isShortable
  ) external override {
    _onlyGov();
    // increment token count for the first time
    if (!whitelistedTokens[_token]) {
      whitelistedTokenCount++;
      allWhitelistedTokens.push(_token);
    }

    uint256 _totalTokenWeights = totalTokenWeights;
    _totalTokenWeights = _totalTokenWeights - tokenWeights[_token];

    whitelistedTokens[_token] = true;
    tokenDecimals[_token] = _tokenDecimals;
    tokenWeights[_token] = _tokenWeight;
    minProfitBasisPoints[_token] = _minProfitBps;
    maxUsdgAmounts[_token] = _maxUsdgAmount;
    stableTokens[_token] = _isStable;
    shortableTokens[_token] = _isShortable;

    totalTokenWeights = _totalTokenWeights + _tokenWeight;

    // validate price feed
    getMaxPrice(_token);
  }

  function clearTokenConfig(address _token) external {
    _onlyGov();
    _validate(whitelistedTokens[_token], 13);
    totalTokenWeights = totalTokenWeights - tokenWeights[_token];
    delete whitelistedTokens[_token];
    delete tokenDecimals[_token];
    delete tokenWeights[_token];
    delete minProfitBasisPoints[_token];
    delete maxUsdgAmounts[_token];
    delete stableTokens[_token];
    delete shortableTokens[_token];
    whitelistedTokenCount--;
  }

  function withdrawFees(address _token, address _receiver) external override returns (uint256) {
    _onlyGov();
    uint256 amount = feeReserves[_token];
    if(amount == 0) { return 0; }
    feeReserves[_token] = 0;
    _transferOut(_token, amount, _receiver);
    return amount;
  }

  function addRouter(address _router) external {
    approvedRouters[msg.sender][_router] = true;
  }

  function removeRouter(address _router) external {
    approvedRouters[msg.sender][_router] = false;
  }

  // the governance controlling this function should have a timelock
  function upgradeVault(address _newVault, address _token, uint256 _amount) external {
    _onlyGov();
    IERC20(_token).safeTransfer(_newVault, _amount);
  }

  // deposit into the pool without minting USDG tokens
  // useful in allowing the pool to become over-collaterised
  function directPoolDeposit(address _token) external override nonReentrant {
    _validate(whitelistedTokens[_token], 14);
    uint256 tokenAmount = _transferIn(_token);
    _validate(tokenAmount > 0, 15);
    _increasePoolAmount(_token, tokenAmount);
    emit DirectPoolDeposit(_token, tokenAmount);
  }

  function getMaxPrice(address _token) public override view returns (uint256) {
    return IVaultPriceFeed(priceFeed).getPrice(_token, true, includeAmmPrice, useSwapPricing);
  }

  function getMinPrice(address _token) public override view returns (uint256) {
    return IVaultPriceFeed(priceFeed).getPrice(_token, false, includeAmmPrice, useSwapPricing);
  }

  function getUtilisation(address _token) public view returns (uint256) {
    uint256 poolAmount = poolAmounts[_token];
    if (poolAmount == 0) { return 0; }

    return reservedAmounts[_token] * FUNDING_RATE_PRECISION / poolAmount;
  }

  // cases to consider
  // 1. initialAmount is far from targetAmount, action increases balance slightly => high rebate
  // 2. initialAmount is far from targetAmount, action increases balance largely => high rebate
  // 3. initialAmount is close to targetAmount, action increases balance slightly => low rebate
  // 4. initialAmount is far from targetAmount, action reduces balance slightly => high tax
  // 5. initialAmount is far from targetAmount, action reduces balance largely => high tax
  // 6. initialAmount is close to targetAmount, action reduces balance largely => low tax
  // 7. initialAmount is above targetAmount, nextAmount is below targetAmount and vice versa
  // 8. a large swap should have similar fees as the same trade split into multiple smaller swaps
  function getFeeBasisPoints(address _token, uint256 _usdgDelta, uint256 _feeBasisPoints, uint256 _taxBasisPoints, bool _increment) public override view returns (uint256) {
    return vaultUtils.getFeeBasisPoints(_token, _usdgDelta, _feeBasisPoints, _taxBasisPoints, _increment);
  }

  function getTargetUsdgAmount(address _token) public override view returns (uint256) {
    uint256 supply = IERC20(usdg).totalSupply();
    if (supply == 0) { return 0; }
    uint256 weight = tokenWeights[_token];
    return weight.mul(supply).div(totalTokenWeights);
  }

}
