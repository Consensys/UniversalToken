// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const {
    nowSeconds,
    advanceTime,
    takeSnapshot,
    revertToSnapshot,
  } = require("../test/utils/time");
const { newSecretHashPair } = require("../test/utils/crypto");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const inOneHour = nowSeconds() + 60 * 60;
const hashLock = newSecretHashPair();

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
  console.log("Account is " + deployer);

  const ERC20LogicMock = await hre.ethers.getContractFactory("ERC20LogicMock");
  
  const ERC20Logic = await hre.ethers.getContractFactory("ERC20Logic");
  const logic = await ERC20Logic.deploy();
  await logic.deployed();
  
  const HoldExtension = await hre.ethers.getContractFactory("HoldExtension");

  const ERC20Extendable = await hre.ethers.getContractFactory("ERC20Extendable");

  console.log("Deploy token test");

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

  console.log("Deploying HoldExtension");
  const holdExtContract = await HoldExtension.deploy();
  await holdExtContract.deployed();

  console.log("Registering HoldExtension on token");
  await erc20.registerExtension(holdExtContract.address);

  const holdableToken = await HoldExtension.attach(erc20.address);
  
  await erc20.mint(accounts[1], "1000");

  console.log("invoking hold");
  await holdableToken.hold(
    web3.utils.randomHex(32),
    accounts[2],
    ZERO_ADDRESS,
    100,
    inOneHour,
    hashLock.hash,
  )
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
