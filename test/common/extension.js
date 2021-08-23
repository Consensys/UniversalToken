const { soliditySha3 } = require("web3-utils");
const { assert } = require("chai");

const ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";

const CERTIFICATE_VALIDATION_NONE = 0;
const CERTIFICATE_VALIDATION_NONCE = 1;
const CERTIFICATE_VALIDATION_SALT = 2;
const CERTIFICATE_VALIDATION_DEFAULT = CERTIFICATE_VALIDATION_SALT;

const assertTokenHasExtension = async (
  _registry,
  _extension,
  _token,
) => {
  let extensionImplementer = await _registry.getInterfaceImplementer(
    _token.address,
    soliditySha3(ERC1400_TOKENS_VALIDATOR)
  );
  assert.equal(extensionImplementer, _extension.address);
}

const setNewExtensionForToken = async (
  _extension,
  _token,
  _sender,
) => {
  const controllers = await _token.controllers();
  await _extension.registerTokenSetup(
    _token.address,
    CERTIFICATE_VALIDATION_DEFAULT,
    true,
    true,
    true,
    true,
    controllers,
    { from: _sender }
  );

  await _token.setTokenExtension(
    _extension.address,
    ERC1400_TOKENS_VALIDATOR,
    true,
    true,
    true,
    { from: _sender }
  );
}

const assertCertificateActivated = async (
  _extension,
  _token,
  _expectedValue
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  assert.equal(_expectedValue, parseInt(tokenSetup[0]));
}

const setCertificateActivated = async (
  _extension,
  _token,
  _sender,
  _value
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  await _extension.registerTokenSetup(
    _token.address,
    _value,
    tokenSetup[1],
    tokenSetup[2],
    tokenSetup[3],
    tokenSetup[4],
    tokenSetup[5],
    { from: _sender }
  );
}

const assertAllowListActivated = async (
  _extension,
  _token,
  _expectedValue
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  assert.equal(_expectedValue, tokenSetup[1]);
}

const setAllowListActivated = async (
  _extension,
  _token,
  _sender,
  _value
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  await _extension.registerTokenSetup(
    _token.address,
    tokenSetup[0],
    _value,
    tokenSetup[2],
    tokenSetup[3],
    tokenSetup[4],
    tokenSetup[5],
    { from: _sender }
  );
}

const assertBlockListActivated = async (
  _extension,
  _token,
  _expectedValue
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  assert.equal(_expectedValue, tokenSetup[2]);
}

const setBlockListActivated = async (
  _extension,
  _token,
  _sender,
  _value
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  await _extension.registerTokenSetup(
    _token.address,
    tokenSetup[0],
    tokenSetup[1],
    _value,
    tokenSetup[3],
    tokenSetup[4],
    tokenSetup[5],
    { from: _sender }
  );
}

const assertGranularityByPartitionActivated = async (
  _extension,
  _token,
  _expectedValue
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  assert.equal(_expectedValue, tokenSetup[3]);
}

const setGranularityByPartitionActivated = async (
  _extension,
  _token,
  _sender,
  _value
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  await _extension.registerTokenSetup(
    _token.address,
    tokenSetup[0],
    tokenSetup[1],
    tokenSetup[2],
    _value,
    tokenSetup[4],
    tokenSetup[5],
    { from: _sender }
  );
}

const assertHoldsActivated = async (
  _extension,
  _token,
  _expectedValue
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  assert.equal(_expectedValue, tokenSetup[4]);
}

const setHoldsActivated = async (
  _extension,
  _token,
  _sender,
  _value
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  await _extension.registerTokenSetup(
    _token.address,
    tokenSetup[0],
    tokenSetup[1],
    tokenSetup[2],
    tokenSetup[3],
    _value,
    tokenSetup[5],
    { from: _sender }
  );
}

const assertIsTokenController = async (
  _extension,
  _token,
  _controller,
  _value,
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  const controllerList = tokenSetup[5];
  assert.equal(_value, controllerList.includes(_controller))
}

const addTokenController = async (
  _extension,
  _token,
  _sender,
  _newController
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  //Need to clone the object since tokenSetup[5] is immutable
  const controllerList = Object.assign([], tokenSetup[5]);
  if (!controllerList.includes(_newController)) {
    controllerList.push(_newController);
  }
  await _extension.registerTokenSetup(
    _token.address,
    tokenSetup[0],
    tokenSetup[1],
    tokenSetup[2],
    tokenSetup[3],
    tokenSetup[4],
    controllerList,
    { from: _sender }
  );
}

module.exports = {
  CERTIFICATE_VALIDATION_NONE,
  CERTIFICATE_VALIDATION_NONCE,
  CERTIFICATE_VALIDATION_SALT,
  CERTIFICATE_VALIDATION_DEFAULT,
  assertTokenHasExtension,
  setNewExtensionForToken,
  assertCertificateActivated,
  setCertificateActivated,
  assertAllowListActivated,
  setAllowListActivated,
  assertBlockListActivated,
  setBlockListActivated,
  assertGranularityByPartitionActivated,
  setGranularityByPartitionActivated,
  assertHoldsActivated,
  setHoldsActivated,
  assertIsTokenController,
  addTokenController
}