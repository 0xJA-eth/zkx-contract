import { expect } from "chai";
import { Wallet, Provider, Contract } from "zksync-web3";
import * as hre from "hardhat";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import {richWallets} from "./utils/addresses";
import {deployContract, getBlockTime, reportGasUsed} from "./utils/contract";
import {expandDecimals, toChainlinkPrice, toNormalizedPrice, toUsd} from "./utils/decimals";
import {Errors} from "./utils/errors";
import {getBnbConfig, getBtcConfig, getDaiConfig} from "./utils/erc20Configs";
import {ethers, Transaction} from "ethers";
import {PromiseUtils} from "./utils/PromiseUtils";
import {TransactionResponse} from "@ethersproject/abstract-provider";

const provider = Provider.getDefaultProvider();
const [wallet, user0, user1, user2, user3] = richWallets(provider, 5);

const deployer = new Deployer(hre, wallet);

async function initVaultErrors(vault: Contract) {
  const vaultErrorController = await deployContract(deployer, "VaultErrorController", [])
  console.log("gov", await vault.gov());
  let tx = await vault.setErrorController(vaultErrorController.address);

  console.log("errorController", await vault.errorController(), vaultErrorController.address);
  await tx.wait();
  console.log("errorController", await vault.errorController(), vaultErrorController.address);

  tx = await vaultErrorController.setErrors(vault.address, Errors);
  await tx.wait();

  return vaultErrorController
}

async function initVaultUtils(vault) {
  const vaultUtils = await deployContract(deployer, "VaultUtils", [vault.address])
  await vault.setVaultUtils(vaultUtils.address)
  return vaultUtils
}

async function initVault(vault, router, usdg, priceFeed) {
  await vault.initialize(
    router.address, // router
    usdg.address, // usdg
    priceFeed.address, // priceFeed
    toUsd(5), // liquidationFeeUsd
    600, // fundingRateFactor
    600 // stableFundingRateFactor
  )

  const vaultUtils = await initVaultUtils(vault)
  const vaultErrorController = await initVaultErrors(vault)

  return { vault, vaultUtils, vaultErrorController }
}

async function validateVaultBalance(expect, vault, token, offset = 0) {
  const poolAmount = await vault.poolAmounts(token.address)
  const feeReserve = await vault.feeReserves(token.address)
  const balance = await token.balanceOf(vault.address)
  let amount = poolAmount.add(feeReserve)
  expect(balance).gt(0)
  expect(poolAmount.add(feeReserve).add(offset)).eq(balance)
}

describe("Vault.increaseLongPosition", function () {

  let vault: Contract, vaultPosition: Contract, vaultUSDG: Contract
  let vaultPriceFeed: Contract
  let usdg: Contract
  let router: Contract
  let bnb: Contract
  let bnbPriceFeed: Contract
  let btc: Contract
  let btcPriceFeed: Contract
  let dai: Contract
  let daiPriceFeed: Contract
  let distributor0: Contract
  let yieldTracker0: Contract

  let glpManager: Contract
  let glp: Contract

  let data: string
  let tx: TransactionResponse

  beforeEach(async () => {
    bnb = await deployContract(deployer, "Token", [])
    bnbPriceFeed = await deployContract(deployer, "PriceFeed", [])

    btc = await deployContract(deployer, "Token", [])
    btcPriceFeed = await deployContract(deployer, "PriceFeed", [])

    dai = await deployContract(deployer, "Token", [])
    daiPriceFeed = await deployContract(deployer, "PriceFeed", [])

    vault = await deployContract(deployer, "Vault", [])
    const vaultNames = Array.from(Object.keys(vault.interface.functions));

    vaultPosition = await deployContract(deployer, "VaultPosition", [vault.address])
    const vPositionNames = Array.from(Object.keys(vaultPosition.interface.functions)).filter(n => !vaultNames.includes(n));
    console.log("vPositionNames", vPositionNames);
    tx = await vault.registerFunctionImpls(vPositionNames, vaultPosition.address);
    await tx.wait();

    usdg = await deployContract(deployer, "USDG", [vault.address])
    router = await deployContract(deployer, "Router", [vault.address, usdg.address, bnb.address])
    vaultPriceFeed = await deployContract(deployer, "VaultPriceFeed", [])

    const initVaultResult = await initVault(vault, router, usdg, vaultPriceFeed)

    distributor0 = await deployContract(deployer, "TimeDistributor", [])
    yieldTracker0 = await deployContract(deployer, "YieldTracker", [usdg.address])

    await yieldTracker0.setDistributor(distributor0.address)
    await distributor0.setDistribution([yieldTracker0.address], [1000], [bnb.address])

    await bnb.mint(distributor0.address, 5000)
    await usdg.setYieldTrackers([yieldTracker0.address])

    await vaultPriceFeed.setTokenConfig(bnb.address, bnbPriceFeed.address, 8, false)
    await vaultPriceFeed.setTokenConfig(btc.address, btcPriceFeed.address, 8, false)
    await vaultPriceFeed.setTokenConfig(dai.address, daiPriceFeed.address, 8, false)

    glp = await deployContract(deployer, "GLP", [])
    glpManager = await deployContract(deployer, "GlpManager", [vault.address, usdg.address, glp.address, ethers.constants.AddressZero, 24 * 60 * 60])
  })

  it("increasePosition long validations", async () => {

    console.log("daiPriceFeed.setLatestAnswer")
    tx = await daiPriceFeed.setLatestAnswer(toChainlinkPrice(1))
    await tx.wait();
    console.log("vault.setMaxGasPrice")
    tx = await vault.setMaxGasPrice("20000000000") // 20 gwei
    await tx.wait();
    console.log("vault.setTokenConfig")
    tx = await vault.setTokenConfig(...getDaiConfig(dai, daiPriceFeed))
    await tx.wait();

    // await expect(vaultPosition.attach(vault.address).connect(user1)
    //   .increasePosition(user0.address, btc.address, btc.address, 0, true))
    //   .to.be.revertedWith("Vault: invalid msg.sender")
    // await expect(vaultPosition.attach(vault.address).connect(user0)
    //   .increasePosition(user0.address, btc.address, btc.address, 0, true, { gasPrice: "21000000000" }))
    //   .to.be.revertedWith("Vault: maxGasPrice exceeded")

    console.log("vault.setMaxGasPrice")
    tx = await vault.setMaxGasPrice(0)
    await tx.wait();
    console.log("vault.setIsLeverageEnabled")
    tx = await vault.setIsLeverageEnabled(false)
    await tx.wait();

    console.log("vault.increasePosition")
    await expect(vaultPosition.attach(vault.address).connect(user1)
      .increasePosition(user0.address, btc.address, btc.address, 0, true, { gasPrice: "21000000000" }))
      .to.be.revertedWith("Vault: leverage not enabled")

    console.log("vault.setIsLeverageEnabled")
    tx = await vault.setIsLeverageEnabled(true)
    await tx.wait();
    console.log("vault.connect(user0).addRouter(user1.address)")
    tx = await vault.connect(user0).addRouter(user1.address)
    await tx.wait();

    await expect(vaultPosition.attach(vault.address).connect(user1)
      .increasePosition(user0.address, btc.address, bnb.address, 0, true))
      .to.be.revertedWith("Vault: mismatched tokens")
    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, bnb.address, toUsd(1000), true))
      .to.be.revertedWith("Vault: mismatched tokens")
    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, dai.address, dai.address, toUsd(1000), true))
      .to.be.revertedWith("Vault: _collateralToken must not be a stableToken")
    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, toUsd(1000), true))
      .to.be.revertedWith("Vault: _collateralToken not whitelisted")

    tx = await btcPriceFeed.setLatestAnswer(toChainlinkPrice(60000))
    await tx.wait();
    tx = await vault.setTokenConfig(...getBtcConfig(btc, btcPriceFeed))
    await tx.wait();

    tx = await btcPriceFeed.setLatestAnswer(toChainlinkPrice(40000))
    await tx.wait();
    tx = await btcPriceFeed.setLatestAnswer(toChainlinkPrice(50000))
    await tx.wait();

    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, toUsd(1000), true))
      .to.be.revertedWith("Vault: insufficient collateral for fees")
    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, 0, true))
      .to.be.revertedWith("Vault: invalid position.size")

    tx = await btc.mint(user0.address, expandDecimals(1, 8))
    await tx.wait();
    tx = await btc.connect(user0).transfer(vault.address, 2500 - 1)
    await tx.wait();

    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, toUsd(1000), true))
      .to.be.revertedWith("Vault: insufficient collateral for fees")

    tx = await btc.connect(user0).transfer(vault.address, 1)
    await tx.wait();

    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, toUsd(1000), true))
      .to.be.revertedWith("Vault: losses exceed collateral")

    tx = await btcPriceFeed.setLatestAnswer(toChainlinkPrice(40000))
    await tx.wait();
    tx = await btcPriceFeed.setLatestAnswer(toChainlinkPrice(40000))
    await tx.wait();
    tx = await btcPriceFeed.setLatestAnswer(toChainlinkPrice(40000))
    await tx.wait();

    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, toUsd(1000), true))
      .to.be.revertedWith("Vault: fees exceed collateral")

    tx = await btc.connect(user0).transfer(vault.address, 10000)
    await tx.wait();

    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, toUsd(1000), true))
      .to.be.revertedWith("Vault: liquidation fees exceed collateral")

    tx = await btc.connect(user0).transfer(vault.address, 10000)
    await tx.wait();

    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, toUsd(500), true))
      .to.be.revertedWith("Vault: maxLeverage exceeded")

    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, toUsd(8), true))
      .to.be.revertedWith("Vault: _size must be more than _collateral")

    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, toUsd(47), true))
      .to.be.revertedWith("Vault: reserve exceeds pool")
  })

  it("increasePosition long", async () => {
    tx = await btcPriceFeed.setLatestAnswer(toChainlinkPrice(60000))
    await tx.wait()
    tx = await vault.setTokenConfig(...getBtcConfig(btc, btcPriceFeed))
    await tx.wait()

    tx = await btcPriceFeed.setLatestAnswer(toChainlinkPrice(40000))
    await tx.wait()
    tx = await btcPriceFeed.setLatestAnswer(toChainlinkPrice(50000))
    await tx.wait()

    tx = await btc.mint(user0.address, expandDecimals(1, 8))
    await tx.wait()

    tx = await btcPriceFeed.setLatestAnswer(toChainlinkPrice(40000))
    await tx.wait()
    tx = await btcPriceFeed.setLatestAnswer(toChainlinkPrice(41000))
    await tx.wait()
    tx = await btcPriceFeed.setLatestAnswer(toChainlinkPrice(40000))
    await tx.wait()

    tx = await btc.connect(user0).transfer(vault.address, 117500 - 1) // 0.001174 BTC => 47
    await tx.wait()

    console.log("increasePosition1")
    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, toUsd(118), true))
      .to.be.revertedWith("Vault: reserve exceeds pool")

    expect(await vault.feeReserves(btc.address)).eq(0)
    expect(await vault.usdgAmounts(btc.address)).eq(0)
    expect(await vault.poolAmounts(btc.address)).eq(0)

    expect(await glpManager.getAumInUsdg(true)).eq(0)
    expect(await vaultPosition.attach(vault.address).getRedemptionCollateralUsd(btc.address)).eq(0)

    tx = await vault.buyUSDG(btc.address, user1.address)
    await tx.wait()

    expect(await vaultPosition.attach(vault.address).getRedemptionCollateralUsd(btc.address)).eq(toUsd("46.8584"))
    expect(await glpManager.getAumInUsdg(true)).eq("48029860000000000000") // 48.02986
    expect(await glpManager.getAumInUsdg(false)).eq("46858400000000000000") // 46.8584

    expect(await vault.feeReserves(btc.address)).eq(353) // (117500 - 1) * 0.3% => 353
    expect(await vault.usdgAmounts(btc.address)).eq("46858400000000000000") // (117500 - 1 - 353) * 40000
    expect(await vault.poolAmounts(btc.address)).eq(117500 - 1 - 353)

    tx = await btc.connect(user0).transfer(vault.address, 117500 - 1)
    await tx.wait()

    console.log("increasePosition2")
    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, toUsd(200), true))
      .to.be.revertedWith("Vault: reserve exceeds pool")

    // data = vaultPosition.interface.encodeFunctionData("increasePosition",
    //   [user0.address, btc.address, btc.address, toUsd(200), true]);
    // await expect(vault.connect(user0).fallback({data, gasPrice: "0x10000000"}))
    //   .to.be.revertedWith("Vault: reserve exceeds pool")

    tx = await vault.buyUSDG(btc.address, user1.address)
    await tx.wait()

    expect(await vaultPosition.attach(vault.address).getRedemptionCollateralUsd(btc.address)).eq(toUsd("93.7168"))
    expect(await glpManager.getAumInUsdg(true)).eq("96059720000000000000") // 96.05972
    expect(await glpManager.getAumInUsdg(false)).eq("93716800000000000000") // 93.7168

    expect(await vault.feeReserves(btc.address)).eq(353 * 2) // (117500 - 1) * 0.3% * 2
    expect(await vault.usdgAmounts(btc.address)).eq("93716800000000000000") // (117500 - 1 - 353) * 40000 * 2
    expect(await vault.poolAmounts(btc.address)).eq((117500 - 1 - 353) * 2)

    console.log("increasePosition3")
    await expect(vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, toUsd(47), true))
      .to.be.revertedWith("Vault: insufficient collateral for fees")

    tx = await btc.connect(user0).transfer(vault.address, 22500)
    await tx.wait()

    expect(await vault.reservedAmounts(btc.address)).eq(0)
    expect(await vault.guaranteedUsd(btc.address)).eq(0)

    let position = await vaultPosition.attach(vault.address)
      .getPosition(user0.address, btc.address, btc.address, true)
    expect(position[0]).eq(0) // size
    expect(position[1]).eq(0) // collateral
    expect(position[2]).eq(0) // averagePrice
    expect(position[3]).eq(0) // entryFundingRate
    expect(position[4]).eq(0) // reserveAmount
    expect(position[5]).eq(0) // realisedPnl
    expect(position[6]).eq(true) // hasProfit
    expect(position[7]).eq(0) // lastIncreasedTime

    console.log("increasePosition4 Success")
    tx = await vaultPosition.attach(vault.address).connect(user0)
      .increasePosition(user0.address, btc.address, btc.address, toUsd(47), true)

    // const blockTime = await getBlockTime(provider)
    // console.log("blockTime", blockTime);

    await reportGasUsed(provider, tx, "increasePosition gas used")

    expect(await vault.poolAmounts(btc.address)).eq(256792 - 114)
    expect(await vault.reservedAmounts(btc.address)).eq(117500)
    expect(await vault.guaranteedUsd(btc.address)).eq(toUsd(38.047))
    expect(await vaultPosition.attach(vault.address).getRedemptionCollateralUsd(btc.address)).eq(toUsd(92.79))
    expect(await glpManager.getAumInUsdg(true)).eq("95109980000000000000") // 95.10998
    expect(await glpManager.getAumInUsdg(false)).eq("93718200000000000000") // 93.7182

    position = await vaultPosition.attach(vault.address)
      .getPosition(user0.address, btc.address, btc.address, true)
    console.log("position", position.map(p => p?.toString()));
    expect(position[0]).eq(toUsd(47)) // size
    expect(position[1]).eq(toUsd(8.953)) // collateral, 0.000225 BTC => 9, 9 - 0.047 => 8.953
    expect(position[2]).eq(toNormalizedPrice(41000)) // averagePrice
    expect(position[3]).eq(0) // entryFundingRate
    expect(position[4]).eq(117500) // reserveAmount
    expect(position[5]).eq(0) // realisedPnl
    expect(position[6]).eq(true) // hasProfit
    // expect(position[7]).eq(blockTime) // lastIncreasedTime

    expect(await vault.feeReserves(btc.address)).eq(353 * 2 + 114) // fee is 0.047 USD => 0.00000114 BTC
    expect(await vault.usdgAmounts(btc.address)).eq("93716800000000000000") // (117500 - 1 - 353) * 40000 * 2
    expect(await vault.poolAmounts(btc.address)).eq((117500 - 1 - 353) * 2 + 22500 - 114)

    expect(await vault.globalShortSizes(btc.address)).eq(0)
    expect(await vault.globalShortAveragePrices(btc.address)).eq(0)

    await validateVaultBalance(expect, vault, btc)
  })

})
