// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../access/Governable.sol";

contract Bridge is ReentrancyGuard, Governable {

    address public token;
    address public wToken;

    constructor(address _token, address _wToken) public {
        token = _token;
        wToken = _wToken;
    }

    function wrap(uint256 _amount, address _receiver) external nonReentrant {
        IERC20(token).transferFrom(msg.sender, address(this), _amount);
        IERC20(wToken).transfer(_receiver, _amount);
    }

    function unwrap(uint256 _amount, address _receiver) external nonReentrant {
        IERC20(wToken).transferFrom(msg.sender, address(this), _amount);
        IERC20(token).transfer(_receiver, _amount);
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).transfer(_account, _amount);
    }
}
