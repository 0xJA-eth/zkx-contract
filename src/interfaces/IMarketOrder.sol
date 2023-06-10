
pragma solidity ^0.8.0;

interface IMarketOrder {

  function make(
    // path.length == 1 || path.length == 2
    // path[0]: payToken 用于支付的Token
    // path[path.length - 1]: collateralToken 用于抵押物的Token
    address[] memory _path,
    address _indexToken, // 指数Token
    uint256 _amountIn, // 支付数量
    uint256 _minOut, // ?
    uint256 _sizeDelta, // 头寸改变量
    bool _isLong,
    uint256 _acceptablePrice, // 可接受价格
    uint256 _executionFee, // 交易费
    bytes32 _referralCode, // 邀请码
    address _callbackTarget
  ) external;

  function execute(
    bytes32 _key, // Order key
    address payable _executionFeeReceiver // 手续费接受者
  ) external;

}
