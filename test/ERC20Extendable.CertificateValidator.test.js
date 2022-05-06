const { assert } = require("chai");
const { expectRevert } = require("@openzeppelin/test-helpers");
const {
  nowSeconds,
  advanceTime,
  takeSnapshot,
  revertToSnapshot,
} = require("./utils/time");
const { soliditySha3 } = require("web3-utils");
const { newSecretHashPair } = require("./utils/crypto");
const { bytes32 } = require("./utils/regex");
const Account = require('eth-lib/lib/account');

const CERTIFICATE_VALIDATION_NONE = 0;
const CERTIFICATE_VALIDATION_NONCE = 1;
const CERTIFICATE_VALIDATION_SALT = 2;
const CERTIFICATE_VALIDATION_DEFAULT = CERTIFICATE_VALIDATION_SALT;
const EMPTY_CERTIFICATE = "0x";
const CERTIFICATE_VALIDITY_PERIOD = 1; // Certificate will be valid for 1 hour
const SECONDS_IN_AN_HOUR = 3600;
const SECONDS_IN_A_DAY = 24*SECONDS_IN_AN_HOUR;

const CertificateValidatorExtension = artifacts.require("CertificateValidatorExtension");
const ERC20Extendable = artifacts.require("ERC20");
const ERC20Logic = artifacts.require("ERC20Logic");
const ClockMock = artifacts.require("ClockMock");

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
  const extension = await CertificateValidatorExtension.at(_token.address);
  const tokenSetup = await extension.getValidationMode();
  const domainSeparator = await _token.generateDomainSeparator();
  if (tokenSetup == CERTIFICATE_VALIDATION_NONCE) {
    return craftNonceBasedCertificate(
      _txPayload,
      _token,
      _clock, // this.clock
      _txSender,
      domainSeparator
    );
  } else if (tokenSetup == CERTIFICATE_VALIDATION_SALT) {
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
  const extension = await CertificateValidatorExtension.at(_token.address);
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
  const extension = await CertificateValidatorExtension.at(_token.address);
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


contract(
  "ERC20",
  function ([deployer, sender, holder, recipient, recipient2, notary]) {
    describe("ERC20 with Certificate Validator Extension", function () {
      const initialSupply = 1000;
      const maxSupply = 5000;
      let token;
      let certificateValidator;
      let certificateValidatorContract;
      let clock;
      before(async function () {
        //snapshot = await takeSnapshot();
        //snapshotId = snapshot["result"];
        this.logic = await ERC20Logic.new();
        token = await ERC20Extendable.new(
          "ERC20Extendable",
          "DAU",
          true,
          true,
          deployer,
          initialSupply,
          maxSupply,
          this.logic.address
        );

        clock = await ClockMock.new();
        certificateValidatorContract = await CertificateValidatorExtension.new();
        certificateValidator = certificateValidatorContract.address;
        assert.equal(await token.isMinter(deployer), true);
        assert.equal(await token.name(), "ERC20Extendable");
        assert.equal(await token.symbol(), "DAU");
        assert.equal(await token.totalSupply(), initialSupply);
        assert.equal(await token.balanceOf(deployer), initialSupply);
      });

      it("Deployer can registers extension", async () => {
        assert.equal((await token.allExtensionsRegistered()).length, 0);

        const result = await token.registerExtension(certificateValidator, { from: deployer });
        assert.equal(result.receipt.status, 1);

        assert.equal((await token.allExtensionsRegistered()).length, 1);

        const ext = await CertificateValidatorExtension.at(token.address);
        assert.equal((await ext.isCertificateSigner(deployer)), true);
      });

      it("Transfers fail if no certificate is attached", async () => {
        assert.equal(await token.balanceOf(deployer), initialSupply);
        await expectRevert.unspecified(
          token.transfer(recipient, 200, { from: deployer })
        );
      });

      it("Certificate signers can add other certificate signers", async () => {
        const ext = await CertificateValidatorExtension.at(token.address);
        assert.equal((await ext.isCertificateSigner(deployer)), true);
        assert.equal((await ext.isCertificateSigner(CERTIFICATE_SIGNER)), false);

        const result = await ext.addCertificateSigner(CERTIFICATE_SIGNER, { from: deployer });
        assert.equal(result.receipt.status, 1);

        assert.equal((await ext.isCertificateSigner(CERTIFICATE_SIGNER)), true);
      });

      it("Only certificate signers can add new signers", async () => {
        const ext = await CertificateValidatorExtension.at(token.address);
        await expectRevert.unspecified(
          ext.addCertificateSigner(CERTIFICATE_SIGNER, { from: recipient })
        );
      });

      it("Only certificate signers can remove other signers", async () => {
        const ext = await CertificateValidatorExtension.at(token.address);
        await expectRevert.unspecified(
          ext.removeCertificateSigner(CERTIFICATE_SIGNER, { from: recipient })
        );
      });

      it("Certificate signers can set the validation mode", async () => {
        const ext = await CertificateValidatorExtension.at(token.address);
        assert.equal((await ext.getValidationMode()), CERTIFICATE_VALIDATION_NONE);

        const result = await ext.setValidationMode(CERTIFICATE_VALIDATION_DEFAULT, { from: deployer });
        assert.equal(result.receipt.status, 1);

        assert.equal((await ext.getValidationMode()), CERTIFICATE_VALIDATION_DEFAULT);
      });

      it("Only certificate signers can set the validation mode", async () => {
        const ext = await CertificateValidatorExtension.at(token.address);
        assert.equal((await ext.getValidationMode()), CERTIFICATE_VALIDATION_DEFAULT);

        await expectRevert.unspecified(
          ext.setValidationMode(CERTIFICATE_VALIDATION_DEFAULT, { from: recipient })
        );

        assert.equal((await ext.getValidationMode()), CERTIFICATE_VALIDATION_DEFAULT);
      });

      it("Transfer 100 tokens from deployer to recipient with salt-based certificate", async () => {
        const certificate = await craftCertificate(
          token.contract.methods.transfer(
            recipient,
            100,
          ).encodeABI(),
          token,
          clock, // this.clock
          deployer
        );

        assert.equal(await token.totalSupply(), initialSupply);
        assert.equal(await token.balanceOf(deployer), initialSupply);
        const result = await token.transferWithData(recipient, 100, certificate, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await token.balanceOf(deployer), initialSupply - 100);
        assert.equal(await token.balanceOf(holder), 0);
        assert.equal(await token.balanceOf(sender), 0);
        assert.equal(await token.balanceOf(recipient), 100);
        assert.equal(await token.balanceOf(recipient2), 0);
        assert.equal(await token.balanceOf(notary), 0);
        assert.equal(await token.totalSupply(), initialSupply);
      });

      it("Transfers fail if bad certificate", async () => {
        const domainSeparator = await token.generateDomainSeparator();
        const certificate = await craftNonceBasedCertificate(
          token.contract.methods.transfer(
            recipient,
            200,
          ).encodeABI(),
          token,
          clock, // this.clock
          deployer,
          domainSeparator
        );

        assert.equal(await token.balanceOf(deployer), initialSupply - 100);
        await expectRevert.unspecified(
          token.transferWithData(recipient, 200, certificate, { from: deployer })
        );
      });

      it("Transfers fail if valid certificate, but transfer payload does not match", async () => {
        const certificate = await craftCertificate(
          token.contract.methods.transfer(
            recipient,
            100,
          ).encodeABI(),
          token,
          clock, // this.clock
          deployer
        );

        assert.equal(await token.balanceOf(deployer), initialSupply - 100);
        await expectRevert.unspecified(
          token.transferWithData(recipient, 200, certificate, { from: deployer })
        );
      });

      it("Certificate signers can change the validation mode", async () => {
        const ext = await CertificateValidatorExtension.at(token.address);
        assert.equal((await ext.getValidationMode()), CERTIFICATE_VALIDATION_DEFAULT);

        const result = await ext.setValidationMode(CERTIFICATE_VALIDATION_NONCE, { from: deployer });
        assert.equal(result.receipt.status, 1);

        assert.equal((await ext.getValidationMode()), CERTIFICATE_VALIDATION_NONCE);
      });

      it("Transfer 100 tokens from deployer to recipient with nonce-based certificate", async () => {
        const certificate = await craftCertificate(
          token.contract.methods.transfer(
            recipient,
            200,
          ).encodeABI(),
          token,
          clock, // this.clock
          deployer
        );

        assert.equal(await token.totalSupply(), initialSupply);
        assert.equal(await token.balanceOf(deployer), initialSupply - 100);
        const result = await token.transferWithData(recipient, 200, certificate, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await token.balanceOf(deployer), initialSupply - 300);
        assert.equal(await token.balanceOf(holder), 0);
        assert.equal(await token.balanceOf(sender), 0);
        assert.equal(await token.balanceOf(recipient), 300);
        assert.equal(await token.balanceOf(recipient2), 0);
        assert.equal(await token.balanceOf(notary), 0);
        assert.equal(await token.totalSupply(), initialSupply);
      });
    });
  })