// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../Vault.sol";

contract VaultTest is Vault {
    function _increaseGlobalShortSize(address _token, uint256 _amount) internal {
        globalShortSizes[_token] = globalShortSizes[_token] + _amount;

        uint256 maxSize = maxGlobalShortSizes[_token];
        if (maxSize != 0) {
            require(globalShortSizes[_token] <= maxSize, "Vault: max shorts exceeded");
        }
    }
    function increaseGlobalShortSize(address token, uint256 amount) external {
        _increaseGlobalShortSize(token, amount);
    }
}
