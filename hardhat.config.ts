import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
require('@openzeppelin/hardhat-upgrades');
require('dotenv').config()


// require("@nomiclabs/hardhat-etherscan");
require("hardhat-deploy");
require("solidity-coverage");
require("hardhat-gas-reporter");

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
// const REPORT_GAS = process.env.REPORT_GAS || false
const BSCTESTNET_RPC_URL = process.env.RPC_URL_BSC_TEST || "https://"
const BSCSCAN_API_KEY = process.env.BSCSCAN_API_KEY || "Your etherscan API key"
const PRIVATE_KEY = process.env.PK_ACCOUNT_1 || "0x"
const PRIVATE_KEY_PROD = process.env.PK_ACCOUNT_BSC || "0x"

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    bsc_test: {
      url: BSCTESTNET_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      timeout: 600000,
      blockGasLimit: 0x1fffffffffffff,
      throwOnTransactionFailures: true,
      throwOnCallFailures: true,
      allowUnlimitedContractSize: true,
    },
    bsc: {
      url: process.env.RPC_URL_BSC,
      accounts: PRIVATE_KEY_PROD !== undefined ? [PRIVATE_KEY_PROD] : [],
      timeout: 600000,
    },
  },
  etherscan: {
    // npx hardhat verify --network <NETWORK> <CONTRACT_ADDRESS> <CONSTRUCTOR_PARAMETERS>
    apiKey: {
      bsc: BSCSCAN_API_KEY,
      bscTestnet: BSCSCAN_API_KEY,
    },
  },
  solidity: {
    version: '0.8.23',
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  mocha: {
    timeout: 100000000
  },
}

export default config
