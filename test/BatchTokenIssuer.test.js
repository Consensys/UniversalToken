const ethWallet = require("ethereumjs-wallet");

const { shouldFail } = require("openzeppelin-test-helpers");

const BatchTokenIssuer = artifacts.require("BatchTokenIssuer.sol");

const ERC1400 = artifacts.require("ERC1400CertificateMock");

const CERTIFICATE_SIGNER = "0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630";

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

const MAX_NUMBER_OF_ISSUANCES_IN_A_BATCH = 46;

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
  ([owner, controller, tokenMinter1, tokenMinter2, unknown]) => {
    beforeEach(async function () {
      this.token = await ERC1400.new(
        "ERC1400Token",
        "DAU20",
        1,
        [controller],
        CERTIFICATE_SIGNER,
        true,
        [partition1]
      );
      this.batchIssuer = await BatchTokenIssuer.new();

      await this.token.setCertificateSigner(this.batchIssuer.address, true, {
        from: owner,
      });
      await this.token.addMinter(this.batchIssuer.address, { from: owner });

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
        describe("when the operator is the owner of the token contract", function () {
          it("issues tokens for multiple different holders", async function () {
            await this.batchIssuer.batchIssueByPartition(
              this.token.address,
              this.issuancePartitions,
              this.tokenHolders,
              this.values,
              { from: owner }
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
        describe("when the operator has been declared as minter in the BatchTokenIssuer contract", function () {
          it("issues tokens for multiple different holders", async function () {
            await this.batchIssuer.setTokenMinters(
              this.token.address,
              [tokenMinter1],
              { from: owner }
            );
            await this.batchIssuer.batchIssueByPartition(
              this.token.address,
              this.issuancePartitions,
              this.tokenHolders,
              this.values,
              { from: tokenMinter1 }
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
        describe("when the operator neither the owner of the token contract, nor a minter in the BatchTokenIssuer contract", function () {
          it("issues tokens for multiple different holders", async function () {
            await shouldFail.reverting(
              this.batchIssuer.batchIssueByPartition(
                this.token.address,
                this.issuancePartitions,
                this.tokenHolders,
                this.values,
                { from: tokenMinter1 }
              )
            );
          });
        });
      });
      describe("when tokenHoler list is not correct", function () {
        it("reverts", async function () {
          this.tokenHolders.push(unknown);
          await shouldFail.reverting(
            this.batchIssuer.batchIssueByPartition(
              this.token.address,
              this.issuancePartitions,
              this.tokenHolders,
              this.values,
              { from: owner }
            )
          );
        });
      });
      describe("when values list is not correct", function () {
        it("reverts", async function () {
          this.values.push(10);
          await shouldFail.reverting(
            this.batchIssuer.batchIssueByPartition(
              this.token.address,
              this.issuancePartitions,
              this.tokenHolders,
              this.values,
              { from: owner }
            )
          );
        });
      });
    });

    // SET TOKEN MINTERS

    describe("setTokenMinters", function () {
      describe("when the caller is the token contract owner", function () {
        it("sets the operators as token minters", async function () {
          let tokenMinters = await this.batchIssuer.tokenMinters(
            this.token.address
          );
          assert.equal(tokenMinters.length, 0);

          await this.batchIssuer.setTokenMinters(
            this.token.address,
            [tokenMinter1, tokenMinter2],
            { from: owner }
          );

          tokenMinters = await this.batchIssuer.tokenMinters(
            this.token.address
          );
          assert.equal(tokenMinters.length, 2);
          assert.equal(tokenMinters[0], tokenMinter1);
          assert.equal(tokenMinters[1], tokenMinter2);
        });
      });
      describe("when the caller is an other token minter", function () {
        it("sets the operators as token minters", async function () {
          let tokenMinters = await this.batchIssuer.tokenMinters(
            this.token.address
          );
          assert.equal(tokenMinters.length, 0);

          await this.batchIssuer.setTokenMinters(
            this.token.address,
            [tokenMinter2],
            { from: owner }
          );

          tokenMinters = await this.batchIssuer.tokenMinters(
            this.token.address
          );
          assert.equal(tokenMinters.length, 1);
          assert.equal(tokenMinters[0], tokenMinter2);

          await this.batchIssuer.setTokenMinters(
            this.token.address,
            [tokenMinter1, unknown],
            { from: tokenMinter2 }
          );

          tokenMinters = await this.batchIssuer.tokenMinters(
            this.token.address
          );
          assert.equal(tokenMinters.length, 2);
          assert.equal(tokenMinters[0], tokenMinter1);
          assert.equal(tokenMinters[1], unknown);
        });
      });
      describe("when the caller is neither the token contract owner nor a token minter", function () {
        it("reverts", async function () {
          await shouldFail.reverting(
            this.batchIssuer.setTokenMinters(
              this.token.address,
              [tokenMinter1, tokenMinter2],
              { from: unknown }
            )
          );
        });
      });
    });
  }
);
