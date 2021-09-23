module.exports = async function(callback) {
  const UpgradableERC20 = artifacts.require('UpgradableERC20');
  const erc20Diamond = await UpgradableERC20.new(
    'TestToken', 'TEST'
  );

 /*  const ERC20Token = artifacts.require('ERC20Token');
  const erc20 = await ERC20Token.at(erc20Diamond.address);

  await erc20.mint('0xA1b9E2228ab592e742817aD4BE61509d5e6e331f', 1000000);

  const balance = await erc20.balanceOf('0xA1b9E2228ab592e742817aD4BE61509d5e6e331f');
  const totalSupply = await erc20.totalSupply();

  console.log('Total Supply: ' + totalSupply);
  console.log('Balance: ' + balance);

  await erc20.transfer('0xc4ba9659442360ffe327aBf93E3d9aE0A838a8D2', 100); */

  const newBalance = await erc20Diamond.balanceOf('0xc4ba9659442360ffe327aBf93E3d9aE0A838a8D2');
  const totalSupply2 = await erc20Diamond.totalSupply();

  console.log('Total Supply: ' + totalSupply2);
  console.log('Balance: ' + newBalance);

  callback();
}