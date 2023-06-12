// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "../src/contracts/multiProxy/MultiProxy.sol";
import "../src/contracts/multiProxy/ProxyTarget.sol";

contract MainState {
  string public _a = "110";
}
contract Main is MultiProxy, MainState {

}

interface IMain {
  function main() external view returns(IMain);
  function a() external view returns(string memory);
  function setA(string memory val) external;
  function aa() external view returns(string memory);
  function bb() external view returns(string memory);
  function ba() external view returns(string memory);
}

contract A is ProxyTarget, MainState {

  constructor(MultiProxy _parent) ProxyTarget(_parent) {}

  function main() public view returns(IMain) {
    return IMain(address(this));
  }

  function a() external view returns(string memory) {
    return _a;
  }
  function setA(string memory val) external {
    _a = val;
  }
  function aa() external pure returns(string memory) {
    return "Hello aa";
  }
}
contract B is ProxyTarget, MainState {
  constructor(MultiProxy _parent) ProxyTarget(_parent) {}

  function main() public view returns(IMain) {
    return IMain(address(this));
  }

  function bb() external pure returns(string memory) {
    return "Hello bb";
  }
  function ba() external view returns(string memory) {
    return main().a();
  }
}

contract MultiProxyTest is Test {
  address mainAddress;

  function setUp() public {
    Main main = new Main();
    new A(main); new B(main);

    mainAddress = address(main);
  }

  function testRun() public {
    IMain main = IMain(mainAddress);
    string memory aRes = main.aa();
    assertEq(aRes, "Hello aa");

    string memory bRes = main.bb();
    assertEq(bRes, "Hello bb");

    string memory baRes = main.a();
    assertEq(baRes, "110");

    baRes = main.ba();
    assertEq(baRes, "110");

    main.setA("ss");

    baRes = main.a();
    assertEq(baRes, "ss");

    baRes = main.ba();
    assertEq(baRes, "ss");
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
