const { soliditySha3 } = require("web3-utils");

const BatchIssuer = artifacts.require('./BatchIssuer.sol');

const ERC1820Registry = artifacts.require('ERC1820Registry');

const BATCH_ISSUER = 'BatchIssuer';

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(BatchIssuer);
  console.log('\n   > Batch issuer deployment: Success -->', BatchIssuer.address);

  const registry = await ERC1820Registry.at('0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24');
  
  await registry.setInterfaceImplementer(accounts[0], soliditySha3(BATCH_ISSUER), BatchIssuer.address, { from: accounts[0] });

  const registeredBatchIssuerAddress = await registry.getInterfaceImplementer(accounts[0], soliditySha3(BATCH_ISSUER), { from: accounts[1] });

  if(registeredBatchIssuerAddress === BatchIssuer.address) {
    console.log('\n   > Batch issuer registry in ERC1820: Success -->', registeredBatchIssuerAddress);
  }
  
};
