var CertificateController = artifacts.require('./ControlledMock.sol');
const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

module.exports = function (deployer, network, accounts) {
  deployer.deploy(CertificateController, CERTIFICATE_SIGNER);
};

// const EthereumTx = require('ethereumjs-tx');
//
// /* eslint max-len: ["error", { "ignoreStrings": true }] */
// const rawTx = require("../js/rawTransaction.js");
// console.log(rawTx);
//
// const deployerAddress = "0x"+(new EthereumTx(rawTx).getSenderAddress().toString('hex'));
//
// console.log("Deployer address : ", deployerAddress);
//
// module.exports = async function (deployer, network, accounts) {
//
//   await web3.eth.sendTransaction({
//     from: accounts[0], to: deployerAddress, value: '100000000000000000'/* web3.utils.toWei(0.1) */
//   });
//   web3.eth.sendSignedTransaction(rawTx).then((res) => {
//     console.log("\n   > ERC820 deployment: Success -->", res.contractAddress);
//   }).catch((err) => {
//     if (err.message.search('nonce too low') >= 0) {
//       console.log('\n   > ERC820 deployment: Invalid nonce, probably already deployed');
//     } else {
//       console.log("\n   > ERC820 deployment: Unknown error", err);
//     }
//   });
//
// };
