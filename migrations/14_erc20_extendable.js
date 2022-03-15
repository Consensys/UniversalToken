const { soliditySha3 } = require("web3-utils");

const ERC20Logic = artifacts.require('./ERC20Logic.sol');

const ERC20Extendable = artifacts.require('./ERC20Logic.sol');

const tokenName = "ERC20Extendable";
const tokenSymbol = "DAU";
const allowMint = true;
const allowBurn = true;
const initialSupply = 100;
const maxSupply = -1;
const owner = '0xb5747835141b46f7C472393B31F8F5A57F74A44f';

module.exports = async function (deployer, network, accounts) {
  if (network == "test") return; // test maintains own contracts
  
  const logic = await ERC20Logic.deployed();

  await deployer.deploy(ERC20Extendable, 
    tokenName, tokenSymbol, 
    allowMint, allowBurn, 
    owner, initialSupply, 
    maxSupply, logic.address
  );
  console.log('\n   > ERC20Extendable deployment: Success -->', ERC20Extendable.address);
};
