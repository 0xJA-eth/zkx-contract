// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IRouter.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IPositionRouter.sol";
import "./interfaces/IPositionRouterCallbackReceiver.sol";

import "../lib/Address.sol";
import "../peripherals/interfaces/ITimelock.sol";
import "./BasePositionManager.sol";

contract PositionRouter is BasePositionManager, IPositionRouter {
    using Address for address;

    struct IncreasePositionRequest {
        address account;
        address[] path;
        address indexToken;
        uint256 amountIn;
        uint256 minOut;
        uint256 sizeDelta;
        bool isLong;
        uint256 acceptablePrice;
        uint256 executionFee;
        uint256 blockNumber;
        uint256 blockTime;
        bool hasCollateralInETH;
        address callbackTarget;
    }

    struct DecreasePositionRequest {
        address account;
        address[] path;
        address indexToken;
        uint256 collateralDelta;
        uint256 sizeDelta;
        bool isLong;
        address receiver;
        uint256 acceptablePrice;
        uint256 minOut;
        uint256 executionFee;
        uint256 blockNumber;
        uint256 blockTime;
        bool withdrawETH;
        address callbackTarget;
    }

    uint256 public minExecutionFee;

    uint256 public minBlockDelayKeeper;
    uint256 public minTimeDelayPublic;
    uint256 public maxTimeDelay;

    bool public isLeverageEnabled = true;

    bytes32[] public override increasePositionRequestKeys;
    bytes32[] public override decreasePositionRequestKeys;

    uint256 public override increasePositionRequestKeysStart;
    uint256 public override decreasePositionRequestKeysStart;

    uint256 public callbackGasLimit;
    mapping (address => uint256) public customCallbackGasLimits;

    mapping (address => bool) public isPositionKeeper;

    mapping (address => uint256) public increasePositionsIndex;
    mapping (bytes32 => IncreasePositionRequest) public increasePositionRequests;

    mapping (address => uint256) public decreasePositionsIndex;
    mapping (bytes32 => DecreasePositionRequest) public decreasePositionRequests;

    event CreateIncreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 amountIn,
        uint256 minOut,
        uint256 sizeDelta,
        bool isLong,
        uint256 acceptablePrice,
        uint256 executionFee,
        uint256 index,
        uint256 queueIndex,
        uint256 blockNumber,
        uint256 blockTime,
        uint256 gasPrice
    );

    event ExecuteIncreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 amountIn,
        uint256 minOut,
        uint256 sizeDelta,
        bool isLong,
        uint256 acceptablePrice,
        uint256 executionFee,
        uint256 blockGap,
        uint256 timeGap
    );

    event CancelIncreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 amountIn,
        uint256 minOut,
        uint256 sizeDelta,
        bool isLong,
        uint256 acceptablePrice,
        uint256 executionFee,
        uint256 blockGap,
        uint256 timeGap
    );

    event CreateDecreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        address receiver,
        uint256 acceptablePrice,
        uint256 minOut,
        uint256 executionFee,
        uint256 index,
        uint256 queueIndex,
        uint256 blockNumber,
        uint256 blockTime
    );

    event ExecuteDecreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        address receiver,
        uint256 acceptablePrice,
        uint256 minOut,
        uint256 executionFee,
        uint256 blockGap,
        uint256 timeGap
    );

    event CancelDecreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        address receiver,
        uint256 acceptablePrice,
        uint256 minOut,
        uint256 executionFee,
        uint256 blockGap,
        uint256 timeGap
    );

    event SetPositionKeeper(address indexed account, bool isActive);
    event SetMinExecutionFee(uint256 minExecutionFee);
    event SetIsLeverageEnabled(bool isLeverageEnabled);
    event SetDelayValues(uint256 minBlockDelayKeeper, uint256 minTimeDelayPublic, uint256 maxTimeDelay);
    event SetRequestKeysStartValues(uint256 increasePositionRequestKeysStart, uint256 decreasePositionRequestKeysStart);
    event SetCallbackGasLimit(uint256 callbackGasLimit);
    event SetCustomCallbackGasLimit(address callbackTarget, uint256 callbackGasLimit);
    event Callback(address callbackTarget, bool success, uint256 callbackGasLimit);

    modifier onlyPositionKeeper() {
        require(isPositionKeeper[msg.sender], "403");
        _;
    }

    constructor(
        address _vault,
        address _router,
        address _weth,
        address _shortsTracker,
        uint256 _depositFee,
        uint256 _minExecutionFee
    ) public BasePositionManager(_vault, _router, _shortsTracker, _weth, _depositFee) {
        minExecutionFee = _minExecutionFee;
    }

    function setPositionKeeper(address _account, bool _isActive) external onlyAdmin {
        isPositionKeeper[_account] = _isActive;
        emit SetPositionKeeper(_account, _isActive);
    }

    function setCallbackGasLimit(uint256 _callbackGasLimit) external onlyAdmin {
        callbackGasLimit = _callbackGasLimit;
        emit SetCallbackGasLimit(_callbackGasLimit);
    }

    function setCustomCallbackGasLimit(address _callbackTarget, uint256 _callbackGasLimit) external onlyAdmin {
        customCallbackGasLimits[_callbackTarget] = _callbackGasLimit;
        emit SetCustomCallbackGasLimit(_callbackTarget, _callbackGasLimit);
    }

    function setMinExecutionFee(uint256 _minExecutionFee) external onlyAdmin {
        minExecutionFee = _minExecutionFee;
        emit SetMinExecutionFee(_minExecutionFee);
    }

    function setIsLeverageEnabled(bool _isLeverageEnabled) external onlyAdmin {
        isLeverageEnabled = _isLeverageEnabled;
        emit SetIsLeverageEnabled(_isLeverageEnabled);
    }

    function setDelayValues(uint256 _minBlockDelayKeeper, uint256 _minTimeDelayPublic, uint256 _maxTimeDelay) external onlyAdmin {
        minBlockDelayKeeper = _minBlockDelayKeeper;
        minTimeDelayPublic = _minTimeDelayPublic;
        maxTimeDelay = _maxTimeDelay;
        emit SetDelayValues(_minBlockDelayKeeper, _minTimeDelayPublic, _maxTimeDelay);
    }

    function setRequestKeysStartValues(uint256 _increasePositionRequestKeysStart, uint256 _decreasePositionRequestKeysStart) external onlyAdmin {
        increasePositionRequestKeysStart = _increasePositionRequestKeysStart;
        decreasePositionRequestKeysStart = _decreasePositionRequestKeysStart;

        emit SetRequestKeysStartValues(_increasePositionRequestKeysStart, _decreasePositionRequestKeysStart);
    }

    function executeIncreasePositions(uint256 _endIndex, address payable _executionFeeReceiver) external override onlyPositionKeeper {
        // 获取起始索引和数组长度
        uint256 index = increasePositionRequestKeysStart;
        uint256 length = increasePositionRequestKeys.length;

        // 如果起始索引大于等于数组长度，表示没有需要处理的请求，直接返回
        if (index >= length) {
            return;
        }

        // 如果 _endIndex 大于数组长度，将其设置为数组长度，以避免越界访问
        if (_endIndex > length) {
            _endIndex = length;
        }

        // 循环处理请求
        while (index < _endIndex) {
            // 获取当前请求的键（key）
            bytes32 key = increasePositionRequestKeys[index];

            // 尝试执行增加头寸的请求
            // 如果请求被执行，则删除该键并继续下一次循环
            // 如果请求未被执行，跳出循环
            try this.executeIncreasePosition(key, _executionFeeReceiver) returns (bool _wasExecuted) {
                if (!_wasExecuted) {
                    break;
                }
            }
            catch {
                // 尝试取消增加头寸的请求
                // 如果请求被取消，则删除该键并继续下一次循环
                // 如果请求未被取消，跳出循环
                try this.cancelIncreasePosition(key, _executionFeeReceiver) returns (bool _wasCancelled) {
                    if (!_wasCancelled) {
                        break;
                    }
                }
                catch {}
            }

            // 删除处理完的键，并增加索引值
            delete increasePositionRequestKeys[index];
            index++;
        }

        // 更新起始索引的值，以便下次调用时从正确的位置开始处理
        increasePositionRequestKeysStart = index;
    }

    function executeDecreasePositions(uint256 _endIndex, address payable _executionFeeReceiver) external override onlyPositionKeeper {
        uint256 index = decreasePositionRequestKeysStart;
        uint256 length = decreasePositionRequestKeys.length;

        if (index >= length) { return; }

        if (_endIndex > length) {
            _endIndex = length;
        }

        while (index < _endIndex) {
            bytes32 key = decreasePositionRequestKeys[index];

            // if the request was executed then delete the key from the array
            // if the request was not executed then break from the loop, this can happen if the
            // minimum number of blocks has not yet passed
            // an error could be thrown if the request is too old
            // in case an error was thrown, cancel the request
            try this.executeDecreasePosition(key, _executionFeeReceiver) returns (bool _wasExecuted) {
                if (!_wasExecuted) { break; }
            } catch {
                // wrap this call in a try catch to prevent invalid cancels from blocking the loop
                try this.cancelDecreasePosition(key, _executionFeeReceiver) returns (bool _wasCancelled) {
                    if (!_wasCancelled) { break; }
                } catch {}
            }

            delete decreasePositionRequestKeys[index];
            index++;
        }

        decreasePositionRequestKeysStart = index;
    }

    function createIncreasePosition(
        address[] memory _path, // path[0] 是要支付的Token
        address _indexToken,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _acceptablePrice,
        uint256 _executionFee,
        bytes32 _referralCode,
        address _callbackTarget
    ) external payable nonReentrant returns (bytes32) {
        require(_executionFee >= minExecutionFee, "fee");
        require(msg.value == _executionFee, "val");
        require(_path.length == 1 || _path.length == 2, "len");

        _transferInETH();
        _setTraderReferralCode(_referralCode);

        if (_amountIn > 0) { // 支付Token
            IRouter(router).pluginTransfer(_path[0], msg.sender, address(this), _amountIn);
        }

        return _createIncreasePosition(
            msg.sender,
            _path,
            _indexToken,
            _amountIn,
            _minOut,
            _sizeDelta,
            _isLong,
            _acceptablePrice,
            _executionFee,
            false,
            _callbackTarget
        );
    }

    function createIncreasePositionETH(
        address[] memory _path,
        address _indexToken,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _acceptablePrice,
        uint256 _executionFee,
        bytes32 _referralCode,
        address _callbackTarget
    ) external payable nonReentrant returns (bytes32) {
        require(_executionFee >= minExecutionFee, "fee");
        require(msg.value >= _executionFee, "val");
        require(_path.length == 1 || _path.length == 2, "len");
        require(_path[0] == weth, "path");
        _transferInETH();
        _setTraderReferralCode(_referralCode);

        uint256 amountIn = msg.value - _executionFee;

        return _createIncreasePosition(
            msg.sender,
            _path,
            _indexToken,
            amountIn,
            _minOut,
            _sizeDelta,
            _isLong,
            _acceptablePrice,
            _executionFee,
            true,
            _callbackTarget
        );
    }

    function createDecreasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _acceptablePrice,
        uint256 _minOut,
        uint256 _executionFee,
        bool _withdrawETH,
        address _callbackTarget
    ) external payable nonReentrant returns (bytes32) {
        require(_executionFee >= minExecutionFee, "fee");
        require(msg.value == _executionFee, "val");
        require(_path.length == 1 || _path.length == 2, "len");

        if (_withdrawETH) {
            require(_path[_path.length - 1] == weth, "path");
        }

        _transferInETH();

        return _createDecreasePosition(
            msg.sender,
            _path,
            _indexToken,
            _collateralDelta,
            _sizeDelta,
            _isLong,
            _receiver,
            _acceptablePrice,
            _minOut,
            _executionFee,
            _withdrawETH,
            _callbackTarget
        );
    }

    function getRequestQueueLengths() external view override returns (uint256, uint256, uint256, uint256) {
        return (
            increasePositionRequestKeysStart,
            increasePositionRequestKeys.length,
            decreasePositionRequestKeysStart,
            decreasePositionRequestKeys.length
        );
    }

    function executeIncreasePosition(bytes32 _key, address payable _executionFeeReceiver) public nonReentrant returns (bool) {
        // 从映射中获取增加头寸请求
        IncreasePositionRequest memory request = increasePositionRequests[_key];
        // 如果请求已经执行或取消，则返回true，以便继续执行executeIncreasePositions循环中的下一个请求
        if (request.account == address(0)) { return true; }

        // 验证是否应该执行请求
        bool shouldExecute = _validateExecution(request.blockNumber, request.blockTime, request.account);
        if (!shouldExecute) { return false; }

        // 从映射中删除请求
        delete increasePositionRequests[_key];

        if (request.amountIn > 0) {
            uint256 amountIn = request.amountIn;

            if (request.path.length > 1) {
                // 将amountIn数量的第一个代币转移到vault合约
                IERC20(request.path[0]).transfer(vault, request.amountIn);
                // 执行交换操作，将路径中的代币交换为目标代币，并返回交换后的数量
                amountIn = _swap(request.path, request.minOut, address(this));
            }

            // 收取费用，并返回扣除费用后的金额
            uint256 afterFeeAmount = _collectFees(request.account, request.path, amountIn, request.indexToken, request.isLong, request.sizeDelta);
            // 将扣除费用后的金额转移到vault合约
            IERC20(request.path[request.path.length - 1]).transfer(vault, afterFeeAmount);
        }

        // 增加头寸
        _increasePosition(request.account, request.path[request.path.length - 1], request.indexToken, request.sizeDelta, request.isLong, request.acceptablePrice);

        // 将执行费用转移给_executionFeeReceiver
        _transferOutETHWithGasLimitFallbackToWeth(request.executionFee, _executionFeeReceiver);

        // 发出事件，表示执行增加头寸请求
        emit ExecuteIncreasePosition(
            request.account,
            request.path,
            request.indexToken,
            request.amountIn,
            request.minOut,
            request.sizeDelta,
            request.isLong,
            request.acceptablePrice,
            request.executionFee,
            block.number - request.blockNumber,
            block.timestamp - request.blockTime
        );

        // 调用请求的回调函数，将请求标识为成功执行
        _callRequestCallback(request.callbackTarget, _key, true, true);

        return true;
    }

    function cancelIncreasePosition(bytes32 _key, address payable _executionFeeReceiver) public nonReentrant returns (bool) {
        // 从映射中获取增加头寸请求
        IncreasePositionRequest memory request = increasePositionRequests[_key];
        // 如果请求已经执行或取消，则返回true，以便继续执行executeIncreasePositions循环中的下一个请求
        if (request.account == address(0)) { return true; }

        // 验证是否应该取消请求
        bool shouldCancel = _validateCancellation(request.blockNumber, request.blockTime, request.account);
        if (!shouldCancel) { return false; }

        // 从映射中删除请求
        delete increasePositionRequests[_key];

        if (request.hasCollateralInETH) {
            // 如果请求中有ETH作为抵押品，则将抵押品退还给请求的账户
            _transferOutETHWithGasLimitFallbackToWeth(request.amountIn, payable(request.account));
        } else {
            // 否则，将请求的代币转移给请求的账户
            IERC20(request.path[0]).transfer(request.account, request.amountIn);
        }

        // 将执行费用转移给_executionFeeReceiver
        _transferOutETHWithGasLimitFallbackToWeth(request.executionFee, _executionFeeReceiver);

        // 发出事件，表示取消增加头寸请求
        emit CancelIncreasePosition(
            request.account,
            request.path,
            request.indexToken,
            request.amountIn,
            request.minOut,
            request.sizeDelta,
            request.isLong,
            request.acceptablePrice,
            request.executionFee,
            block.number - request.blockNumber,
            block.timestamp - request.blockTime
        );

        // 调用请求的回调函数，将请求标识为成功取消
        _callRequestCallback(request.callbackTarget, _key, false, true);

        return true;
    }


    function executeDecreasePosition(bytes32 _key, address payable _executionFeeReceiver) public nonReentrant returns (bool) {
        DecreasePositionRequest memory request = decreasePositionRequests[_key];
        // if the request was already executed or cancelled, return true so that the executeDecreasePositions loop will continue executing the next request
        if (request.account == address(0)) { return true; }

        bool shouldExecute = _validateExecution(request.blockNumber, request.blockTime, request.account);
        if (!shouldExecute) { return false; }

        delete decreasePositionRequests[_key];

        uint256 amountOut = _decreasePosition(request.account, request.path[0], request.indexToken, request.collateralDelta, request.sizeDelta, request.isLong, address(this), request.acceptablePrice);

        if (amountOut > 0) {
            if (request.path.length > 1) {
                IERC20(request.path[0]).transfer(vault, amountOut);
                amountOut = _swap(request.path, request.minOut, address(this));
            }

            if (request.withdrawETH) {
               _transferOutETHWithGasLimitFallbackToWeth(amountOut, payable(request.receiver));
            } else {
               IERC20(request.path[request.path.length - 1]).transfer(request.receiver, amountOut);
            }
        }

       _transferOutETHWithGasLimitFallbackToWeth(request.executionFee, _executionFeeReceiver);

        emit ExecuteDecreasePosition(
            request.account,
            request.path,
            request.indexToken,
            request.collateralDelta,
            request.sizeDelta,
            request.isLong,
            request.receiver,
            request.acceptablePrice,
            request.minOut,
            request.executionFee,
            block.number - request.blockNumber,
            block.timestamp - request.blockTime
        );

        _callRequestCallback(request.callbackTarget, _key, true, false);

        return true;
    }

    function cancelDecreasePosition(bytes32 _key, address payable _executionFeeReceiver) public nonReentrant returns (bool) {
        DecreasePositionRequest memory request = decreasePositionRequests[_key];
        // if the request was already executed or cancelled, return true so that the executeDecreasePositions loop will continue executing the next request
        if (request.account == address(0)) { return true; }

        bool shouldCancel = _validateCancellation(request.blockNumber, request.blockTime, request.account);
        if (!shouldCancel) { return false; }

        delete decreasePositionRequests[_key];

       _transferOutETHWithGasLimitFallbackToWeth(request.executionFee, _executionFeeReceiver);

        emit CancelDecreasePosition(
            request.account,
            request.path,
            request.indexToken,
            request.collateralDelta,
            request.sizeDelta,
            request.isLong,
            request.receiver,
            request.acceptablePrice,
            request.minOut,
            request.executionFee,
            block.number - request.blockNumber,
            block.timestamp - request.blockTime
        );

        _callRequestCallback(request.callbackTarget, _key, false, false);

        return true;
    }

    function getRequestKey(address _account, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _index));
    }

    function getIncreasePositionRequestPath(bytes32 _key) public view override returns (address[] memory) {
        IncreasePositionRequest memory request = increasePositionRequests[_key];
        return request.path;
    }

    function getDecreasePositionRequestPath(bytes32 _key) public view override returns (address[] memory) {
        DecreasePositionRequest memory request = decreasePositionRequests[_key];
        return request.path;
    }

    function _setTraderReferralCode(bytes32 _referralCode) internal {
        if (_referralCode != bytes32(0) && referralStorage != address(0)) {
            IReferralStorage(referralStorage).setTraderReferralCode(msg.sender, _referralCode);
        }
    }

    function _validateExecution(uint256 _positionBlockNumber, uint256 _positionBlockTime, address _account) internal view returns (bool) {
        if (_positionBlockTime + maxTimeDelay <= block.timestamp) {
            revert("expired");
        }

        return _validateExecutionOrCancellation(_positionBlockNumber, _positionBlockTime, _account);
    }

    function _validateCancellation(uint256 _positionBlockNumber, uint256 _positionBlockTime, address _account) internal view returns (bool) {
        return _validateExecutionOrCancellation(_positionBlockNumber, _positionBlockTime, _account);
    }

    function _validateExecutionOrCancellation(uint256 _positionBlockNumber, uint256 _positionBlockTime, address _account) internal view returns (bool) {
        bool isKeeperCall = msg.sender == address(this) || isPositionKeeper[msg.sender];

        if (!isLeverageEnabled && !isKeeperCall) {
            revert("403");
        }

        if (isKeeperCall) {
            return _positionBlockNumber + minBlockDelayKeeper <= block.number;
        }

        require(msg.sender == _account, "403");

        require(_positionBlockTime + minTimeDelayPublic <= block.timestamp, "delay");

        return true;
    }

    function _createIncreasePosition(
        address _account,
        address[] memory _path,
        address _indexToken,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _acceptablePrice,
        uint256 _executionFee,
        bool _hasCollateralInETH,
        address _callbackTarget
    ) internal returns (bytes32) {
        IncreasePositionRequest memory request = IncreasePositionRequest(
            _account,
            _path,
            _indexToken,
            _amountIn,
            _minOut,
            _sizeDelta,
            _isLong,
            _acceptablePrice,
            _executionFee,
            block.number,
            block.timestamp,
            _hasCollateralInETH,
            _callbackTarget
        );

        (uint256 index, bytes32 requestKey) = _storeIncreasePositionRequest(request);
        emit CreateIncreasePosition(
            _account,
            _path,
            _indexToken,
            _amountIn,
            _minOut,
            _sizeDelta,
            _isLong,
            _acceptablePrice,
            _executionFee,
            index,
            increasePositionRequestKeys.length - 1,
            block.number,
            block.timestamp,
            tx.gasprice
        );

        return requestKey;
    }

    function _storeIncreasePositionRequest(IncreasePositionRequest memory _request) internal returns (uint256, bytes32) {
        address account = _request.account;
        uint256 index = increasePositionsIndex[account] + 1;
        increasePositionsIndex[account] = index;
        bytes32 key = getRequestKey(account, index);

        increasePositionRequests[key] = _request;
        increasePositionRequestKeys.push(key);

        return (index, key);
    }

    function _storeDecreasePositionRequest(DecreasePositionRequest memory _request) internal returns (uint256, bytes32) {
        address account = _request.account;
        uint256 index = decreasePositionsIndex[account] + 1;
        decreasePositionsIndex[account] = index;
        bytes32 key = getRequestKey(account, index);

        decreasePositionRequests[key] = _request;
        decreasePositionRequestKeys.push(key);

        return (index, key);
    }

    function _createDecreasePosition(
        address _account,
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _acceptablePrice,
        uint256 _minOut,
        uint256 _executionFee,
        bool _withdrawETH,
        address _callbackTarget
    ) internal returns (bytes32) {
        DecreasePositionRequest memory request = DecreasePositionRequest(
            _account,
            _path,
            _indexToken,
            _collateralDelta,
            _sizeDelta,
            _isLong,
            _receiver,
            _acceptablePrice,
            _minOut,
            _executionFee,
            block.number,
            block.timestamp,
            _withdrawETH,
            _callbackTarget
        );

        (uint256 index, bytes32 requestKey) = _storeDecreasePositionRequest(request);
        emit CreateDecreasePosition(
            request.account,
            request.path,
            request.indexToken,
            request.collateralDelta,
            request.sizeDelta,
            request.isLong,
            request.receiver,
            request.acceptablePrice,
            request.minOut,
            request.executionFee,
            index,
            decreasePositionRequestKeys.length - 1,
            block.number,
            block.timestamp
        );
        return requestKey;
    }

    function _callRequestCallback(
        address _callbackTarget,
        bytes32 _key,
        bool _wasExecuted,
        bool _isIncrease
    ) internal {
        if (_callbackTarget == address(0)) {
            return;
        }

        if (!_callbackTarget.isContract()) {
            return;
        }

        uint256 _gasLimit = callbackGasLimit;

        uint256 _customCallbackGasLimit = customCallbackGasLimits[_callbackTarget];

        if (_customCallbackGasLimit > _gasLimit) {
            _gasLimit = _customCallbackGasLimit;
        }

        if (_gasLimit == 0) {
            return;
        }

        bool success;
        try IPositionRouterCallbackReceiver(_callbackTarget).gmxPositionCallback{ gas: _gasLimit }(_key, _wasExecuted, _isIncrease) {
            success = true;
        } catch {}

        emit Callback(_callbackTarget, success, _gasLimit);
    }
}
