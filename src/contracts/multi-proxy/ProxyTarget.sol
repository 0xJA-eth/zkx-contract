// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)

pragma solidity ^0.8.0;

import "./MultiProxy.sol";

abstract contract ProxyTarget {

  MultiProxy public parent;

  constructor(MultiProxy _parent) {
    parent = _parent;
  }
}
