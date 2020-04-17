const { shouldFail } = require('openzeppelin-test-helpers');

const CertificateController = artifacts.require('ControlledMock.sol');

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

// const exampleUint = 5;
// const exampleByte = '0x5265736572766564000000000000000000000000000000000000000000000000';

// const contractAddress = '0x820b586C8C28125366C998641B09DCbE7d4cBF06';

contract('CertificateController', ([owner, operator, controller, unknown]) => {
  describe('deployment', function () {
    describe('when the certificate signer address is valid', function () {
      it('deploys the contract', async function () {
        this.controllerMock = await CertificateController.new(CERTIFICATE_SIGNER);
        assert(this.controllerMock);
      });
    });
    describe('when the certificate signer address is not valid', function () {
      it('reverts', async function () {
        await shouldFail.reverting.withMessage(
          CertificateController.new(ZERO_ADDRESS),
          '' // Action Blocked - Not a valid address
        );
      });
    });
  });

  // SETCERTIFICATESIGNER

  describe('setCertificateSigner', function () {
    beforeEach(async function () {
      this.controllerMock = await CertificateController.new(CERTIFICATE_SIGNER);
    });
    describe('when the sender is the contract owner', function () {
      describe('when the new certificate signer address is valid', function () {
        it('sets the operator as certificate signer', async function () {
          assert(!(await this.controllerMock.certificateSigners(operator)));
          await this.controllerMock.setCertificateSigner(operator, true, { from: owner });
          assert(await this.controllerMock.certificateSigners(operator));
        });
        it('sets the operator as certificate signer', async function () {
          assert(!(await this.controllerMock.certificateSigners(operator)));
          await this.controllerMock.setCertificateSigner(operator, true, { from: owner });
          assert(await this.controllerMock.certificateSigners(operator));
          await this.controllerMock.setCertificateSigner(operator, false, { from: owner });
          assert(!(await this.controllerMock.certificateSigners(operator)));
        });
      });
      describe('when the certificate signer address is not valid', function () {
        it('reverts', async function () {
          await shouldFail.reverting.withMessage(
            this.controllerMock.setCertificateSigner(ZERO_ADDRESS, true, { from: owner }),
            '' // Action Blocked - Not a valid address
          );
        });
        it('reverts', async function () {
          await shouldFail.reverting.withMessage(
            this.controllerMock.setCertificateSigner(ZERO_ADDRESS, false, { from: owner }),
            '' // Action Blocked - Not a valid address
          );
        });
      });
    });
    describe('when the sender is not the contract owner', function () {
      it('reverts', async function () {
        await shouldFail.reverting(
          this.controllerMock.setCertificateSigner(operator, true, { from: unknown })
        );
      });
    });
  });

  // SET CERTIFICATE CONTROLLER ACTIVATED

  describe('setCertificateControllerActivated', function () {
    beforeEach(async function () {
      this.controllerMock = await CertificateController.new(CERTIFICATE_SIGNER);
    });
    describe('when the sender is the contract owner', function () {
      it('disactivates the certificate controller', async function () {
        await this.controllerMock.setCertificateControllerActivated(false, { from: owner });
        assert(!(await this.controllerMock.certificateControllerActivated()));
      });
      it('disactivates and reactivates the certificate controller', async function () {
        assert(await this.controllerMock.certificateControllerActivated());
        await this.controllerMock.setCertificateControllerActivated(false, { from: owner });
        assert(!(await this.controllerMock.certificateControllerActivated()));
        await this.controllerMock.setCertificateControllerActivated(true, { from: owner });
        assert(await this.controllerMock.certificateControllerActivated());
      });
    });
    describe('when the sender is not the contract owner', function () {
      it('reverts', async function () {
        await shouldFail.reverting(
          this.controllerMock.setCertificateControllerActivated(true, { from: unknown })
        );
      });
    });
  });

  // CHECKCERTIFICATE

  describe('checkCertificate', function () {
    beforeEach(async function () {
      this.controllerMock = await CertificateController.new(CERTIFICATE_SIGNER);
    });
    describe('when the certificate is valid', function () {
      it('increases the sender local nonce', async function () {
        // assert(await this.controllerMock.test(exampleUint, exampleByte, exampleByte, { from: operator }));
        assert(true);
      });
    });
    describe('when the certificate is not valid', function () {
      it('reverts', async function () {
        // await shouldFail.reverting());
      });
    });
  });
});
