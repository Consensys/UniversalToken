const { soliditySha3 } = require("web3-utils");

const FundIssuer = artifacts.require('./FundIssuer.sol');

const ERC1820Registry = artifacts.require('IERC1820Registry');

const FUND_ISSUER = 'FundIssuer';

module.exports = async function (deployer, network, accounts) {
  if (network == "test") return; // test maintains own contracts
  
  await deployer.deploy(FundIssuer);
  console.log('\n   > FundIssuer deployment: Success -->', FundIssuer.address);

  const registry = await ERC1820Registry.at('0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24');
  
  await registry.setInterfaceImplementer(accounts[0], soliditySha3(FUND_ISSUER), FundIssuer.address, { from: accounts[0] });

  const registeredFundIssuerAddress = await registry.getInterfaceImplementer(accounts[0], soliditySha3(FUND_ISSUER));

  if(registeredFundIssuerAddress === FundIssuer.address) {
    console.log('\n   > FundIssuer registry in ERC1820: Success -->', registeredFundIssuerAddress);
  }
};
