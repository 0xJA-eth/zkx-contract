// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import "./YieldToken.sol";

contract YieldFarm is YieldToken, ReentrancyGuard {

    address public stakingToken;

    constructor(string memory _name, string memory _symbol, address _stakingToken) public YieldToken(_name, _symbol, 0) {
        stakingToken = _stakingToken;
    }

    function stake(uint256 _amount) external nonReentrant {
        IERC20(stakingToken).transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
    }

    function unstake(uint256 _amount) external nonReentrant {
        _burn(msg.sender, _amount);
        IERC20(stakingToken).transfer(msg.sender, _amount);
    }
}
