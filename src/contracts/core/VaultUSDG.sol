pragma solidity ^0.8.0;

import "../multiProxy/MultiProxy.sol";
import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "./VaultProxyTarget.sol";
import "./VaultBase.sol";
import "../tokens/interfaces/IUSDG.sol";

contract VaultUSDG is VaultProxyTarget, VaultBase {

  constructor(MultiProxy _parent) VaultProxyTarget(_parent) {}

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
