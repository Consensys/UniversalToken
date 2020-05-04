const { shouldFail } = require("openzeppelin-test-helpers");

const { soliditySha3 } = require("web3-utils");

const ERC1400 = artifacts.require("ERC1400CertificateMock");
const ERC1820Registry = artifacts.require("ERC1820Registry");

const ERC1400TokensValidator = artifacts.require("ERC1400TokensValidator");
const ERC1400TokensChecker = artifacts.require("ERC1400TokensChecker");

const BlacklistMock = artifacts.require("BlacklistMock.sol");

const ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";
const ERC1400_TOKENS_CHECKER = "ERC1400TokensChecker";

const ERC1400_TOKENS_SENDER = "ERC1400TokensSender";
const ERC1400_TOKENS_RECIPIENT = "ERC1400TokensRecipient";

const ERC1400TokensSender = artifacts.require("ERC1400TokensSenderMock");
const ERC1400TokensRecipient = artifacts.require("ERC1400TokensRecipientMock");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ZERO_BYTE = "0x";

const EMPTY_BYTE32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

const CERTIFICATE_SIGNER = "0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630";

const VALID_CERTIFICATE =
  "0x1000000000000000000000000000000000000000000000000000000000000000";
const INVALID_CERTIFICATE =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

const INVALID_CERTIFICATE_SENDER =
  "0x1100000000000000000000000000000000000000000000000000000000000000";
const INVALID_CERTIFICATE_RECIPIENT =
  "0x2200000000000000000000000000000000000000000000000000000000000000";
const INVALID_CERTIFICATE_VALIDATOR =
  "0x3300000000000000000000000000000000000000000000000000000000000000";

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

const ESC_00 = "0x00"; // Transfer verifier not setup
const ESC_50 = "0x50"; // 0x50	transfer failure
const ESC_51 = "0x51"; // 0x51	transfer success
const ESC_52 = "0x52"; // 0x52	insufficient balance
// const ESC_53 = '0x53'; // 0x53	insufficient allowance
const ESC_54 = "0x54"; // 0x54	transfers halted (contract paused)
// const ESC_55 = '0x55'; // 0x55	funds locked (lockup period)
const ESC_56 = "0x56"; // 0x56	invalid sender
const ESC_57 = "0x57"; // 0x57	invalid receiver
const ESC_58 = "0x58"; // 0x58	invalid operator (transfer agent)

const issuanceAmount = 1000;

const assertTotalSupply = async (_contract, _amount) => {
  totalSupply = await _contract.totalSupply();
  assert.equal(totalSupply, _amount);
};

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

const assertEscResponse = async (
  _response,
  _escCode,
  _additionalCode,
  _destinationPartition
) => {
  assert.equal(_response[0], _escCode);
  assert.equal(_response[1], _additionalCode);
  assert.equal(_response[2], _destinationPartition);
};

contract("ERC1400 with validator hook", function ([
  owner,
  operator,
  controller,
  tokenHolder,
  recipient,
  unknown,
]) {
  before(async function () {
    this.registry = await ERC1820Registry.at(
      "0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24"
    );
  });

  // HOOKS
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
    this.registry = await ERC1820Registry.at(
      "0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24"
    );
    this.validatorContract = await ERC1400TokensValidator.new(true, false, {
      from: owner,
    });
  });

  describe("setHookContract", function () {
    describe("when the caller is the contract owner", function () {
      it("sets the validator hook", async function () {
        let hookImplementer = await this.registry.getInterfaceImplementer(
          this.token.address,
          soliditySha3(ERC1400_TOKENS_VALIDATOR)
        );
        assert.equal(hookImplementer, ZERO_ADDRESS);

        await this.token.setHookContract(
          this.validatorContract.address,
          ERC1400_TOKENS_VALIDATOR,
          { from: owner }
        );

        hookImplementer = await this.registry.getInterfaceImplementer(
          this.token.address,
          soliditySha3(ERC1400_TOKENS_VALIDATOR)
        );
        assert.equal(hookImplementer, this.validatorContract.address);
      });
    });
    describe("when the caller is not the contract owner", function () {
      it("reverts", async function () {
        await shouldFail.reverting(
          this.token.setHookContract(
            this.validatorContract.address,
            ERC1400_TOKENS_VALIDATOR,
            { from: unknown }
          )
        );
      });
    });
  });

  describe("hooks", function () {
    const amount = issuanceAmount;
    const to = recipient;

    beforeEach(async function () {
      await this.token.setHookContract(
        this.validatorContract.address,
        ERC1400_TOKENS_VALIDATOR,
        { from: owner }
      );
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: owner }
      );
    });
    afterEach(async function () {
      await this.token.setHookContract(ZERO_ADDRESS, ERC1400_TOKENS_VALIDATOR, {
        from: owner,
      });
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
        await shouldFail.reverting(
          this.token.transferWithData(
            to,
            amount,
            INVALID_CERTIFICATE_VALIDATOR,
            { from: tokenHolder }
          )
        );
      });
    });
  });

  // BLACKLIST
  describe("addBlacklisted/renounceBlacklistAdmin", function () {
    beforeEach(async function () {
      this.validatorContract = await ERC1400TokensValidator.new(false, true, {
        from: owner,
      });
      await this.token.setHookContract(
        this.validatorContract.address,
        ERC1400_TOKENS_VALIDATOR,
        { from: owner }
      );
      let hookImplementer = await this.registry.getInterfaceImplementer(
        this.token.address,
        soliditySha3(ERC1400_TOKENS_VALIDATOR)
      );
      assert.equal(hookImplementer, this.validatorContract.address);

      await this.validatorContract.addBlacklisted(tokenHolder, { from: owner });
      await this.validatorContract.addBlacklisted(recipient, { from: owner });
      assert.equal(
        await this.validatorContract.isBlacklisted(tokenHolder),
        true
      );
      assert.equal(await this.validatorContract.isBlacklisted(recipient), true);
    });
    describe("add/remove a blacklist admin", function () {
      describe("when caller is a blacklist admin", function () {
        it("adds a blacklist admin", async function () {
          assert.equal(
            await this.validatorContract.isBlacklistAdmin(unknown),
            false
          );
          await this.validatorContract.addBlacklistAdmin(unknown, {
            from: owner,
          });
          assert.equal(
            await this.validatorContract.isBlacklistAdmin(unknown),
            true
          );
        });
        it("renounces blacklist admin", async function () {
          assert.equal(
            await this.validatorContract.isBlacklistAdmin(unknown),
            false
          );
          await this.validatorContract.addBlacklistAdmin(unknown, {
            from: owner,
          });
          assert.equal(
            await this.validatorContract.isBlacklistAdmin(unknown),
            true
          );
          await this.validatorContract.renounceBlacklistAdmin({
            from: unknown,
          });
          assert.equal(
            await this.validatorContract.isBlacklistAdmin(unknown),
            false
          );
        });
      });
      describe("when caller is not a blacklist admin", function () {
        it("reverts", async function () {
          assert.equal(
            await this.validatorContract.isBlacklistAdmin(unknown),
            false
          );
          await shouldFail.reverting(
            this.validatorContract.addBlacklistAdmin(unknown, { from: unknown })
          );
          assert.equal(
            await this.validatorContract.isBlacklistAdmin(unknown),
            false
          );
        });
      });
    });
  });
  describe("onlyNotBlacklisted", function () {
    beforeEach(async function () {
      this.blacklistMock = await BlacklistMock.new({ from: owner });
    });
    describe("can not call function if blacklisted", function () {
      it("reverts", async function () {
        assert.equal(await this.blacklistMock.isBlacklisted(unknown), false);
        await this.blacklistMock.setBlacklistActivated(true, { from: unknown });
        await this.blacklistMock.addBlacklisted(unknown, { from: owner });
        assert.equal(await this.blacklistMock.isBlacklisted(unknown), true);

        await shouldFail.reverting(
          this.blacklistMock.setBlacklistActivated(true, { from: unknown })
        );
      });
    });
  });

  // WHITELIST - (section to check if certificate-based functions can still be called even when contract has a whitelist and a blacklist)
  describe("whitelist", function () {
    const redeemAmount = 50;
    const transferAmount = 300;
    beforeEach(async function () {
      this.validatorContract = await ERC1400TokensValidator.new(true, true, {
        from: owner,
      });
      await this.token.setHookContract(
        this.validatorContract.address,
        ERC1400_TOKENS_VALIDATOR,
        { from: owner }
      );
      let hookImplementer = await this.registry.getInterfaceImplementer(
        this.token.address,
        soliditySha3(ERC1400_TOKENS_VALIDATOR)
      );
      assert.equal(hookImplementer, this.validatorContract.address);

      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: owner }
      );
    });
    describe("can still call ERC1400 functions", function () {
      describe("can still call issueByPartition", function () {
        it("issues new tokens", async function () {
          await this.token.issueByPartition(
            partition1,
            tokenHolder,
            issuanceAmount,
            VALID_CERTIFICATE,
            { from: owner }
          );
          await assertTotalSupply(this.token, 2 * issuanceAmount);
          await assertBalanceOf(
            this.token,
            tokenHolder,
            partition1,
            2 * issuanceAmount
          );
        });
      });
      describe("can still call redeemByPartition", function () {
        it("redeems the requested amount", async function () {
          await this.token.redeemByPartition(
            partition1,
            redeemAmount,
            VALID_CERTIFICATE,
            { from: tokenHolder }
          );
          await assertTotalSupply(this.token, issuanceAmount - redeemAmount);
          await assertBalanceOf(
            this.token,
            tokenHolder,
            partition1,
            issuanceAmount - redeemAmount
          );
        });
      });
      describe("can still call operatorRedeemByPartition", function () {
        it("redeems the requested amount", async function () {
          await this.token.authorizeOperatorByPartition(partition1, operator, {
            from: tokenHolder,
          });
          await this.token.operatorRedeemByPartition(
            partition1,
            tokenHolder,
            redeemAmount,
            VALID_CERTIFICATE,
            { from: operator }
          );

          await assertTotalSupply(this.token, issuanceAmount - redeemAmount);
          await assertBalanceOf(
            this.token,
            tokenHolder,
            partition1,
            issuanceAmount - redeemAmount
          );
        });
      });
      describe("can still call transferByPartition", function () {
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
      });
      describe("can still call operatorTransferByPartition", function () {
        it("transfers the requested amount", async function () {
          await assertBalanceOf(
            this.token,
            tokenHolder,
            partition1,
            issuanceAmount
          );
          await assertBalanceOf(this.token, recipient, partition1, 0);
          assert.equal(
            await this.token.allowanceByPartition(
              partition1,
              tokenHolder,
              operator
            ),
            0
          );

          const approvedAmount = 400;
          await this.token.approveByPartition(
            partition1,
            operator,
            approvedAmount,
            { from: tokenHolder }
          );
          assert.equal(
            await this.token.allowanceByPartition(
              partition1,
              tokenHolder,
              operator
            ),
            approvedAmount
          );
          await this.token.operatorTransferByPartition(
            partition1,
            tokenHolder,
            recipient,
            transferAmount,
            ZERO_BYTE,
            VALID_CERTIFICATE,
            { from: operator }
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
          assert.equal(
            await this.token.allowanceByPartition(
              partition1,
              tokenHolder,
              operator
            ),
            approvedAmount - transferAmount
          );
        });
      });
      describe("can still call redeem", function () {
        it("redeeems the requested amount", async function () {
          await assertTotalSupply(this.token, issuanceAmount);
          await assertBalance(this.token, tokenHolder, issuanceAmount);

          await this.token.redeem(issuanceAmount, VALID_CERTIFICATE, {
            from: tokenHolder,
          });

          await assertTotalSupply(this.token, 0);
          await assertBalance(this.token, tokenHolder, 0);
        });
      });
      describe("can still call redeemFrom", function () {
        it("redeems the requested amount", async function () {
          await assertTotalSupply(this.token, issuanceAmount);
          await assertBalance(this.token, tokenHolder, issuanceAmount);

          await this.token.authorizeOperator(operator, { from: tokenHolder });
          await this.token.redeemFrom(
            tokenHolder,
            issuanceAmount,
            VALID_CERTIFICATE,
            { from: operator }
          );

          await assertTotalSupply(this.token, 0);
          await assertBalance(this.token, tokenHolder, 0);
        });
      });
      describe("can still call transferWithData", function () {
        it("transfers the requested amount", async function () {
          await assertBalance(this.token, tokenHolder, issuanceAmount);
          await assertBalance(this.token, recipient, 0);

          await this.token.transferWithData(
            recipient,
            transferAmount,
            VALID_CERTIFICATE,
            { from: tokenHolder }
          );

          await assertBalance(
            this.token,
            tokenHolder,
            issuanceAmount - transferAmount
          );
          await assertBalance(this.token, recipient, transferAmount);
        });
      });
      describe("can still call transferFromWithData", function () {
        it("transfers the requested amount", async function () {
          await assertBalance(this.token, tokenHolder, issuanceAmount);
          await assertBalance(this.token, recipient, 0);

          await this.token.authorizeOperator(operator, { from: tokenHolder });
          await this.token.transferFromWithData(
            tokenHolder,
            recipient,
            transferAmount,
            VALID_CERTIFICATE,
            { from: operator }
          );

          await assertBalance(
            this.token,
            tokenHolder,
            issuanceAmount - transferAmount
          );
          await assertBalance(this.token, recipient, transferAmount);
        });
      });
    });
    describe("can not call ERC20 functions", function () {
      describe("can still call transferWithData", function () {
        it("transfers the requested amount", async function () {
          await assertBalance(this.token, tokenHolder, issuanceAmount);
          await assertBalance(this.token, recipient, 0);

          await shouldFail.reverting(
            this.token.transfer(recipient, issuanceAmount, {
              from: tokenHolder,
            })
          );
        });
      });
      describe("can still call transferFromWithData", function () {
        it("transfers the requested amount", async function () {
          await assertBalance(this.token, tokenHolder, issuanceAmount);
          await assertBalance(this.token, recipient, 0);

          await this.token.authorizeOperator(operator, { from: tokenHolder });
          await shouldFail.reverting(
            this.token.transferFrom(tokenHolder, recipient, issuanceAmount, {
              from: operator,
            })
          );
        });
      });
    });
  });

  // WHITELIST ACTIVATED

  describe("setWhitelistActivated", function () {
    beforeEach(async function () {
      this.validatorContract = await ERC1400TokensValidator.new(false, false, {
        from: owner,
      });
      await this.token.setHookContract(
        this.validatorContract.address,
        ERC1400_TOKENS_VALIDATOR,
        { from: owner }
      );
      let hookImplementer = await this.registry.getInterfaceImplementer(
        this.token.address,
        soliditySha3(ERC1400_TOKENS_VALIDATOR)
      );
      assert.equal(hookImplementer, this.validatorContract.address);
    });
    describe("when the caller is the contract owner", function () {
      it("activates the whitelist", async function () {
        assert.equal(
          await this.validatorContract.isWhitelistActivated(),
          false
        );

        await this.validatorContract.setWhitelistActivated(true, {
          from: owner,
        });
        assert.equal(await this.validatorContract.isWhitelistActivated(), true);

        await this.validatorContract.setWhitelistActivated(false, {
          from: owner,
        });
        assert.equal(
          await this.validatorContract.isWhitelistActivated(),
          false
        );

        await this.validatorContract.setWhitelistActivated(true, {
          from: owner,
        });
        assert.equal(await this.validatorContract.isWhitelistActivated(), true);
      });
    });
    describe("when the caller is not the contract owner", function () {
      it("reverts", async function () {
        await shouldFail.reverting(
          this.validatorContract.setWhitelistActivated(true, { from: unknown })
        );
      });
    });
  });

  // BLACKLIST ACTIVATED

  describe("setBlacklistActivated", function () {
    beforeEach(async function () {
      this.validatorContract = await ERC1400TokensValidator.new(false, false, {
        from: owner,
      });
      await this.token.setHookContract(
        this.validatorContract.address,
        ERC1400_TOKENS_VALIDATOR,
        { from: owner }
      );
      let hookImplementer = await this.registry.getInterfaceImplementer(
        this.token.address,
        soliditySha3(ERC1400_TOKENS_VALIDATOR)
      );
      assert.equal(hookImplementer, this.validatorContract.address);
    });
    describe("when the caller is the contract owner", function () {
      it("activates the whitelist", async function () {
        assert.equal(
          await this.validatorContract.isBlacklistActivated(),
          false
        );

        await this.validatorContract.setBlacklistActivated(true, {
          from: owner,
        });
        assert.equal(await this.validatorContract.isBlacklistActivated(), true);

        await this.validatorContract.setBlacklistActivated(false, {
          from: owner,
        });
        assert.equal(
          await this.validatorContract.isBlacklistActivated(),
          false
        );

        await this.validatorContract.setBlacklistActivated(true, {
          from: owner,
        });
        assert.equal(await this.validatorContract.isBlacklistActivated(), true);
      });
    });
    describe("when the caller is not the contract owner", function () {
      it("reverts", async function () {
        await shouldFail.reverting(
          this.validatorContract.setBlacklistActivated(true, { from: unknown })
        );
      });
    });
  });

  // CANTRANSFER

  describe("canTransferByPartition/canOperatorTransferByPartition", function () {
    var localGranularity = 10;
    const amount = 10 * localGranularity;

    before(async function () {
      this.senderContract = await ERC1400TokensSender.new({
        from: tokenHolder,
      });
      await this.registry.setInterfaceImplementer(
        tokenHolder,
        soliditySha3(ERC1400_TOKENS_SENDER),
        this.senderContract.address,
        { from: tokenHolder }
      );

      this.validatorContract = await ERC1400TokensValidator.new(true, false, {
        from: owner,
      });

      this.recipientContract = await ERC1400TokensRecipient.new({
        from: recipient,
      });
      await this.registry.setInterfaceImplementer(
        recipient,
        soliditySha3(ERC1400_TOKENS_RECIPIENT),
        this.recipientContract.address,
        { from: recipient }
      );
    });
    after(async function () {
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

    beforeEach(async function () {
      this.token = await ERC1400.new(
        "ERC1400Token",
        "DAU",
        localGranularity,
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

      await this.token.setHookContract(
        this.validatorContract.address,
        ERC1400_TOKENS_VALIDATOR,
        { from: owner }
      );
    });

    describe("when certificate is valid", function () {
      describe("when checker has been setup", function () {
        before(async function () {
          this.checkerContract = await ERC1400TokensChecker.new({
            from: owner,
          });
        });
        beforeEach(async function () {
          await this.token.setHookContract(
            this.checkerContract.address,
            ERC1400_TOKENS_CHECKER,
            { from: owner }
          );
        });
        describe("when the operator is authorized", function () {
          describe("when balance is sufficient", function () {
            describe("when receiver is not the zero address", function () {
              describe("when sender is eligible", function () {
                describe("when validator is ok", function () {
                  describe("when receiver is eligible", function () {
                    describe("when the amount is a multiple of the granularity", function () {
                      it("returns Ethereum status code 51 (canTransferByPartition)", async function () {
                        const response = await this.token.canTransferByPartition(
                          partition1,
                          recipient,
                          amount,
                          VALID_CERTIFICATE,
                          { from: tokenHolder }
                        );
                        await assertEscResponse(
                          response,
                          ESC_51,
                          EMPTY_BYTE32,
                          partition1
                        );
                      });
                      it("returns Ethereum status code 51 (canOperatorTransferByPartition)", async function () {
                        const response = await this.token.canOperatorTransferByPartition(
                          partition1,
                          tokenHolder,
                          recipient,
                          amount,
                          ZERO_BYTE,
                          VALID_CERTIFICATE,
                          { from: tokenHolder }
                        );
                        await assertEscResponse(
                          response,
                          ESC_51,
                          EMPTY_BYTE32,
                          partition1
                        );
                      });
                    });
                    describe("when the amount is not a multiple of the granularity", function () {
                      it("returns Ethereum status code 50", async function () {
                        const response = await this.token.canTransferByPartition(
                          partition1,
                          recipient,
                          1,
                          VALID_CERTIFICATE,
                          { from: tokenHolder }
                        );
                        await assertEscResponse(
                          response,
                          ESC_50,
                          EMPTY_BYTE32,
                          partition1
                        );
                      });
                    });
                  });
                  describe("when receiver is not eligible", function () {
                    it("returns Ethereum status code 57", async function () {
                      const response = await this.token.canTransferByPartition(
                        partition1,
                        recipient,
                        amount,
                        INVALID_CERTIFICATE_RECIPIENT,
                        { from: tokenHolder }
                      );
                      await assertEscResponse(
                        response,
                        ESC_57,
                        EMPTY_BYTE32,
                        partition1
                      );
                    });
                  });
                });
                describe("when validator is not ok", function () {
                  it("returns Ethereum status code 54 (canTransferByPartition)", async function () {
                    const response = await this.token.canTransferByPartition(
                      partition1,
                      recipient,
                      amount,
                      INVALID_CERTIFICATE_VALIDATOR,
                      { from: tokenHolder }
                    );
                    await assertEscResponse(
                      response,
                      ESC_54,
                      EMPTY_BYTE32,
                      partition1
                    );
                  });
                });
              });
              describe("when sender is not eligible", function () {
                it("returns Ethereum status code 56", async function () {
                  const response = await this.token.canTransferByPartition(
                    partition1,
                    recipient,
                    amount,
                    INVALID_CERTIFICATE_SENDER,
                    { from: tokenHolder }
                  );
                  await assertEscResponse(
                    response,
                    ESC_56,
                    EMPTY_BYTE32,
                    partition1
                  );
                });
              });
            });
            describe("when receiver is the zero address", function () {
              it("returns Ethereum status code 57", async function () {
                const response = await this.token.canTransferByPartition(
                  partition1,
                  ZERO_ADDRESS,
                  amount,
                  VALID_CERTIFICATE,
                  { from: tokenHolder }
                );
                await assertEscResponse(
                  response,
                  ESC_57,
                  EMPTY_BYTE32,
                  partition1
                );
              });
            });
          });
          describe("when balance is not sufficient", function () {
            it("returns Ethereum status code 52 (insuficient global balance)", async function () {
              const response = await this.token.canTransferByPartition(
                partition1,
                recipient,
                issuanceAmount + localGranularity,
                VALID_CERTIFICATE,
                { from: tokenHolder }
              );
              await assertEscResponse(
                response,
                ESC_52,
                EMPTY_BYTE32,
                partition1
              );
            });
            it("returns Ethereum status code 52 (insuficient partition balance)", async function () {
              await this.token.issueByPartition(
                partition2,
                tokenHolder,
                localGranularity,
                VALID_CERTIFICATE,
                { from: owner }
              );
              const response = await this.token.canTransferByPartition(
                partition2,
                recipient,
                amount,
                VALID_CERTIFICATE,
                { from: tokenHolder }
              );
              await assertEscResponse(
                response,
                ESC_52,
                EMPTY_BYTE32,
                partition2
              );
            });
          });
        });
        describe("when the operator is not authorized", function () {
          it("returns Ethereum status code 58 (canOperatorTransferByPartition)", async function () {
            const response = await this.token.canOperatorTransferByPartition(
              partition1,
              operator,
              recipient,
              amount,
              ZERO_BYTE,
              VALID_CERTIFICATE,
              { from: tokenHolder }
            );
            await assertEscResponse(response, ESC_58, EMPTY_BYTE32, partition1);
          });
        });
      });
      describe("when checker has not been setup", function () {
        it("returns empty Ethereum status code 00 (canTransferByPartition)", async function () {
          const response = await this.token.canTransferByPartition(
            partition1,
            recipient,
            amount,
            VALID_CERTIFICATE,
            { from: tokenHolder }
          );
          await assertEscResponse(response, ESC_00, EMPTY_BYTE32, partition1);
        });
      });
    });
    describe("when certificate is not valid", function () {
      it("returns Ethereum status code 54 (canTransferByPartition)", async function () {
        const response = await this.token.canTransferByPartition(
          partition1,
          recipient,
          amount,
          INVALID_CERTIFICATE,
          { from: tokenHolder }
        );
        await assertEscResponse(response, ESC_54, EMPTY_BYTE32, partition1);
      });
      it("returns Ethereum status code 54 (canOperatorTransferByPartition)", async function () {
        const response = await this.token.canOperatorTransferByPartition(
          partition1,
          tokenHolder,
          recipient,
          amount,
          ZERO_BYTE,
          INVALID_CERTIFICATE,
          { from: tokenHolder }
        );
        await assertEscResponse(response, ESC_54, EMPTY_BYTE32, partition1);
      });
    });
  });

  // WHITELIST/BLACKLIST EXTENSION

  describe("whitelist/blacklist", function () {
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

    describe("when token has a withlist", function () {
      beforeEach(async function () {
        this.validatorContract = await ERC1400TokensValidator.new(true, false, {
          from: owner,
        });
        await this.token.setHookContract(
          this.validatorContract.address,
          ERC1400_TOKENS_VALIDATOR,
          { from: owner }
        );
        let hookImplementer = await this.registry.getInterfaceImplementer(
          this.token.address,
          soliditySha3(ERC1400_TOKENS_VALIDATOR)
        );
        assert.equal(hookImplementer, this.validatorContract.address);

        await this.validatorContract.addWhitelisted(tokenHolder, {
          from: owner,
        });
        await this.validatorContract.addWhitelisted(recipient, { from: owner });
      });
      describe("when the sender and the recipient are whitelisted", function () {
        beforeEach(async function () {
          assert.equal(
            await this.validatorContract.isWhitelisted(tokenHolder),
            true
          );
          assert.equal(
            await this.validatorContract.isWhitelisted(recipient),
            true
          );
        });
        const amount = issuanceAmount;

        it("transfers the requested amount", async function () {
          await this.token.transfer(recipient, amount, { from: tokenHolder });
          await assertBalance(this.token, tokenHolder, issuanceAmount - amount);
          await assertBalance(this.token, recipient, amount);
        });
      });
      describe("when the sender is not whitelisted", function () {
        const amount = issuanceAmount;

        beforeEach(async function () {
          await this.validatorContract.removeWhitelisted(tokenHolder, {
            from: owner,
          });

          assert.equal(
            await this.validatorContract.isWhitelisted(tokenHolder),
            false
          );
          assert.equal(
            await this.validatorContract.isWhitelisted(recipient),
            true
          );
        });
        it("reverts", async function () {
          await shouldFail.reverting(
            this.token.transfer(recipient, amount, { from: tokenHolder })
          );
        });
      });
      describe("when the recipient is not whitelisted", function () {
        const amount = issuanceAmount;

        beforeEach(async function () {
          await this.validatorContract.removeWhitelisted(recipient, {
            from: owner,
          });

          assert.equal(
            await this.validatorContract.isWhitelisted(tokenHolder),
            true
          );
          assert.equal(
            await this.validatorContract.isWhitelisted(recipient),
            false
          );
        });
        it("reverts", async function () {
          await shouldFail.reverting(
            this.token.transfer(recipient, amount, { from: tokenHolder })
          );
        });
      });
    });
    describe("when token has a blacklist", function () {
      beforeEach(async function () {
        this.validatorContract = await ERC1400TokensValidator.new(false, true, {
          from: owner,
        });
        await this.token.setHookContract(
          this.validatorContract.address,
          ERC1400_TOKENS_VALIDATOR,
          { from: owner }
        );
        let hookImplementer = await this.registry.getInterfaceImplementer(
          this.token.address,
          soliditySha3(ERC1400_TOKENS_VALIDATOR)
        );
        assert.equal(hookImplementer, this.validatorContract.address);

        await this.validatorContract.addBlacklisted(tokenHolder, {
          from: owner,
        });
        await this.validatorContract.addBlacklisted(recipient, { from: owner });
        assert.equal(
          await this.validatorContract.isBlacklisted(tokenHolder),
          true
        );
        assert.equal(
          await this.validatorContract.isBlacklisted(recipient),
          true
        );
      });
      describe("when the blacklist is activated", function () {
        describe("when both the sender and the recipient are blacklisted", function () {
          const amount = issuanceAmount;

          it("reverts", async function () {
            await shouldFail.reverting(
              this.token.transfer(recipient, amount, { from: tokenHolder })
            );
          });
        });
        describe("when the sender is blacklisted", function () {
          const amount = issuanceAmount;

          it("reverts", async function () {
            await this.validatorContract.removeBlacklisted(recipient, {
              from: owner,
            });
            await shouldFail.reverting(
              this.token.transfer(recipient, amount, { from: tokenHolder })
            );
          });
        });
        describe("when the recipient is blacklisted", function () {
          const amount = issuanceAmount;

          it("reverts", async function () {
            await this.validatorContract.removeBlacklisted(tokenHolder, {
              from: owner,
            });
            await shouldFail.reverting(
              this.token.transfer(recipient, amount, { from: tokenHolder })
            );
          });
        });
        describe("when neither the sender nor the recipient are blacklisted", function () {
          const amount = issuanceAmount;

          it("transfers the requested amount", async function () {
            await this.validatorContract.removeBlacklisted(tokenHolder, {
              from: owner,
            });
            await this.validatorContract.removeBlacklisted(recipient, {
              from: owner,
            });

            await this.token.transfer(recipient, amount, { from: tokenHolder });
            await assertBalance(
              this.token,
              tokenHolder,
              issuanceAmount - amount
            );
            await assertBalance(this.token, recipient, amount);
          });
        });
      });
      describe("when the blacklist is not activated", function () {
        beforeEach(async function () {
          await this.validatorContract.setBlacklistActivated(false, {
            from: owner,
          });
        });
        describe("when both the sender and the recipient are blacklisted", function () {
          const amount = issuanceAmount;

          it("transfers the requested amount", async function () {
            await this.token.transfer(recipient, amount, { from: tokenHolder });
            await assertBalance(
              this.token,
              tokenHolder,
              issuanceAmount - amount
            );
            await assertBalance(this.token, recipient, amount);
          });
        });
      });
    });
    describe("when token has neither a whitelist, nor a blacklist", function () {
      const amount = issuanceAmount;

      it("transfers the requested amount", async function () {
        await this.token.transfer(recipient, amount, { from: tokenHolder });
        await assertBalance(this.token, tokenHolder, issuanceAmount - amount);
        await assertBalance(this.token, recipient, amount);
      });
    });
  });

  // TRANSFERFROM

  describe("transferFrom", function () {
    const approvedAmount = 10000;
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

    describe("when token has a withelist", function () {
      beforeEach(async function () {
        this.validatorContract = await ERC1400TokensValidator.new(true, false, {
          from: owner,
        });
        await this.token.setHookContract(
          this.validatorContract.address,
          ERC1400_TOKENS_VALIDATOR,
          { from: owner }
        );
        let hookImplementer = await this.registry.getInterfaceImplementer(
          this.token.address,
          soliditySha3(ERC1400_TOKENS_VALIDATOR)
        );
        assert.equal(hookImplementer, this.validatorContract.address);

        await this.validatorContract.addWhitelisted(tokenHolder, {
          from: owner,
        });
        await this.validatorContract.addWhitelisted(recipient, { from: owner });
      });
      describe("when the sender and the recipient are whitelisted", function () {
        beforeEach(async function () {
          assert.equal(
            await this.validatorContract.isWhitelisted(tokenHolder),
            true
          );
          assert.equal(
            await this.validatorContract.isWhitelisted(recipient),
            true
          );
        });
        describe("when the operator is approved", function () {
          beforeEach(async function () {
            // await this.token.authorizeOperator(operator, { from: tokenHolder});
            await this.token.approve(operator, approvedAmount, {
              from: tokenHolder,
            });
          });
          describe("when the amount is a multiple of the granularity", function () {
            describe("when the recipient is not the zero address", function () {
              describe("when the sender has enough balance", function () {
                const amount = 500;

                it("transfers the requested amount", async function () {
                  await this.token.transferFrom(
                    tokenHolder,
                    recipient,
                    amount,
                    { from: operator }
                  );
                  await assertBalance(
                    this.token,
                    tokenHolder,
                    issuanceAmount - amount
                  );
                  await assertBalance(this.token, recipient, amount);

                  assert.equal(
                    await this.token.allowance(tokenHolder, operator),
                    approvedAmount - amount
                  );
                });

                it("emits a sent + a transfer event", async function () {
                  const { logs } = await this.token.transferFrom(
                    tokenHolder,
                    recipient,
                    amount,
                    { from: operator }
                  );

                  assert.equal(logs.length, 2);

                  assert.equal(logs[0].event, "Transfer");
                  assert.equal(logs[0].args.from, tokenHolder);
                  assert.equal(logs[0].args.to, recipient);
                  assert.equal(logs[0].args.value, amount);

                  assert.equal(logs[1].event, "TransferByPartition");
                  assert.equal(logs[1].args.fromPartition, partition1);
                  assert.equal(logs[1].args.operator, operator);
                  assert.equal(logs[1].args.from, tokenHolder);
                  assert.equal(logs[1].args.to, recipient);
                  assert.equal(logs[1].args.value, amount);
                  assert.equal(logs[1].args.data, null);
                  assert.equal(logs[1].args.operatorData, null);
                });
              });
              describe("when the sender does not have enough balance", function () {
                const amount = approvedAmount + 1;

                it("reverts", async function () {
                  await shouldFail.reverting(
                    this.token.transferFrom(tokenHolder, recipient, amount, {
                      from: operator,
                    })
                  );
                });
              });
            });

            describe("when the recipient is the zero address", function () {
              const amount = issuanceAmount;

              it("reverts", async function () {
                await shouldFail.reverting(
                  this.token.transferFrom(tokenHolder, ZERO_ADDRESS, amount, {
                    from: operator,
                  })
                );
              });
            });
          });
          describe("when the amount is not a multiple of the granularity", function () {
            it("reverts", async function () {
              this.token = await ERC1400.new(
                "ERC1400Token",
                "DAU",
                2,
                [],
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
              await shouldFail.reverting(
                this.token.transferFrom(tokenHolder, recipient, 3, {
                  from: operator,
                })
              );
            });
          });
        });
        describe("when the operator is not approved", function () {
          const amount = 100;
          describe("when the operator is not approved but authorized", function () {
            it("transfers the requested amount", async function () {
              await this.token.authorizeOperator(operator, {
                from: tokenHolder,
              });
              assert.equal(
                await this.token.allowance(tokenHolder, operator),
                0
              );

              await this.token.transferFrom(tokenHolder, recipient, amount, {
                from: operator,
              });

              await assertBalance(
                this.token,
                tokenHolder,
                issuanceAmount - amount
              );
              await assertBalance(this.token, recipient, amount);
            });
          });
          describe("when the operator is not approved and not authorized", function () {
            it("reverts", async function () {
              await shouldFail.reverting(
                this.token.transferFrom(tokenHolder, recipient, amount, {
                  from: operator,
                })
              );
            });
          });
        });
      });
      describe("when the sender is not whitelisted", function () {
        const amount = approvedAmount;
        beforeEach(async function () {
          await this.validatorContract.removeWhitelisted(tokenHolder, {
            from: owner,
          });

          assert.equal(
            await this.validatorContract.isWhitelisted(tokenHolder),
            false
          );
          assert.equal(
            await this.validatorContract.isWhitelisted(recipient),
            true
          );
        });
        it("reverts", async function () {
          await shouldFail.reverting(
            this.token.transferFrom(tokenHolder, recipient, amount, {
              from: operator,
            })
          );
        });
      });
      describe("when the recipient is not whitelisted", function () {
        const amount = approvedAmount;
        beforeEach(async function () {
          await this.validatorContract.removeWhitelisted(recipient, {
            from: owner,
          });

          assert.equal(
            await this.validatorContract.isWhitelisted(tokenHolder),
            true
          );
          assert.equal(
            await this.validatorContract.isWhitelisted(recipient),
            false
          );
        });
        it("reverts", async function () {
          await shouldFail.reverting(
            this.token.transferFrom(tokenHolder, recipient, amount, {
              from: operator,
            })
          );
        });
      });
    });
    describe("when token has no withelist", function () {});
  });

  // PAUSABLE EXTENSION

  describe("pausable", function () {
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

    describe("when contract is not paused", function () {
      it("transfers the requested amount", async function () {
        await this.token.transfer(recipient, transferAmount, {
          from: tokenHolder,
        });
        await assertBalance(
          this.token,
          tokenHolder,
          issuanceAmount - transferAmount
        );
        await assertBalance(this.token, recipient, transferAmount);
      });
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
        await this.token.transferByPartition(
          partition1,
          recipient,
          0,
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
    });
    describe("when contract is paused", function () {
      beforeEach(async function () {
        this.validatorContract = await ERC1400TokensValidator.new(true, false, {
          from: owner,
        });
        await this.token.setHookContract(
          this.validatorContract.address,
          ERC1400_TOKENS_VALIDATOR,
          { from: owner }
        );
        let hookImplementer = await this.registry.getInterfaceImplementer(
          this.token.address,
          soliditySha3(ERC1400_TOKENS_VALIDATOR)
        );
        assert.equal(hookImplementer, this.validatorContract.address);

        await this.validatorContract.pause({ from: owner });
      });
      it("reverts", async function () {
        await assertBalance(this.token, tokenHolder, issuanceAmount);
        await shouldFail.reverting(
          this.token.transfer(recipient, issuanceAmount, { from: tokenHolder })
        );
      });
      it("reverts", async function () {
        await assertBalanceOf(
          this.token,
          tokenHolder,
          partition1,
          issuanceAmount
        );

        await shouldFail.reverting(
          this.token.transferByPartition(
            partition1,
            recipient,
            transferAmount,
            VALID_CERTIFICATE,
            { from: tokenHolder }
          )
        );
      });
    });
  });
});
