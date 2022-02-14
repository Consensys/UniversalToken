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
  const ERC20Storage = await hre.ethers.getContractFactory("ERC20Storage");
  const ERC20Extendable = await hre.ethers.getContractFactory("ERC20Extendable");

  const logic = await ERC20Logic.deploy();
  await logic.deployed();

  console.log("Deploy token test");
  const erc20 = await ERC20Extendable.deploy(
    "ERC20Extendable",
    "DAU",
    true,
    true,
    deployer,
    1000,
    5000,
    logic.address
  );
  await erc20.deployed();

  console.log("Deployer is " + deployer);
  console.log("Is deployer minter? " + (await erc20.isMinter(deployer)));

  console.log("Deployed to " + erc20.address);

  await erc20.mint(accounts[1], "1000");

  console.log("ERC20Extendable token contract deployed to:", erc20.address);

  console.log("Deploying mock logic");
  const logic2 = await ERC20LogicMock.deploy();
  await logic2.deployed();

  console.log("Testing directly");
  console.log(await logic2.isMock());

  console.log("Performing upgrade on token to use new mock logic");
  await erc20.upgradeTo(logic2.address);
  
  console.log("Attaching to new logic ABI at address: " + logic2.address);
  const test = await ERC20LogicMock.attach(erc20.address);
  
  console.log("Running isMock()");
  const tttt = await test.isMock();

  console.log(tttt);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
