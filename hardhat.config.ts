import { HardhatUserConfig } from "hardhat/config";
import "@matterlabs/hardhat-zksync-solc";
import "@matterlabs/hardhat-zksync-chai-matchers";
// import "@nomicfoundation/hardhat-verify";
import "@matterlabs/hardhat-zksync-verify";
// import "@nomiclabs/hardhat-vyper";
// import "@matterlabs/hardhat-zksync-vyper";
import "@matterlabs/hardhat-zksync-deploy";
// import "@nomicfoundation/hardhat-toolbox";

import "hardhat-preprocessor";
import * as fs from "fs";
import dotenv from "dotenv"

dotenv.config();

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split("="));
}

const config: HardhatUserConfig = {
  zksolc: {
    version: "1.3.10",
    compilerSource: "binary",
    settings: {
      // optional. Ignored for compilerSource "docker". Can be used if compiler is located in a specific folder
      compilerPath: "E:/Exermon/OutSource/Samuel/ZK-GMX/zkx-contract/zksolc-bin-main/windows-amd64/zksolc-windows-amd64-gnu-v1.3.10.exe",
      // libraries: {}, // optional. References to non-inlinable libraries
      // isSystem: false, // optional.  Enables Yul instructions available only for zkSync system contracts and libraries
      // forceEvmla: false, // optional. Falls back to EVM legacy assembly if there is a bug with Yul
      optimizer: {
        enabled: true, // optional. True by default
        mode: '3' // optional. 3 by default, z to optimize bytecode size
      }
    }
  },
  defaultNetwork: "test",
  // zkvyper: {
  //   version: "1.3.10",
  //   compilerSource: "binary",  // binary or docker
  //   settings: {
  //     compilerPath: "zkvyper",  // ignored for compilerSource: "docker"
  //     libraries: {} // optional. References to non-inlinable libraries
  //   }
  // },

  solidity: {
    version: "0.8.14",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    // hardhat: {
    // },
    test: {
      url: "https://testnet.era.zksync.dev", // The testnet RPC URL of zkSync Era network.
      ethNetwork: "goerli", // The Ethereum Web3 RPC URL, or the identifier of the network (e.g. `mainnet` or `goerli`)
      zksync: true,
      // Verification endpoint for Goerli
      verifyURL: 'https://zksync2-testnet-explorer.zksync.dev/contract_verification'
    },
    // test: {
    //   url: process.env["TESTNET_RPC_URL"] as string,
    //   accounts: [process.env["PRIVATE_KEY"] as string],
    //   zksync: true
    // },
    // main: {
    //   url: process.env["MAINNET_RPC_URL"] as string,
    //   accounts: [process.env["PRIVATE_KEY"] as string],
    //   zksync: true
    // }
  },
  // etherscan: {
  //   customChains: [{
  //     network: "test",
  //     chainId: 280,
  //     urls: {
  //       apiURL: "",
  //       browserURL: ""
  //     }
  //   }]
  // },
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          for (const [from, to] of getRemappings()) {
            if (line.includes(from)) {
              line = line.replace(from, to);
              break;
            }
          }
        }
        return line;
      },
    }),
  },
  paths: {
    sources: "./src",
    cache: "./cache_hardhat",
  },
};

export default config;
