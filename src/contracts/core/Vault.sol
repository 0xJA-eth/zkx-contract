pragma solidity ^0.8.0;

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../multi-proxy/MultiProxy.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IVaultPriceFeed.sol";
import "./VaultBase.sol";
import "../tokens/interfaces/IUSDG.sol";

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

  function registerFunctionImpls(string[] calldata names, address impl) public {
    _onlyGov();
    _registerFunctionImpls(names, impl);
  }

  function setVaultUtils(IVaultUtils _vaultUtils) external {
    _onlyGov();
    vaultUtils = _vaultUtils;
  }

  function setErrorController(address _errorController) external {
    _onlyGov();
    errorController = _errorController;
  }

//  function toString(address account) public pure returns(string memory) {
//    return toString(abi.encodePacked(account));
//  }
//  function toString(uint256 value) public pure returns(string memory) {
//    return toString(abi.encodePacked(value));
//  }
//  function toString(bytes32 value) public pure returns(string memory) {
//    return toString(abi.encodePacked(value));
//  }
//  function toString(bytes memory data) public pure returns(string memory) {
//    bytes memory alphabet = "0123456789abcdef";
//
//    bytes memory str = new bytes(2 + data.length * 2);
//    str[0] = "0";
//    str[1] = "x";
//    for (uint i = 0; i < data.length; i++) {
//      str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
//      str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
//    }
//    return string(str);
//  }

  function setError(uint256 _errorCode, string calldata _error) external {
    require(msg.sender == errorController,
      toString(msg.sender)
    );
    errors[_errorCode] = _error;
  }

  function allWhitelistedTokensLength() external view returns (uint256) {
    return allWhitelistedTokens.length;
  }

  function setInManagerMode(bool _inManagerMode) external {
    _onlyGov();
    inManagerMode = _inManagerMode;
  }

  function setManager(address _manager, bool _isManager) external {
    _onlyGov();
    isManager[_manager] = _isManager;
  }

  function setInPrivateLiquidationMode(bool _inPrivateLiquidationMode) external {
    _onlyGov();
    inPrivateLiquidationMode = _inPrivateLiquidationMode;
  }

  function setLiquidator(address _liquidator, bool _isActive) external {
    _onlyGov();
    isLiquidator[_liquidator] = _isActive;
  }

  function setIsSwapEnabled(bool _isSwapEnabled) external {
    _onlyGov();
    isSwapEnabled = _isSwapEnabled;
  }

  function setIsLeverageEnabled(bool _isLeverageEnabled) external {
    _onlyGov();
    isLeverageEnabled = _isLeverageEnabled;
  }

  function setMaxGasPrice(uint256 _maxGasPrice) external {
    _onlyGov();
    maxGasPrice = _maxGasPrice;
  }

  function setGov(address _gov) external {
    _onlyGov();
    gov = _gov;
  }

  function setPriceFeed(address _priceFeed) external {
    _onlyGov();
    priceFeed = _priceFeed;
  }

  function setMaxLeverage(uint256 _maxLeverage) external {
    _onlyGov();
    _validate(_maxLeverage > MIN_LEVERAGE, 2);
    maxLeverage = _maxLeverage;
  }

  function setBufferAmount(address _token, uint256 _amount) external {
    _onlyGov();
    bufferAmounts[_token] = _amount;
  }

  function setMaxGlobalShortSize(address _token, uint256 _amount) external {
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
  ) external {
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

  function setFundingRate(uint256 _fundingInterval, uint256 _fundingRateFactor, uint256 _stableFundingRateFactor) external {
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
  ) external {
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

  function withdrawFees(address _token, address _receiver) external returns (uint256) {
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
    IERC20(_token).transfer(_newVault, _amount);
  }

  // deposit into the pool without minting USDG tokens
  // useful in allowing the pool to become over-collaterised
  function directPoolDeposit(address _token) external nonReentrant {
    _validate(whitelistedTokens[_token], 14);
    uint256 tokenAmount = _transferIn(_token);
    _validate(tokenAmount > 0, 15);
    _increasePoolAmount(_token, tokenAmount);
    emit DirectPoolDeposit(_token, tokenAmount);
  }

  function getMaxPrice(address _token) public view returns (uint256) {
    return IVaultPriceFeed(priceFeed).getPrice(_token, true, includeAmmPrice, useSwapPricing);
  }

  function getMinPrice(address _token) public view returns (uint256) {
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
  function getFeeBasisPoints(address _token, uint256 _usdgDelta, uint256 _feeBasisPoints, uint256 _taxBasisPoints, bool _increment) public view returns (uint256) {
    return vaultUtils.getFeeBasisPoints(_token, _usdgDelta, _feeBasisPoints, _taxBasisPoints, _increment);
  }

  function getTargetUsdgAmount(address _token) public view returns (uint256) {
    uint256 supply = IERC20(usdg).totalSupply();
    if (supply == 0) { return 0; }
    uint256 weight = tokenWeights[_token];
    return weight * supply / totalTokenWeights;
  }

  // USDG

  function vault() public view returns(IVault) {
    return IVault(address(this));
  }

  function setUsdgAmount(address _token, uint256 _amount) external {
    _onlyGov();

    uint256 usdgAmount = usdgAmounts[_token];
    if (_amount > usdgAmount) {
      _increaseUsdgAmount(_token, _amount - usdgAmount);
      return;
    }

    _decreaseUsdgAmount(_token, usdgAmount - _amount);
  }

  function buyUSDG(address _token, address _receiver) external nonReentrant returns (uint256) {
    _validateManager();
    _validate(whitelistedTokens[_token], 16);
    useSwapPricing = true;

    uint256 tokenAmount = _transferIn(_token);
    _validate(tokenAmount > 0, 17);

    updateCumulativeFundingRate(_token, _token);

    uint256 price = vault().getMinPrice(_token);

    uint256 usdgAmount = tokenAmount * price / PRICE_PRECISION;
    usdgAmount = adjustForDecimals(usdgAmount, _token, usdg);
    _validate(usdgAmount > 0, 18);

    uint256 feeBasisPoints = vaultUtils.getBuyUsdgFeeBasisPoints(_token, usdgAmount);
    uint256 amountAfterFees = _collectSwapFees(_token, tokenAmount, feeBasisPoints);
    uint256 mintAmount = amountAfterFees * price / PRICE_PRECISION;
    mintAmount = adjustForDecimals(mintAmount, _token, usdg);

    _increaseUsdgAmount(_token, mintAmount);
    _increasePoolAmount(_token, amountAfterFees);

    IUSDG(usdg).mint(_receiver, mintAmount);

    emit BuyUSDG(_receiver, _token, tokenAmount, mintAmount, feeBasisPoints);

    useSwapPricing = false;
    return mintAmount;
  }

  function sellUSDG(address _token, address _receiver) external nonReentrant returns (uint256) {
    _validateManager();
    _validate(whitelistedTokens[_token], 19);
    useSwapPricing = true;

    uint256 usdgAmount = _transferIn(usdg);
    _validate(usdgAmount > 0, 20);

    updateCumulativeFundingRate(_token, _token);

    uint256 redemptionAmount = getRedemptionAmount(_token, usdgAmount);
    _validate(redemptionAmount > 0, 21);

    _decreaseUsdgAmount(_token, usdgAmount);
    _decreasePoolAmount(_token, redemptionAmount);

    IUSDG(usdg).burn(address(this), usdgAmount);

    // the _transferIn call increased the value of tokenBalances[usdg]
    // usually decreases in token balances are synced by calling _transferOut
    // however, for usdg, the tokens are burnt, so _updateTokenBalance should
    // be manually called to record the decrease in tokens
    _updateTokenBalance(usdg);

    uint256 feeBasisPoints = vaultUtils.getSellUsdgFeeBasisPoints(_token, usdgAmount);
    uint256 amountOut = _collectSwapFees(_token, redemptionAmount, feeBasisPoints);
    _validate(amountOut > 0, 22);

    _transferOut(_token, amountOut, _receiver);

    emit SellUSDG(_receiver, _token, usdgAmount, amountOut, feeBasisPoints);

    useSwapPricing = false;
    return amountOut;
  }

  function swap(address _tokenIn, address _tokenOut, address _receiver) external nonReentrant returns (uint256) {
    // 验证交易是否启用
    _validate(isSwapEnabled, 23);
    // 验证输入资产是否在白名单中
    _validate(whitelistedTokens[_tokenIn], 24);
    // 验证输出资产是否在白名单中
    _validate(whitelistedTokens[_tokenOut], 25);
    // 验证输入资产和输出资产是否不同
    _validate(_tokenIn != _tokenOut, 26);

    // 开启交换定价
    useSwapPricing = true;

    // 更新输入资产和输出资产的累计资金费率
    updateCumulativeFundingRate(_tokenIn, _tokenIn);
    updateCumulativeFundingRate(_tokenOut, _tokenOut);

    // 将输入资产转入到合约中
    uint256 amountIn = _transferIn(_tokenIn);
    // 验证转入金额必须大于零
    _validate(amountIn > 0, 27);

    // 获取输入资产的最低价格
    uint256 priceIn = vault().getMinPrice(_tokenIn);
    // 获取输出资产的最高价格
    uint256 priceOut = vault().getMaxPrice(_tokenOut);

    // 计算输出资产的金额
    uint256 amountOut = amountIn * priceIn / priceOut;
    // 根据资产的小数位数调整金额
    amountOut = adjustForDecimals(amountOut, _tokenIn, _tokenOut);

    // 根据转入金额计算 USDG 的金额
    uint256 usdgAmount = amountIn * priceIn / PRICE_PRECISION;
    // 根据资产的小数位数调整 USDG 的金额
    usdgAmount = adjustForDecimals(usdgAmount, _tokenIn, usdg);

    // 获取交换手续费的基准点数
    uint256 feeBasisPoints = vaultUtils.getSwapFeeBasisPoints(_tokenIn, _tokenOut, usdgAmount);
    // 收取交换手续费，并计算扣除手续费后的输出金额
    uint256 amountOutAfterFees = _collectSwapFees(_tokenOut, amountOut, feeBasisPoints);

    // 增加输入资产的 USDG 金额
    _increaseUsdgAmount(_tokenIn, usdgAmount);
    // 减少输出资产的 USDG 金额
    _decreaseUsdgAmount(_tokenOut, usdgAmount);

    // 增加输入资产的池子金额
    _increasePoolAmount(_tokenIn, amountIn);
    // 减少输出资产的池子金额
    _decreasePoolAmount(_tokenOut, amountOut);

    // 验证输出资产的缓冲金额
    _validateBufferAmount(_tokenOut);

    // 将输出资产转出到接收地址
    _transferOut(_tokenOut, amountOutAfterFees, _receiver);

    // 发出 Swap 事件
    emit Swap(_receiver, _tokenIn, _tokenOut, amountIn, amountOut, amountOutAfterFees, feeBasisPoints);

    // 关闭交换定价
    useSwapPricing = false;
    // 返回扣除手续费后的输出金额
    return amountOutAfterFees;
  }

  function _increaseUsdgAmount(address _token, uint256 _amount) private {
    usdgAmounts[_token] = usdgAmounts[_token] + _amount;
    uint256 maxUsdgAmount = maxUsdgAmounts[_token];
    if (maxUsdgAmount != 0) {
      _validate(usdgAmounts[_token] <= maxUsdgAmount, 51);
    }
    emit IncreaseUsdgAmount(_token, _amount);
  }

  function _decreaseUsdgAmount(address _token, uint256 _amount) private {
    uint256 value = usdgAmounts[_token];
    // since USDG can be minted using multiple assets
    // it is possible for the USDG debt for a single asset to be less than zero
    // the USDG debt is capped to zero for this case
    if (value <= _amount) {
      usdgAmounts[_token] = 0;
      emit DecreaseUsdgAmount(_token, value);
      return;
    }
    usdgAmounts[_token] = value - _amount;
    emit DecreaseUsdgAmount(_token, _amount);
  }

  function _validateBufferAmount(address _token) private view {
    if (poolAmounts[_token] < bufferAmounts[_token]) {
      revert("Vault: poolAmount < buffer");
    }
  }

  function getRedemptionAmount(address _token, uint256 _usdgAmount) public view returns (uint256) {
    uint256 price = vault().getMaxPrice(_token);
    uint256 redemptionAmount = _usdgAmount * PRICE_PRECISION / price;
    return adjustForDecimals(redemptionAmount, usdg, _token);
  }

  function adjustForDecimals(uint256 _amount, address _tokenDiv, address _tokenMul) public view returns (uint256) {
    uint256 decimalsDiv = _tokenDiv == usdg ? USDG_DECIMALS : tokenDecimals[_tokenDiv];
    uint256 decimalsMul = _tokenMul == usdg ? USDG_DECIMALS : tokenDecimals[_tokenMul];
    return _amount * (10 ** decimalsMul) / (10 ** decimalsDiv);
  }

  function _collectSwapFees(address _token, uint256 _amount, uint256 _feeBasisPoints) private returns (uint256) {
    uint256 afterFeeAmount = _amount * (BASIS_POINTS_DIVISOR - _feeBasisPoints) / BASIS_POINTS_DIVISOR;
    uint256 feeAmount = _amount - afterFeeAmount;
    feeReserves[_token] = feeReserves[_token] + feeAmount;
    emit CollectSwapFees(_token, vault().tokenToUsdMin(_token, feeAmount), feeAmount);
    return afterFeeAmount;
  }

  // we have this validation as a function instead of a modifier to reduce contract size
  function _validateManager() private view {
    if (inManagerMode) {
      _validate(isManager[msg.sender], 54);
    }
  }
}
