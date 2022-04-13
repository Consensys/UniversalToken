// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  const accounts = await ethers.provider.listAccounts();

  const deployer = accounts[0];
  
  const BlockExtension = await hre.ethers.getContractFactory("BlockExtension");

  console.log("Deploying BlockExtension");
  const blockExtContract = await BlockExtension.deploy();
  await blockExtContract.deployed();
  console.log("Deployed BlockExtension at " + blockExtContract.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
