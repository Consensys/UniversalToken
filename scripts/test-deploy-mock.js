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

  const ERC20LogicMock = await hre.ethers.getContractFactory("ERC20LogicMock");
  
  const ERC20Logic = await hre.ethers.getContractFactory("ERC20Logic");
  const logic = await ERC20Logic.deploy();
  await logic.deployed();
  
  const PauseExtension = await hre.ethers.getContractFactory("PauseExtension");

  const ERC20Extendable = await hre.ethers.getContractFactory("ERC20");
  const erc20 = await ERC20Extendable.attach("0x7DB654D584B62f1047fD317b3d6faF546CBD8898");

  const pauseToken = await PauseExtension.attach("0x7DB654D584B62f1047fD317b3d6faF546CBD8898");

  console.log("Am I a pauser?" + (await pauseToken.isPauser(deployer)));

  console.log("Is token a pauser?" + (await pauseToken.isPauser(erc20.address)));
  
  console.log("Doing pause()");
  await pauseToken.pause();
  console.log("Checking isPaused()");
  console.log(await pauseToken.isPaused());
  console.log("Doing unpause()");
  await pauseToken.unpause();
  console.log("Checking isPaused()");
  console.log(await pauseToken.isPaused());
  
  console.log("Doing post extension mint");
  await erc20.mint(accounts[1], "1000");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
