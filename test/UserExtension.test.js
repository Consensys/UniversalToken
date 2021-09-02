const { expectRevert } = require("@openzeppelin/test-helpers");

const { soliditySha3 } = require("web3-utils");

const ERC1400 = artifacts.require("ERC1400");
const ERC1820Registry = artifacts.require("IERC1820Registry");

const ERC1400TokensSender = artifacts.require("ERC1400TokensSenderMock");
const ERC1400TokensRecipient = artifacts.require("ERC1400TokensRecipientMock");

const ERC1400_TOKENS_SENDER = "ERC1400TokensSender";
const ERC1400_TOKENS_RECIPIENT = "ERC1400TokensRecipient";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

const CERTIFICATE_SIGNER = "0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630";
const VALID_CERTIFICATE =
  "0x1000000000000000000000000000000000000000000000000000000000000000";

const INVALID_CERTIFICATE_SENDER =
  "0x1100000000000000000000000000000000000000000000000000000000000000";
const INVALID_CERTIFICATE_RECIPIENT =
  "0x2200000000000000000000000000000000000000000000000000000000000000";

const partition1_short =
  "5265736572766564000000000000000000000000000000000000000000000000"; // Reserved in hex
const partition2_short =
  "4973737565640000000000000000000000000000000000000000000000000000"; // Issued in hex
const partition3_short =
  "4c6f636b65640000000000000000000000000000000000000000000000000000"; // Locked in hex

const partition1 = "0x".concat(partition1_short);
const partition2 = "0x".concat(partition2_short);
const partition3 = "0x".concat(partition3_short);

const partitions = [partition1, partition2, partition3];

const issuanceAmount = 1000;

contract("ERC1400 with sender and recipient hooks", function ([
  owner,
  operator,
  controller,
  tokenHolder,
  recipient,
  unknown,
]) {
  beforeEach(async function () {
    this.registry = await ERC1820Registry.at(
      "0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24"
    );
  });

  // HOOKS

  describe("hooks", function () {
    const amount = issuanceAmount;
    const to = recipient;

    beforeEach(async function () {
      this.token = await ERC1400.new(
        "ERC1400Token",
        "DAU",
        1,
        [controller],
        partitions,
        { from: owner }
      );
      this.registry = await ERC1820Registry.at(
        "0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24"
      );

      this.senderContract = await ERC1400TokensSender.new({
        from: tokenHolder,
      });
      await this.registry.setInterfaceImplementer(
        tokenHolder,
        soliditySha3(ERC1400_TOKENS_SENDER),
        this.senderContract.address,
        { from: tokenHolder }
      );

      this.recipientContract = await ERC1400TokensRecipient.new({
        from: recipient,
      });
      await this.registry.setInterfaceImplementer(
        recipient,
        soliditySha3(ERC1400_TOKENS_RECIPIENT),
        this.recipientContract.address,
        { from: recipient }
      );

      await this.token.issue(tokenHolder, issuanceAmount, VALID_CERTIFICATE, {
        from: owner,
      });
    });
    afterEach(async function () {
      await this.registry.setInterfaceImplementer(
        tokenHolder,
        soliditySha3(ERC1400_TOKENS_SENDER),
        ZERO_ADDRESS,
        { from: tokenHolder }
      );
      await this.registry.setInterfaceImplementer(
        recipient,
        soliditySha3(ERC1400_TOKENS_RECIPIENT),
        ZERO_ADDRESS,
        { from: recipient }
      );
    });
    describe("when the transfer is successfull", function () {
      it("transfers the requested amount", async function () {
        await this.token.transferWithData(to, amount, VALID_CERTIFICATE, {
          from: tokenHolder,
        });
        const senderBalance = await this.token.balanceOf(tokenHolder);
        assert.equal(senderBalance, issuanceAmount - amount);

        const recipientBalance = await this.token.balanceOf(to);
        assert.equal(recipientBalance, amount);
      });
    });
    describe("when the transfer fails", function () {
      it("sender hook reverts", async function () {
        // Default sender hook failure data for the mock only: 0x1100000000000000000000000000000000000000000000000000000000000000
        await expectRevert.unspecified(
          this.token.transferWithData(to, amount, INVALID_CERTIFICATE_SENDER, {
            from: tokenHolder,
          })
        );
      });
      it("recipient hook reverts", async function () {
        // Default recipient hook failure data for the mock only: 0x2200000000000000000000000000000000000000000000000000000000000000
        await expectRevert.unspecified(
          this.token.transferWithData(
            to,
            amount,
            INVALID_CERTIFICATE_RECIPIENT,
            { from: tokenHolder }
          )
        );
      });
    });
  });
});
