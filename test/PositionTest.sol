// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "../src/contracts/core/Vault.sol";
import "../src/contracts/core/VaultPosition.sol";
import "../src/contracts/core/VaultUSDG.sol";
import "../src/contracts/core/VaultUSDG.sol";
import "../src/contracts/core/VaultPosition.sol";
import "../src/contracts/core/VaultErrorController.sol";

contract PositionTest is Test {

  address payable vaultAddress;
  VaultPosition vp;

  function setUp() public {
    Vault vault = new Vault();
    vp = new VaultPosition(vault); // new VaultUSDG(vault);

    string[] memory names = new string[](1);
    names[0] = "increasePosition(address,address,address,uint256,bool)";
//    names[1] = "isLeverageEnabled()";

    vault.registerFunctionImpls(names, address(vp));

    vaultAddress = payable(address(vault));
  }

  function testRun() public {
    VaultErrorController controller = new VaultErrorController();
    Vault(vaultAddress).setErrorController(address(controller));

    string[] memory errors = new string[](30);
    errors[0] = "Vault: zero error";
    errors[1] = "Vault: already initialized";
    errors[2] = "Vault: invalid _maxLeverage";
    errors[3] = "Vault: invalid _taxBasisPoints";
    errors[4] = "Vault: invalid _stableTaxBasisPoints";
    errors[5] = "Vault: invalid _mintBurnFeeBasisPoints";
    errors[6] = "Vault: invalid _swapFeeBasisPoints";
    errors[7] = "Vault: invalid _stableSwapFeeBasisPoints";
    errors[8] = "Vault: invalid _marginFeeBasisPoints";
    errors[9] = "Vault: invalid _liquidationFeeUsd";
    errors[10] = "Vault: invalid _fundingInterval";
    errors[11] = "Vault: invalid _fundingRateFactor";
    errors[12] = "Vault: invalid _stableFundingRateFactor";
    errors[13] = "Vault: token not whitelisted";
    errors[14] = "Vault: _token not whitelisted";
    errors[15] = "Vault: invalid tokenAmount";
    errors[16] = "Vault: _token not whitelisted";
    errors[17] = "Vault: invalid tokenAmount";
    errors[18] = "Vault: invalid usdgAmount";
    errors[19] = "Vault: _token not whitelisted";
    errors[20] = "Vault: invalid usdgAmount";
    errors[21] = "Vault: invalid redemptionAmount";
    errors[22] = "Vault: invalid amountOut";
    errors[23] = "Vault: swaps not enabled";
    errors[24] = "Vault: _tokenIn not whitelisted";
    errors[25] = "Vault: _tokenOut not whitelisted";
    errors[26] = "Vault: invalid tokens";
    errors[27] = "Vault: invalid amountIn";
    errors[28] = "Vault: leverage not enabled";
    errors[29] = "29";

    IVault v = IVault(vaultAddress);

    controller.setErrors(v, errors);

//    vp.setIsLeverageEnabled(true);
//    vp.increasePosition(
//      address(0x0), address(0x0), address(0x0), 1, true
//    );

    v.setIsLeverageEnabled(true);
    v.setIsSwapEnabled(true);
    v.setInManagerMode(true);

    require(v.isLeverageEnabled(), "Not enabled");
    require(v.isSwapEnabled(), "Not enabled");
    require(v.inManagerMode(), "Not enabled");

    v.increasePosition(
      address(0x0), address(0x0), address(0x0), 1, true
    );

//    v.setIsLeverageEnabled(true);
    require(v.isLeverageEnabled(), "Not enabled");
//    v.increasePosition(
//      address(0x0), address(0x0), address(0x0), 1, true
//    );
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
