const { ethers, upgrades } = require("hardhat");

void async function main() {
  const [owner] = await ethers.getSigners();
  console.log(owner.address);
  const Test = await ethers.getContractFactory("test");
  const test = await Test.deploy();
  console.log(await test.sign(
    "0x0000000000000000000000000000000000000000",
    "0x387891491a5df45bBFf22dE502B066ec3bA0Cf52",
    0,
    70,
    "fd4aacbf08b1dd6203048b8978fbc7ad153f4abf9ba1b14d6f912a5b473aa7fb",
    "0xdf7ca26a394a08ed647efc749d6e912accab9de4288b499b8327b086553ad74d106e430fb29830579c84dbc3dfd1bddf01429dde1354c1bab8e456a00b333cd21c"
    ));
}();