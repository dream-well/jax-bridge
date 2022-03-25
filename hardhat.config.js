require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');
require("@nomiclabs/hardhat-etherscan");
require('hardhat-abi-exporter');
require('hardhat-contract-sizer');


const { deployerWalletPrivateKey } = require('./secrets.json');
const { bscscanAPIkey, polygonscanAPIkey, avaAPIkey, etherscan, alchemyAPIkeyRinkeby } = require('./secrets.json');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.11",
    settings: {
      optimizer: {
        enabled: true,
        runs: 20
      }
    }
  },
  defaultNetwork: "bsctestnet",
  hardhat: {
    loggingEnabled: true,
    mining: {
      auto: false,
      interval: 10
    },
    accounts: {
      accountsBalance: "100000000000000000000000"
    }
  },
  networks: {
    ethmainnet: {
      url: "https://mainnet.infura.io/v3/aedc2f89691644c5ad87877903d280b8",
      accounts: [deployerWalletPrivateKey],
    },
    rinkeby: {
      url: alchemyAPIkeyRinkeby,
      accounts: [deployerWalletPrivateKey],
      gas: 10000000
    },
    bsctestnet: {
      url: "https://speedy-nodes-nyc.moralis.io/cb02b6b8ff2cdd26f1db08a4/bsc/testnet",
      chainId: 97,
      accounts: [deployerWalletPrivateKey],
      
    },
    bscmainnet: {
      url: `https://bsc-dataseed1.binance.org/`,
      accounts: [deployerWalletPrivateKey],
    },
    polygonmainnet: {
      url: `https://rpc-mainnet.maticvigil.com/`,
      accounts: [deployerWalletPrivateKey],
    },
    polygontestnet: {
      url: `https://rpc-mumbai.maticvigil.com/`,
      accounts: [deployerWalletPrivateKey],
    },
    avalancheTestnet: {
      url: 'https://api.avax-test.network/ext/bc/C/rpc',
      gasPrice: 225000000000,
      //gas: 10000000,
      chainId: 43113,
      accounts: [deployerWalletPrivateKey],
    },
    avalancheMainnet: {
      url: 'https://api.avax.network/ext/bc/C/rpc',
      gasPrice: 225000000000,
      chainId: 43114,
      accounts: [deployerWalletPrivateKey]
    }
  },
  etherscan: {
    apiKey: bscscanAPIkey
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  chai: {
    enableTimeouts: false,
    timeout: 200000,
    before_timeout: 120000 // Here is 2min but can be whatever timeout is suitable for you.
  },
  mocha: {
    enableTimeouts: false,
    timeout: 200000,
    before_timeout: 120000 // Here is 2min but can be whatever timeout is suitable for you.
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true
  },
  // abiExporter: {
  //   runOnCompile: true,
  //   clear: true,
  //   flat: true,
  //   spacing: 2,
  //   pretty: true,
  // }
};