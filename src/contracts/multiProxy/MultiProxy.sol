// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)

pragma solidity ^0.8.0;

import "./BaseMultiProxy.sol";

abstract contract MultiProxy is BaseMultiProxy {

  address[] public implementations;

  function _implementations() internal view override returns (address[] memory) {
    return implementations;
  }

  function addImplementation(address impl) public {
    implementations.push(impl);
  }

  function removeImplementation(address impl) public {
    for (uint i = 0; i < implementations.length; i++) {
      if (implementations[i] == impl) {
        implementations[i] = implementations[implementations.length - 1];
        implementations.pop();
        break;
      }
    }
  }
}
