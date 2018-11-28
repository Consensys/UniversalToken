var ERC1400 = artifacts.require('./ERC1400.sol');

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

module.exports = function (deployer, network, accounts) {
  const defaultOperator = accounts[2];
  deployer.deploy(ERC1400, 'ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
};
