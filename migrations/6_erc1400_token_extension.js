const ERC1400 = artifacts.require('./ERC1400.sol');
const Extension = artifacts.require('./ERC1400TokensValidator.sol');
const ERC1400HoldableCertificateTokenMock = artifacts.require('./ERC1400HoldableCertificateTokenMock.sol');

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';
const controller = '0xb5747835141b46f7C472393B31F8F5A57F74A44f';

const partition1 = '0x7265736572766564000000000000000000000000000000000000000000000000'; // reserved in hex
const partition2 = '0x6973737565640000000000000000000000000000000000000000000000000000'; // issued in hex
const partition3 = '0x6c6f636b65640000000000000000000000000000000000000000000000000000'; // locked in hex
const partitions = [partition1, partition2, partition3];

const ERC1400_TOKENS_VALIDATOR = 'ERC1400TokensValidator';

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(Extension);
  const tokenExtension = await Extension.deployed();
  console.log('\n   > Holdable token extension deployment: Success -->', tokenExtension.address);

  const tokenInstance = await ERC1400.deployed();
  console.log('\n   > Token deployment: Success -->', tokenInstance.address);
  
  await tokenExtension.registerTokenSetup(tokenInstance.address, true, true, true, true, false, [controller]);
  console.log('\n   > Manual holdable token extension setup: Success');

  await tokenInstance.setTokenExtension(tokenExtension.address, ERC1400_TOKENS_VALIDATOR, true, true);
  console.log('\n   > Manual token connection to holdable token extension: Success');

  await tokenInstance.transferOwnership(controller);
  console.log('\n   > Manual token ownership transfer: Success');

  await deployer.deploy(ERC1400HoldableCertificateTokenMock, 'ERC1400HoldableCertificateTokenMock', 'DAU', 1, [controller], partitions, tokenExtension.address, ZERO_ADDRESS, CERTIFICATE_SIGNER, true);
  console.log('\n   > Automated holdable token deployment anad setup: Success');
};
