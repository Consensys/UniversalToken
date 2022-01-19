module.exports = async function(callback) {
  try {
    const ERC20HoldableToken = artifacts.require("ERC20HoldableToken");

    const from = "0x4EeABa74D7f51fe3202D7963EFf61D2e7e166cBa";

    const erc20 = await ERC20HoldableToken.new("Test Holdable ERC20", "TEST", 18, {
      from: from,
    });

    await erc20.mint(from, '1000000000000000000000000000');
    
    console.log("ERC20HoldableToken deployed at: " + erc20.address);

    callback();
  } catch (e) {
    callback(e);
  }
}