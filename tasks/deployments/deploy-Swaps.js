module.exports = async function(callback) {
  try {
    const Swaps = artifacts.require("Swaps");

    const from = "0x4EeABa74D7f51fe3202D7963EFf61D2e7e166cBa";

    const swaps = await Swaps.new(false, {
      from: from,
    });
    
    console.log("Swaps deployed at: " + swaps.address);

    callback();
  } catch (e) {
    callback(e);
  }
}