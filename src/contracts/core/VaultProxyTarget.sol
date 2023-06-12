pragma solidity ^0.8.0;

import "../multiProxy/MultiProxy.sol";
import "../multiProxy/MultiProxy.sol";
import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../interfaces/IVault.sol";
import "../multiProxy/ProxyTarget.sol";
import "./Vault.sol";

abstract contract VaultProxyTarget is ReentrancyGuard, ProxyTarget {

  constructor(MultiProxy _parent) ProxyTarget(_parent) {}

  function vault() public view returns(IVault) {
    return IVault(address(this));
  }
}
