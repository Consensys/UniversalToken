var ERC1400 = artifacts.require('./ERC1400.sol');
var ERC1400ERC20 = artifacts.require('./ERC1400ERC20.sol');

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

module.exports = function (deployer, network, accounts) {
  const controller = accounts[2];
  // deployer.deploy(ERC1400, 'ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER);
  deployer.deploy(ERC1400ERC20, 'ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER);
};
