var ERC1400 = artifacts.require('./ERC1400.sol');
var ERC1400ERC20 = artifacts.require('./ERC1400ERC20.sol');

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

const partition1 = '0x5265736572766564000000000000000000000000000000000000000000000000'; // Reserved in hex
const partition2 = '0x4973737565640000000000000000000000000000000000000000000000000000'; // Issued in hex
const partition3 = '0x4c6f636b65640000000000000000000000000000000000000000000000000000'; // Locked in hex
const partitions = [partition1, partition2, partition3];

module.exports = function (deployer, network, accounts) {
  const controller = accounts[2];
  // deployer.deploy(ERC1400, 'ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER);
  deployer.deploy(ERC1400ERC20, 'ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, partitions);
};
