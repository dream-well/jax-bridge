const { ethers, upgrades } = require("hardhat");

void async function main() {
  const [owner] = await ethers.getSigners();
  console.log(owner.address);
  const JaxBridge = await ethers.getContractFactory("Jxn2BscBridge");
  const jaxBridge = await JaxBridge.deploy();
  console.log("Jxn2BscBridge", jaxBridge.address);
}();