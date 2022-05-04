// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { soliditySha3 } = require("web3-utils");
const Account = require('eth-lib/lib/account');

const CERTIFICATE_VALIDATION_NONE = 0;
const CERTIFICATE_VALIDATION_NONCE = 1;
const CERTIFICATE_VALIDATION_SALT = 2;
const CERTIFICATE_VALIDATION_DEFAULT = CERTIFICATE_VALIDATION_NONCE;
const EMPTY_CERTIFICATE = "0x";
const CERTIFICATE_VALIDITY_PERIOD = 1; // Certificate will be valid for 1 hour
const SECONDS_IN_AN_HOUR = 3600;
const SECONDS_IN_A_DAY = 24*SECONDS_IN_AN_HOUR;

const CERTIFICATE_SIGNER_PRIVATE_KEY = "0x1699611cc662aad2db30d5cf44bd531a8b16710e43624fc0e801c6592f72f9ab";
const CERTIFICATE_SIGNER = "0x2A3cE238F1903B1cA935D734e6160aBA029ff80a";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ZERO_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

const numberToHexa = (num, pushTo) => {
  const arr1 = [];
  const str = num.toString(16);
  if(str.length%2 === 1) {
    arr1.push('0');
    pushTo -=1;
  }
  for (let m = str.length / 2; m < pushTo; m++) {
    arr1.push('0');
    arr1.push('0');
  }
  for (let n = 0, l = str.length; n < l; n++) {
    const hex = str.charAt(n);
    arr1.push(hex);
  }
  return arr1.join('');
};

const craftCertificate = async (
  _txPayload,
  _token,
  _clock, // this.clock
  _txSender
) => {
  const CertificateValidatorExtension = await hre.ethers.getContractFactory("CertificateValidatorExtension");
  const extension = await CertificateValidatorExtension.attach(_token.address);
  const tokenSetup = await extension.getValidationMode();
  const domainSeparator = await _token.generateDomainSeparator();
  if (tokenSetup === CERTIFICATE_VALIDATION_NONCE) {
    return craftNonceBasedCertificate(
      _txPayload,
      _token,
      _clock, // this.clock
      _txSender,
      domainSeparator
    );
  } else if (tokenSetup === CERTIFICATE_VALIDATION_SALT) {
    return craftSaltBasedCertificate(
      _txPayload,
      _token,
      _clock,
      _txSender,
      domainSeparator
    );
  } else {
    return EMPTY_CERTIFICATE;
  }
}

const craftNonceBasedCertificate = async (
  _txPayload,
  _token,
  _clock, // this.clock
  _txSender,
  _domain
) => {
  const CertificateValidatorExtension = await hre.ethers.getContractFactory("CertificateValidatorExtension");
  const extension = await CertificateValidatorExtension.attach(_token.address);
  // Retrieve current nonce from smart contract
  const nonce = await extension.usedCertificateNonce(_txSender);

  const time = await _clock.getTime();
  const expirationTime = new Date(1000*(parseInt(time) + CERTIFICATE_VALIDITY_PERIOD * SECONDS_IN_AN_HOUR));
  const expirationTimeAsNumber = Math.floor(
    expirationTime.getTime() / 1000,
  );

  const rawTxPayload = _txPayload;

  /* let rawTxPayload;
  if (_txPayload.length >= 64) {
    rawTxPayload = _txPayload.substring(0, _txPayload.length - 64);
  } else {
    throw new Error(
      `txPayload shall be at least 32 bytes long (${
        _txPayload.length / 2
      } instead)`,
    );
  } */

  const packedAndHashedParameters = soliditySha3(
    { type: 'address', value: _txSender.toString() },
    { type: 'address', value: _token.address.toString() },
    { type: 'bytes', value: rawTxPayload },
    { type: 'uint256', value: expirationTimeAsNumber.toString() },
    { type: 'uint256', value: nonce.toString()  },
  );

  const packedAndHashedData = soliditySha3(
    { type: 'bytes32', value: _domain },
    { type: 'bytes32', value: packedAndHashedParameters }
  );

  const signature = Account.sign(
    packedAndHashedData,
    CERTIFICATE_SIGNER_PRIVATE_KEY,
  );
  const vrs = Account.decodeSignature(signature);
  const v = vrs[0].substring(2).replace('1b', '00').replace('1c', '01');
  const r = vrs[1].substring(2);
  const s = vrs[2].substring(2);

  const certificate = `0x${numberToHexa(expirationTimeAsNumber,32)}${r}${s}${v}`;

  return certificate;

}

const craftSaltBasedCertificate = async (
  _txPayload,
  _token,
  _clock, // this.clock
  _txSender,
  _domain
) => {
  const CertificateValidatorExtension = await hre.ethers.getContractFactory("CertificateValidatorExtension");
  const extension = await CertificateValidatorExtension.attach(_token.address);
  // Generate a random salt, which has never been used before
  const salt = soliditySha3(new Date().getTime().toString());

  // Check if salt has already been used, even though that very un likely to happen (statistically impossible)
  const saltHasAlreadyBeenUsed = await extension.usedCertificateSalt(salt);

  if (saltHasAlreadyBeenUsed) {
    throw new Error('can never happen: salt has already been used (statistically impossible)');
  }

  const time = await _clock.getTime();
  const expirationTime = new Date(1000*(parseInt(time) + CERTIFICATE_VALIDITY_PERIOD * 3600));
  const expirationTimeAsNumber = Math.floor(
    expirationTime.getTime() / 1000,
  );

  const rawTxPayload = _txPayload;

  /*   let rawTxPayload;
  if (_txPayload.length >= 64) {
    rawTxPayload = _txPayload.substring(0, _txPayload.length - 64);
  } else {
    throw new Error(
      `txPayload shall be at least 32 bytes long (${
        _txPayload.length / 2
      } instead)`,
    );
  } */

  const packedAndHashedParameters = soliditySha3(
    { type: 'address', value: _txSender.toString() },
    { type: 'address', value: _token.address.toString() },
    { type: 'bytes', value: rawTxPayload },
    { type: 'uint256', value: expirationTimeAsNumber.toString() },
    { type: 'bytes32', value: salt.toString() },
  );

  const packedAndHashedData = soliditySha3(
    { type: 'bytes32', value: _domain },
    { type: 'bytes32', value: packedAndHashedParameters }
  );

  const signature = Account.sign(
    packedAndHashedData,
    CERTIFICATE_SIGNER_PRIVATE_KEY,
  );
  const vrs = Account.decodeSignature(signature);
  const v = vrs[0].substring(2).replace('1b', '00').replace('1c', '01');
  const r = vrs[1].substring(2);
  const s = vrs[2].substring(2);

  const certificate = `0x${salt.substring(2)}${numberToHexa(
    expirationTimeAsNumber,
    32,
  )}${r}${s}${v}`;

  return certificate;

}

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const accounts = await ethers.provider.listAccounts();

  const deployer = accounts[0];
  const recipient = accounts[1];
  const maxSupply = 5000;
  const initialSupply = 1000;
  
  const ClockMock = await hre.ethers.getContractFactory("ClockMock");
  const ERC20Logic = await hre.ethers.getContractFactory("ERC20Logic");
  const ERC20Extendable = await hre.ethers.getContractFactory("ERC20");
  const CertificateValidatorExtension = await hre.ethers.getContractFactory("CertificateValidatorExtension");

  console.log("deploying clock");
  const clock = await ClockMock.deploy();
  await clock.deployed();

  console.log("deploying logic");
  const logic = await ERC20Logic.deploy();
  await logic.deployed();

  console.log("deploying erc20 extendable");
  const erc20 = await ERC20Extendable.deploy(
    "ERC20Extendable",
    "DAU",
    true,
    true,
    deployer,
    initialSupply,
    maxSupply,
    logic.address
  );
  await erc20.deployed();

  console.log("deploying certificate extension");
  const extension = await CertificateValidatorExtension.deploy();
  await extension.deployed();

  console.log("registering extension");
  await erc20.registerExtension(extension.address, { from: deployer });
  
  const validatorERC20 = CertificateValidatorExtension.attach(erc20.address);

  console.log("doing extension setup");
  await validatorERC20.addCertificateSigner(CERTIFICATE_SIGNER, { from: deployer });
  await validatorERC20.setValidationMode(CERTIFICATE_VALIDATION_DEFAULT, { from: deployer });

  console.log("crafting certificate");
  const certificate = await craftCertificate(
    erc20.interface.encodeFunctionData(
      "transfer",
      [recipient, 100]
    ),
    erc20,
    clock, // this.clock
    deployer
  );

  console.log("doing transferWithData with " + certificate);
  console.log("certificate is " + certificate.length + " chars");
  
  //transferWithData(address,uint256,bytes) is the same as doing 
  //encodePacked(transfer(address,uint256), bytes)
  await erc20.transferWithData(recipient, 100, certificate, { from: deployer });
  console.log("it worked");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
