import {Deployer} from "@matterlabs/hardhat-zksync-deploy";
import {Contract, Provider} from "zksync-web3";

export async function deployContract(deployer: Deployer, name: string, args: any[]): Promise<Contract> {
  const artifact = await deployer.loadArtifact(name);
  return await deployer.deploy(artifact, args);
}

export async function reportGasUsed(provider: Provider, tx, label) {
  const { gasUsed } = await provider.getTransactionReceipt(tx.hash)
  console.info(label, gasUsed.toString())
  return gasUsed
}

export async function getBlockTime(provider) {
  const blockNumber = await provider.getBlockNumber()
  const block = await provider.getBlock(blockNumber)
  return block.timestamp
}
