const BatchBalanceReader = artifacts.require("BatchBalanceReader.sol");

const ERC1400 = artifacts.require("ERC1400CertificateMock");

const CERTIFICATE_SIGNER = "0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630";

const VALID_CERTIFICATE =
  "0x1000000000000000000000000000000000000000000000000000000000000000";

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

const issuanceAmount11 = 11;
const issuanceAmount12 = 12;
const issuanceAmount13 = 13;

const issuanceAmount21 = 21;
const issuanceAmount22 = 22;
const issuanceAmount23 = 23;

const issuanceAmount31 = 31;
const issuanceAmount32 = 32;
const issuanceAmount33 = 33;

const issuanceAmount41 = 41;
const issuanceAmount42 = 42;
const issuanceAmount43 = 43;

contract(
  "BatchBalanceReader",
  ([owner, controller, tokenHolder1, tokenHolder2, tokenHolder3, unknown]) => {
    beforeEach(async function () {
      this.token1 = await ERC1400.new(
        "ERC1400Token",
        "DAU20",
        1,
        [controller],
        CERTIFICATE_SIGNER,
        true,
        partitions
      );
      this.token2 = await ERC1400.new(
        "ERC1400Token",
        "DAU20",
        1,
        [controller],
        CERTIFICATE_SIGNER,
        true,
        partitions
      );
      this.balanceReader = await BatchBalanceReader.new();

      // Token1
      await this.token1.issueByPartition(
        partition1,
        tokenHolder1,
        issuanceAmount11,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token1.issueByPartition(
        partition1,
        tokenHolder2,
        issuanceAmount12,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token1.issueByPartition(
        partition1,
        tokenHolder3,
        issuanceAmount13,
        VALID_CERTIFICATE,
        { from: owner }
      );

      await this.token1.issueByPartition(
        partition2,
        tokenHolder1,
        issuanceAmount21,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token1.issueByPartition(
        partition2,
        tokenHolder2,
        issuanceAmount22,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token1.issueByPartition(
        partition2,
        tokenHolder3,
        issuanceAmount23,
        VALID_CERTIFICATE,
        { from: owner }
      );

      await this.token1.issueByPartition(
        partition3,
        tokenHolder1,
        issuanceAmount31,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token1.issueByPartition(
        partition3,
        tokenHolder2,
        issuanceAmount32,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token1.issueByPartition(
        partition3,
        tokenHolder3,
        issuanceAmount33,
        VALID_CERTIFICATE,
        { from: owner }
      );

      await this.token1.issueByPartition(
        partition4,
        tokenHolder1,
        issuanceAmount41,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token1.issueByPartition(
        partition4,
        tokenHolder2,
        issuanceAmount42,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token1.issueByPartition(
        partition4,
        tokenHolder3,
        issuanceAmount43,
        VALID_CERTIFICATE,
        { from: owner }
      );

      // Token2
      await this.token2.issueByPartition(
        partition1,
        tokenHolder1,
        2 * issuanceAmount11,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token2.issueByPartition(
        partition1,
        tokenHolder2,
        2 * issuanceAmount12,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token2.issueByPartition(
        partition1,
        tokenHolder3,
        2 * issuanceAmount13,
        VALID_CERTIFICATE,
        { from: owner }
      );

      await this.token2.issueByPartition(
        partition2,
        tokenHolder1,
        2 * issuanceAmount21,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token2.issueByPartition(
        partition2,
        tokenHolder2,
        2 * issuanceAmount22,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token2.issueByPartition(
        partition2,
        tokenHolder3,
        2 * issuanceAmount23,
        VALID_CERTIFICATE,
        { from: owner }
      );

      await this.token2.issueByPartition(
        partition3,
        tokenHolder1,
        2 * issuanceAmount31,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token2.issueByPartition(
        partition3,
        tokenHolder2,
        2 * issuanceAmount32,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token2.issueByPartition(
        partition3,
        tokenHolder3,
        2 * issuanceAmount33,
        VALID_CERTIFICATE,
        { from: owner }
      );

      await this.token2.issueByPartition(
        partition4,
        tokenHolder1,
        2 * issuanceAmount41,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token2.issueByPartition(
        partition4,
        tokenHolder2,
        2 * issuanceAmount42,
        VALID_CERTIFICATE,
        { from: owner }
      );
      await this.token2.issueByPartition(
        partition4,
        tokenHolder3,
        2 * issuanceAmount43,
        VALID_CERTIFICATE,
        { from: owner }
      );
    });

    describe("balancesOfByPartition", function () {
      it("returns the partition balances list", async function () {
        const tokenHolders = [tokenHolder1, tokenHolder2, tokenHolder3];
        const tokenAddresses = [this.token1.address, this.token2.address];

        const balancesOfByPartition = await this.balanceReader.balancesOfByPartition(
          tokenHolders,
          tokenAddresses,
          partitions,
          { from: unknown }
        );

        assert.equal(balancesOfByPartition.length, 24);

        // Tokenholder1
        assert.equal(balancesOfByPartition[0], issuanceAmount11);
        assert.equal(balancesOfByPartition[1], issuanceAmount21);
        assert.equal(balancesOfByPartition[2], issuanceAmount31);
        assert.equal(balancesOfByPartition[3], issuanceAmount41);

        assert.equal(balancesOfByPartition[4], 2 * issuanceAmount11);
        assert.equal(balancesOfByPartition[5], 2 * issuanceAmount21);
        assert.equal(balancesOfByPartition[6], 2 * issuanceAmount31);
        assert.equal(balancesOfByPartition[7], 2 * issuanceAmount41);

        // Tokenholder2
        assert.equal(balancesOfByPartition[8], issuanceAmount12);
        assert.equal(balancesOfByPartition[9], issuanceAmount22);
        assert.equal(balancesOfByPartition[10], issuanceAmount32);
        assert.equal(balancesOfByPartition[11], issuanceAmount42);

        assert.equal(balancesOfByPartition[12], 2 * issuanceAmount12);
        assert.equal(balancesOfByPartition[13], 2 * issuanceAmount22);
        assert.equal(balancesOfByPartition[14], 2 * issuanceAmount32);
        assert.equal(balancesOfByPartition[15], 2 * issuanceAmount42);

        // Tokenholder3
        assert.equal(balancesOfByPartition[16], issuanceAmount13);
        assert.equal(balancesOfByPartition[17], issuanceAmount23);
        assert.equal(balancesOfByPartition[18], issuanceAmount33);
        assert.equal(balancesOfByPartition[19], issuanceAmount43);

        assert.equal(balancesOfByPartition[20], 2 * issuanceAmount13);
        assert.equal(balancesOfByPartition[21], 2 * issuanceAmount23);
        assert.equal(balancesOfByPartition[22], 2 * issuanceAmount33);
        assert.equal(balancesOfByPartition[23], 2 * issuanceAmount43);
      });
    });

    describe("balancesOf", function () {
      it("returns the balances list", async function () {
        const tokenHolders = [tokenHolder1, tokenHolder2, tokenHolder3];
        const tokenAddresses = [this.token1.address, this.token2.address];

        const balancesOf = await this.balanceReader.balancesOf(
          tokenHolders,
          tokenAddresses,
          { from: unknown }
        );

        assert.equal(balancesOf.length, 6);

        // Tokenholder1
        assert.equal(
          balancesOf[0],
          issuanceAmount11 +
            issuanceAmount21 +
            issuanceAmount31 +
            issuanceAmount41
        );
        assert.equal(
          balancesOf[1],
          2 *
            (issuanceAmount11 +
              issuanceAmount21 +
              issuanceAmount31 +
              issuanceAmount41)
        );

        // Tokenholder2
        assert.equal(
          balancesOf[2],
          issuanceAmount12 +
            issuanceAmount22 +
            issuanceAmount32 +
            issuanceAmount42
        );
        assert.equal(
          balancesOf[3],
          2 *
            (issuanceAmount12 +
              issuanceAmount22 +
              issuanceAmount32 +
              issuanceAmount42)
        );

        // Tokenholder3
        assert.equal(
          balancesOf[4],
          issuanceAmount13 +
            issuanceAmount23 +
            issuanceAmount33 +
            issuanceAmount43
        );
        assert.equal(
          balancesOf[5],
          2 *
            (issuanceAmount13 +
              issuanceAmount23 +
              issuanceAmount33 +
              issuanceAmount43)
        );
      });
    });
  }
);
