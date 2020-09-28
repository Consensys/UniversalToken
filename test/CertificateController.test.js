const { expectRevert } = require("@openzeppelin/test-helpers");

const ERC1400 = artifacts.require("ERC1400CertificateMock");

const CERTIFICATE_SIGNER = "0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630";
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

const VALID_CERTIFICATE =
  "0x1000000000000000000000000000000000000000000000000000000000000000";
const INVALID_CERTIFICATE =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

const partition1_short =
  "7265736572766564000000000000000000000000000000000000000000000000"; // reserved in hex
const partition2_short =
  "6973737565640000000000000000000000000000000000000000000000000000"; // issued in hex
const partition3_short =
  "6c6f636b65640000000000000000000000000000000000000000000000000000"; // locked in hex
const partition1 = "0x".concat(partition1_short);
const partition2 = "0x".concat(partition2_short);
const partition3 = "0x".concat(partition3_short);
const partitions = [partition1, partition2, partition3];

const issuanceAmount = 1000;

const assertBalanceOf = async (
  _contract,
  _tokenHolder,
  _partition,
  _amount
) => {
  await assertBalance(_contract, _tokenHolder, _amount);
  await assertBalanceOfByPartition(
    _contract,
    _tokenHolder,
    _partition,
    _amount
  );
};

const assertBalanceOfByPartition = async (
  _contract,
  _tokenHolder,
  _partition,
  _amount
) => {
  balanceByPartition = await _contract.balanceOfByPartition(
    _partition,
    _tokenHolder
  );
  assert.equal(balanceByPartition, _amount);
};

const assertBalance = async (_contract, _tokenHolder, _amount) => {
  balance = await _contract.balanceOf(_tokenHolder);
  assert.equal(balance, _amount);
};

contract(
  "ERC1400 with CertificateController",
  ([owner, operator, controller, tokenHolder, recipient, unknown]) => {
    // SETCERTIFICATESIGNER

    describe("setCertificateSigner", function () {
      beforeEach(async function () {
        this.token = await ERC1400.new(
          "ERC1400Token",
          "DAU",
          1,
          [controller],
          CERTIFICATE_SIGNER,
          true,
          partitions
        );
      });
      describe("when the sender is the contract owner", function () {
        describe("when the new certificate signer address is valid", function () {
          it("sets the operator as certificate signer", async function () {
            assert(!(await this.token.certificateSigners(operator)));
            await this.token.setCertificateSigner(operator, true, {
              from: owner,
            });
            assert(await this.token.certificateSigners(operator));
          });
          it("sets the operator as certificate signer", async function () {
            assert(!(await this.token.certificateSigners(operator)));
            await this.token.setCertificateSigner(operator, true, {
              from: owner,
            });
            assert(await this.token.certificateSigners(operator));
            await this.token.setCertificateSigner(operator, false, {
              from: owner,
            });
            assert(!(await this.token.certificateSigners(operator)));
          });
        });
        describe("when the certificate signer address is not valid", function () {
          it("reverts", async function () {
            await expectRevert.unspecified(
              this.token.setCertificateSigner(ZERO_ADDRESS, true, {
                from: owner,
              }) // Action Blocked - Not a valid address
            );
          });
          it("reverts", async function () {
            await expectRevert.unspecified(
              this.token.setCertificateSigner(ZERO_ADDRESS, false, {
                from: owner,
              }) // Action Blocked - Not a valid address
            );
          });
        });
      });
      describe("when the sender is not the contract owner", function () {
        it("reverts", async function () {
          await expectRevert.unspecified(
            this.token.setCertificateSigner(operator, true, { from: unknown })
          );
        });
      });
    });

    // SET CERTIFICATE CONTROLLER ACTIVATED

    describe("setCertificateControllerActivated", function () {
      beforeEach(async function () {
        this.token = await ERC1400.new(
          "ERC1400Token",
          "DAU",
          1,
          [controller],
          CERTIFICATE_SIGNER,
          true,
          partitions
        );
      });
      describe("when the sender is the contract owner", function () {
        it("deactivates the certificate controller", async function () {
          await this.token.setCertificateControllerActivated(false, {
            from: owner,
          });
          assert.isTrue(!(await this.token.certificateControllerActivated()));
        });
        it("deactivates and reactivates the certificate controller", async function () {
          assert.isTrue(await this.token.certificateControllerActivated());
          await this.token.setCertificateControllerActivated(false, {
            from: owner,
          });

          await this.token.issueByPartition(
            partition1,
            tokenHolder,
            issuanceAmount,
            INVALID_CERTIFICATE,
            { from: owner }
          );
          await this.token.issueByPartition(
            partition1,
            tokenHolder,
            issuanceAmount,
            VALID_CERTIFICATE,
            { from: owner }
          );

          assert.isTrue(!(await this.token.certificateControllerActivated()));
          await this.token.setCertificateControllerActivated(true, {
            from: owner,
          });
          assert.isTrue(await this.token.certificateControllerActivated());

          await expectRevert.unspecified(
            this.token.issueByPartition(
              partition1,
              tokenHolder,
              issuanceAmount,
              INVALID_CERTIFICATE,
              { from: owner }
            )
          );
          await this.token.issueByPartition(
            partition1,
            tokenHolder,
            issuanceAmount,
            VALID_CERTIFICATE,
            { from: owner }
          );
        });
      });
      describe("when the sender is not the contract owner", function () {
        it("reverts", async function () {
          await expectRevert.unspecified(
            this.token.setCertificateControllerActivated(true, {
              from: unknown,
            })
          );
        });
      });
    });

    // TRANSFERBYPARTITION

    describe("transferByPartition", function () {
      const transferAmount = 300;

      beforeEach(async function () {
        this.token = await ERC1400.new(
          "ERC1400Token",
          "DAU",
          1,
          [controller],
          CERTIFICATE_SIGNER,
          true,
          partitions
        );
        await this.token.issueByPartition(
          partition1,
          tokenHolder,
          issuanceAmount,
          VALID_CERTIFICATE,
          { from: owner }
        );
      });

      describe("when thecertifiacte is valid", function () {
        it("transfers the requested amount", async function () {
          await assertBalanceOf(
            this.token,
            tokenHolder,
            partition1,
            issuanceAmount
          );
          await assertBalanceOf(this.token, recipient, partition1, 0);

          await this.token.transferByPartition(
            partition1,
            recipient,
            transferAmount,
            VALID_CERTIFICATE,
            { from: tokenHolder }
          );

          await assertBalanceOf(
            this.token,
            tokenHolder,
            partition1,
            issuanceAmount - transferAmount
          );
          await assertBalanceOf(
            this.token,
            recipient,
            partition1,
            transferAmount
          );
        });
        it("emits a Checked event", async function () {
          const { logs } = await this.token.transferByPartition(
            partition1,
            recipient,
            transferAmount,
            VALID_CERTIFICATE,
            { from: tokenHolder }
          );

          assert.equal(logs.length, 3);

          assert.equal(logs[0].event, "Checked");
          assert.equal(logs[0].args.sender, tokenHolder);

          assert.equal(logs[1].event, "Transfer");
          assert.equal(logs[1].args.from, tokenHolder);
          assert.equal(logs[1].args.to, recipient);
          assert.equal(logs[1].args.value, transferAmount);

          assert.equal(logs[2].event, "TransferByPartition");
          assert.equal(logs[2].args.fromPartition, partition1);
          assert.equal(logs[2].args.operator, tokenHolder);
          assert.equal(logs[2].args.from, tokenHolder);
          assert.equal(logs[2].args.to, recipient);
          assert.equal(logs[2].args.value, transferAmount);
          assert.equal(logs[2].args.data, VALID_CERTIFICATE);
          assert.equal(logs[2].args.operatorData, null);
        });
      });
      describe("when thecertifiacte is not valid", function () {
        it("reverts", async function () {
          await expectRevert.unspecified(
            this.token.transferByPartition(
              partition1,
              recipient,
              transferAmount,
              INVALID_CERTIFICATE,
              { from: tokenHolder }
            )
          );
        });
      });
    });
  }
);
