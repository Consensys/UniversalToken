const { soliditySha3 } = require("web3-utils");

const BatchBalanceReader = artifacts.require('./BatchBalanceReader.sol');

const ERC1820Registry = artifacts.require('ERC1820Registry');

const BALANCE_READER = 'BatchBalanceReader';

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(BatchBalanceReader);
  console.log('\n   > Balance Reader deployment: Success -->', BatchBalanceReader.address);

  const registry = await ERC1820Registry.at('0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24');
  
  await registry.setInterfaceImplementer(accounts[0], soliditySha3(BALANCE_READER), BatchBalanceReader.address, { from: accounts[0] });

  const registeredBatchBalanceReaderAddress = await registry.getInterfaceImplementer(accounts[0], soliditySha3(BALANCE_READER), { from: accounts[1] });

  if(registeredBatchBalanceReaderAddress === BatchBalanceReader.address) {
    console.log('\n   > Balance Reader registry in ERC1820: Success -->', registeredBatchBalanceReaderAddress);
  }
  
};
