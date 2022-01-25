const tokenConfig = require('../../libs/configs/deployments/config-ERC1400HoldableCertificate');

module.exports = async function(callback) {
  try {
    const ERC1400 = artifacts.require("ERC1400");

    const from = tokenConfig.from;
    const name = tokenConfig.name;
    const symbol = tokenConfig.symbol;
    const granularity = tokenConfig.granularity;
    const controller = tokenConfig.controller ? tokenConfig.controller : from;
    const partitions = tokenConfig.partitions ? tokenConfig.partitions :  [];

    if (!name || !symbol || !granularity || !from) {
      console.log("The following parameters are required: --name, --symbol, --granularity, --from, --certificate_mode, --certificate_signer");
      callback(new Error("Missing required parameters"));
      return;
    }
    console.log("Starting deployment");

    const token = await ERC1400.new(
      name,
      symbol,
      granularity,
      [controller],
      partitions,
      { from: controller }
    );

    console.log("Token deployed at: " + token.address);

    callback();
  } catch (e) {
    callback(e);
  }
}