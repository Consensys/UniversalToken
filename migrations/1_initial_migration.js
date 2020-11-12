const Migrations = artifacts.require('./Migrations.sol');

module.exports = function (deployer, network, accounts) {
  if (network == "test") return; // test maintains own contracts
  
  console.log('Account to load with ETH: ', accounts[0]);
  deployer.deploy(Migrations);
};
