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

contract BuyUSDGTest is Test {

  address payable vaultAddress;

  function setUp() public {
    Vault vault = new Vault();
    new VaultPosition(vault); new VaultUSDG(vault);

    vaultAddress = payable(address(vault));
  }

  function testRun() public {
    VaultErrorController controller = new VaultErrorController();
    Vault(vaultAddress).setErrorController(address(controller));

    string[] memory errors = new string[](26);
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
//    errors.push"Vault: invalid tokens";
//    errors.push"Vault: invalid amountIn";
//    errors.push"Vault: leverage not enabled";
//    errors.push"Vault: insufficient collateral for fees";
//    errors.push"Vault: invalid position.size";
//    errors.push"Vault: empty position";
//    errors.push"Vault: position size exceeded";
//    errors.push"Vault: position collateral exceeded";
//    errors.push"Vault: invalid liquidator";
//    errors.push"Vault: empty position";
//    errors.push"Vault: position cannot be liquidated";
//    errors.push"Vault: invalid position";
//    errors.push"Vault: invalid _averagePrice";
//    errors.push"Vault: collateral should be withdrawn";
//    errors.push"Vault: _size must be more than _collateral";
//    errors.push"Vault: invalid msg.sender";
//    errors.push"Vault: mismatched tokens";
//    errors.push"Vault: _collateralToken not whitelisted";
//    errors.push"Vault: _collateralToken must not be a stableToken";
//    errors.push"Vault: _collateralToken not whitelisted";
//    errors.push"Vault: _collateralToken must be a stableToken";
//    errors.push"Vault: _indexToken must not be a stableToken";
//    errors.push"Vault: _indexToken not shortable";
//    errors.push"Vault: invalid increase";
//    errors.push"Vault: reserve exceeds pool";
//    errors.push"Vault: max USDG exceeded";
//    errors.push"Vault: reserve exceeds pool";
//    errors.push"Vault: forbidden";
//    errors.push"Vault: forbidden";
//    errors.push"Vault: maxGasPrice exceeded";

    controller.setErrors(IVault(vaultAddress), errors);
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
