// import hre from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import * as ethers from "ethers";
import { Wallet, utils } from "zksync-web3";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";

import dotenv from "dotenv"

dotenv.config();

export default async function (hre: HardhatRuntimeEnvironment) {
  // Initialize the wallet.
  const wallet = new Wallet(process.env["PRIVATE_KEY"] as string);

  // Create deployer object and load the artifact of the contract you want to deploy.
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact("Vault");

  // Estimate contract deployment fee
  const deploymentFee = await deployer.estimateDeployFee(artifact, []);

  // Deploy this contract. The returned object will be of a `Contract` type, similarly to ones in `ethers`.
  // `greeting` is an argument for contract constructor.
  const parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const contract = await deployer.deploy(artifact, []);

  //obtain the Constructor Arguments
  console.log("Deployed: ", contract);

  // Show the contract info.
  console.log(`${artifact.contractName} was deployed to ${contract.address}`);

  const verificationId = await hre.run("verify:verify", {
    address: contract.address,
    contract: "src/contracts/core/Vault.sol:Vault",
    // contract: "src/gmx-contracts/peripherals/Reader.sol:Reader",
    constructorArguments: []
  });

  console.log("verificationId",  verificationId);

}

// async function main() {
//
//   // const vault = await ethers.deployContract("Reader", []);
//   //
//   // await vault.waitForDeployment();
//   //
//   // console.log("Deploy: ", vault, vault.target);
// }
//
// // We recommend this pattern to be able to use async/await everywhere
// // and properly handle errors.
// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });
