pragma solidity ^0.8.0;

import "../multiProxy/MultiProxy.sol";
import "../multiProxy/MultiProxy.sol";
import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../interfaces/IVault.sol";
import "../multiProxy/ProxyTarget.sol";
import "./Vault.sol";
import "./VaultProxyTarget.sol";

contract VaultGetter is VaultProxyTarget, VaultBase {

  constructor(MultiProxy _parent) VaultProxyTarget(_parent) {}


}
