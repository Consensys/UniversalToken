const ethWallet = require("ethereumjs-wallet");

const { expectRevert } = require("@openzeppelin/test-helpers");

const BatchTokenIssuer = artifacts.require("BatchTokenIssuer.sol");

const ERC1400HoldableCertificate = artifacts.require("ERC1400HoldableCertificateToken");
const ERC1400TokensValidator = artifacts.require("ERC1400TokensValidator");

const CERTIFICATE_SIGNER = "0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

const partition1_short =
  "7265736572766564000000000000000000000000000000000000000000000000"; // reserved in hex
const partition2_short =
  "6973737565640000000000000000000000000000000000000000000000000000"; // issued in hex
const partition3_short =
  "6c6f636b65640000000000000000000000000000000000000000000000000000"; // locked in hex
const partition4_short =
  "636f6c6c61746572616c00000000000000000000000000000000000000000000"; // collateral in hex
const partition1 = "0x".concat(partition1_short);
const partition2 = "0x".concat(partition2_short);
const partition3 = "0x".concat(partition3_short);
const partition4 = "0x".concat(partition4_short);

const partitions = [partition1, partition2, partition3, partition4];

const CERTIFICATE_VALIDATION_NONE = 0;
const CERTIFICATE_VALIDATION_NONCE = 1;
const CERTIFICATE_VALIDATION_SALT = 2;
const CERTIFICATE_VALIDATION_DEFAULT = CERTIFICATE_VALIDATION_SALT;

const MAX_NUMBER_OF_ISSUANCES_IN_A_BATCH = 40;

const assertBalanceOfByPartition = async (
  _contract,
  _tokenHolder,
  _partition,
  _amount
) => {
  const balanceByPartition = (
    await _contract.balanceOfByPartition(_partition, _tokenHolder)
  ).toNumber();
  assert.equal(balanceByPartition, _amount);
};

contract(
  "BatchTokenIssuer",
  ([owner, controller, unknown]) => {

    before(async function () {  
      this.extension = await ERC1400TokensValidator.new({
        from: unknown,
      });
    });

    beforeEach(async function () {
      this.token = await ERC1400HoldableCertificate.new(
        "ERC1400Token",
        "DAU",
        1,
        [controller],
        [partition1],
        this.extension.address,
        owner,
        CERTIFICATE_SIGNER,
        CERTIFICATE_VALIDATION_DEFAULT,
        { from: controller }
      );
      this.batchIssuer = await BatchTokenIssuer.new();

      await this.extension.addCertificateSigner(this.token.address, this.batchIssuer.address, {
        from: controller,
      });
      
      await this.token.addMinter(this.batchIssuer.address, { from: controller });

      this.issuancePartitions = [];
      this.tokenHolders = [];
      this.values = [];

      for (let index = 0; index < MAX_NUMBER_OF_ISSUANCES_IN_A_BATCH; index++) {
        const wallet = ethWallet.generate();
        this.issuancePartitions.push(
          partitions[Math.floor(Math.random() * partitions.length)]
        );
        this.tokenHolders.push(wallet.getAddressString());
        this.values.push(index);
      }
    });

    // BATCH ISSUEBYPARTITION

    describe("batchIssueByPartition", function () {
      describe("when input is correct", function () {
        describe("when the operator is a minter", function () {
          it("issues tokens for multiple different holders", async function () {
            await this.batchIssuer.batchIssueByPartition(
              this.token.address,
              this.issuancePartitions,
              this.tokenHolders,
              this.values,
              { from: controller }
            );

            for (let i = 0; i < this.issuancePartitions.length; i++) {
              await assertBalanceOfByPartition(
                this.token,
                this.tokenHolders[i],
                this.issuancePartitions[i],
                this.values[i]
              );
            }
          });
        });
        describe("when the operator is not a minter", function () {
          it("reverts", async function () {
            await expectRevert.unspecified(
              this.batchIssuer.batchIssueByPartition(
                this.token.address,
                this.issuancePartitions,
                this.tokenHolders,
                this.values,
                { from: unknown }
              )
            );
          });
        });
      });
      describe("when tokenHoler list is not correct", function () {
        it("reverts", async function () {
          this.tokenHolders.push(unknown);
          await expectRevert.unspecified(
            this.batchIssuer.batchIssueByPartition(
              this.token.address,
              this.issuancePartitions,
              this.tokenHolders,
              this.values,
              { from: controller }
            )
          );
        });
      });
      describe("when values list is not correct", function () {
        it("reverts", async function () {
          this.values.push(10);
          await expectRevert.unspecified(
            this.batchIssuer.batchIssueByPartition(
              this.token.address,
              this.issuancePartitions,
              this.tokenHolders,
              this.values,
              { from: controller }
            )
          );
        });
      });
    });

  }
);
