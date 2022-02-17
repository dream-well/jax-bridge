const { ethers, upgrades } = require("hardhat");

void async function main() {
  const JaxBridge = await ethers.getContractFactory("JaxBridge");
  const jaxBridge = await JaxBridge.deploy();
  console.log(jaxBridge.address);
}();