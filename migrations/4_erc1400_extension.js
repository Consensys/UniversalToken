const Extension = artifacts.require('./ERC1400TokensValidator.sol');

module.exports = async function (deployer, network, accounts) {
  if (network == "test") return; // test maintains own contracts
  
  await deployer.deploy(Extension);
  const extension = await Extension.deployed();
  console.log('\n   > Extension deployment: Success -->', extension.address);
};
