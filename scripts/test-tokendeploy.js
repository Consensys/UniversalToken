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

  const ERC20Logic = await hre.ethers.getContractFactory("ERC20Logic");
  const ERC20Storage = await hre.ethers.getContractFactory("ERC20Storage");
  const ERC20Extendable = await hre.ethers.getContractFactory("ERC20Extendable");

  const logic = await ERC20Logic.deploy();

  console.log("Deploy token test");
  const erc20 = await ERC20Extendable.deploy(
    "ERC20Extendable",
    "DAU",
    true,
    true,
    deployer,
    1000,
    logic.address
  );
  await erc20.deployed();

  console.log("Deployer is " + deployer);
  console.log("Is deployer minter? " + (await erc20.isMinter(deployer)));

  console.log("Deployed to " + erc20.address);

  await erc20.mint(accounts[1], "1000");

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
