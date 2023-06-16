// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "../src/contracts/multi-proxy/MultiProxy.sol";
import "../src/contracts/multi-proxy/ProxyTarget.sol";
import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract MainState {
  string public _a = "110";
  bool public isLeverageEnabled = true;

  function _validate(bool _condition, uint256 _errorCode) public view {
    require(_condition, toString2(_errorCode));
  }

  function toString2(address account) public pure returns(string memory) {
    return toString2(abi.encodePacked(account));
  }
  function toString2(uint256 value) public pure returns(string memory) {
    return toString2(abi.encodePacked(value));
  }
  function toString2(bytes32 value) public pure returns(string memory) {
    return toString2(abi.encodePacked(value));
  }
  function toString2(bytes memory data) public pure returns(string memory) {
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
contract Main is MultiProxy, MainState {

  function registerFunctionImpls(string[] calldata names, address impl) public {
    _registerFunctionImpls(names, impl);
  }

//  function setA(string memory val) external {
//    _a = val;
//  }
  function setIsLeverageEnabled(bool _isLeverageEnabled) external {
    isLeverageEnabled = _isLeverageEnabled;
  }
}

interface IMain {
  function main() external view returns(IMain);
  function isLeverageEnabled() external view returns(bool);
  function setIsLeverageEnabled(bool _isLeverageEnabled) external;
  function a() external view returns(string memory);
  function setA(string memory val) external;
  function aa() external view returns(string memory);
  function bb() external view returns(string memory);
  function ba() external view returns(string memory);
}

contract A is ProxyTarget, MainState, ReentrancyGuard {

  constructor(MultiProxy _parent) ProxyTarget(_parent) {}

  function main() public view returns(IMain) {
    return IMain(address(this));
  }

  function a() external view returns(string memory) {
    return _a;
  }
  function setA(string memory val) external nonReentrant {
    _validate(isLeverageEnabled, 28);
    _a = val;
  }
  function aa() external view returns(string memory) {
    return isLeverageEnabled ? "ooo" : "kkk";
  }
}
contract B is ProxyTarget, MainState {
  constructor(MultiProxy _parent) ProxyTarget(_parent) {}

  function main() public view returns(IMain) {
    return IMain(address(this));
  }

  function bb() external pure returns(string memory) {
    revert("Hello bb");
  }
  function ba() external view returns(string memory) {
    return _a;
  }
}

contract MultiProxyTest is Test {
  address mainAddress;

  function setUp() public {
    Main main = new Main();

    A a = new A(main);

    string[] memory aNames = new string[](3);
    aNames[0] = "aa()";
    aNames[1] = "a()";
    aNames[2] = "setA(string)";
    main.registerFunctionImpls(aNames, address(a));

    B b = new B(main);

    string[] memory bNames = new string[](2);
    bNames[0] = "bb()";
    bNames[1] = "ba()";
    main.registerFunctionImpls(bNames, address(b));

    mainAddress = address(main);
  }

  function bytes2Uint256(bytes memory data) public pure returns (uint256) {
    uint256 result;
    assembly { result := mload(add(data, 32)) }

    return result >> (256 - data.length * 8);
  }
//  function uint2562Bytes(uint256 value) public pure returns (bytes memory) {
//    bytes memory result = new bytes(32);
//    assembly {
//      mstore(add(result, 32), value)
//    }
//    return result;
//  }

  function testRun() public {
//    bytes memory b = abi.encodePacked(uint256(0x8466c3e6000000000000));
//    require(false, toString(subByte(b, 0, 4)));

    IMain main = IMain(mainAddress);
    string memory aRes = main.aa();
//    assertEq(aRes, "kkk", "Equal to kkk");

    main.setIsLeverageEnabled(true);
//    vm.expectRevert("Not enabled");
    main.setA("11");

    main.setIsLeverageEnabled(true);
    assertEq(main.aa(), "ooo", "Equal to ooo");

    vm.expectRevert("Hello bb");
    string memory bRes = main.bb();

    string memory baRes = main.a();
    assertEq(baRes, "11", "Equal to 110");

    baRes = main.ba();
    assertEq(baRes, "11", "Equal to 110");

    main.setA("ss");

    baRes = main.a();
    assertEq(baRes, "ss", "a() Equal to ss");

    baRes = main.ba();
    assertEq(baRes, "ss", "ba() Equal to 110");
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
