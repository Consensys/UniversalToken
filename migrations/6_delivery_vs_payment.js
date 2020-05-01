const { soliditySha3 } = require("web3-utils");

const DVPContract = artifacts.require('./DVP.sol');

const ERC1820Registry = artifacts.require('ERC1820Registry');

const DELIVERY_VS_PAYMENT = 'DeliveryVsPayment';

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(DVPContract, false, false);
  console.log('\n   > DVP deployment: Success -->', DVPContract.address);

  const registry = await ERC1820Registry.at('0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24');
  
  await registry.setInterfaceImplementer(accounts[0], soliditySha3(DELIVERY_VS_PAYMENT), DVPContract.address, { from: accounts[0] });

  const registeredDVPAddress = await registry.getInterfaceImplementer(accounts[0], soliditySha3(DELIVERY_VS_PAYMENT), { from: accounts[1] });

  if(registeredDVPAddress === DVPContract.address) {
    console.log('\n   > DVP registry in ERC1820: Success -->', registeredDVPAddress);
  }
};
