// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.12;

import "forge-std/Script.sol";
import "../src/gmx-contracts/core/Vault.sol";
import "../src/gmx-contracts/peripherals/Reader.sol";

contract Deploy is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Reader vault = new Reader();

        vm.stopBroadcast();
    }
}
