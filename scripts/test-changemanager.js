// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const accounts = await ethers.provider.listAccounts();

  const deployer = accounts[0];

  const ERC20Extendable = await hre.ethers.getContractFactory("ERC20Extendable");
  const erc20 = await ERC20Extendable.attach("0x34498189098A58DB130a1db262Cf7e8212EbB5C0");
  await erc20.deployed();

  console.log("Deployer is " + deployer);
  console.log("Total supply is " + (await erc20.totalSupply()));
  console.log("Is deployer minter? " + (await erc20.isMinter(deployer)));

  console.log("Changing manager");
  await erc20.mint("0x4EeABa74D7f51fe3202D7963EFf61D2e7e166cBa", "1000");

  console.log("ERC20Extendable token contract deployed to:", erc20.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
