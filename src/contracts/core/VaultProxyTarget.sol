pragma solidity ^0.8.0;

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../multi-proxy/ProxyTarget.sol";
import "../multi-proxy/MultiProxy.sol";
import "./interfaces/IVault.sol";
import "./Vault.sol";

abstract contract VaultProxyTarget is ReentrancyGuard, ProxyTarget {

  constructor(MultiProxy _parent) ProxyTarget(_parent) {}

  function vault() public view returns(IVault) {
    return IVault(address(this));
  }

}
