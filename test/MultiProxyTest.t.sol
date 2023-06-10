// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "../src/contracts/multiProxy/MultiProxy.sol";
import "../src/contracts/multiProxy/ProxyTarget.sol";

contract Main is MultiProxy {

}

interface IMain {
  function aa() external view returns(string memory);
  function bb() external view returns(string memory);
}

contract A is ProxyTarget {
  constructor(MultiProxy _parent) ProxyTarget(_parent) {}

  function aa() external view returns(string memory) {
    return "Hello aa";
  }
}
contract B is ProxyTarget {
  constructor(MultiProxy _parent) ProxyTarget(_parent) {}

  function bb() external view returns(string memory) {
    return "Hello bb";
  }
}

contract MultiProxyTest is Test {
  address mainAddress;

  function setUp() public {
    Main main = new Main();
    A a = new A(main);
    B b = new B(main);

    mainAddress = address(main);
  }

  function testRun() public {
    IMain main = IMain(mainAddress);
    string memory aRes = main.aa();
    assertEq(aRes, "Hello aa");

    string memory bRes = main.bb();
    assertEq(bRes, "Hello bb");
  }
}
