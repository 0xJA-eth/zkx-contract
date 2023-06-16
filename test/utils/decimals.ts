import {ethers} from "ethers";

export function toUsd(value) {
  const normalizedValue = Math.round(value * Math.pow(10, 10));
  return ethers.BigNumber.from(normalizedValue).mul(
    ethers.BigNumber.from(10).pow(20))
}
export const toNormalizedPrice = toUsd

export function toChainlinkPrice(value) {
  return Math.round(value * Math.pow(10, 8))
}

export function newWallet() {
  return ethers.Wallet.createRandom()
}

export function bigNumberify(n) {
  return ethers.BigNumber.from(n)
}

export function expandDecimals(n, decimals) {
  return bigNumberify(n).mul(bigNumberify(10).pow(decimals))
}
