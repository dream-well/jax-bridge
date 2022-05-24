const { ethers, upgrades } = require("hardhat");

const contracts = ['JaxBscBridge', 'JxnWjxn2Bridge', 'WjaxBscBridge', 'WjaxJaxBridge', 'Wjxn2JxnBridge', 'WjxnBscBridge'];
// const contracts = ['JaxBscBridge'];

// const contracts = ['JxnWjxn2Bridge'];

void async function main() {
  const [owner] = await ethers.getSigners();
  for(let contract of contracts) {
    let Contract = await ethers.getContractFactory(contract);
    let deployed = await Contract.deploy();
    console.log(contract, deployed.address);
    await deployed.deployed();
  }
}();