const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { newSecretHashPair } = require("../test/utils/crypto");
const { nowSeconds } = require("../test/utils/time");
const inOneHour = nowSeconds() + 60 * 60;
const hashLock = newSecretHashPair();

const ERC20Extendable = artifacts.require('./ERC20Extendable.sol');
const HoldExtension = artifacts.require('./HoldExtension.sol');

module.exports = async function (deployer, network, accounts) {
  if (network == "test") return; // test maintains own contracts
  
  await deployer.deploy(HoldExtension);

  const token = await ERC20Extendable.deployed();

  //Test registration
  await token.registerExtension(HoldExtension.address);

  //Test hold
  //first mint
  await token.mint(accounts[1], "1000");

  //then hold
  const holdableToken = await HoldExtension.at(ERC20Extendable.address);

  await holdableToken.hold(
      web3.utils.randomHex(32),
      accounts[2],
      accounts[3],
      100,
      inOneHour,
      hashLock.hash,
  )

  console.log('\n   > HoldExtension deployment: Success -->', HoldExtension.address);
};
