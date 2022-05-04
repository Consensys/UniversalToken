const { soliditySha3 } = require("web3-utils");

const ERC20Logic = artifacts.require('./ERC20Logic.sol');

module.exports = async function (deployer, network, accounts) {
    if (network == "test") return; // test maintains own contracts
  
    await deployer.deploy(ERC20Logic);
    console.log('\n   > ERC20Logic deployment: Success -->', ERC20Logic.address);
  
};
