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



  console.log("Deploy token test");

  const ERC20Extendable = await hre.ethers.getContractFactory("ERC20");
  const erc20 = await ERC20Extendable.deploy(
    "TokenName",   //token name
    "DAU",         //token symbol
    true,          //allow minting
    true,          //allow burning
    deployer,      //token owner address
    1000,          //initial supply to give to owner address
    5000,          //max supply
    logic.address  //address of token logic contract
  );
  await erc20.deployed();

  console.log("Deployer is " + deployer);
  console.log("Total supply is " + (await erc20.totalSupply()));
  console.log("Is deployer minter? " + (await erc20.isMinter(deployer)));

  console.log("Deployed to " + erc20.address);
  
  console.log("Doing pre-extension mint");
  await erc20.mint(accounts[1], "1000");

  console.log("ERC20Extendable token contract deployed to:", erc20.address);

  console.log("Deploying PauseableExtension");
  const pauseExtContract = await PauseExtension.deploy();
  await pauseExtContract.deployed();

  console.log("Registering PauseExtension on token");
  await erc20.registerExtension(pauseExtContract.address);

  const pauseToken = await PauseExtension.attach(erc20.address);
  
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
