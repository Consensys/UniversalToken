const { soliditySha3 } = require("web3-utils");

const BatchBalanceReader = artifacts.require('./BatchBalanceReader.sol'); // deprecated
const BatchReader = artifacts.require('./BatchReader.sol');

const ERC1820Registry = artifacts.require('IERC1820Registry');

const BALANCE_READER = 'BatchBalanceReader';
const READER = 'BatchReader';

module.exports = async function (deployer, network, accounts) {
  if (network == "test") return; // test maintains own contracts
  
  await deployer.deploy(BatchReader);
  console.log('\n   > Batch Reader deployment: Success -->', BatchReader.address);

  const registry = await ERC1820Registry.at('0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24');

  await registry.setInterfaceImplementer(accounts[0], soliditySha3(READER), BatchReader.address, { from: accounts[0] });

  const registeredBatchReaderAddress = await registry.getInterfaceImplementer(accounts[0], soliditySha3(READER));

  if(registeredBatchReaderAddress === BatchReader.address) {
    console.log('\n   > Batch Reader registry in ERC1820: Success -->', registeredBatchReaderAddress);
  }

  // Deprecated
  await deployer.deploy(BatchBalanceReader);
  console.log('\n   > Batch Balance Reader deployment: Success -->', BatchBalanceReader.address);

  await registry.setInterfaceImplementer(accounts[0], soliditySha3(BALANCE_READER), BatchBalanceReader.address, { from: accounts[0] });

  const registeredBatchBalanceReaderAddress = await registry.getInterfaceImplementer(accounts[0], soliditySha3(BALANCE_READER));

  if(registeredBatchBalanceReaderAddress === BatchBalanceReader.address) {
    console.log('\n   > BatchBalance Reader registry in ERC1820: Success -->', registeredBatchBalanceReaderAddress);
  }
  //
  
};
