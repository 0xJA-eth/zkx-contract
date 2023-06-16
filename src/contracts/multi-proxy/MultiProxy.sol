// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)

pragma solidity ^0.8.0;

abstract contract MultiProxy {

  mapping(uint256 => address) public functionImpls;

//  function registerFunctionImpls(bytes[] calldata hashes, address impl) public {
//    for (uint256 i = 0; i < hashes.length; i++) {
//      functionImpls[bytes2Uint256(subByte(hashes[i], 0, 4))] = impl;
//    }
//  }

  function _registerFunctionImpls(string[] calldata names, address impl) internal {
    for (uint256 i = 0; i < names.length; i++) {
      bytes memory hash = abi.encodePacked(keccak256(bytes(names[i])));
      functionImpls[bytes2Uint256(subByte(hash, 0, 4))] = impl;
    }
  }

  /**
   * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
  function _delegate(address implementation) internal virtual {
    //    uint256 size;
    assembly {
      let p1 := mload(0x40)

      calldatacopy(p1, 0, calldatasize())

      let p2 := mload(0x40)

    // Call the implementation.
    // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas(), implementation, p1, calldatasize(), 0, 0)
    //      size := returndatasize()

    // Copy the returned data.
      returndatacopy(p2, 0, returndatasize())

      switch result
      // delegatecall returns 0 on error.
      case 0 { revert(p2, returndatasize()) }
      default { return(p2, returndatasize()) }
    }
    //    revert (toString(size));
  }

  /**
   * @dev This is a virtual function that should be overridden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
  //  function _implementations() internal view virtual returns (address[] memory);

  /**
   * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
  function _fallback() internal virtual {
    _beforeFallback();

    bytes memory hash = subByte(msg.data, 0, 4);
    address impl = functionImpls[bytes2Uint256(hash)];

    if (impl != address(0x0)) _delegate(impl);
    else revert("No implementations");
  }

  /**
   * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
  fallback() external payable virtual {
    _fallback();
  }

  /**
   * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
  receive() external payable virtual {
    _fallback();
  }

  /**
   * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overridden should call `super._beforeFallback()`.
     */
  function _beforeFallback() internal virtual {}

  function bytes2Uint256(bytes memory data) public pure returns (uint256) {
    uint256 result;
    assembly { result := mload(add(data, 32)) }

    return result >> (256 - data.length * 8);
  }

  function subByte(bytes memory self, uint256 startIndex, uint256 len) internal pure returns (bytes memory) {
    require(startIndex <= self.length && self.length - startIndex >= len);
    uint addr = dataPtr(self);
    return toBytes(addr + startIndex, len);
  }
  function dataPtr(bytes memory bts) internal pure returns (uint addr) {
    assembly {
      addr := add(bts, 32)
    }
  }
  function toBytes(uint addr, uint len) internal pure returns (bytes memory bts) {
    bts = new bytes(len);
    uint btsptr;
    assembly {
      btsptr := add(bts, 32)
    }
    copy(addr, btsptr, len);
  }
  function copy(uint src, uint dest, uint len) internal pure {
    for (; len >= 32; len -= 32) {
      assembly {
        mstore(dest, mload(src))
      }
      dest += 32;
      src += 32;
    }
    uint mask = 256 ** (32 - len) - 1;
    assembly {
      let srcpart := and(mload(src), not(mask))
      let destpart := and(mload(dest), mask)
      mstore(dest, or(destpart, srcpart))
    }
  }

  function toString(address account) public pure returns(string memory) {
    return toString(abi.encodePacked(account));
  }
  function toString(uint256 value) public pure returns(string memory) {
    return toString(abi.encodePacked(value));
  }
  function toString(bytes32 value) public pure returns(string memory) {
    return toString(abi.encodePacked(value));
  }
  function toString(bytes memory data) public pure returns(string memory) {
    bytes memory alphabet = "0123456789abcdef";

    bytes memory str = new bytes(2 + data.length * 2);
    str[0] = "0";
    str[1] = "x";
    for (uint i = 0; i < data.length; i++) {
      str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
      str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
    }
    return string(str);
  }
}
