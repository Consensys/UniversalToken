module.exports = async function(callback) {
  const ERC20Logic = artifacts.require('ERC20Logic');
  const logic = await ERC20Logic.new();

  const ERC20Extendable = artifacts.require('ERC20Extendable');
  const token1 = await ERC20Extendable.new(
    "TokenName",   //token name
    "DAU",         //token symbol
    true,          //allow minting
    true,          //allow burning
    deployer,      //token owner address
    1000,          //initial supply to give to owner address
    5000,          //max supply
    logic.address  //address of token logic contract
  );
  const token2 = await ERC20Extendable.new(
    'TestToken2', 'TEST2', coreLogic.address
  );

  const PauseExtension = artifacts.require('PauseExtension');
  const ext = await PauseExtension.new();

  //Lets check the balance of both
  let b1 = await token1.balanceOf('0x4EeABa74D7f51fe3202D7963EFf61D2e7e166cBa');
  let b2 = await token2.balanceOf('0x4EeABa74D7f51fe3202D7963EFf61D2e7e166cBa');

  console.log(b1.toString());
  console.log(b2.toString());

  //Lets try a transfer and ensure only one balance changes
  await token1.transfer('0xc4ba9659442360ffe327aBf93E3d9aE0A838a8D2', '1000000000000000000');

  b1 = await token1.balanceOf('0x4EeABa74D7f51fe3202D7963EFf61D2e7e166cBa');
  b2 = await token2.balanceOf('0x4EeABa74D7f51fe3202D7963EFf61D2e7e166cBa');
  let b1_1 = await token1.balanceOf('0xc4ba9659442360ffe327aBf93E3d9aE0A838a8D2');
  let b2_1 = await token2.balanceOf('0xc4ba9659442360ffe327aBf93E3d9aE0A838a8D2');

  console.log(b1.toString());
  console.log(b2.toString());
  console.log(b1_1.toString());
  console.log(b2_1.toString());

  await token1.registerExtension(ext.address);

  const pauseExt = await PauseExtension.at(token1.address);

  await pauseExt.pause();

  let isPaused = await pauseExt.isPaused();

  console.log(isPaused);

  try {
     //Lets try a transfer again and ensure we revert
    await token1.transfer('0xc4ba9659442360ffe327aBf93E3d9aE0A838a8D2', '1000000000000000000');
  } catch (e) {
    console.log(e);
  }

  b1 = await token1.balanceOf('0x4EeABa74D7f51fe3202D7963EFf61D2e7e166cBa');
  b2 = await token2.balanceOf('0x4EeABa74D7f51fe3202D7963EFf61D2e7e166cBa');
  b1_1 = await token1.balanceOf('0xc4ba9659442360ffe327aBf93E3d9aE0A838a8D2');
  b2_1 = await token2.balanceOf('0xc4ba9659442360ffe327aBf93E3d9aE0A838a8D2');

  console.log(b1.toString());
  console.log(b2.toString());
  console.log(b1_1.toString());
  console.log(b2_1.toString());

  callback();
}