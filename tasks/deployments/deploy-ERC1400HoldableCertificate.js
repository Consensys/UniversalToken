const tokenConfig = require('../../libs/configs/deployments/config-ERC1400HoldableCertificate');

module.exports = async function(callback) {
  try {
    const ERC1400HoldableCertificate = artifacts.require("ERC1400HoldableCertificateToken");
    
    const ERC1400TokensValidator = artifacts.require("ERC1400TokensValidator");
    const ERC1400TokensChecker = artifacts.require("ERC1400TokensChecker");
    
    const ERC1400_TOKENS_CHECKER = "ERC1400TokensChecker";

    const from = tokenConfig.from;
    const name = tokenConfig.name;
    const symbol = tokenConfig.symbol;
    const granularity = tokenConfig.granularity;
    const controller = tokenConfig.controller ? tokenConfig.controller : from;
    const partitions = tokenConfig.partitions ? tokenConfig.partitions :  [];
    const owner = tokenConfig.owner ? tokenConfig.owner : from;
    const certificate_mode = tokenConfig.certificateMode;
    const certificate_signer = tokenConfig.certificateSigner;

    if (!name || !symbol || !granularity || !from || !certificate_mode || !certificate_signer) {
      console.log("The following parameters are required: --name, --symbol, --granularity, --from, --certificate_mode, --certificate_signer");
      callback(new Error("Missing required parameters"));
      return;
    }

    const extension = await ERC1400TokensValidator.new({
      from: from,
    });
    
    console.log("Validator Extension deployed at: " + extension.address);

    const extension2 = await ERC1400TokensChecker.new({
      from: owner,
    });
    
    console.log("Checker Extension deployed at: " + extension2.address);

    const token = await ERC1400HoldableCertificate.new(
      name,
      symbol,
      granularity,
      [controller],
      partitions,
      extension.address,
      owner,
      certificate_signer,
      certificate_mode,
      { from: controller }
    );

    await token.setTokenExtension(
      extension2.address,
      ERC1400_TOKENS_CHECKER,
      true,
      true,
      true,
      { from: owner }
    );

    console.log("Token deployed at: " + token.address);

    callback();
  } catch (e) {
    callback(e);
  }
}