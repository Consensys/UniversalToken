const { soliditySha3 } = require("web3-utils");

const BatchTokenIssuer = artifacts.require('./BatchTokenIssuer.sol');

const ERC1820Registry = artifacts.require('IERC1820Registry');

const BATCH_ISSUER = 'BatchTokenIssuer';

module.exports = async function (deployer, network, accounts) {
  if (network == "test") return; // test maintains own contracts
  
  await deployer.deploy(BatchTokenIssuer);
  console.log('\n   > Batch issuer deployment: Success -->', BatchTokenIssuer.address);

  const registry = await ERC1820Registry.at('0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24');
  
  await registry.setInterfaceImplementer(accounts[0], soliditySha3(BATCH_ISSUER), BatchTokenIssuer.address, { from: accounts[0] });

  const registeredBatchTokenIssuerAddress = await registry.getInterfaceImplementer(accounts[0], soliditySha3(BATCH_ISSUER));

  if(registeredBatchTokenIssuerAddress === BatchTokenIssuer.address) {
    console.log('\n   > Batch issuer registry in ERC1820: Success -->', registeredBatchTokenIssuerAddress);
  }
  
};
