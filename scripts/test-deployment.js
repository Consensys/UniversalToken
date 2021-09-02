module.exports = async function(callback) {
  const ERC20Extendable = artifacts.require('ERC20Extendable');
  const erc20Diamond = await ERC20Extendable.new(
    'TestToken', 'TEST', 18
  );

  const ERC20Token = artifacts.require('ERC20Token');
  const erc20 = await ERC20Token.at(erc20Diamond.address);

  await erc20.mint('0xA1b9E2228ab592e742817aD4BE61509d5e6e331f', 1000000);

  const balance = await erc20.balanceOf('0xA1b9E2228ab592e742817aD4BE61509d5e6e331f');
  const totalSupply = await erc20.totalSupply();

  console.log('Total Supply: ' + totalSupply);
  console.log('Balance: ' + balance);

  await erc20.transfer('0xc4ba9659442360ffe327aBf93E3d9aE0A838a8D2', 100);

  const newBalance = await erc20.balanceOf('0xc4ba9659442360ffe327aBf93E3d9aE0A838a8D2');
  const totalSupply2 = await erc20.totalSupply();
  const owner = await erc20.owner();

  console.log('Total Supply: ' + totalSupply2);
  console.log('Balance: ' + newBalance);
  console.log('Owner: ' + owner);

  callback();
}