import Web3 from "web3";
import fs from 'fs-extra'
import addresses from './addresses.js';

const {jaxBridgeBsc, jaxBridgePolygon, jaxBridgeEthereum} = addresses;
const {deployerWalletPrivateKey, deployerWalletPublicKey} = fs.readJsonSync("../secrets.json");

const providers = {
    "rinkeby": {
      providers: ['wss://speedy-nodes-nyc.moralis.io/63021305c6423bed5d079c57/eth/rinkeby/ws'],
      testnet: true,
      privateKey: deployerWalletPrivateKey
    },
    "bsctestnet": {
      providers: ['wss://speedy-nodes-nyc.moralis.io/63021305c6423bed5d079c57/bsc/testnet/ws'],
      testnet: true,
      privateKey: deployerWalletPrivateKey
    },
    "polygontestnet": {
      // providers: ['https://bsc-dataseed.binance.org', 'wss://bsc-ws-node.nariox.org:443'],
      providers: [`wss://speedy-nodes-nyc.moralis.io/63021305c6423bed5d079c57/polygon/mumbai/ws`],
      testnet: true,
      privateKey: deployerWalletPrivateKey
    },
    "polygonmainnet": {
      // providers: ['https://bsc-dataseed.binance.org', 'wss://bsc-ws-node.nariox.org:443'],
      providers: [`wss://speedy-nodes-nyc.moralis.io/63021305c6423bed5d079c57/polygon/mainnet/ws`],
      // testnet: true,
      privateKey: deployerWalletPrivateKey
    },
    avalancheTestnet: {
      providers: ['wss://speedy-nodes-nyc.moralis.io/63021305c6423bed5d079c57/avalanche/testnet/ws'],
      testnet: true,
      privateKey: deployerWalletPrivateKey
    },
}

const privateKey = deployerWalletPrivateKey;
const publicKey = deployerWalletPublicKey;

const bridgeABI = fs.readJsonSync("../artifacts/contracts/JaxBridge.sol/JaxBridge.json").abi;

const web3Ethereum = new Web3(providers.rinkeby.providers[0]);
const web3Bsc = new Web3(providers.bsctestnet.providers[0]);
const web3Polygon = new Web3(providers.polygontestnet.providers[0]);


web3Ethereum.eth.accounts.wallet.add(privateKey);
web3Bsc.eth.accounts.wallet.add(privateKey);
web3Polygon.eth.accounts.wallet.add(privateKey);

const bridgeEthereum = new web3Ethereum.eth.Contract(
  bridgeABI,
  jaxBridgeEthereum
);

const bridgeBsc = new web3Bsc.eth.Contract(
  bridgeABI,
  jaxBridgeBsc
);

const bridgePolygon = new web3Polygon.eth.Contract(
  bridgeABI,
  jaxBridgePolygon
);

const bridgeContracts = {
  [await web3Ethereum.eth.getChainId()]: bridgeEthereum,
  [await web3Bsc.eth.getChainId()]: bridgeBsc,
  [await web3Polygon.eth.getChainId()]: bridgePolygon,
}

Object.keys(bridgeContracts).forEach((chainId) => {
  listen_events(bridgeContracts[chainId], chainId);
})

function listen_events(bridgeContract, chainId) {
  bridgeContract.events.Transfer(
    {fromBlock: 0}
  )
  .on('data', async event => {
    console.log('on data');
    const { from, to, destChainId, amount, date, nonce, signature, step } = event.returnValues;
    if(step == '1') {
      return;
    }
    console.log(`
      Processed transfer:
      - srcChain ${chainId}
      - destChain ${destChainId}
      - from ${from} 
      - to ${to} 
      - amount ${amount} tokens
      - date ${date}
      - nonce ${nonce}
      - signature ${signature}
      - txHash (BSC) ${event.transactionHash}
    `);
    let func = "withdraw";
    let args = [from, to, amount, nonce, signature];
    
    let gasAmount;
    const bridgeDest = bridgeContracts[destChainId];
    try {
      gasAmount = await bridgeDest.methods[func](...args).estimateGas({from: publicKey});
    }catch(e) {
      if(e.message.startsWith("Internal JSON-RPC error.")) {
        e = JSON.parse(e.message.substr(24));
      }
      console.log(e.message);
      return;
    }
    console.log("Gas", gasAmount);
    const tx = await bridgeDest.methods[func](...args).send({from: publicKey, gasLimit: gasAmount});
    // console.log(`Transaction hash: ${receipt.transactionHash}`);
    console.log(`
      Processed transfer:
      - from ${from} 
      - to ${to} 
      - amount ${amount} tokens
      - date ${date}
      - nonce ${nonce}
      - signature ${signature}
      - txHash (BSC) ${event.transactionHash}
      - txHash (Polygon) ${tx.transactionHash}
    `);
  })
  .on('changed', changed => console.log(changed))
  .on('error', err => {throw err})
  .on('connected', str => console.log("Connected", chainId));
  
}