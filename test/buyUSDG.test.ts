// import { expect } from "chai";
// import { Wallet, Provider, Contract } from "zksync-web3";
// import * as hre from "hardhat";
// import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
// import {richWallets} from "./utils/addresses";
// import {deployContract, reportGasUsed} from "./utils/contract";
// import {expandDecimals, toChainlinkPrice, toUsd} from "./utils/decimals";
// import {Errors} from "./utils/errors";
// import {getBnbConfig, getBtcConfig, getDaiConfig} from "./utils/erc20Configs";
// import {ethers, Transaction} from "ethers";
// import {PromiseUtils} from "./utils/PromiseUtils";
// import {TransactionResponse} from "@ethersproject/abstract-provider";
//
// const provider = Provider.getDefaultProvider();
// const [wallet, user0, user1, user2, user3] = richWallets(provider, 5);
//
// const deployer = new Deployer(hre, wallet);
//
// async function initVaultErrors(vault: Contract) {
//   const vaultErrorController = await deployContract(deployer, "VaultErrorController", [])
//   console.log("gov", await vault.gov());
//   let tx = await vault.setErrorController(vaultErrorController.address);
//
//   console.log("errorController", await vault.errorController(), vaultErrorController.address);
//   await tx.wait();
//   // console.log("waiting...");
//   // await PromiseUtils.wait(1500);
//   console.log("errorController", await vault.errorController(), vaultErrorController.address);
//
//   tx = await vaultErrorController.setErrors(vault.address, Errors);
//   await tx.wait();
//
//   return vaultErrorController
// }
//
// async function initVaultUtils(vault) {
//   const vaultUtils = await deployContract(deployer, "VaultUtils", [vault.address])
//   await vault.setVaultUtils(vaultUtils.address)
//   return vaultUtils
// }
//
// async function initVault(vault, router, usdg, priceFeed) {
//   await vault.initialize(
//     router.address, // router
//     usdg.address, // usdg
//     priceFeed.address, // priceFeed
//     toUsd(5), // liquidationFeeUsd
//     600, // fundingRateFactor
//     600 // stableFundingRateFactor
//   )
//
//   const vaultUtils = await initVaultUtils(vault)
//   const vaultErrorController = await initVaultErrors(vault)
//
//   return { vault, vaultUtils, vaultErrorController }
// }
//
// async function validateVaultBalance(expect, vault, token, offset = 0) {
//   const poolAmount = await vault.poolAmounts(token.address)
//   const feeReserve = await vault.feeReserves(token.address)
//   const balance = await token.balanceOf(vault.address)
//   let amount = poolAmount.add(feeReserve)
//   expect(balance).gt(0)
//   expect(poolAmount.add(feeReserve).add(offset)).eq(balance)
// }
//
// describe("Vault.buyUSDG", function () {
//
//   let vault: Contract, vaultPosition: Contract, vaultUSDG: Contract
//   let vaultPriceFeed: Contract
//   let usdg: Contract
//   let router: Contract
//   let bnb: Contract
//   let bnbPriceFeed: Contract
//   let btc: Contract
//   let btcPriceFeed: Contract
//   let dai: Contract
//   let daiPriceFeed: Contract
//   let distributor0: Contract
//   let yieldTracker0: Contract
//
//   let glpManager: Contract
//   let glp: Contract
//
//   let data: string
//   let tx: TransactionResponse
//
//   beforeEach(async () => {
//     bnb = await deployContract(deployer, "Token", [])
//     bnbPriceFeed = await deployContract(deployer, "PriceFeed", [])
//
//     btc = await deployContract(deployer, "Token", [])
//     btcPriceFeed = await deployContract(deployer, "PriceFeed", [])
//
//     dai = await deployContract(deployer, "Token", [])
//     daiPriceFeed = await deployContract(deployer, "PriceFeed", [])
//
//     vault = await deployContract(deployer, "Vault", [])
//     const vaultNames = Array.from(Object.keys(vault.interface.functions));
//
//     vaultPosition = await deployContract(deployer, "VaultPosition", [vault.address])
//     const vPositionNames = Array.from(Object.keys(vaultPosition.interface.functions)).filter(n => !vaultNames.includes(n));
//     console.log("vPositionNames", vPositionNames);
//     tx = await vaultPosition.registerFunctionImpls(vPositionNames)
//     await tx.wait();
//
//     // vaultUSDG = await deployContract(deployer, "VaultUSDG", [vault.address])
//     // const vUSDGNames = Array.from(Object.keys(vaultUSDG.interface.functions)).filter(n => !vaultNames.includes(n));
//     // console.log("vUSDGNames", vUSDGNames);
//     // // tx = await vaultUSDG.registerFunctionImpls(vUSDGNames)
//     // await tx.wait();
//
//     usdg = await deployContract(deployer, "USDG", [vault.address])
//     router = await deployContract(deployer, "Router", [vault.address, usdg.address, bnb.address])
//     vaultPriceFeed = await deployContract(deployer, "VaultPriceFeed", [])
//
//     await initVault(vault, router, usdg, vaultPriceFeed)
//
//     distributor0 = await deployContract(deployer, "TimeDistributor", [])
//     yieldTracker0 = await deployContract(deployer, "YieldTracker", [usdg.address])
//
//     await yieldTracker0.setDistributor(distributor0.address)
//     await distributor0.setDistribution([yieldTracker0.address], [1000], [bnb.address])
//
//     await bnb.mint(distributor0.address, 5000)
//     await usdg.setYieldTrackers([yieldTracker0.address])
//
//     await vaultPriceFeed.setTokenConfig(bnb.address, bnbPriceFeed.address, 8, false)
//     await vaultPriceFeed.setTokenConfig(btc.address, btcPriceFeed.address, 8, false)
//     await vaultPriceFeed.setTokenConfig(dai.address, daiPriceFeed.address, 8, false)
//
//     glp = await deployContract(deployer, "GLP", [])
//     glpManager = await deployContract(deployer, "GlpManager", [
//       vault.address, usdg.address, glp.address,
//       ethers.constants.AddressZero, 24 * 60 * 60
//     ])
//   })
//
//   it("buyUSDG", async () => {
//     // data = vaultUSDG.interface.encodeFunctionData("buyUSDG", [bnb.address, wallet.address]); // 合约B的函数a的调用数据
//     // console.log("data", data);
//     // await expect(vault.fallback({data, gasPrice: "0x10000000"}))
//     //   .to.be.revertedWith("Vault: _token not whitelisted")
//
//     console.log("errors", await vault.errors(16));
//
//     await expect(vault.buyUSDG(bnb.address, wallet.address))
//       .to.be.revertedWith("Vault: _token not whitelisted")
//
//     data = vault.interface.encodeFunctionData("buyUSDG", [bnb.address, user1.address]); // 合约B的函数a的调用数据
//     console.log("data", data);
//     await expect(vault.connect(user0).fallback({data, gasPrice: "0x10000000"}))
//       .to.be.revertedWith("Vault: _token not whitelisted")
//
//     // await expect(vault.connect(user0).buyUSDG(bnb.address, user1.address))
//     //   .to.be.revertedWith("Vault: _token not whitelisted")
//
//     tx = await bnbPriceFeed.setLatestAnswer(toChainlinkPrice(300), {gasPrice: "10000000000"})
//     await tx.wait();
//     console.log("latestRound, latestAnswer",
//       (await bnbPriceFeed.latestRound()).toString(),
//       (await bnbPriceFeed.latestAnswer()).toString());
//
//     tx = await vault.setTokenConfig(...getBnbConfig(bnb, bnbPriceFeed), {gasPrice: "10000000000"})
//     console.log("whitelistedTokens bnb", await vault.whitelistedTokens(bnb.address));
//
//     const res = await tx.wait();
//
//     console.log("tran res", res);
//     console.log("whitelistedTokens bnb", await vault.whitelistedTokens(bnb.address));
//
//     data = vault.interface.encodeFunctionData("buyUSDG", [bnb.address, user1.address]); // 合约B的函数a的调用数据
//     console.log("data", data);
//     await expect(vault.connect(user0).fallback({data, gasPrice: "0x10000000"}))
//       .to.be.revertedWith("Vault: invalid tokenAmount")
//
//     // await expect(vault.connect(user0).buyUSDG(bnb.address, user1.address))
//     //   .to.be.revertedWith("Vault: invalid tokenAmount")
//
//     expect(await usdg.balanceOf(user0.address)).eq(0)
//     expect(await usdg.balanceOf(user1.address)).eq(0)
//     expect(await vault.feeReserves(bnb.address)).eq(0)
//     expect(await vault.usdgAmounts(bnb.address)).eq(0)
//     expect(await vault.poolAmounts(bnb.address)).eq(0)
//
//     console.log("bnb.mint(user0.address, 100)");
//     tx = await bnb.mint(user0.address, 100, {gasPrice: "10000000000"})
//     await tx.wait();
//
//     console.log("bnb.connect(user0).transfer(vault.address, 100)");
//     tx = await bnb.connect(user0).transfer(vault.address, 100, {gasPrice: "10000000000"})
//     await tx.wait();
//     // const tx = await vault.connect(user0).buyUSDG(bnb.address, user1.address, { gasPrice: "10000000000" })
//
//     data = vault.interface.encodeFunctionData("buyUSDG", [bnb.address, user1.address]); // 合约B的函数a的调用数据
//     console.log("data", data);
//     tx = await vault.connect(user0).fallback({data, gasPrice: "0x1000000000"})
//     await tx.wait();
//
//     await reportGasUsed(provider, tx, "buyUSDG gas used")
//
//     console.log("usdg.balanceOf(user0.address)", (await usdg.balanceOf(user0.address)).toString())
//     console.log("usdg.balanceOf(user1.address)", (await usdg.balanceOf(user1.address)).toString())
//
//     expect(await usdg.balanceOf(user0.address)).eq(0)
//     expect(await usdg.balanceOf(user1.address)).eq(29700)
//     expect(await vault.feeReserves(bnb.address)).eq(1)
//     expect(await vault.usdgAmounts(bnb.address)).eq(29700)
//     expect(await vault.poolAmounts(bnb.address)).eq(100 - 1)
//
//     await validateVaultBalance(expect, vault, bnb);
//
//     expect(await glpManager.getAumInUsdg(true)).eq(29700)
//   })
//
//   // it("buyUSDG allows gov to mint", async () => {
//   //   await vault.setInManagerMode(true)
//   //   await expect(vault.buyUSDG(bnb.address, wallet.address))
//   //     .to.be.revertedWith("Vault: forbidden")
//   //
//   //   await bnbPriceFeed.setLatestAnswer(toChainlinkPrice(300))
//   //   await vault.setTokenConfig(...getBnbConfig(bnb, bnbPriceFeed))
//   //
//   //   await bnb.mint(wallet.address, 100)
//   //   await bnb.transfer(vault.address, 100)
//   //
//   //   expect(await usdg.balanceOf(wallet.address)).eq(0)
//   //   expect(await vault.feeReserves(bnb.address)).eq(0)
//   //   expect(await vault.usdgAmounts(bnb.address)).eq(0)
//   //   expect(await vault.poolAmounts(bnb.address)).eq(0)
//   //
//   //   await expect(vault.connect(user0).buyUSDG(bnb.address, wallet.address))
//   //     .to.be.revertedWith("Vault: forbidden")
//   //
//   //   await vault.setManager(user0.address, true)
//   //   await vault.connect(user0).buyUSDG(bnb.address, wallet.address)
//   //
//   //   expect(await usdg.balanceOf(wallet.address)).eq(29700)
//   //   expect(await vault.feeReserves(bnb.address)).eq(1)
//   //   expect(await vault.usdgAmounts(bnb.address)).eq(29700)
//   //   expect(await vault.poolAmounts(bnb.address)).eq(100 - 1)
//   //
//   //   await validateVaultBalance(expect, vault, bnb)
//   // })
//   //
//   // it("buyUSDG uses min price", async () => {
//   //   await expect(vault.connect(user0).buyUSDG(bnb.address, user1.address))
//   //     .to.be.revertedWith("Vault: _token not whitelisted")
//   //
//   //   await bnbPriceFeed.setLatestAnswer(toChainlinkPrice(300))
//   //   await bnbPriceFeed.setLatestAnswer(toChainlinkPrice(200))
//   //   await bnbPriceFeed.setLatestAnswer(toChainlinkPrice(250))
//   //
//   //   await vault.setTokenConfig(...getBnbConfig(bnb, bnbPriceFeed))
//   //
//   //   expect(await usdg.balanceOf(user0.address)).eq(0)
//   //   expect(await usdg.balanceOf(user1.address)).eq(0)
//   //   expect(await vault.feeReserves(bnb.address)).eq(0)
//   //   expect(await vault.usdgAmounts(bnb.address)).eq(0)
//   //   expect(await vault.poolAmounts(bnb.address)).eq(0)
//   //   await bnb.mint(user0.address, 100)
//   //   await bnb.connect(user0).transfer(vault.address, 100)
//   //   await vault.connect(user0).buyUSDG(bnb.address, user1.address)
//   //   expect(await usdg.balanceOf(user0.address)).eq(0)
//   //   expect(await usdg.balanceOf(user1.address)).eq(19800)
//   //   expect(await vault.feeReserves(bnb.address)).eq(1)
//   //   expect(await vault.usdgAmounts(bnb.address)).eq(19800)
//   //   expect(await vault.poolAmounts(bnb.address)).eq(100 - 1)
//   //
//   //   await validateVaultBalance(expect, vault, bnb)
//   // })
//   //
//   // it("buyUSDG updates fees", async () => {
//   //   await expect(vault.connect(user0).buyUSDG(bnb.address, user1.address))
//   //     .to.be.revertedWith("Vault: _token not whitelisted")
//   //
//   //   await bnbPriceFeed.setLatestAnswer(toChainlinkPrice(300))
//   //   await vault.setTokenConfig(...getBnbConfig(bnb, bnbPriceFeed))
//   //
//   //   expect(await usdg.balanceOf(user0.address)).eq(0)
//   //   expect(await usdg.balanceOf(user1.address)).eq(0)
//   //   expect(await vault.feeReserves(bnb.address)).eq(0)
//   //   expect(await vault.usdgAmounts(bnb.address)).eq(0)
//   //   expect(await vault.poolAmounts(bnb.address)).eq(0)
//   //   await bnb.mint(user0.address, 10000)
//   //   await bnb.connect(user0).transfer(vault.address, 10000)
//   //   await vault.connect(user0).buyUSDG(bnb.address, user1.address)
//   //   expect(await usdg.balanceOf(user0.address)).eq(0)
//   //   expect(await usdg.balanceOf(user1.address)).eq(9970 * 300)
//   //   expect(await vault.feeReserves(bnb.address)).eq(30)
//   //   expect(await vault.usdgAmounts(bnb.address)).eq(9970 * 300)
//   //   expect(await vault.poolAmounts(bnb.address)).eq(10000 - 30)
//   //
//   //   await validateVaultBalance(expect, vault, bnb)
//   // })
//   //
//   // it("buyUSDG uses mintBurnFeeBasisPoints", async () => {
//   //   await daiPriceFeed.setLatestAnswer(toChainlinkPrice(1))
//   //   await vault.setTokenConfig(...getDaiConfig(dai, daiPriceFeed))
//   //
//   //   await vault.setFees(
//   //     50, // _taxBasisPoints
//   //     10, // _stableTaxBasisPoints
//   //     4, // _mintBurnFeeBasisPoints
//   //     30, // _swapFeeBasisPoints
//   //     4, // _stableSwapFeeBasisPoints
//   //     10, // _marginFeeBasisPoints
//   //     toUsd(5), // _liquidationFeeUsd
//   //     0, // _minProfitTime
//   //     false // _hasDynamicFees
//   //   )
//   //
//   //   expect(await usdg.balanceOf(user0.address)).eq(0)
//   //   expect(await usdg.balanceOf(user1.address)).eq(0)
//   //   expect(await vault.feeReserves(bnb.address)).eq(0)
//   //   expect(await vault.usdgAmounts(bnb.address)).eq(0)
//   //   expect(await vault.poolAmounts(bnb.address)).eq(0)
//   //   await dai.mint(user0.address, expandDecimals(10000, 18))
//   //   await dai.connect(user0).transfer(vault.address, expandDecimals(10000, 18))
//   //   await vault.connect(user0).buyUSDG(dai.address, user1.address)
//   //   expect(await usdg.balanceOf(user0.address)).eq(0)
//   //   expect(await usdg.balanceOf(user1.address)).eq(expandDecimals(10000 - 4, 18))
//   //   expect(await vault.feeReserves(dai.address)).eq(expandDecimals(4, 18))
//   //   expect(await vault.usdgAmounts(dai.address)).eq(expandDecimals(10000 - 4, 18))
//   //   expect(await vault.poolAmounts(dai.address)).eq(expandDecimals(10000 - 4, 18))
//   // })
//   //
//   // it("buyUSDG adjusts for decimals", async () => {
//   //   await btcPriceFeed.setLatestAnswer(toChainlinkPrice(60000))
//   //   await vault.setTokenConfig(...getBtcConfig(btc, btcPriceFeed))
//   //
//   //   await expect(vault.connect(user0).buyUSDG(btc.address, user1.address))
//   //     .to.be.revertedWith("Vault: invalid tokenAmount")
//   //
//   //   expect(await usdg.balanceOf(user0.address)).eq(0)
//   //   expect(await usdg.balanceOf(user1.address)).eq(0)
//   //   expect(await vault.feeReserves(btc.address)).eq(0)
//   //   expect(await vault.usdgAmounts(bnb.address)).eq(0)
//   //   expect(await vault.poolAmounts(bnb.address)).eq(0)
//   //   await btc.mint(user0.address, expandDecimals(1, 8))
//   //   await btc.connect(user0).transfer(vault.address, expandDecimals(1, 8))
//   //   await vault.connect(user0).buyUSDG(btc.address, user1.address)
//   //   expect(await usdg.balanceOf(user0.address)).eq(0)
//   //   expect(await vault.feeReserves(btc.address)).eq(300000)
//   //   expect(await usdg.balanceOf(user1.address)).eq(expandDecimals(60000, 18).sub(expandDecimals(180, 18))) // 0.3% of 60,000 => 180
//   //   expect(await vault.usdgAmounts(btc.address)).eq(expandDecimals(60000, 18).sub(expandDecimals(180, 18)))
//   //   expect(await vault.poolAmounts(btc.address)).eq(expandDecimals(1, 8).sub(300000))
//   //
//   //   await validateVaultBalance(expect, vault, btc)
//   // })
// })
