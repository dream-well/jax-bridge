const { ethers, upgrades } = require("hardhat");

void async function main() {
  const [owner] = await ethers.getSigners();
  console.log(owner.address);
  const JaxBridge = await ethers.getContractFactory("WjaxEthBridge");
  const jaxBridge = await JaxBridge.deploy();
  console.log("wjaxEth", jaxBridge.address);
}();