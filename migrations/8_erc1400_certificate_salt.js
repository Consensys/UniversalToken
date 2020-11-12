const ERC1400HoldableCertificateToken = artifacts.require('./ERC1400HoldableCertificateToken.sol');
const Extension = artifacts.require('./ERC1400TokensValidator.sol');

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';
const controller = '0xb5747835141b46f7C472393B31F8F5A57F74A44f';

const partition1 = '0x7265736572766564000000000000000000000000000000000000000000000000'; // reserved in hex
const partition2 = '0x6973737565640000000000000000000000000000000000000000000000000000'; // issued in hex
const partition3 = '0x6c6f636b65640000000000000000000000000000000000000000000000000000'; // locked in hex
const partitions = [partition1, partition2, partition3];

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

const ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";

const CERTIFICATE_VALIDATION_NONE = 0;
const CERTIFICATE_VALIDATION_NONCE = 1;
const CERTIFICATE_VALIDATION_SALT = 2;

module.exports = async function (deployer, network, accounts) {
  if (network == "test") return; // test maintains own contracts
  
  const extension = await Extension.deployed();

  await deployer.deploy(ERC1400HoldableCertificateToken, 'ERC1400HoldableCertificateSaltToken', 'DAU', 1, [controller], partitions, extension.address, controller, CERTIFICATE_SIGNER, CERTIFICATE_VALIDATION_SALT);
  const tokenInstance = await ERC1400HoldableCertificateToken.deployed();
  console.log('\n   > ERC1400HoldableCertificateSaltToken token deployment with automated extension setup: Success -->', tokenInstance.address);

  await deployer.deploy(ERC1400HoldableCertificateToken, 'ERC1400HoldableCertificateSaltToken', 'DAU', 1, [controller], partitions, ZERO_ADDRESS, ZERO_ADDRESS, CERTIFICATE_SIGNER, CERTIFICATE_VALIDATION_NONE);
  const tokenInstance2 = await ERC1400HoldableCertificateToken.deployed();
  console.log('\n   > ERC1400HoldableCertificateSaltToken token deployment with manual extension setup: Success -->', tokenInstance2.address);

  await extension.registerTokenSetup(tokenInstance2.address, CERTIFICATE_VALIDATION_SALT, true, true, true, true, [controller]);
  console.log('\n   > Manual token extension setup: Success');

  await tokenInstance2.setTokenExtension(extension.address, ERC1400_TOKENS_VALIDATOR, true, true, true);
  console.log('\n   > Manual token connection to token extension: Success');

  await tokenInstance2.transferOwnership(controller);
  console.log('\n   > Manual token ownership transfer: Success');
};
