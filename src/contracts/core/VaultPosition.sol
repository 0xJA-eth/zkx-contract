pragma solidity ^0.8.0;

import "../multiProxy/MultiProxy.sol";
import "../multiProxy/MultiProxy.sol";
import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../interfaces/IVault.sol";
import "../multiProxy/ProxyTarget.sol";
import "./Vault.sol";
import "./VaultProxyTarget.sol";

contract VaultPosition is VaultProxyTarget, VaultBase {

  constructor(MultiProxy _parent) VaultProxyTarget(_parent) {}

  function increasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external override nonReentrant {
    _validate(isLeverageEnabled, 28);
    _validateGasPrice();
    _validateRouter(_account);
    _validateTokens(_collateralToken, _indexToken, _isLong);
    vaultUtils.validateIncreasePosition(_account, _collateralToken, _indexToken, _sizeDelta, _isLong);

    updateCumulativeFundingRate(_collateralToken, _indexToken);

    bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
    Position storage position = positions[key];

    uint256 price = _isLong ? getMaxPrice(_indexToken) : getMinPrice(_indexToken);

    if (position.size == 0) {
      position.averagePrice = price;
    }

    if (position.size > 0 && _sizeDelta > 0) {
      position.averagePrice = getNextAveragePrice(_indexToken, position.size, position.averagePrice, _isLong, price, _sizeDelta, position.lastIncreasedTime);
    }

    uint256 fee = _collectMarginFees(_account, _collateralToken, _indexToken, _isLong, _sizeDelta, position.size, position.entryFundingRate);
    uint256 collateralDelta = _transferIn(_collateralToken);
    uint256 collateralDeltaUsd = tokenToUsdMin(_collateralToken, collateralDelta);

    position.collateral = position.collateral + collateralDeltaUsd;
    _validate(position.collateral >= fee, 29);

    position.collateral = position.collateral - fee;
    position.entryFundingRate = getEntryFundingRate(_collateralToken, _indexToken, _isLong);
    position.size = position.size + _sizeDelta;
    position.lastIncreasedTime = block.timestamp;

    _validate(position.size > 0, 30);
    _validatePosition(position.size, position.collateral);
    validateLiquidation(_account, _collateralToken, _indexToken, _isLong, true);

    // reserve tokens to pay profits on the position
    uint256 reserveDelta = usdToTokenMax(_collateralToken, _sizeDelta);
    position.reserveAmount = position.reserveAmount + reserveDelta;
    _increaseReservedAmount(_collateralToken, reserveDelta);

    if (_isLong) {
      // guaranteedUsd stores the sum of (position.size - position.collateral) for all positions
      // if a fee is charged on the collateral then guaranteedUsd should be increased by that fee amount
      // since (position.size - position.collateral) would have increased by `fee`
      _increaseGuaranteedUsd(_collateralToken, _sizeDelta + fee);
      _decreaseGuaranteedUsd(_collateralToken, collateralDeltaUsd);
      // treat the deposited collateral as part of the pool
      _increasePoolAmount(_collateralToken, collateralDelta);
      // fees need to be deducted from the pool since fees are deducted from position.collateral
      // and collateral is treated as part of the pool
      _decreasePoolAmount(_collateralToken, usdToTokenMin(_collateralToken, fee));
    } else {
      if (globalShortSizes[_indexToken] == 0) {
        globalShortAveragePrices[_indexToken] = price;
      } else {
        globalShortAveragePrices[_indexToken] = getNextGlobalShortAveragePrice(_indexToken, price, _sizeDelta);
      }

      _increaseGlobalShortSize(_indexToken, _sizeDelta);
    }

    emit IncreasePosition(key, _account, _collateralToken, _indexToken, collateralDeltaUsd, _sizeDelta, _isLong, price, fee);
    emit UpdatePosition(key, position.size, position.collateral, position.averagePrice, position.entryFundingRate, position.reserveAmount, position.realisedPnl, price);
  }

  function decreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external override nonReentrant returns (uint256) {
    _validateGasPrice();
    _validateRouter(_account);
    return _decreasePosition(_account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver);
  }

  function _decreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) private returns (uint256) {
    vaultUtils.validateDecreasePosition(_account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver);
    updateCumulativeFundingRate(_collateralToken, _indexToken);

    bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
    Position storage position = positions[key];
    _validate(position.size > 0, 31);
    _validate(position.size >= _sizeDelta, 32);
    _validate(position.collateral >= _collateralDelta, 33);

    uint256 collateral = position.collateral;
    // scrop variables to avoid stack too deep errors
    {
      uint256 reserveDelta = position.reserveAmount * _sizeDelta / position.size;
      position.reserveAmount = position.reserveAmount - reserveDelta;
      _decreaseReservedAmount(_collateralToken, reserveDelta);
    }

    (uint256 usdOut, uint256 usdOutAfterFee) = _reduceCollateral(_account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong);

    if (position.size != _sizeDelta) {
      position.entryFundingRate = getEntryFundingRate(_collateralToken, _indexToken, _isLong);
      position.size = position.size - _sizeDelta;

      _validatePosition(position.size, position.collateral);
      validateLiquidation(_account, _collateralToken, _indexToken, _isLong, true);

      if (_isLong) {
        _increaseGuaranteedUsd(_collateralToken, collateral - position.collateral);
        _decreaseGuaranteedUsd(_collateralToken, _sizeDelta);
      }

      uint256 price = _isLong ? getMinPrice(_indexToken) : getMaxPrice(_indexToken);
      emit DecreasePosition(key, _account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, price, usdOut - usdOutAfterFee);
      emit UpdatePosition(key, position.size, position.collateral, position.averagePrice, position.entryFundingRate, position.reserveAmount, position.realisedPnl, price);
    } else {
      if (_isLong) {
        _increaseGuaranteedUsd(_collateralToken, collateral);
        _decreaseGuaranteedUsd(_collateralToken, _sizeDelta);
      }

      uint256 price = _isLong ? getMinPrice(_indexToken) : getMaxPrice(_indexToken);
      emit DecreasePosition(key, _account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, price, usdOut - usdOutAfterFee);
      emit ClosePosition(key, position.size, position.collateral, position.averagePrice, position.entryFundingRate, position.reserveAmount, position.realisedPnl);

      delete positions[key];
    }

    if (!_isLong) {
      _decreaseGlobalShortSize(_indexToken, _sizeDelta);
    }

    if (usdOut > 0) {
      if (_isLong) {
        _decreasePoolAmount(_collateralToken, usdToTokenMin(_collateralToken, usdOut));
      }
      uint256 amountOutAfterFees = usdToTokenMin(_collateralToken, usdOutAfterFee);
      _transferOut(_collateralToken, amountOutAfterFees, _receiver);
      return amountOutAfterFees;
    }

    return 0;
  }

  function liquidatePosition(address _account, address _collateralToken, address _indexToken, bool _isLong, address _feeReceiver) external override nonReentrant {
    if (inPrivateLiquidationMode) {
      _validate(isLiquidator[msg.sender], 34);
    }

    // set includeAmmPrice to false to prevent manipulated liquidations
    includeAmmPrice = false;

    updateCumulativeFundingRate(_collateralToken, _indexToken);

    bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
    Position memory position = positions[key];
    _validate(position.size > 0, 35);

    (uint256 liquidationState, uint256 marginFees) = validateLiquidation(_account, _collateralToken, _indexToken, _isLong, false);
    _validate(liquidationState != 0, 36);
    if (liquidationState == 2) {
      // max leverage exceeded but there is collateral remaining after deducting losses so decreasePosition instead
      _decreasePosition(_account, _collateralToken, _indexToken, 0, position.size, _isLong, _account);
      includeAmmPrice = true;
      return;
    }

    uint256 feeTokens = usdToTokenMin(_collateralToken, marginFees);
    feeReserves[_collateralToken] = feeReserves[_collateralToken] + feeTokens;
    emit CollectMarginFees(_collateralToken, marginFees, feeTokens);

    _decreaseReservedAmount(_collateralToken, position.reserveAmount);
    if (_isLong) {
      _decreaseGuaranteedUsd(_collateralToken, position.size - position.collateral);
      _decreasePoolAmount(_collateralToken, usdToTokenMin(_collateralToken, marginFees));
    }

    uint256 markPrice = _isLong ? getMinPrice(_indexToken) : getMaxPrice(_indexToken);
    emit LiquidatePosition(key, _account, _collateralToken, _indexToken, _isLong, position.size, position.collateral, position.reserveAmount, position.realisedPnl, markPrice);

    if (!_isLong && marginFees < position.collateral) {
      uint256 remainingCollateral = position.collateral - marginFees;
      _increasePoolAmount(_collateralToken, usdToTokenMin(_collateralToken, remainingCollateral));
    }

    if (!_isLong) {
      _decreaseGlobalShortSize(_indexToken, position.size);
    }

    delete positions[key];

    // pay the fee receiver using the pool, we assume that in general the liquidated amount should be sufficient to cover
    // the liquidation fees
    _decreasePoolAmount(_collateralToken, usdToTokenMin(_collateralToken, liquidationFeeUsd));
    _transferOut(_collateralToken, usdToTokenMin(_collateralToken, liquidationFeeUsd), _feeReceiver);

    includeAmmPrice = true;
  }

  // validateLiquidation returns (state, fees)
  function validateLiquidation(address _account, address _collateralToken, address _indexToken, bool _isLong, bool _raise) override public view returns (uint256, uint256) {
    return vaultUtils.validateLiquidation(_account, _collateralToken, _indexToken, _isLong, _raise);
  }

  function _reduceCollateral(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong) private returns (uint256, uint256) {
    bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
    Position storage position = positions[key];

    uint256 fee = _collectMarginFees(_account, _collateralToken, _indexToken, _isLong, _sizeDelta, position.size, position.entryFundingRate);
    bool hasProfit;
    uint256 adjustedDelta;

    // scope variables to avoid stack too deep errors
    {
      (bool _hasProfit, uint256 delta) = getDelta(_indexToken, position.size, position.averagePrice, _isLong, position.lastIncreasedTime);
      hasProfit = _hasProfit;
      // get the proportional change in pnl
      adjustedDelta = (_sizeDelta * delta) / position.size;
    }

    uint256 usdOut;
    // transfer profits out
    if (hasProfit && adjustedDelta > 0) {
      usdOut = adjustedDelta;
      position.realisedPnl = position.realisedPnl + int256(adjustedDelta);

      // pay out realised profits from the pool amount for short positions
      if (!_isLong) {
        uint256 tokenAmount = usdToTokenMin(_collateralToken, adjustedDelta);
        _decreasePoolAmount(_collateralToken, tokenAmount);
      }
    }

    if (!hasProfit && adjustedDelta > 0) {
      position.collateral = position.collateral - adjustedDelta;

      // transfer realised losses to the pool for short positions
      // realised losses for long positions are not transferred here as
      // _increasePoolAmount was already called in increasePosition for longs
      if (!_isLong) {
        uint256 tokenAmount = usdToTokenMin(_collateralToken, adjustedDelta);
        _increasePoolAmount(_collateralToken, tokenAmount);
      }

      position.realisedPnl = position.realisedPnl - int256(adjustedDelta);
    }

    // reduce the position's collateral by _collateralDelta
    // transfer _collateralDelta out
    if (_collateralDelta > 0) {
      usdOut = usdOut + _collateralDelta;
      position.collateral = position.collateral - _collateralDelta;
    }

    // if the position will be closed, then transfer the remaining collateral out
    if (position.size == _sizeDelta) {
      usdOut = usdOut + position.collateral;
      position.collateral = 0;
    }

    // if the usdOut is more than the fee then deduct the fee from the usdOut directly
    // else deduct the fee from the position's collateral
    uint256 usdOutAfterFee = usdOut;
    if (usdOut > fee) {
      usdOutAfterFee = usdOut - fee;
    } else {
      position.collateral = position.collateral - fee;
      if (_isLong) {
        uint256 feeTokens = usdToTokenMin(_collateralToken, fee);
        _decreasePoolAmount(_collateralToken, feeTokens);
      }
    }

    emit UpdatePnl(key, hasProfit, adjustedDelta);

    return (usdOut, usdOutAfterFee);
  }

  function _increaseReservedAmount(address _token, uint256 _amount) private {
    reservedAmounts[_token] = reservedAmounts[_token] + _amount;
    _validate(reservedAmounts[_token] <= poolAmounts[_token], 52);
    emit IncreaseReservedAmount(_token, _amount);
  }

  function _decreaseReservedAmount(address _token, uint256 _amount) private {
    reservedAmounts[_token] = reservedAmounts[_token] - _amount;
    emit DecreaseReservedAmount(_token, _amount);
  }

  function _increaseGuaranteedUsd(address _token, uint256 _usdAmount) private {
    guaranteedUsd[_token] = guaranteedUsd[_token] + _usdAmount;
    emit IncreaseGuaranteedUsd(_token, _usdAmount);
  }

  function _decreaseGuaranteedUsd(address _token, uint256 _usdAmount) private {
    guaranteedUsd[_token] = guaranteedUsd[_token] - _usdAmount;
    emit DecreaseGuaranteedUsd(_token, _usdAmount);
  }

  function _increaseGlobalShortSize(address _token, uint256 _amount) internal {
    globalShortSizes[_token] = globalShortSizes[_token] + _amount;

    uint256 maxSize = maxGlobalShortSizes[_token];
    if (maxSize != 0) {
      require(globalShortSizes[_token] <= maxSize, "Vault: max shorts exceeded");
    }
  }

  function _decreaseGlobalShortSize(address _token, uint256 _amount) private {
    uint256 size = globalShortSizes[_token];
    if (_amount > size) {
      globalShortSizes[_token] = 0;
      return;
    }

    globalShortSizes[_token] = size - _amount;
  }

  function getRedemptionCollateral(address _token) public view returns (uint256) {
    if (stableTokens[_token]) {
      return poolAmounts[_token];
    }
    uint256 collateral = usdToTokenMin(_token, guaranteedUsd[_token]);
    return collateral + poolAmounts[_token] - reservedAmounts[_token];
  }

  function getRedemptionCollateralUsd(address _token) public view returns (uint256) {
    return tokenToUsdMin(_token, getRedemptionCollateral(_token));
  }

  function tokenToUsdMin(address _token, uint256 _tokenAmount) public override view returns (uint256) {
    if (_tokenAmount == 0) { return 0; }
    uint256 price = getMinPrice(_token);
    uint256 decimals = tokenDecimals[_token];
    return _tokenAmount * price / (10 ** decimals);
  }

  function usdToTokenMax(address _token, uint256 _usdAmount) public view returns (uint256) {
    if (_usdAmount == 0) { return 0; }
    return usdToToken(_token, _usdAmount, getMinPrice(_token));
  }

  function usdToTokenMin(address _token, uint256 _usdAmount) public view returns (uint256) {
    if (_usdAmount == 0) { return 0; }
    return usdToToken(_token, _usdAmount, getMaxPrice(_token));
  }

  function usdToToken(address _token, uint256 _usdAmount, uint256 _price) public view returns (uint256) {
    if (_usdAmount == 0) { return 0; }
    uint256 decimals = tokenDecimals[_token];
    return _usdAmount * (10 ** decimals) / _price;
  }

  function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong) public override view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256) {
    bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
    Position memory position = positions[key];
    uint256 realisedPnl = position.realisedPnl > 0 ? uint256(position.realisedPnl) : uint256(-position.realisedPnl);
    return (
    position.size, // 0
    position.collateral, // 1
    position.averagePrice, // 2
    position.entryFundingRate, // 3
    position.reserveAmount, // 4
    realisedPnl, // 5
    position.realisedPnl >= 0, // 6
    position.lastIncreasedTime // 7
    );
  }

  function getPositionKey(address _account, address _collateralToken, address _indexToken, bool _isLong) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(
        _account,
        _collateralToken,
        _indexToken,
        _isLong
      ));
  }

  // for longs: nextAveragePrice = (nextPrice * nextSize)/ (nextSize + delta)
  // for shorts: nextAveragePrice = (nextPrice * nextSize) / (nextSize - delta)
  function getNextAveragePrice(address _indexToken, uint256 _size, uint256 _averagePrice, bool _isLong, uint256 _nextPrice, uint256 _sizeDelta, uint256 _lastIncreasedTime) public view returns (uint256) {
    (bool hasProfit, uint256 delta) = getDelta(_indexToken, _size, _averagePrice, _isLong, _lastIncreasedTime);
    uint256 nextSize = _size + _sizeDelta;
    uint256 divisor;
    if (_isLong) {
      divisor = hasProfit ? nextSize + delta : nextSize - delta;
    } else {
      divisor = hasProfit ? nextSize - delta : nextSize + delta;
    }
    return _nextPrice * nextSize / divisor;
  }

  // for longs: nextAveragePrice = (nextPrice * nextSize)/ (nextSize + delta)
  // for shorts: nextAveragePrice = (nextPrice * nextSize) / (nextSize - delta)
  function getNextGlobalShortAveragePrice(address _indexToken, uint256 _nextPrice, uint256 _sizeDelta) public view returns (uint256) {
    uint256 size = globalShortSizes[_indexToken];
    uint256 averagePrice = globalShortAveragePrices[_indexToken];
    uint256 priceDelta = averagePrice > _nextPrice ? averagePrice - _nextPrice : _nextPrice - averagePrice;
    uint256 delta = size * priceDelta / averagePrice;
    bool hasProfit = averagePrice > _nextPrice;

    uint256 nextSize = size + _sizeDelta;
    uint256 divisor = hasProfit ? nextSize - delta : nextSize + delta;

    return _nextPrice * nextSize / divisor;
  }

  function getGlobalShortDelta(address _token) public view returns (bool, uint256) {
    uint256 size = globalShortSizes[_token];
    if (size == 0) { return (false, 0); }

    uint256 nextPrice = getMaxPrice(_token);
    uint256 averagePrice = globalShortAveragePrices[_token];
    uint256 priceDelta = averagePrice > nextPrice ? averagePrice - nextPrice : nextPrice - averagePrice;
    uint256 delta = size * priceDelta / averagePrice;
    bool hasProfit = averagePrice > nextPrice;

    return (hasProfit, delta);
  }

  function getPositionDelta(address _account, address _collateralToken, address _indexToken, bool _isLong) public view returns (bool, uint256) {
    bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
    Position memory position = positions[key];
    return getDelta(_indexToken, position.size, position.averagePrice, _isLong, position.lastIncreasedTime);
  }

  function getPositionLeverage(address _account, address _collateralToken, address _indexToken, bool _isLong) public view returns (uint256) {
    bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
    Position memory position = positions[key];
    _validate(position.collateral > 0, 37);
    return position.size * BASIS_POINTS_DIVISOR / position.collateral;
  }

  function getDelta(address _indexToken, uint256 _size, uint256 _averagePrice, bool _isLong, uint256 _lastIncreasedTime) public override view returns (bool, uint256) {
    _validate(_averagePrice > 0, 38);
    uint256 price = _isLong ? getMinPrice(_indexToken) : getMaxPrice(_indexToken);
    uint256 priceDelta = _averagePrice > price ? _averagePrice - price : price - _averagePrice;
    uint256 delta = _size * priceDelta / _averagePrice;

    bool hasProfit;

    if (_isLong) {
      hasProfit = price > _averagePrice;
    } else {
      hasProfit = _averagePrice > price;
    }

    // if the minProfitTime has passed then there will be no min profit threshold
    // the min profit threshold helps to prevent front-running issues
    uint256 minBps = block.timestamp > _lastIncreasedTime + minProfitTime ? 0 : minProfitBasisPoints[_indexToken];
    if (hasProfit && delta * BASIS_POINTS_DIVISOR <= _size * minBps) {
      delta = 0;
    }

    return (hasProfit, delta);
  }

  function _collectMarginFees(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta, uint256 _size, uint256 _entryFundingRate) private returns (uint256) {
    uint256 feeUsd = getPositionFee(_account, _collateralToken, _indexToken, _isLong, _sizeDelta);

    uint256 fundingFee = getFundingFee(_account, _collateralToken, _indexToken, _isLong, _size, _entryFundingRate);
    feeUsd = feeUsd + fundingFee;

    uint256 feeTokens = usdToTokenMin(_collateralToken, feeUsd);
    feeReserves[_collateralToken] = feeReserves[_collateralToken] + feeTokens;

    emit CollectMarginFees(_collateralToken, feeUsd, feeTokens);
    return feeUsd;
  }

  function getEntryFundingRate(address _collateralToken, address _indexToken, bool _isLong) public view returns (uint256) {
    return vaultUtils.getEntryFundingRate(_collateralToken, _indexToken, _isLong);
  }

  function getFundingFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _size, uint256 _entryFundingRate) public view returns (uint256) {
    return vaultUtils.getFundingFee(_account, _collateralToken, _indexToken, _isLong, _size, _entryFundingRate);
  }

  function getPositionFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta) public view returns (uint256) {
    return vaultUtils.getPositionFee(_account, _collateralToken, _indexToken, _isLong, _sizeDelta);
  }
}
