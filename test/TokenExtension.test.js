const { expectRevert } = require("@openzeppelin/test-helpers");
const { soliditySha3 } = require("web3-utils");
const { advanceTimeAndBlock } = require("./utils/time")
const { newSecretHashPair, newHoldId } = require("./utils/crypto");
const { assert } = require("chai");

const ERC1400HoldableCertificate = artifacts.require("ERC1400HoldableCertificateTokenMock");
const ERC1820Registry = artifacts.require("ERC1820Registry");

const ERC1400TokensValidator = artifacts.require("ERC1400TokensValidator");
const ERC1400TokensValidatorMock = artifacts.require("ERC1400TokensValidatorMock");
const ERC1400TokensChecker = artifacts.require("ERC1400TokensChecker");

const PauserMock = artifacts.require("PauserMock.sol");
const AllowlistMock = artifacts.require("AllowlistMock.sol");
const BlocklistMock = artifacts.require("BlocklistMock.sol");

const ClockMock = artifacts.require("ClockMock.sol");

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

const HOLD_STATUS_NON_EXISTENT = 0;
const HOLD_STATUS_ORDERED = 1;
const HOLD_STATUS_EXECUTED = 2;
const HOLD_STATUS_EXECUTED_AND_KEPT_OPEN = 3;
const HOLD_STATUS_RELEASED_BY_NOTARY = 4;
const HOLD_STATUS_RELEASED_BY_PAYEE = 5;
const HOLD_STATUS_RELEASED_ON_EXPIRATION = 6;

const issuanceAmount = 1000;
const holdAmount = 600;
const smallHoldAmount = 400;

const SECONDS_IN_AN_HOUR = 3600;
const SECONDS_IN_A_DAY = 24*SECONDS_IN_AN_HOUR;

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

const assertAllowListActivated = async (
  _extension,
  _token,
  _expectedValue
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  assert.equal(_expectedValue, tokenSetup[0]);
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
    _value,
    tokenSetup[1],
    tokenSetup[2],
    tokenSetup[3],
    tokenSetup[4],
    { from: _sender }
  );
}

const assertBlockListActivated = async (
  _extension,
  _token,
  _expectedValue
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  assert.equal(_expectedValue, tokenSetup[1]);
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
    _value,
    tokenSetup[2],
    tokenSetup[3],
    tokenSetup[4],
    { from: _sender }
  );
}

const assertHoldsActivated = async (
  _extension,
  _token,
  _expectedValue
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  assert.equal(_expectedValue, tokenSetup[2]);
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
    _value,
    tokenSetup[3],
    tokenSetup[4],
    { from: _sender }
  );
}

const assertSelfHoldsActivated = async (
  _extension,
  _token,
  _expectedValue
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  assert.equal(_expectedValue, tokenSetup[3]);
}

const setSelfHoldsActivated = async (
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
    { from: _sender }
  );
}

const assertTokenHasExtension = async (
  _registry,
  _extension,
  _token,
) => {
  let hookImplementer = await _registry.getInterfaceImplementer(
    _token.address,
    soliditySha3(ERC1400_TOKENS_VALIDATOR)
  );
  assert.equal(hookImplementer, _extension.address);
}

const addTokenController = async (
  _extension,
  _token,
  _sender,
  _newController
) => {
  const tokenSetup = await _extension.retrieveTokenSetup(_token.address);
  const controllerList = tokenSetup[4];
  if (!controllerList.includes(_newController)) {
    controllerList.push(_newController);
  }
  await _extension.registerTokenSetup(
    _token.address,
    tokenSetup[0],
    tokenSetup[1],
    tokenSetup[2],
    tokenSetup[3],
    controllerList,
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
  const controllerList = tokenSetup[4];
  assert.equal(_value, controllerList.includes(_controller))
}

const setNewExtensionForToken = async (
  _extension,
  _token,
  _sender,
) => {
  const controllers = await _token.controllers();
  await _extension.registerTokenSetup(
    _token.address,
    true,
    true,
    true,
    false,
    controllers,
    { from: _sender }
  );

  await _token.setTokenExtension(
    _extension.address,
    ERC1400_TOKENS_VALIDATOR,
    true,
    true,
    { from: _sender }
  );
}

contract("ERC1400HoldableCertificate with validator hook", function ([
  deployer,
  owner,
  operator,
  controller,
  tokenHolder,
  recipient,
  notary,
  unknown,
  tokenController1,
  tokenController2
]) {
  before(async function () {
    this.registry = await ERC1820Registry.at(
      "0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24"
    );

    this.clock = await ClockMock.new();

    this.validatorContract = await ERC1400TokensValidator.new({
      from: deployer,
    });
  });

  beforeEach(async function () {
    this.token = await ERC1400HoldableCertificate.new(
      "ERC1400Token",
      "DAU",
      1,
      [controller],
      partitions,
      this.validatorContract.address,
      owner,
      CERTIFICATE_SIGNER,
      true,
      { from: controller }
    );
  });

  // HOOKS
  describe("setTokenExtension", function () {
    describe("when the caller is the contract owner", function () {
      describe("when the the validator contract is not already a minter", function () {
        describe("when there is was no previous validator contract", function () {
          it("sets the validator hook", async function () {
            this.token = await ERC1400HoldableCertificate.new(
              "ERC1400Token",
              "DAU",
              1,
              [controller],
              partitions,
              ZERO_ADDRESS,
              owner,
              CERTIFICATE_SIGNER,
              true,
              { from: controller }
            );

            assert.equal(await this.token.owner(), owner)

            let hookImplementer = await this.registry.getInterfaceImplementer(
              this.token.address,
              soliditySha3(ERC1400_TOKENS_VALIDATOR)
            );
            assert.equal(hookImplementer, ZERO_ADDRESS);
            assert.equal(await this.token.isOperator(this.validatorContract.address, unknown), false)
            assert.equal(await this.token.isMinter(this.validatorContract.address), false)
            assert.equal(await this.token.certificateSigners(this.validatorContract.address), false)
    
            await this.token.setTokenExtension(
              this.validatorContract.address,
              ERC1400_TOKENS_VALIDATOR,
              true,
              true,
              { from: owner }
            );
    
            hookImplementer = await this.registry.getInterfaceImplementer(
              this.token.address,
              soliditySha3(ERC1400_TOKENS_VALIDATOR)
            );
            assert.equal(hookImplementer, this.validatorContract.address);
            assert.equal(await this.token.isOperator(this.validatorContract.address, unknown), true)
            assert.equal(await this.token.isMinter(this.validatorContract.address), true)
            assert.equal(await this.token.certificateSigners(this.validatorContract.address), true)
          });
        });
        describe("when there is was a previous validator contract", function () {
          describe("when the previous validator contract was a minter", function () {
            it("sets the validator hook (with controller rights)", async function () {
              assert.equal(await this.token.owner(), owner)

              await assertTokenHasExtension(
                this.registry,
                this.validatorContract,
                this.token,
              );
              assert.equal(await this.token.isOperator(this.validatorContract.address, unknown), true)
              assert.equal(await this.token.isMinter(this.validatorContract.address), true)
              assert.equal(await this.token.certificateSigners(this.validatorContract.address), true)
  
              this.validatorContract2 = await ERC1400TokensValidator.new({
                from: deployer,
              });
      
              await this.token.setTokenExtension(
                this.validatorContract2.address,
                ERC1400_TOKENS_VALIDATOR,
                true,
                true,
                { from: owner }
              );
      
              await assertTokenHasExtension(
                this.registry,
                this.validatorContract2,
                this.token,
              );
              assert.equal(await this.token.isOperator(this.validatorContract2.address, unknown), true)
              assert.equal(await this.token.isMinter(this.validatorContract2.address), true)
              assert.equal(await this.token.certificateSigners(this.validatorContract2.address), true)
  
              assert.equal(await this.token.isOperator(this.validatorContract.address, unknown), false)
              assert.equal(await this.token.isMinter(this.validatorContract.address), false)
              assert.equal(await this.token.certificateSigners(this.validatorContract.address), false)
            });
            it("sets the validator hook (without controller rights)", async function () {
              assert.equal(await this.token.owner(), owner)

              await assertTokenHasExtension(
                this.registry,
                this.validatorContract,
                this.token,
              );
              assert.equal(await this.token.isOperator(this.validatorContract.address, unknown), true)
              assert.equal(await this.token.isMinter(this.validatorContract.address), true)
              assert.equal(await this.token.certificateSigners(this.validatorContract.address), true)
  
              this.validatorContract2 = await ERC1400TokensValidator.new({
                from: deployer,
              });
      
              await this.token.setTokenExtension(
                this.validatorContract2.address,
                ERC1400_TOKENS_VALIDATOR,
                true,
                false,
                { from: owner }
              );
      
              await assertTokenHasExtension(
                this.registry,
                this.validatorContract2,
                this.token,
              );
              assert.equal(await this.token.isOperator(this.validatorContract2.address, unknown), false)
              assert.equal(await this.token.isMinter(this.validatorContract2.address), true)
              assert.equal(await this.token.certificateSigners(this.validatorContract2.address), true)
  
              assert.equal(await this.token.isOperator(this.validatorContract.address, unknown), false)
              assert.equal(await this.token.isMinter(this.validatorContract.address), false)
              assert.equal(await this.token.certificateSigners(this.validatorContract.address), false)
            });
          });
          describe("when the previous validator contract was not a minter", function () {
            it("sets the validator hook", async function () {  
              this.validatorContract2 = await ERC1400TokensValidatorMock.new({
                from: deployer,
              });
      
              await this.token.setTokenExtension(
                this.validatorContract2.address,
                ERC1400_TOKENS_VALIDATOR,
                true,
                true,
                { from: owner }
              );
      
              await assertTokenHasExtension(
                this.registry,
                this.validatorContract2,
                this.token,
              );
              assert.equal(await this.token.isOperator(this.validatorContract2.address, unknown), true)
              assert.equal(await this.token.isMinter(this.validatorContract2.address), true)
              assert.equal(await this.token.certificateSigners(this.validatorContract2.address), true)

              await this.validatorContract2.renounceMinter(this.token.address, { from: owner });

              assert.equal(await this.token.isOperator(this.validatorContract2.address, unknown), true)
              assert.equal(await this.token.isMinter(this.validatorContract2.address), false)
              assert.equal(await this.token.certificateSigners(this.validatorContract2.address), true)
      
              await this.token.setTokenExtension(
                this.validatorContract.address,
                ERC1400_TOKENS_VALIDATOR,
                true,
                true,
                { from: owner }
              );

              assert.equal(await this.token.isOperator(this.validatorContract2.address, unknown), false)
              assert.equal(await this.token.isMinter(this.validatorContract2.address), false)
              assert.equal(await this.token.certificateSigners(this.validatorContract2.address), false)
      
              await assertTokenHasExtension(
                this.registry,
                this.validatorContract,
                this.token,
              );
              assert.equal(await this.token.isOperator(this.validatorContract.address, unknown), true)
              assert.equal(await this.token.isMinter(this.validatorContract.address), true)
              assert.equal(await this.token.certificateSigners(this.validatorContract.address), true)
            });
          });
        });
      });
      describe("when the the validator contract is already a minter", function () {
        it("sets the validator hook", async function () {
          this.validatorContract2 = await ERC1400TokensValidatorMock.new({
            from: deployer,
          });

          await assertTokenHasExtension(
            this.registry,
            this.validatorContract,
            this.token,
          );

          await this.token.addMinter(this.validatorContract2.address, { from: controller });

          assert.equal(await this.token.isOperator(this.validatorContract2.address, unknown), false)
          assert.equal(await this.token.isMinter(this.validatorContract2.address), true)
          assert.equal(await this.token.certificateSigners(this.validatorContract2.address), false)
  
          await this.token.setTokenExtension(
            this.validatorContract2.address,
            ERC1400_TOKENS_VALIDATOR,
            true,
            true,
            { from: owner }
          );
  
          await assertTokenHasExtension(
            this.registry,
            this.validatorContract2,
            this.token,
          );
          assert.equal(await this.token.isOperator(this.validatorContract2.address, unknown), true)
          assert.equal(await this.token.isMinter(this.validatorContract2.address), true)
          assert.equal(await this.token.certificateSigners(this.validatorContract2.address), true)
        });
      });
    });
    describe("when the caller is not the contract owner", function () {
      it("reverts", async function () {
        this.validatorContract2 = await ERC1400TokensValidator.new({
          from: deployer,
        });
        await expectRevert.unspecified(
          this.token.setTokenExtension(
            this.validatorContract2.address,
            ERC1400_TOKENS_VALIDATOR,
            true,
            true,
            { from: controller }
          )
        );
      });
    });
  });

  // PAUSER
  describe("addPauser/renouncePauser", function () {
    beforeEach(async function () {
      await assertTokenHasExtension(
        this.registry,
        this.validatorContract,
        this.token,
      );

      // await this.validatorContract.addBlocklisted(this.token.address, tokenHolder, { from: controller });
      // await this.validatorContract.addBlocklisted(this.token.address, recipient, { from: controller });
      // assert.equal(await this.validatorContract.isBlocklisted(this.token.address, tokenHolder), true);
      // assert.equal(await this.validatorContract.isBlocklisted(this.token.address, recipient), true);
    });
    describe("add/remove a pauser", function () {
      describe("when caller is a pauser", function () {
        it("adds a pauser as token owner", async function () {
          assert.equal(
            await this.validatorContract.isPauser(this.token.address, unknown),
            false
          );
          await this.validatorContract.addPauser(this.token.address, unknown, {
            from: owner,
          });
          assert.equal(
            await this.validatorContract.isPauser(this.token.address, unknown),
            true
          );
        });
        it("adds a pauser as token controller", async function () {
          assert.equal(
            await this.validatorContract.isPauser(this.token.address, unknown),
            false
          );
          await this.validatorContract.addPauser(this.token.address, unknown, {
            from: controller,
          });
          assert.equal(
            await this.validatorContract.isPauser(this.token.address, unknown),
            true
          );
        });
        it("adds a pauser as pauser", async function () {
          assert.equal(
            await this.validatorContract.isPauser(this.token.address, unknown),
            false
          );
          await this.validatorContract.addPauser(this.token.address, unknown, {
            from: controller,
          });
          assert.equal(
            await this.validatorContract.isPauser(this.token.address, unknown),
            true
          );

          assert.equal(
            await this.validatorContract.isPauser(this.token.address, tokenHolder),
            false
          );
          await this.validatorContract.addPauser(this.token.address, tokenHolder, {
            from: unknown,
          });
          assert.equal(
            await this.validatorContract.isPauser(this.token.address, tokenHolder),
            true
          );
        });
        it("renounces pauser", async function () {
          assert.equal(
            await this.validatorContract.isPauser(this.token.address, unknown),
            false
          );
          await this.validatorContract.addPauser(this.token.address, unknown, {
            from: controller,
          });
          assert.equal(
            await this.validatorContract.isPauser(this.token.address, unknown),
            true
          );
          await this.validatorContract.renouncePauser(this.token.address, {
            from: unknown,
          });
          assert.equal(
            await this.validatorContract.isPauser(this.token.address, unknown),
            false
          );
        });
      });
      describe("when caller is not a pauser", function () {
        it("reverts", async function () {
          assert.equal(
            await this.validatorContract.isPauser(this.token.address, unknown),
            false
          );
          await expectRevert.unspecified(
            this.validatorContract.addPauser(this.token.address, unknown, { from: unknown })
          );
          assert.equal(
            await this.validatorContract.isPauser(this.token.address, unknown),
            false
          );
        });
      });
    });
  });
  describe("onlyPauser [mock for coverage]", function () {
    beforeEach(async function () {
      this.pauserMock = await PauserMock.new(this.token.address, { from: owner });
    });
    describe("can not call function if pauser", function () {
      it("reverts", async function () {
        assert.equal(await this.pauserMock.isPauser(this.token.address, unknown), false);
        await expectRevert.unspecified(
          this.pauserMock.mockFunction(this.token.address, true, { from: unknown })
        );
        await this.pauserMock.addPauser(this.token.address, unknown, { from: owner });
        assert.equal(await this.pauserMock.isPauser(this.token.address, unknown), true);

        await this.pauserMock.mockFunction(this.token.address, true, { from: unknown });
      });
    });
  });

  // BLOCKLIST ADMIN
  describe("addBlocklisted/renounceBlocklistAdmin", function () {
    beforeEach(async function () {
      await assertTokenHasExtension(
        this.registry,
        this.validatorContract,
        this.token,
      );

      await this.validatorContract.addBlocklisted(this.token.address, tokenHolder, { from: controller });
      await this.validatorContract.addBlocklisted(this.token.address, recipient, { from: controller });
      assert.equal(await this.validatorContract.isBlocklisted(this.token.address, tokenHolder), true);
      assert.equal(await this.validatorContract.isBlocklisted(this.token.address, recipient), true);
    });
    describe("add/remove a blocklist admin", function () {
      describe("when caller is a blocklist admin", function () {
        it("adds a blocklist admin as owner", async function () {
          assert.equal(
            await this.validatorContract.isBlocklistAdmin(this.token.address, unknown),
            false
          );
          await this.validatorContract.addBlocklistAdmin(this.token.address, unknown, {
            from: owner,
          });
          assert.equal(
            await this.validatorContract.isBlocklistAdmin(this.token.address, unknown),
            true
          );
        });
        it("adds a blocklist admin as token controller", async function () {
          assert.equal(
            await this.validatorContract.isBlocklistAdmin(this.token.address, unknown),
            false
          );
          await this.validatorContract.addBlocklistAdmin(this.token.address, unknown, {
            from: controller,
          });
          assert.equal(
            await this.validatorContract.isBlocklistAdmin(this.token.address, unknown),
            true
          );
        });
        it("adds a blocklist admin as blocklist admin", async function () {
          assert.equal(
            await this.validatorContract.isBlocklistAdmin(this.token.address, unknown),
            false
          );
          await this.validatorContract.addBlocklistAdmin(this.token.address, unknown, {
            from: controller,
          });
          assert.equal(
            await this.validatorContract.isBlocklistAdmin(this.token.address, unknown),
            true
          );

          assert.equal(
            await this.validatorContract.isBlocklistAdmin(this.token.address, tokenHolder),
            false
          );
          await this.validatorContract.addBlocklistAdmin(this.token.address, tokenHolder, {
            from: unknown,
          });
          assert.equal(
            await this.validatorContract.isBlocklistAdmin(this.token.address, tokenHolder),
            true
          );
        });
        it("renounces blocklist admin", async function () {
          assert.equal(
            await this.validatorContract.isBlocklistAdmin(this.token.address, unknown),
            false
          );
          await this.validatorContract.addBlocklistAdmin(this.token.address, unknown, {
            from: controller,
          });
          assert.equal(
            await this.validatorContract.isBlocklistAdmin(this.token.address, unknown),
            true
          );
          await this.validatorContract.renounceBlocklistAdmin(this.token.address, {
            from: unknown,
          });
          assert.equal(
            await this.validatorContract.isBlocklistAdmin(this.token.address, unknown),
            false
          );
        });
      });
      describe("when caller is not a blocklist admin", function () {
        it("reverts", async function () {
          assert.equal(
            await this.validatorContract.isBlocklistAdmin(this.token.address, unknown),
            false
          );
          await expectRevert.unspecified(
            this.validatorContract.addBlocklistAdmin(this.token.address, unknown, { from: unknown })
          );
          assert.equal(
            await this.validatorContract.isBlocklistAdmin(this.token.address, unknown),
            false
          );
        });
      });
    });
  });
  describe("onlyNotBlocklisted [mock for coverage]", function () {
    beforeEach(async function () {
      this.blocklistMock = await BlocklistMock.new(this.token.address, { from: owner });
    });
    describe("can not call function if blocklisted", function () {
      it("reverts", async function () {
        assert.equal(await this.blocklistMock.isBlocklisted(this.token.address, unknown), false);
        await this.blocklistMock.mockFunction(this.token.address, true, { from: unknown });
        await this.blocklistMock.addBlocklisted(this.token.address, unknown, { from: owner });
        assert.equal(await this.blocklistMock.isBlocklisted(this.token.address, unknown), true);

        await expectRevert.unspecified(
          this.blocklistMock.mockFunction(this.token.address, true, { from: unknown })
        );
      });
    });
  });
  describe("onlyBlocklistAdmin [mock for coverage]", function () {
    beforeEach(async function () {
      this.blocklistMock = await BlocklistMock.new(this.token.address, { from: owner });
    });
    describe("can not call function if not blocklist admin", function () {
      it("reverts", async function () {
        assert.equal(await this.blocklistMock.isBlocklistAdmin(this.token.address, unknown), false);
        await expectRevert.unspecified(
          this.blocklistMock.addBlocklistAdmin(this.token.address, unknown, { from: unknown })
        );
        assert.equal(await this.blocklistMock.isBlocklistAdmin(this.token.address, unknown), false);
        await this.blocklistMock.addBlocklistAdmin(this.token.address, unknown, { from: owner })
        assert.equal(await this.blocklistMock.isBlocklistAdmin(this.token.address, unknown), true);
      });
    });
  });

  // ALLOWLIST ADMIN
  describe("addAllowlisted/renounceAllowlistAdmin", function () {
    beforeEach(async function () {
      await assertTokenHasExtension(
        this.registry,
        this.validatorContract,
        this.token,
      );

      await this.validatorContract.addAllowlisted(this.token.address, tokenHolder, { from: controller });
      await this.validatorContract.addAllowlisted(this.token.address, recipient, { from: controller });
      assert.equal(await this.validatorContract.isAllowlisted(this.token.address, tokenHolder), true);
      assert.equal(await this.validatorContract.isAllowlisted(this.token.address, recipient), true);
    });
    describe("add/remove a allowlist admin", function () {
      describe("when caller is a allowlist admin", function () {
        it("adds a allowlist admin as owner", async function () {
          assert.equal(
            await this.validatorContract.isAllowlistAdmin(this.token.address, unknown),
            false
          );
          await this.validatorContract.addAllowlistAdmin(this.token.address, unknown, {
            from: owner,
          });
          assert.equal(
            await this.validatorContract.isAllowlistAdmin(this.token.address, unknown),
            true
          );
        });
        it("adds a allowlist admin as token controller", async function () {
          assert.equal(
            await this.validatorContract.isAllowlistAdmin(this.token.address, unknown),
            false
          );
          await this.validatorContract.addAllowlistAdmin(this.token.address, unknown, {
            from: controller,
          });
          assert.equal(
            await this.validatorContract.isAllowlistAdmin(this.token.address, unknown),
            true
          );
        });
        it("adds a allowlist admin as allowlist admin", async function () {
          assert.equal(
            await this.validatorContract.isAllowlistAdmin(this.token.address, unknown),
            false
          );
          await this.validatorContract.addAllowlistAdmin(this.token.address, unknown, {
            from: controller,
          });
          assert.equal(
            await this.validatorContract.isAllowlistAdmin(this.token.address, unknown),
            true
          );

          assert.equal(
            await this.validatorContract.isAllowlistAdmin(this.token.address, tokenHolder),
            false
          );
          await this.validatorContract.addAllowlistAdmin(this.token.address, tokenHolder, {
            from: unknown,
          });
          assert.equal(
            await this.validatorContract.isAllowlistAdmin(this.token.address, tokenHolder),
            true
          );
        });
        it("renounces allowlist admin", async function () {
          assert.equal(
            await this.validatorContract.isAllowlistAdmin(this.token.address, unknown),
            false
          );
          await this.validatorContract.addAllowlistAdmin(this.token.address, unknown, {
            from: controller,
          });
          assert.equal(
            await this.validatorContract.isAllowlistAdmin(this.token.address, unknown),
            true
          );
          await this.validatorContract.renounceAllowlistAdmin(this.token.address, {
            from: unknown,
          });
          assert.equal(
            await this.validatorContract.isAllowlistAdmin(this.token.address, unknown),
            false
          );
        });
      });
      describe("when caller is not a allowlist admin", function () {
        it("reverts", async function () {
          assert.equal(
            await this.validatorContract.isAllowlistAdmin(this.token.address, unknown),
            false
          );
          await expectRevert.unspecified(
            this.validatorContract.addAllowlistAdmin(this.token.address, unknown, { from: unknown })
          );
          assert.equal(
            await this.validatorContract.isAllowlistAdmin(this.token.address, unknown),
            false
          );
        });
      });
    });
  });
  describe("onlyNotAllowlisted [mock for coverage]", function () {
    beforeEach(async function () {
      this.allowlistMock = await AllowlistMock.new(this.token.address, { from: owner });
    });
    describe("can not call function if allowlisted", function () {
      it("reverts", async function () {
        assert.equal(await this.allowlistMock.isAllowlisted(this.token.address, unknown), false);
        await this.allowlistMock.mockFunction(this.token.address, true, { from: unknown });
        await this.allowlistMock.addAllowlisted(this.token.address, unknown, { from: owner });
        assert.equal(await this.allowlistMock.isAllowlisted(this.token.address, unknown), true);

        await expectRevert.unspecified(
          this.allowlistMock.mockFunction(this.token.address, true, { from: unknown })
        );
      });
    });
  });
  describe("onlyAllowlistAdmin [mock for coverage]", function () {
    beforeEach(async function () {
      this.allowlistMock = await AllowlistMock.new(this.token.address, { from: owner });
    });
    describe("can not call function if not allowlist admin", function () {
      it("reverts", async function () {
        assert.equal(await this.allowlistMock.isAllowlistAdmin(this.token.address, unknown), false);
        await expectRevert.unspecified(
          this.allowlistMock.addAllowlistAdmin(this.token.address, unknown, { from: unknown })
        );
        assert.equal(await this.allowlistMock.isAllowlistAdmin(this.token.address, unknown), false);
        this.allowlistMock.addAllowlistAdmin(this.token.address, unknown, { from: owner })
        assert.equal(await this.allowlistMock.isAllowlistAdmin(this.token.address, unknown), true);
      });
    });
  });

  // ALLOWLIST - (section to check if certificate-based functions can still be called even when contract has a allowlist and a blocklist)
  describe("allowlist", function () {
    const redeemAmount = 50;
    const transferAmount = 300;
    beforeEach(async function () {
      await assertTokenHasExtension(
        this.registry,
        this.validatorContract,
        this.token,
      );

      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
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
            { from: controller }
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

          await expectRevert.unspecified(
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
          await expectRevert.unspecified(
            this.token.transferFrom(tokenHolder, recipient, issuanceAmount, {
              from: operator,
            })
          );
        });
      });
    });
  });

  // ALLOWLIST ACTIVATED

  describe("setAllowlistActivated", function () {
    beforeEach(async function () {
      await assertTokenHasExtension(
        this.registry,
        this.validatorContract,
        this.token,
      );
    });
    describe("when the caller is the contract owner", function () {
      it("activates the allowlist", async function () {
        await assertAllowListActivated(
          this.validatorContract,
          this.token,
          true
        );

        await setAllowListActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        );

        await assertAllowListActivated(
          this.validatorContract,
          this.token,
          false
        )
      });
    });
    describe("when the caller is not the contract owner", function () {
      it("reverts", async function () {
        await expectRevert.unspecified(
          setAllowListActivated(
            this.validatorContract,
            this.token,
            unknown,
            false
          )
        );
      });
    });
  });

  // BLOCKLIST ACTIVATED

  describe("setBlocklistActivated", function () {
    beforeEach(async function () {
      await assertTokenHasExtension(
        this.registry,
        this.validatorContract,
        this.token,
      );
    });
    describe("when the caller is the contract owner", function () {
      it("activates the blocklist", async function () {
        await assertBlockListActivated(
          this.validatorContract,
          this.token,
          true
        );

        await setBlockListActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        );

        await assertBlockListActivated(
          this.validatorContract,
          this.token,
          false
        )
      });
    });
    describe("when the caller is not the contract owner", function () {
      it("reverts", async function () {
        await expectRevert.unspecified(
          setBlockListActivated(
            this.validatorContract,
            this.token,
            unknown,
            false
          )
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
      this.token2 = await ERC1400HoldableCertificate.new(
        "ERC1400Token",
        "DAU",
        localGranularity,
        [controller],
        partitions,
        this.validatorContract.address,
        owner,
        CERTIFICATE_SIGNER,
        true,
        { from: controller }
      );

      await this.token2.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
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
          await this.token2.setTokenExtension(
            this.checkerContract.address,
            ERC1400_TOKENS_CHECKER,
            true,
            true,
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
                        const response = await this.token2.canTransferByPartition(
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
                        const response = await this.token2.canOperatorTransferByPartition(
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
                        const response = await this.token2.canTransferByPartition(
                          partition1,
                          recipient,
                          1, // amount
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
                      const response = await this.token2.canTransferByPartition(
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
                    const secretHashPair = newSecretHashPair();  
                    await this.validatorContract.holdFrom(this.token2.address, newHoldId(), tokenHolder, recipient, notary, partition1, issuanceAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller })
                    const response = await this.token2.canTransferByPartition(
                      partition1,
                      recipient,
                      amount,
                      VALID_CERTIFICATE,
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
                  const response = await this.token2.canTransferByPartition(
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
                const response = await this.token2.canTransferByPartition(
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
              const response = await this.token2.canTransferByPartition(
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
              await this.token2.issueByPartition(
                partition2,
                tokenHolder,
                localGranularity,
                VALID_CERTIFICATE,
                { from: controller }
              );
              const response = await this.token2.canTransferByPartition(
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
            const response = await this.token2.canOperatorTransferByPartition(
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
          const response = await this.token2.canTransferByPartition(
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
        const response = await this.token2.canTransferByPartition(
          partition1,
          recipient,
          amount,
          INVALID_CERTIFICATE,
          { from: tokenHolder }
        );
        await assertEscResponse(response, ESC_54, EMPTY_BYTE32, partition1);
      });
      it("returns Ethereum status code 54 (canOperatorTransferByPartition)", async function () {
        const response = await this.token2.canOperatorTransferByPartition(
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

  // ALLOWLIST/BLOCKLIST EXTENSION

  describe("allowlist/blocklist", function () {
    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );
    });

    describe("when token allowlist is activated", function () {
      beforeEach(async function () {
        await assertAllowListActivated(
          this.validatorContract,
          this.token,
          true
        );

        await assertTokenHasExtension(
          this.registry,
          this.validatorContract,
          this.token,
        );

        await this.validatorContract.addAllowlisted(this.token.address, tokenHolder, {
          from: controller,
        });
        await this.validatorContract.addAllowlisted(this.token.address, recipient, { from: controller });
      });
      describe("when the sender and the recipient are allowlisted", function () {
        beforeEach(async function () {
          assert.equal(
            await this.validatorContract.isAllowlisted(this.token.address, tokenHolder),
            true
          );
          assert.equal(
            await this.validatorContract.isAllowlisted(this.token.address, recipient),
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
      describe("when the sender is not allowlisted", function () {
        const amount = issuanceAmount;

        beforeEach(async function () {
          await this.validatorContract.removeAllowlisted(this.token.address, tokenHolder, {
            from: owner,
          });

          assert.equal(
            await this.validatorContract.isAllowlisted(this.token.address, tokenHolder),
            false
          );
          assert.equal(
            await this.validatorContract.isAllowlisted(this.token.address, recipient),
            true
          );
        });
        it("reverts", async function () {
          await expectRevert.unspecified(
            this.token.transfer(recipient, amount, { from: tokenHolder })
          );
        });
      });
      describe("when the recipient is not allowlisted", function () {
        const amount = issuanceAmount;

        beforeEach(async function () {
          await this.validatorContract.removeAllowlisted(this.token.address, recipient, {
            from: owner,
          });

          assert.equal(
            await this.validatorContract.isAllowlisted(this.token.address, tokenHolder),
            true
          );
          assert.equal(
            await this.validatorContract.isAllowlisted(this.token.address, recipient),
            false
          );
        });
        it("reverts", async function () {
          await expectRevert.unspecified(
            this.token.transfer(recipient, amount, { from: tokenHolder })
          );
        });
      });
    });
    describe("when token blocklist is activated", function () {
      beforeEach(async function () {
        await assertTokenHasExtension(
          this.registry,
          this.validatorContract,
          this.token,
        );

        await setAllowListActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        )
        await assertAllowListActivated(
          this.validatorContract,
          this.token,
          false
        );
        await setBlockListActivated(
          this.validatorContract,
          this.token,
          controller,
          true
        )
        await assertBlockListActivated(
          this.validatorContract,
          this.token,
          true
        );

        await this.validatorContract.addBlocklisted(this.token.address, tokenHolder, {
          from: controller,
        });
        await this.validatorContract.addBlocklisted(this.token.address, recipient, { from: controller });
        assert.equal(
          await this.validatorContract.isBlocklisted(this.token.address, tokenHolder),
          true
        );
        assert.equal(
          await this.validatorContract.isBlocklisted(this.token.address, recipient),
          true
        );
      });
      describe("when the blocklist is activated", function () {
        describe("when both the sender and the recipient are blocklisted", function () {
          const amount = issuanceAmount;

          it("reverts", async function () {
            await expectRevert.unspecified(
              this.token.transfer(recipient, amount, { from: tokenHolder })
            );
          });
        });
        describe("when the sender is blocklisted", function () {
          const amount = issuanceAmount;

          it("reverts", async function () {
            await this.validatorContract.removeBlocklisted(this.token.address, recipient, {
              from: controller,
            });
            await expectRevert.unspecified(
              this.token.transfer(recipient, amount, { from: tokenHolder })
            );
          });
        });
        describe("when the recipient is blocklisted", function () {
          const amount = issuanceAmount;

          it("reverts", async function () {
            await this.validatorContract.removeBlocklisted(this.token.address, tokenHolder, {
              from: controller,
            });
            await expectRevert.unspecified(
              this.token.transfer(recipient, amount, { from: tokenHolder })
            );
          });
        });
        describe("when neither the sender nor the recipient are blocklisted", function () {
          const amount = issuanceAmount;

          it("transfers the requested amount", async function () {
            await this.validatorContract.removeBlocklisted(this.token.address, tokenHolder, {
              from: owner,
            });
            await this.validatorContract.removeBlocklisted(this.token.address, recipient, {
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
      describe("when the blocklist is not activated", function () {
        beforeEach(async function () {
          await setBlockListActivated(
            this.validatorContract,
            this.token,
            controller,
            false
          )
          await assertBlockListActivated(
            this.validatorContract,
            this.token,
            false
          );
        });
        describe("when both the sender and the recipient are blocklisted", function () {
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
    describe("when token has neither a allowlist, nor a blocklist", function () {
      const amount = issuanceAmount;

      beforeEach(async function () {
        await setAllowListActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        )
        await assertAllowListActivated(
          this.validatorContract,
          this.token,
          false
        );

        await setBlockListActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        )
        await assertBlockListActivated(
          this.validatorContract,
          this.token,
          false
        );
      });

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
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );
    });

    describe("when token allowlist is activated", function () {
      beforeEach(async function () {
        await assertTokenHasExtension(
          this.registry,
          this.validatorContract,
          this.token,
        );

        await assertAllowListActivated(
          this.validatorContract,
          this.token,
          true
        );

        await this.validatorContract.addAllowlisted(this.token.address, tokenHolder, {
          from: controller,
        });
        await this.validatorContract.addAllowlisted(this.token.address, recipient, { from: controller });
      });
      describe("when the sender and the recipient are allowlisted", function () {
        beforeEach(async function () {
          assert.equal(
            await this.validatorContract.isAllowlisted(this.token.address, tokenHolder),
            true
          );
          assert.equal(
            await this.validatorContract.isAllowlisted(this.token.address, recipient),
            true
          );
        });
        describe("when the operator is approved", function () {
          beforeEach(async function () {
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
                  await expectRevert.unspecified(
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
                await expectRevert.unspecified(
                  this.token.transferFrom(tokenHolder, ZERO_ADDRESS, amount, {
                    from: operator,
                  })
                );
              });
            });
          });
          describe("when the amount is not a multiple of the granularity", function () {
            it("reverts", async function () {
              this.token2 = await ERC1400HoldableCertificate.new(
                "ERC1400Token",
                "DAU",
                2,
                [controller],
                partitions,
                this.validatorContract.address,
                owner,
                CERTIFICATE_SIGNER,
                true,
                { from: controller }
              );
              await this.token2.issueByPartition(
                partition1,
                tokenHolder,
                issuanceAmount,
                VALID_CERTIFICATE,
                { from: controller }
              );
              await assertTokenHasExtension(
                this.registry,
                this.validatorContract,
                this.token2,
              );

              await assertAllowListActivated(
                this.validatorContract,
                this.token2,
                true
              );
      
              await this.validatorContract.addAllowlisted(this.token2.address, tokenHolder, {
                from: controller,
              });
              await this.validatorContract.addAllowlisted(this.token2.address, recipient, { from: controller });

              await this.token2.approve(operator, approvedAmount, {
                from: tokenHolder,
              });

              await expectRevert.unspecified(
                this.token2.transferFrom(tokenHolder, recipient, 3, {
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
              await expectRevert.unspecified(
                this.token.transferFrom(tokenHolder, recipient, amount, {
                  from: operator,
                })
              );
            });
          });
        });
      });
      describe("when the sender is not allowlisted", function () {
        const amount = approvedAmount;
        beforeEach(async function () {
          await this.validatorContract.removeAllowlisted(this.token.address, tokenHolder, {
            from: controller,
          });

          assert.equal(
            await this.validatorContract.isAllowlisted(this.token.address, tokenHolder),
            false
          );
          assert.equal(
            await this.validatorContract.isAllowlisted(this.token.address, recipient),
            true
          );
        });
        it("reverts", async function () {
          await expectRevert.unspecified(
            this.token.transferFrom(tokenHolder, recipient, amount, {
              from: operator,
            })
          );
        });
      });
      describe("when the recipient is not allowlisted", function () {
        const amount = approvedAmount;
        beforeEach(async function () {
          await this.validatorContract.removeAllowlisted(this.token.address, recipient, {
            from: controller,
          });

          assert.equal(
            await this.validatorContract.isAllowlisted(this.token.address, tokenHolder),
            true
          );
          assert.equal(
            await this.validatorContract.isAllowlisted(this.token.address, recipient),
            false
          );
        });
        it("reverts", async function () {
          await expectRevert.unspecified(
            this.token.transferFrom(tokenHolder, recipient, amount, {
              from: operator,
            })
          );
        });
      });
    });
    // describe("when token has no allowlist", function () {});
    describe("when token holds are activated", function () {
      beforeEach(async function () {
        await assertTokenHasExtension(
          this.registry,
          this.validatorContract,
          this.token,
        );

        await setAllowListActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        )
        await assertAllowListActivated(
          this.validatorContract,
          this.token,
          false
        );

        await setBlockListActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        )
        await assertBlockListActivated(
          this.validatorContract,
          this.token,
          false
        );

        await setHoldsActivated(
          this.validatorContract,
          this.token,
          controller,
          true
        )
        await assertHoldsActivated(
          this.validatorContract,
          this.token,
          true
        );

        await setSelfHoldsActivated(
          this.validatorContract,
          this.token,
          controller,
          true
        )
        await assertSelfHoldsActivated(
          this.validatorContract,
          this.token,
          true
        );

        // Add notary as controller
        const controllers = await this.token.controllers();
        assert.equal(controllers.length, 1);
        controllers.push(notary);
        await this.token.setControllers(controllers, { from: owner });

        // Create hold in state Ordered
        this.time = await this.clock.getTime();
        this.holdId = newHoldId();
        this.secretHashPair = newSecretHashPair();
        await this.validatorContract.hold(this.token.address, this.holdId, recipient, notary, partition1, smallHoldAmount, SECONDS_IN_AN_HOUR, this.secretHashPair.hash, { from: tokenHolder })
      });
      describe("when a hold is executed", function () {
        it("executes the hold", async function() {
          const initialBalance = await this.token.balanceOf(tokenHolder)
          const initialPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
  
          const initialBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, tokenHolder)
          const initialBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)
  
          const initialSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder)
          const initialSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, tokenHolder)
  
          const initialTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
          const initialTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)
  
          const initialRecipientBalance = await this.token.balanceOf(recipient)
          const initialRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)
  
          await this.token.transferFrom(
            tokenHolder,
            recipient,
            smallHoldAmount,
            { from: notary }
          )
  
          const finalBalance = await this.token.balanceOf(tokenHolder)
          const finalPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
  
          const finalBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, tokenHolder)
          const finalBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)
  
          const finalSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder)
          const finalSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, tokenHolder)
  
          const finalTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
          const finalTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)
  
          const finalRecipientBalance = await this.token.balanceOf(recipient)
          const finalRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)
  
          assert.equal(initialBalance, issuanceAmount)
          assert.equal(finalBalance, issuanceAmount-smallHoldAmount)
          assert.equal(initialPartitionBalance, issuanceAmount)
          assert.equal(finalPartitionBalance, issuanceAmount-smallHoldAmount)
  
          assert.equal(initialBalanceOnHold, smallHoldAmount)
          assert.equal(initialBalanceOnHoldByPartition, smallHoldAmount)
          assert.equal(finalBalanceOnHold, 0)
          assert.equal(finalBalanceOnHoldByPartition, 0)
  
          assert.equal(initialSpendableBalance, issuanceAmount-smallHoldAmount)
          assert.equal(initialSpendableBalanceByPartition, issuanceAmount-smallHoldAmount)
          assert.equal(finalSpendableBalance, issuanceAmount-smallHoldAmount)
          assert.equal(finalSpendableBalanceByPartition, issuanceAmount-smallHoldAmount)
  
          assert.equal(initialTotalSupplyOnHold, smallHoldAmount)
          assert.equal(initialTotalSupplyOnHoldByPartition, smallHoldAmount)
          assert.equal(finalTotalSupplyOnHold, 0)
          assert.equal(finalTotalSupplyOnHoldByPartition, 0)
  
          assert.equal(initialRecipientBalance, 0)
          assert.equal(initialRecipientPartitionBalance, 0)
          assert.equal(finalRecipientBalance, smallHoldAmount)
          assert.equal(finalRecipientPartitionBalance, smallHoldAmount)
  
          this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
          assert.equal(this.holdData[0], partition1);
          assert.equal(this.holdData[1], tokenHolder);
          assert.equal(this.holdData[2], recipient);
          assert.equal(this.holdData[3], notary);
          assert.equal(parseInt(this.holdData[4]), smallHoldAmount);
          assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR);
          assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);
          assert.equal(this.holdData[6], this.secretHashPair.hash);
          assert.equal(this.holdData[7], EMPTY_BYTE32);
          assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_EXECUTED);
        });
        it("executes 2 holds", async function() {
          // Create a second hold in state Ordered
          this.time2 = await this.clock.getTime();
          this.holdId2 = newHoldId();
          this.secretHashPair2 = newSecretHashPair();
          await this.validatorContract.hold(this.token.address, this.holdId2, recipient, notary, partition1, smallHoldAmount, SECONDS_IN_AN_HOUR, this.secretHashPair2.hash, { from: tokenHolder })
  
          const initialPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
          const initialRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)
  
          await this.token.transferFrom(
            tokenHolder,
            recipient,
            smallHoldAmount,
            { from: notary }
          )
  
          const intermediatePartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
          const intermediateRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)
  
          assert.equal(initialPartitionBalance, issuanceAmount)
          assert.equal(intermediatePartitionBalance, issuanceAmount-smallHoldAmount)
  
          assert.equal(initialRecipientPartitionBalance, 0)
          assert.equal(intermediateRecipientPartitionBalance, smallHoldAmount)
  
          this.holdData2 = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId2);
          assert.equal(this.holdData2[0], partition1);
          assert.equal(this.holdData2[1], tokenHolder);
          assert.equal(this.holdData2[2], recipient);
          assert.equal(this.holdData2[3], notary);
          assert.equal(parseInt(this.holdData2[4]), smallHoldAmount);
          assert.isAtLeast(parseInt(this.holdData2[5]), parseInt(this.time2)+SECONDS_IN_AN_HOUR);
          assert.isBelow(parseInt(this.holdData2[5]), parseInt(this.time2)+SECONDS_IN_AN_HOUR+100);
          assert.equal(this.holdData2[6], this.secretHashPair2.hash);
          assert.equal(this.holdData2[7], EMPTY_BYTE32);
          assert.equal(parseInt(this.holdData2[8]), HOLD_STATUS_EXECUTED);
  
          await this.token.transferFrom(
            tokenHolder,
            recipient,
            smallHoldAmount,
            { from: notary }
          )
  
          const finalPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
          const finalRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)
  
          assert.equal(initialPartitionBalance, issuanceAmount)
          assert.equal(finalPartitionBalance, issuanceAmount-2*smallHoldAmount)
  
          assert.equal(initialRecipientPartitionBalance, 0)
          assert.equal(finalRecipientPartitionBalance, 2*smallHoldAmount)
  
          this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
          assert.equal(this.holdData[0], partition1);
          assert.equal(this.holdData[1], tokenHolder);
          assert.equal(this.holdData[2], recipient);
          assert.equal(this.holdData[3], notary);
          assert.equal(parseInt(this.holdData[4]), smallHoldAmount);
          assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR);
          assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);
          assert.equal(this.holdData[6], this.secretHashPair.hash);
          assert.equal(this.holdData[7], EMPTY_BYTE32);
          assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_EXECUTED);
        });
  
      });
      describe("when a hold is not executed", function () {
        beforeEach(async function () {
          this.validatorContract2 = await ERC1400TokensValidator.new({ from: deployer });

          await setNewExtensionForToken(
            this.validatorContract2,
            this.token,
            owner,
          );
  
          await setAllowListActivated(
            this.validatorContract2,
            this.token,
            controller,
            false
          )
          await assertAllowListActivated(
            this.validatorContract2,
            this.token,
            false
          );

          await this.token.transferFrom(
            tokenHolder,
            recipient,
            smallHoldAmount,
            { from: notary }
          );
          await setNewExtensionForToken(
            this.validatorContract,
            this.token,
            owner,
          );
        });
        it("reverts", async function() {
          await expectRevert.unspecified(
            this.token.transferFrom(
              tokenHolder,
              recipient,
              smallHoldAmount,
              { from: notary }
            )
          )
        });
  
      });
    });
  });

  // PAUSABLE EXTENSION

  describe("pausable", function () {
    const transferAmount = 300;

    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );

      await setAllowListActivated(
        this.validatorContract,
        this.token,
        controller,
        false
      )
      await assertAllowListActivated(
        this.validatorContract,
        this.token,
        false
      );
    });

    describe("when contract is not paused", function () {
      beforeEach(async function () {
        await assertTokenHasExtension(
          this.registry,
          this.validatorContract,
          this.token,
        );

        assert.equal(false, await this.validatorContract.paused(this.token.address));
      });
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
      it("transfers the requested amount (after pause/unpause)", async function () {
        assert.equal(false, await this.validatorContract.paused(this.token.address));
        await this.validatorContract.pause(this.token.address, { from: controller });
        await expectRevert.unspecified(
          this.validatorContract.pause(this.token.address, { from: controller })
        );

        assert.equal(true, await this.validatorContract.paused(this.token.address));
        await this.validatorContract.unpause(this.token.address, { from: controller });
        await expectRevert.unspecified(
          this.validatorContract.unpause(this.token.address, { from: controller })
        );

        assert.equal(false, await this.validatorContract.paused(this.token.address));
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
        await assertTokenHasExtension(
          this.registry,
          this.validatorContract,
          this.token,
        );

        await this.validatorContract.pause(this.token.address, { from: controller });

        assert.equal(true, await this.validatorContract.paused(this.token.address));
      });
      it("reverts", async function () {
        await assertBalance(this.token, tokenHolder, issuanceAmount);
        await expectRevert.unspecified(
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

        await expectRevert.unspecified(
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

  // IS HOLDS ACTIVATED
  describe("isHoldsActivated", function () {

    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );

    });

    describe("when holds are activated by the owner", function () {
      it("activates the holds", async function () {
        await setHoldsActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        )
        await assertHoldsActivated(
          this.validatorContract,
          this.token,
          false
        );
        await setHoldsActivated(
          this.validatorContract,
          this.token,
          controller,
          true
        )
        await assertHoldsActivated(
          this.validatorContract,
          this.token,
          true
        );

        const holdId = newHoldId();
        const secretHashPair = newSecretHashPair();
        await this.validatorContract.holdFrom(this.token.address, holdId, tokenHolder, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller })
        const spendableBalance = parseInt(await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder))

        const transferAmount = spendableBalance + 1
        await expectRevert.unspecified(this.token.transferByPartition(partition1, recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder }))

        await setHoldsActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        )
        await assertHoldsActivated(
          this.validatorContract,
          this.token,
          false
        );

        assert.equal(parseInt(await this.token.balanceOfByPartition(partition1, recipient)), 0)
        await this.token.transferByPartition(partition1, recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder })
        assert.equal(parseInt(await this.token.balanceOfByPartition(partition1, recipient)), transferAmount)
      });
    });
    describe("when holds are not activated by the owner", function () {
      it("reverts", async function () {
        await setHoldsActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        )
        await assertHoldsActivated(
          this.validatorContract,
          this.token,
          false
        );

        await expectRevert.unspecified(
          setHoldsActivated(
            this.validatorContract,
            this.token,
            tokenHolder,
            true
          )
        );
      });
    });
  });

  // IS SELF HOLDS ACTIVATED
  describe("isSelfHoldsActivated", function () {

    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );
    });

    describe("when unrestricted holds are activated by the owner", function () {
      it("activates the unrestricted holds", async function () {
        const smallHoldAmount = 33

        await assertSelfHoldsActivated(
          this.validatorContract,
          this.token,
          false
        );
        await setSelfHoldsActivated(
          this.validatorContract,
          this.token,
          controller,
          true
        )
        await assertSelfHoldsActivated(
          this.validatorContract,
          this.token,
          true
        );

        const holdId = newHoldId();
        const secretHashPair = newSecretHashPair();
        await this.validatorContract.hold(this.token.address, holdId, recipient, notary, partition1, smallHoldAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder })

        await setSelfHoldsActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        )
        await assertSelfHoldsActivated(
          this.validatorContract,
          this.token,
          false
        );

        await expectRevert.unspecified(this.validatorContract.hold(this.token.address, holdId, recipient, notary, partition1, smallHoldAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder }));
      });
    });
    describe("when unrestricted holds are not activated by the owner", function () {
      it("reverts", async function () {
        await assertSelfHoldsActivated(
          this.validatorContract,
          this.token,
          false
        );

        await expectRevert.unspecified(
          setSelfHoldsActivated(
            this.validatorContract,
            this.token,
            tokenHolder,
            true
          )
        );
      });
    });
  });
  
  // HOLD

  describe("hold", function () {
    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );

      await setSelfHoldsActivated(
        this.validatorContract,
        this.token,
        controller,
        true
      )
      await assertSelfHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
      await assertHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
    });

    describe("when unrestricted holds are authorized", function () {
      beforeEach(async function () {
        await assertSelfHoldsActivated(
          this.validatorContract,
          this.token,
          true
        );
      });
      describe("when hold recipient is not the zero address", function () {
        describe("when hold value is greater than 0", function () {
          describe("when hold ID doesn't already exist", function () {
            describe("when notary is not the zero address", function () {
              describe("when hold value is not greater than spendable balance", function () {
                it("creates a hold", async function () {
                  const initialBalance = await this.token.balanceOf(tokenHolder)
                  const initialPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
  
                  const initialBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, tokenHolder)
                  const initialBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)
  
                  const initialSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder)
                  const initialSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, tokenHolder)
  
                  const initialTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
                  const initialTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)
  
                  const time = await this.clock.getTime();
                  const holdId = newHoldId();
                  const secretHashPair = newSecretHashPair();
                  await this.validatorContract.hold(this.token.address, holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder })
  
                  const finalBalance = await this.token.balanceOf(tokenHolder)
                  const finalPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
  
                  const finalBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, tokenHolder)
                  const finalBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)
  
                  const finalSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder)
                  const finalSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, tokenHolder)
  
                  const finalTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
                  const finalTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)
  
                  assert.equal(initialBalance, issuanceAmount)
                  assert.equal(finalBalance, issuanceAmount)
                  assert.equal(initialPartitionBalance, issuanceAmount)
                  assert.equal(finalPartitionBalance, issuanceAmount)
  
                  assert.equal(initialBalanceOnHold, 0)
                  assert.equal(initialBalanceOnHoldByPartition, 0)
                  assert.equal(finalBalanceOnHold, holdAmount)
                  assert.equal(finalBalanceOnHoldByPartition, holdAmount)
  
                  assert.equal(initialSpendableBalance, issuanceAmount)
                  assert.equal(initialSpendableBalanceByPartition, issuanceAmount)
                  assert.equal(finalSpendableBalance, issuanceAmount - holdAmount)
                  assert.equal(finalSpendableBalanceByPartition, issuanceAmount - holdAmount)
  
                  assert.equal(initialTotalSupplyOnHold, 0)
                  assert.equal(initialTotalSupplyOnHoldByPartition, 0)
                  assert.equal(finalTotalSupplyOnHold, holdAmount)
                  assert.equal(finalTotalSupplyOnHoldByPartition, holdAmount)
  
                  this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, holdId);
                  assert.equal(this.holdData[0], partition1);
                  assert.equal(this.holdData[1], tokenHolder);
                  assert.equal(this.holdData[2], recipient);
                  assert.equal(this.holdData[3], notary);
                  assert.equal(parseInt(this.holdData[4]), holdAmount);
                  assert.isAtLeast(parseInt(this.holdData[5]), parseInt(time)+SECONDS_IN_AN_HOUR);
                  assert.isBelow(parseInt(this.holdData[5]), parseInt(time)+SECONDS_IN_AN_HOUR+100);
                  assert.equal(this.holdData[6], secretHashPair.hash);
                  assert.equal(this.holdData[7], EMPTY_BYTE32);
                  assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_ORDERED);
                });
                it("can transfer less than spendable balance", async function () {
                  const holdId = newHoldId();
                  const secretHashPair = newSecretHashPair();
                  await this.validatorContract.hold(this.token.address, holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder })
                  const initialSpendableBalance = parseInt(await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder))
                  const initialSenderBalance = parseInt(await this.token.balanceOfByPartition(partition1, tokenHolder))
                  const initialRecipientBalance = parseInt(await this.token.balanceOfByPartition(partition1, recipient))
  
                  const transferAmount = initialSpendableBalance
                  await this.token.transferByPartition(partition1, recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder })
  
                  const finalSpendableBalance = parseInt(await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder))
                  const finalSenderBalance = parseInt(await this.token.balanceOfByPartition(partition1, tokenHolder))
                  const finalRecipientBalance = parseInt(await this.token.balanceOfByPartition(partition1, recipient))
  
                  assert.equal(initialSpendableBalance, issuanceAmount - holdAmount)
                  assert.equal(finalSpendableBalance, 0)
  
                  assert.equal(initialSenderBalance, issuanceAmount)
                  assert.equal(initialRecipientBalance, 0)
  
                  assert.equal(finalSenderBalance, issuanceAmount - transferAmount)
                  assert.equal(finalRecipientBalance, transferAmount)
                });
                it("can not transfer more than spendable balance", async function () {
                  const holdId = newHoldId();
                  const secretHashPair = newSecretHashPair();
                  await this.validatorContract.hold(this.token.address, holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder })
                  const initialSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder)
  
                  const transferAmount = initialSpendableBalance + 1
                  await expectRevert.unspecified(this.token.transferByPartition(partition1, recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder }))
                });
                it("emits an event", async function () {
                  const holdId = newHoldId();
                  const secretHashPair = newSecretHashPair();
                  const time = await this.clock.getTime();
                  const { logs } = await this.validatorContract.hold(this.token.address, holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder })
  
                  assert.equal(logs[0].event, "HoldCreated");
                  assert.equal(logs[0].args.token, this.token.address);
                  assert.equal(logs[0].args.holdId, holdId);
                  assert.equal(logs[0].args.partition, partition1);
                  assert.equal(logs[0].args.sender, tokenHolder);
                  assert.equal(logs[0].args.recipient, recipient);
                  assert.equal(logs[0].args.notary, notary);
                  assert.equal(logs[0].args.value, holdAmount);
                  assert.isAtLeast(parseInt(logs[0].args.expiration), parseInt(time)+SECONDS_IN_AN_HOUR);
                  assert.isBelow(parseInt(logs[0].args.expiration), parseInt(time)+SECONDS_IN_AN_HOUR+100);
                  assert.equal(logs[0].args.secretHash, secretHashPair.hash);
                });
              });
              describe("when hold value is greater than spendable balance", function () {
                it("reverts", async function () {
                  const holdId = newHoldId();
                  const secretHashPair = newSecretHashPair();
                  const initialSpendableBalance = parseInt(await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder))
                  await expectRevert.unspecified(this.validatorContract.hold(this.token.address, holdId, recipient, notary, partition1, initialSpendableBalance+1, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder }))
                });
              });
            });
            describe("when notary is the zero address", function () {
              it("reverts", async function () {
                const holdId = newHoldId();
                const secretHashPair = newSecretHashPair();
                await expectRevert.unspecified(this.validatorContract.hold(this.token.address, holdId, recipient, ZERO_ADDRESS, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder }))
              });
            });
          });
          describe("when hold ID already exists", function () {
            it("reverts", async function () {
              const holdId = newHoldId();
              const secretHashPair = newSecretHashPair();
              await this.validatorContract.hold(this.token.address, holdId, recipient, notary, partition1, 1, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder })
              await expectRevert.unspecified(this.validatorContract.hold(this.token.address, holdId, recipient, notary, partition1, 1, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder }))
            });
          });
        });
        describe("when hold value is not greater than 0", function () {
          it("reverts", async function () {
            const holdId = newHoldId();
            const secretHashPair = newSecretHashPair();
            await expectRevert.unspecified(this.validatorContract.hold(this.token.address, holdId, recipient, notary, partition1, 0, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder }))
          });
        });
      });
      describe("when hold recipient is the zero address", function () {
        it("reverts", async function () {
          const holdId = newHoldId();
          const secretHashPair = newSecretHashPair();
          await expectRevert.unspecified(this.validatorContract.hold(this.token.address, holdId, ZERO_ADDRESS, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder }))
        });
      });
    });
    describe("when unrestricted holds are not authorized", function () {
      beforeEach(async function () {
        await setSelfHoldsActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        )
        await assertSelfHoldsActivated(
          this.validatorContract,
          this.token,
          false
        );
      });
      it("reverts", async function () {
        const holdId = newHoldId();
        const secretHashPair = newSecretHashPair();
        await expectRevert.unspecified(this.validatorContract.hold(this.token.address, holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder }))
      });
    });

  });

  // HOLD WITH EXPIRATION DATE

  describe("holdWithExpirationDate", function () {

    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );

      await setSelfHoldsActivated(
        this.validatorContract,
        this.token,
        controller,
        true
      )
      await assertSelfHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
      await assertHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
    });

    describe("when unrestricted holds are authorized", function () {
      describe("when expiration date is valid", function () {
        describe("when expiration date is in the future", function () {
          it("creates a hold", async function () {
            const time = parseInt(await this.clock.getTime());
            const holdId = newHoldId();
            const secretHashPair = newSecretHashPair();
            const { logs } = await this.validatorContract.holdWithExpirationDate(this.token.address, holdId, recipient, notary, partition1, holdAmount, time+SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder })
            assert.equal(parseInt(logs[0].args.expiration), time+SECONDS_IN_AN_HOUR);
            this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, holdId);
            assert.equal(parseInt(this.holdData[5]), time+SECONDS_IN_AN_HOUR);
          });
        });
        describe("when there is no expiration date", function () {
          it("creates a hold", async function () {
            const time = parseInt(await this.clock.getTime());
            const holdId = newHoldId();
            const secretHashPair = newSecretHashPair();
            const { logs } = await this.validatorContract.holdWithExpirationDate(this.token.address, holdId, recipient, notary, partition1, holdAmount, 0, secretHashPair.hash, { from: tokenHolder })
            assert.equal(parseInt(logs[0].args.expiration), 0);
            this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, holdId);
            assert.equal(parseInt(this.holdData[5]), 0);
          });
        });
      });
      describe("when expiration date is not valid", function () {
        it("reverts", async function () {
          const time = parseInt(await this.clock.getTime());
          const holdId = newHoldId();
          const secretHashPair = newSecretHashPair();
          await expectRevert.unspecified(this.validatorContract.holdWithExpirationDate(this.token.address, holdId, recipient, notary, partition1, holdAmount, time-1, secretHashPair.hash, { from: tokenHolder }))
        });
      });
    });
    describe("when unrestricted holds are not authorized", function () {
      beforeEach(async function () {
        await setSelfHoldsActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        )
        await assertSelfHoldsActivated(
          this.validatorContract,
          this.token,
          false
        );
      });
      it("reverts", async function () {
        const time = parseInt(await this.clock.getTime());
        const holdId = newHoldId();
        const secretHashPair = newSecretHashPair();
        await expectRevert.unspecified(this.validatorContract.holdWithExpirationDate(this.token.address, holdId, recipient, notary, partition1, holdAmount, time+SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenHolder }))
      });
    });
  });

  // HOLD FROM

  describe("holdFrom", function () {

    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );

      await setSelfHoldsActivated(
        this.validatorContract,
        this.token,
        controller,
        true
      )
      await assertSelfHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
      await assertHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
    });

    describe("when unrestricted holds are authorized", function () {
      describe("when hold sender is not the zero address", function () {
        describe("when hold is created by an operator", function () {
          it("creates a hold", async function () {
            assert.equal(parseInt(await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)), 0);
            const holdId = newHoldId();
            const secretHashPair = newSecretHashPair();
            await this.validatorContract.holdFrom(this.token.address, holdId, tokenHolder, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller });
            assert.equal(parseInt(await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)), holdAmount);
          });
        });
        describe("when hold is not created by an operator", function () {
          it("reverts", async function () {
            const holdId = newHoldId();
            const secretHashPair = newSecretHashPair();
            await expectRevert.unspecified(this.validatorContract.holdFrom(this.token.address, holdId, tokenHolder, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: recipient }));
          });
        });
      });
      describe("when hold sender is the zero address", function () {
        it("reverts", async function () {
          const holdId = newHoldId();
          const secretHashPair = newSecretHashPair();
          await expectRevert.unspecified(this.validatorContract.holdFrom(this.token.address, holdId, ZERO_ADDRESS, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller }));
        });
      });
    });
    describe("when unrestricted holds are not authorized", function () {
      beforeEach(async function () {
        await setSelfHoldsActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        )
        await assertSelfHoldsActivated(
          this.validatorContract,
          this.token,
          false
        );
      });
      describe("when hold is created by a token controller", function () {
        beforeEach(async function () {
          await assertIsTokenController(
            this.validatorContract,
            this.token,
            tokenController1,
            false,
          )
          await addTokenController(
            this.validatorContract,
            this.token,
            controller,
            tokenController1
          )
          await assertIsTokenController(
            this.validatorContract,
            this.token,
            tokenController1,
            true,
          )
        });
        it("creates a hold", async function () {
          assert.equal(parseInt(await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)), 0);
          const holdId = newHoldId();
          const secretHashPair = newSecretHashPair();
          await expectRevert.unspecified(this.validatorContract.holdFrom(this.token.address, holdId, tokenHolder, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenController2 }));
          await this.validatorContract.holdFrom(this.token.address, holdId, tokenHolder, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenController1 });
          assert.equal(parseInt(await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)), holdAmount);
        });
      });
      describe("when hold is not created by a token controller", function () {
        it("reverts", async function () {
          assert.equal(parseInt(await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)), 0);
          const holdId = newHoldId();
          const secretHashPair = newSecretHashPair();
          await expectRevert.unspecified(this.validatorContract.holdFrom(this.token.address, holdId, tokenHolder, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenController2 }));
        });
      });
    });
  });

  // HOLD FROM WITH EXPIRATION DATE

  describe("holdFromWithExpirationDate", function () {
    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );

      await setSelfHoldsActivated(
        this.validatorContract,
        this.token,
        controller,
        true
      )
      await assertSelfHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
      await assertHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
    });

    describe("when unrestricted holds are authorized", function () {
      describe("when expiration date is valid", function () {
        describe("when expiration date is in the future", function () {
          describe("when hold sender is not the zero address", function () {
            describe("when hold is created by an operator", function () {
              it("creates a hold", async function () {
                assert.equal(parseInt(await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)), 0);
                const time = parseInt(await this.clock.getTime());
                const holdId = newHoldId();
                const secretHashPair = newSecretHashPair();
                const { logs } = await this.validatorContract.holdFromWithExpirationDate(this.token.address, holdId, tokenHolder, recipient, notary, partition1, holdAmount, time+SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller });
                assert.equal(parseInt(await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)), holdAmount);
  
                assert.equal(parseInt(logs[0].args.expiration), time+SECONDS_IN_AN_HOUR);
                this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, holdId);
                assert.equal(parseInt(this.holdData[5]), time+SECONDS_IN_AN_HOUR);
              });
            });
            describe("when hold is not created by an operator", function () {
              it("reverts", async function () {
                const time = parseInt(await this.clock.getTime());
                const holdId = newHoldId();
                const secretHashPair = newSecretHashPair();
                await expectRevert.unspecified(this.validatorContract.holdFromWithExpirationDate(this.token.address, holdId, tokenHolder, recipient, notary, partition1, holdAmount, time+SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: recipient }));
              });
            });
          });
          describe("when hold sender is the zero address", function () {
            it("reverts", async function () {
              const time = parseInt(await this.clock.getTime());
              const holdId = newHoldId();
              const secretHashPair = newSecretHashPair();
              await expectRevert.unspecified(this.validatorContract.holdFromWithExpirationDate(this.token.address, holdId, ZERO_ADDRESS, recipient, notary, partition1, holdAmount, time+SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller }));
            });
          });
        });
        describe("when there is no expiration date", function () {
          it("creates a hold", async function () {
            assert.equal(parseInt(await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)), 0);
            // const time = parseInt(await this.clock.getTime());
            const holdId = newHoldId();
            const secretHashPair = newSecretHashPair();
            const { logs } = await this.validatorContract.holdFromWithExpirationDate(this.token.address, holdId, tokenHolder, recipient, notary, partition1, holdAmount, 0, secretHashPair.hash, { from: controller });
            assert.equal(parseInt(await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)), holdAmount);
  
            assert.equal(parseInt(logs[0].args.expiration), 0);
            this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, holdId);
            assert.equal(parseInt(this.holdData[5]), 0);
          });
        });
      });
      describe("when expiration date is not valid", function () {
        it("reverts", async function () {
          const time = parseInt(await this.clock.getTime());
          const holdId = newHoldId();
          const secretHashPair = newSecretHashPair();
          await expectRevert.unspecified(this.validatorContract.holdFromWithExpirationDate(this.token.address, holdId, tokenHolder, recipient, notary, partition1, holdAmount, time-1, secretHashPair.hash, { from: controller }));
        });
      });
    });
    describe("when unrestricted holds are not authorized", function () {
      beforeEach(async function () {
        await setSelfHoldsActivated(
          this.validatorContract,
          this.token,
          controller,
          false
        )
        await assertSelfHoldsActivated(
          this.validatorContract,
          this.token,
          false
        );
      });
      describe("when hold is created by a token controller", function () {
        beforeEach(async function () {
          await assertIsTokenController(
            this.validatorContract,
            this.token,
            tokenController1,
            false,
          )
          await addTokenController(
            this.validatorContract,
            this.token,
            controller,
            tokenController1
          )
          await assertIsTokenController(
            this.validatorContract,
            this.token,
            tokenController1,
            true,
          )
        });
        it("creates a hold", async function () {
          assert.equal(parseInt(await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)), 0);
          const time = parseInt(await this.clock.getTime());
          const holdId = newHoldId();
          const secretHashPair = newSecretHashPair();
          await expectRevert.unspecified(this.validatorContract.holdFromWithExpirationDate(this.token.address, holdId, tokenHolder, recipient, notary, partition1, holdAmount, time+SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenController2 }));
          await this.validatorContract.holdFromWithExpirationDate(this.token.address, holdId, tokenHolder, recipient, notary, partition1, holdAmount, time+SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenController1 });
          assert.equal(parseInt(await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)), holdAmount);
        });
      });
      describe("when hold is not created by a token controller", function () {
        it("reverts", async function () {
          assert.equal(parseInt(await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)), 0);
          const time = parseInt(await this.clock.getTime());
          const holdId = newHoldId();
          const secretHashPair = newSecretHashPair();
          await expectRevert.unspecified(this.validatorContract.holdFromWithExpirationDate(this.token.address, holdId, tokenHolder, recipient, notary, partition1, holdAmount, time+SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: tokenController2 }));
        });
      });
    });
  });

  // RELEASE HOLD

  describe("releaseHold", function () {
    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );

      await setSelfHoldsActivated(
        this.validatorContract,
        this.token,
        controller,
        true
      )
      await assertSelfHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
      await assertHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );

      // Create hold in state Ordered
      this.time = await this.clock.getTime();
      this.holdId = newHoldId();
      this.secretHashPair = newSecretHashPair();
      await this.validatorContract.hold(this.token.address, this.holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, this.secretHashPair.hash, { from: tokenHolder })
    });

    describe("when hold is in status Ordered", function () {
      describe("when hold can be released", function () {
        describe("when hold expiration date is past", function () {
          it("releases the hold", async function () {
            const initialBalance = await this.token.balanceOf(tokenHolder)
            const initialPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)

            const initialBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, tokenHolder)
            const initialBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)

            const initialSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder)
            const initialSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, tokenHolder)

            const initialTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
            const initialTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)

            // Wait for 1 hour
            await advanceTimeAndBlock(SECONDS_IN_AN_HOUR + 100);
            await this.validatorContract.releaseHold(this.token.address, this.holdId, { from: tokenHolder });

            const finalBalance = await this.token.balanceOf(tokenHolder)
            const finalPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)

            const finalBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, tokenHolder)
            const finalBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)

            const finalSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder)
            const finalSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, tokenHolder)

            const finalTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
            const finalTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)

            assert.equal(initialBalance, issuanceAmount)
            assert.equal(finalBalance, issuanceAmount)
            assert.equal(initialPartitionBalance, issuanceAmount)
            assert.equal(finalPartitionBalance, issuanceAmount)

            assert.equal(initialBalanceOnHold, holdAmount)
            assert.equal(initialBalanceOnHoldByPartition, holdAmount)
            assert.equal(finalBalanceOnHold, 0)
            assert.equal(finalBalanceOnHoldByPartition, 0)

            assert.equal(initialSpendableBalance, issuanceAmount - holdAmount)
            assert.equal(initialSpendableBalanceByPartition, issuanceAmount - holdAmount)
            assert.equal(finalSpendableBalance, issuanceAmount)
            assert.equal(finalSpendableBalanceByPartition, issuanceAmount)

            assert.equal(initialTotalSupplyOnHold, holdAmount)
            assert.equal(initialTotalSupplyOnHoldByPartition, holdAmount)
            assert.equal(finalTotalSupplyOnHold, 0)
            assert.equal(finalTotalSupplyOnHoldByPartition, 0)

            this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
            assert.equal(this.holdData[0], partition1);
            assert.equal(this.holdData[1], tokenHolder);
            assert.equal(this.holdData[2], recipient);
            assert.equal(this.holdData[3], notary);
            assert.equal(parseInt(this.holdData[4]), holdAmount);
            assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR);
            assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);
            assert.equal(this.holdData[6], this.secretHashPair.hash);
            assert.equal(this.holdData[7], EMPTY_BYTE32);
            assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_RELEASED_ON_EXPIRATION);
          });
          it("emits an event", async function () {
            // Wait for 1 hour
            await advanceTimeAndBlock(SECONDS_IN_AN_HOUR + 100);
            const { logs } = await this.validatorContract.releaseHold(this.token.address, this.holdId, { from: tokenHolder });
          
            assert.equal(logs[0].event, "HoldReleased");
            assert.equal(logs[0].args.token, this.token.address);
            assert.equal(logs[0].args.holdId, this.holdId);
            assert.equal(logs[0].args.notary, notary);
            assert.equal(logs[0].args.status, HOLD_STATUS_RELEASED_ON_EXPIRATION);
          });
        });
        describe("when hold is released by the notary", function () {
          it("releases the hold", async function () {
            const initialSpendableBalance = parseInt(await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder))
            assert.equal(initialSpendableBalance, issuanceAmount - holdAmount);

            const { logs } = await this.validatorContract.releaseHold(this.token.address, this.holdId, { from: notary });

            const finalSpendableBalance = parseInt(await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder))
            assert.equal(finalSpendableBalance, issuanceAmount);

            this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
            assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_RELEASED_BY_NOTARY);
            assert.equal(logs[0].args.status, HOLD_STATUS_RELEASED_BY_NOTARY);
          });
        });
        describe("when hold is released by the recipient", function () {
          it("releases the hold", async function () {
            const initialSpendableBalance = parseInt(await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder))
            assert.equal(initialSpendableBalance, issuanceAmount - holdAmount);

            const { logs } = await this.validatorContract.releaseHold(this.token.address, this.holdId, { from: recipient });

            const finalSpendableBalance = parseInt(await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder))
            assert.equal(finalSpendableBalance, issuanceAmount);

            this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
            assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_RELEASED_BY_PAYEE);
            assert.equal(logs[0].args.status, HOLD_STATUS_RELEASED_BY_PAYEE);
          });
        });
      });
      describe("when hold can not be released", function () {
        describe("when hold is released by the hold sender", function () {
          it("reverts", async function () {
            await expectRevert.unspecified(this.validatorContract.releaseHold(this.token.address, this.holdId, { from: tokenHolder }));
          });
        });
      });
    });
    describe("when hold is in status ExecutedAndKeptOpen", function () {
      it("releases the hold", async function () {
        const initialSpendableBalance = parseInt(await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder))
        assert.equal(initialSpendableBalance, issuanceAmount - holdAmount);

        this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
        assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_ORDERED);

        const executedAmount = 10;
        await this.validatorContract.executeHoldAndKeepOpen(this.token.address, this.holdId, executedAmount, EMPTY_BYTE32, { from: notary });
        
        this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
        assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_EXECUTED_AND_KEPT_OPEN);
        
        const { logs } = await this.validatorContract.releaseHold(this.token.address, this.holdId, { from: notary });

        const finalSpendableBalance = parseInt(await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder))
        assert.equal(finalSpendableBalance, issuanceAmount-executedAmount);

        this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
        assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_RELEASED_BY_NOTARY);
        assert.equal(logs[0].args.status, HOLD_STATUS_RELEASED_BY_NOTARY);
      });
    });
    describe("when hold is neither in status Ordered, nor ExecutedAndKeptOpen", function () {
      it("reverts", async function () {
        await this.validatorContract.releaseHold(this.token.address, this.holdId, { from: notary });
        
        this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
        assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_RELEASED_BY_NOTARY);
        
        await expectRevert.unspecified(this.validatorContract.releaseHold(this.token.address, this.holdId, { from: notary }));
      });
    });
  });

  // RENEW HOLD

  describe("renewHold", function () {
    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );

      await setSelfHoldsActivated(
        this.validatorContract,
        this.token,
        controller,
        true
      )
      await assertSelfHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
      await assertHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );

      // Create hold in state Ordered
      this.time = await this.clock.getTime();
      this.holdId = newHoldId();
      this.secretHashPair = newSecretHashPair();
      await this.validatorContract.hold(this.token.address, this.holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, this.secretHashPair.hash, { from: tokenHolder })
    });

    describe("when hold can be renewed", function () {
      describe("when hold is in status Ordered", function () {
        describe("when hold is not expired", function () {
          describe("when hold is renewed by the sender", function () {
            it("renews the hold (expiration date future)", async function () {
              this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
              assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR-1);
              assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);

              this.time = await this.clock.getTime();
              await this.validatorContract.renewHold(this.token.address, this.holdId, SECONDS_IN_A_DAY, { from: tokenHolder });
              
              this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
              assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_A_DAY-1);
              assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_A_DAY+100);
            });
            it("renews the hold (expiration date now)", async function () {
              this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
              assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR-1);
              assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);

              this.time = await this.clock.getTime();
              await this.validatorContract.renewHold(this.token.address, this.holdId, 0, { from: tokenHolder });
              
              this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
              assert.equal(parseInt(this.holdData[5]), 0);
            });
            it("emits an event", async function () {
              const { logs } = await this.validatorContract.renewHold(this.token.address, this.holdId, SECONDS_IN_A_DAY, { from: tokenHolder });

              assert.equal(logs[0].event, "HoldRenewed");
              assert.equal(logs[0].args.token, this.token.address);
              assert.equal(logs[0].args.holdId, this.holdId);
              assert.equal(logs[0].args.notary, notary);
              assert.isAtLeast(parseInt(logs[0].args.oldExpiration), parseInt(this.time)+SECONDS_IN_AN_HOUR-1);
              assert.isBelow(parseInt(logs[0].args.oldExpiration), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);
              assert.isAtLeast(parseInt(logs[0].args.newExpiration), parseInt(this.time)+SECONDS_IN_A_DAY-1);
              assert.isBelow(parseInt(logs[0].args.newExpiration), parseInt(this.time)+SECONDS_IN_A_DAY+100);
            });
          });
          describe("when hold is renewed by an operator", function () {
            it("renews the hold", async function () {
              this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
              assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR-1);
              assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);

              this.time = await this.clock.getTime();
              await this.validatorContract.renewHold(this.token.address, this.holdId, SECONDS_IN_A_DAY, { from: controller });
              
              this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
              assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_A_DAY-1);
              assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_A_DAY+100);
            });
          });
          describe("when hold is neither renewed by the sender, nor by an operator", function () {
            it("reverts", async function () {
              await expectRevert.unspecified(this.validatorContract.renewHold(this.token.address, this.holdId, SECONDS_IN_A_DAY, { from: recipient }));
            });
          });
        });
        describe("when hold is expired", function () {
          it("reverts", async function () {
            this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
            assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR-1);
            assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);

            // Wait for more than an hour
            await advanceTimeAndBlock(SECONDS_IN_AN_HOUR + 100);

            await expectRevert.unspecified(this.validatorContract.renewHold(this.token.address, this.holdId, SECONDS_IN_A_DAY, { from: tokenHolder }));
          });
        });
      });
      describe("when hold is in status ExecutedAndKeptOpen", function () {
        it("renews the hold", async function () {
          this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
          assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_ORDERED);

          const executedAmount = 10;
          await this.validatorContract.executeHoldAndKeepOpen(this.token.address, this.holdId, executedAmount, EMPTY_BYTE32, { from: notary });
          
          this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
          assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_EXECUTED_AND_KEPT_OPEN);

          this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
          assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR-1);
          assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);

          this.time = await this.clock.getTime();
          await this.validatorContract.renewHold(this.token.address, this.holdId, SECONDS_IN_A_DAY, { from: tokenHolder });
          
          this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
          assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_A_DAY-1);
          assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_A_DAY+100);
        });
      });
    });
    describe("when hold can not be renewed", function () {
      describe("when hold is neither in status Ordered, nor ExecutedAndKeptOpen", function () {
        it("reverts", async function () {
          await this.validatorContract.releaseHold(this.token.address, this.holdId, { from: notary });

          this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
          assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_RELEASED_BY_NOTARY);

          await expectRevert.unspecified(this.validatorContract.renewHold(this.token.address, this.holdId, SECONDS_IN_A_DAY, { from: tokenHolder }));
        });
      });
    });
  });

  // RENEW HOLD WITH EXPIRATION DATE

  describe("renewHoldWithExpirationDate", function () {
    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );

      await setSelfHoldsActivated(
        this.validatorContract,
        this.token,
        controller,
        true
      )
      await assertSelfHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
      await assertHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );

      // Create hold in state Ordered
      this.time = await this.clock.getTime();
      this.holdId = newHoldId();
      this.secretHashPair = newSecretHashPair();
      await this.validatorContract.hold(this.token.address, this.holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, this.secretHashPair.hash, { from: tokenHolder })
    });

    describe("when expiration date is valid", function () {
      describe("when expiration date is in the future", function () {
        it("renews the hold", async function () {
          this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
          assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR-1);
          assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);

          this.time = parseInt(await this.clock.getTime());
          const { logs } = await this.validatorContract.renewHoldWithExpirationDate(this.token.address, this.holdId, this.time+SECONDS_IN_A_DAY, { from: tokenHolder });
          
          this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
          assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_A_DAY-1);
          assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_A_DAY+100);

          assert.equal(logs[0].event, "HoldRenewed");
          assert.equal(logs[0].args.token, this.token.address);
          assert.equal(logs[0].args.holdId, this.holdId);
          assert.equal(logs[0].args.notary, notary);
          assert.isAtLeast(parseInt(logs[0].args.oldExpiration), parseInt(this.time)+SECONDS_IN_AN_HOUR-1);
          assert.isBelow(parseInt(logs[0].args.oldExpiration), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);
          assert.isAtLeast(parseInt(logs[0].args.newExpiration), parseInt(this.time)+SECONDS_IN_A_DAY-1);
          assert.isBelow(parseInt(logs[0].args.newExpiration), parseInt(this.time)+SECONDS_IN_A_DAY+100);
        });
      });
      describe("when there is no expiration date", function () {
        it("renews the hold", async function () {
          this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
          assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR-1);
          assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);

          const { logs } = await this.validatorContract.renewHoldWithExpirationDate(this.token.address, this.holdId, 0, { from: tokenHolder });

          this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
                    
          assert.equal(parseInt(this.holdData[5]), 0);

          assert.equal(logs[0].event, "HoldRenewed");
          assert.isAtLeast(parseInt(logs[0].args.oldExpiration), parseInt(this.time)+SECONDS_IN_AN_HOUR-1);
          assert.isBelow(parseInt(logs[0].args.oldExpiration), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);
          assert.equal(parseInt(logs[0].args.newExpiration), 0);
        });
      });
    });
    describe("when expiration date is not valid", function () {
      it("reverts", async function () {
        this.time = await this.clock.getTime();
        await expectRevert.unspecified(this.validatorContract.renewHoldWithExpirationDate(this.token.address, this.holdId, this.time-1, { from: tokenHolder }));
      });
    });
  });

  // EXECUTE HOLD

  describe("executeHold", function () {
    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );

      await setSelfHoldsActivated(
        this.validatorContract,
        this.token,
        controller,
        true
      )
      await assertSelfHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
      await assertHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );

      // Create hold in state Ordered
      this.time = await this.clock.getTime();
      this.holdId = newHoldId();
      this.secretHashPair = newSecretHashPair();
      await this.validatorContract.hold(this.token.address, this.holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, this.secretHashPair.hash, { from: tokenHolder })
    });

    describe("when hold can be executed", function () {
      describe("when hold is in status Ordered", function () {
        describe("when value is not nil", function () {
          describe("when hold is executed by the notary", function () {
            describe("when hold is not expired", function () {
              describe("when value is not higher than hold value", function () {
                describe("when hold shall not be kept open", function () {
                  describe("when the whole amount is executed", function () {
                    it("executes the hold", async function() {
                      const initialBalance = await this.token.balanceOf(tokenHolder)
                      const initialPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
      
                      const initialBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, tokenHolder)
                      const initialBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)
      
                      const initialSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder)
                      const initialSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, tokenHolder)
      
                      const initialTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
                      const initialTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)
      
                      const initialRecipientBalance = await this.token.balanceOf(recipient)
                      const initialRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)
  
                      await this.validatorContract.executeHold(this.token.address, this.holdId, holdAmount, EMPTY_BYTE32, { from: notary })
      
                      const finalBalance = await this.token.balanceOf(tokenHolder)
                      const finalPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
      
                      const finalBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, tokenHolder)
                      const finalBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)
      
                      const finalSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder)
                      const finalSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, tokenHolder)
      
                      const finalTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
                      const finalTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)
  
                      const finalRecipientBalance = await this.token.balanceOf(recipient)
                      const finalRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)
  
                      assert.equal(initialBalance, issuanceAmount)
                      assert.equal(finalBalance, issuanceAmount-holdAmount)
                      assert.equal(initialPartitionBalance, issuanceAmount)
                      assert.equal(finalPartitionBalance, issuanceAmount-holdAmount)
      
                      assert.equal(initialBalanceOnHold, holdAmount)
                      assert.equal(initialBalanceOnHoldByPartition, holdAmount)
                      assert.equal(finalBalanceOnHold, 0)
                      assert.equal(finalBalanceOnHoldByPartition, 0)
      
                      assert.equal(initialSpendableBalance, issuanceAmount-holdAmount)
                      assert.equal(initialSpendableBalanceByPartition, issuanceAmount-holdAmount)
                      assert.equal(finalSpendableBalance, issuanceAmount-holdAmount)
                      assert.equal(finalSpendableBalanceByPartition, issuanceAmount-holdAmount)
      
                      assert.equal(initialTotalSupplyOnHold, holdAmount)
                      assert.equal(initialTotalSupplyOnHoldByPartition, holdAmount)
                      assert.equal(finalTotalSupplyOnHold, 0)
                      assert.equal(finalTotalSupplyOnHoldByPartition, 0)
  
                      assert.equal(initialRecipientBalance, 0)
                      assert.equal(initialRecipientPartitionBalance, 0)
                      assert.equal(finalRecipientBalance, holdAmount)
                      assert.equal(finalRecipientPartitionBalance, holdAmount)
      
                      this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
                      assert.equal(this.holdData[0], partition1);
                      assert.equal(this.holdData[1], tokenHolder);
                      assert.equal(this.holdData[2], recipient);
                      assert.equal(this.holdData[3], notary);
                      assert.equal(parseInt(this.holdData[4]), holdAmount);
                      assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR);
                      assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);
                      assert.equal(this.holdData[6], this.secretHashPair.hash);
                      assert.equal(this.holdData[7], EMPTY_BYTE32);
                      assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_EXECUTED);
                    });
                    it("emits an event", async function() {
                      const { logs } = await this.validatorContract.executeHold(this.token.address, this.holdId, holdAmount, EMPTY_BYTE32, { from: notary })
      
                      assert.equal(logs[0].event, "HoldExecuted");
                      assert.equal(logs[0].args.token, this.token.address);
                      assert.equal(logs[0].args.holdId, this.holdId);
                      assert.equal(logs[0].args.notary, notary);
                      assert.equal(logs[0].args.heldValue, holdAmount);
                      assert.equal(logs[0].args.transferredValue, holdAmount);
                      assert.equal(logs[0].args.secret, EMPTY_BYTE32);
                    });
                  });
                  describe("when a partial amount is executed", function () {
                    it("executes the hold", async function() {
                      const initialPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
                      const initialRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)
  
                      const executedAmount = 400
                      await this.validatorContract.executeHold(this.token.address, this.holdId, executedAmount, EMPTY_BYTE32, { from: notary })
      
                      const finalPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
                      const finalRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)
  
                      assert.equal(initialPartitionBalance, issuanceAmount)
                      assert.equal(finalPartitionBalance, issuanceAmount-executedAmount)
      
                      assert.equal(initialRecipientPartitionBalance, 0)
                      assert.equal(finalRecipientPartitionBalance, executedAmount)
      
                      this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
                      assert.equal(parseInt(this.holdData[4]), holdAmount);
                    });
                    it("emits an event", async function() {
                      const executedAmount = 400
                      const { logs } = await this.validatorContract.executeHold(this.token.address, this.holdId, executedAmount, EMPTY_BYTE32, { from: notary })
      
                      assert.equal(logs[0].event, "HoldExecuted");
                      assert.equal(logs[0].args.token, this.token.address);
                      assert.equal(logs[0].args.holdId, this.holdId);
                      assert.equal(logs[0].args.notary, notary);
                      assert.equal(logs[0].args.heldValue, holdAmount);
                      assert.equal(logs[0].args.transferredValue, executedAmount);
                      assert.equal(logs[0].args.secret, EMPTY_BYTE32);
                    });
                  });
                });
                describe("when hold shall be kept open", function () {
                  describe("when value is lower than hold value", function () {
                    it("executes the hold", async function() {
                      const initialBalance = await this.token.balanceOf(tokenHolder)
                      const initialPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
      
                      const initialBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, tokenHolder)
                      const initialBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)
      
                      const initialSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder)
                      const initialSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, tokenHolder)
      
                      const initialTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
                      const initialTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)
      
                      const initialRecipientBalance = await this.token.balanceOf(recipient)
                      const initialRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)
  
                      const executedAmount = 400
                      await this.validatorContract.executeHoldAndKeepOpen(this.token.address, this.holdId, executedAmount, EMPTY_BYTE32, { from: notary })
      
                      const finalBalance = await this.token.balanceOf(tokenHolder)
                      const finalPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
      
                      const finalBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, tokenHolder)
                      const finalBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, tokenHolder)
      
                      const finalSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, tokenHolder)
                      const finalSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, tokenHolder)
      
                      const finalTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
                      const finalTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)
  
                      const finalRecipientBalance = await this.token.balanceOf(recipient)
                      const finalRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)
  
                      assert.equal(initialBalance, issuanceAmount)
                      assert.equal(finalBalance, issuanceAmount-executedAmount)
                      assert.equal(initialPartitionBalance, issuanceAmount)
                      assert.equal(finalPartitionBalance, issuanceAmount-executedAmount)
      
                      assert.equal(initialBalanceOnHold, holdAmount)
                      assert.equal(initialBalanceOnHoldByPartition, holdAmount)
                      assert.equal(finalBalanceOnHold, holdAmount-executedAmount)
                      assert.equal(finalBalanceOnHoldByPartition, holdAmount-executedAmount)
      
                      assert.equal(initialSpendableBalance, issuanceAmount-holdAmount)
                      assert.equal(initialSpendableBalanceByPartition, issuanceAmount-holdAmount)
                      assert.equal(finalSpendableBalance, issuanceAmount-holdAmount)
                      assert.equal(finalSpendableBalanceByPartition, issuanceAmount-holdAmount)
      
                      assert.equal(initialTotalSupplyOnHold, holdAmount)
                      assert.equal(initialTotalSupplyOnHoldByPartition, holdAmount)
                      assert.equal(finalTotalSupplyOnHold, holdAmount-executedAmount)
                      assert.equal(finalTotalSupplyOnHoldByPartition, holdAmount-executedAmount)
  
                      assert.equal(initialRecipientBalance, 0)
                      assert.equal(initialRecipientPartitionBalance, 0)
                      assert.equal(finalRecipientBalance, executedAmount)
                      assert.equal(finalRecipientPartitionBalance, executedAmount)
      
                      this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
                      assert.equal(this.holdData[0], partition1);
                      assert.equal(this.holdData[1], tokenHolder);
                      assert.equal(this.holdData[2], recipient);
                      assert.equal(this.holdData[3], notary);
                      assert.equal(parseInt(this.holdData[4]), holdAmount-executedAmount);
                      assert.isAtLeast(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR);
                      assert.isBelow(parseInt(this.holdData[5]), parseInt(this.time)+SECONDS_IN_AN_HOUR+100);
                      assert.equal(this.holdData[6], this.secretHashPair.hash);
                      assert.equal(this.holdData[7], EMPTY_BYTE32);
                      assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_EXECUTED_AND_KEPT_OPEN);
                    });
                    it("emits an event", async function() {
                      const executedAmount = 400
                      const { logs } = await this.validatorContract.executeHoldAndKeepOpen(this.token.address, this.holdId, executedAmount, EMPTY_BYTE32, { from: notary })
                      
                      assert.equal(logs[0].event, "HoldExecutedAndKeptOpen");
                      assert.equal(logs[0].args.token, this.token.address);
                      assert.equal(logs[0].args.holdId, this.holdId);
                      assert.equal(logs[0].args.notary, notary);
                      assert.equal(logs[0].args.heldValue, holdAmount-executedAmount);
                      assert.equal(logs[0].args.transferredValue, executedAmount);
                      assert.equal(logs[0].args.secret, EMPTY_BYTE32);
                    });
                  });
                  describe("when value is equal to hold value", function () {
                    it("executes the hold", async function() {
                      const initialPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
                      const initialRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)

                      await this.validatorContract.executeHoldAndKeepOpen(this.token.address, this.holdId, holdAmount, EMPTY_BYTE32, { from: notary })
      
                      const finalPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
                      const finalRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)
  
                      assert.equal(initialPartitionBalance, issuanceAmount)
                      assert.equal(finalPartitionBalance, issuanceAmount-holdAmount)
      
                      assert.equal(initialRecipientPartitionBalance, 0)
                      assert.equal(finalRecipientPartitionBalance, holdAmount)
                    });
                    it("emits an event", async function() {
                      const { logs } = await this.validatorContract.executeHoldAndKeepOpen(this.token.address, this.holdId, holdAmount, EMPTY_BYTE32, { from: notary })
                      
                      assert.equal(logs[0].event, "HoldExecuted");
                      assert.equal(logs[0].args.token, this.token.address);
                      assert.equal(logs[0].args.holdId, this.holdId);
                      assert.equal(logs[0].args.notary, notary);
                      assert.equal(logs[0].args.heldValue, holdAmount);
                      assert.equal(logs[0].args.transferredValue, holdAmount);
                      assert.equal(logs[0].args.secret, EMPTY_BYTE32);
                    });
                  });
                });
              });
              describe("when value is higher than hold value", function () {
                it("reverts", async function() {
                  await expectRevert.unspecified(this.validatorContract.executeHold(this.token.address, this.holdId, holdAmount+1, EMPTY_BYTE32, { from: notary }));
                });
              });
            });
            describe("when hold is expired", function () {
              it("reverts", async function () {
                // Wait for more than an hour
                await advanceTimeAndBlock(SECONDS_IN_AN_HOUR + 100);

                await expectRevert.unspecified(this.validatorContract.executeHold(this.token.address, this.holdId, holdAmount, EMPTY_BYTE32, { from: notary }));
              });
            });
          });
          describe("when hold is executed by the secret holder", function () {
            describe("when the token sender provides the correct secret", function () {
              it("executes the hold", async function () {
                const initialPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
                const initialRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)

                const { logs } = await this.validatorContract.executeHold(this.token.address, this.holdId, holdAmount, this.secretHashPair.secret, { from: recipient })

                const finalPartitionBalance = await this.token.balanceOfByPartition(partition1, tokenHolder)
                const finalRecipientPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)

                assert.equal(initialPartitionBalance, issuanceAmount)
                assert.equal(finalPartitionBalance, issuanceAmount-holdAmount)

                assert.equal(initialRecipientPartitionBalance, 0)
                assert.equal(finalRecipientPartitionBalance, holdAmount)

                this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
                assert.equal(parseInt(this.holdData[4]), holdAmount);

                assert.equal(logs[0].event, "HoldExecuted");
                assert.equal(logs[0].args.secret, this.secretHashPair.secret); // HTLC mechanism
              });
            });
            describe("when the token sender doesn't provide the correct secret", function () {
              it("reverts", async function () {
                this.fakeSecretHashPair = newSecretHashPair();
                await expectRevert.unspecified(this.validatorContract.executeHold(this.token.address, this.holdId, holdAmount, this.fakeSecretHashPair.secret, { from: recipient }));
              });
            });
          });
        });
        describe("when value is nil", function () {
          it("reverts", async function () {
            await expectRevert.unspecified(this.validatorContract.executeHold(this.token.address, this.holdId, 0, EMPTY_BYTE32, { from: notary }));
          });
        });
      });
      describe("when hold is in status ExecutedAndKeptOpen", function () {
        it("executes the hold", async function () {
          this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
          assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_ORDERED);

          const partitionBalance1 = await this.token.balanceOfByPartition(partition1, tokenHolder)
          const recipientPartitionBalance1 = await this.token.balanceOfByPartition(partition1, recipient)

          const executedAmount = 10;
          await this.validatorContract.executeHoldAndKeepOpen(this.token.address, this.holdId, executedAmount, EMPTY_BYTE32, { from: notary });

          this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
          assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_EXECUTED_AND_KEPT_OPEN);

          const partitionBalance2 = await this.token.balanceOfByPartition(partition1, tokenHolder)
          const recipientPartitionBalance2 = await this.token.balanceOfByPartition(partition1, recipient)

          await this.validatorContract.executeHold(this.token.address, this.holdId, holdAmount-executedAmount, EMPTY_BYTE32, { from: notary })

          const partitionBalance3 = await this.token.balanceOfByPartition(partition1, tokenHolder)
          const recipientPartitionBalance3 = await this.token.balanceOfByPartition(partition1, recipient)

          assert.equal(partitionBalance1, issuanceAmount)
          assert.equal(recipientPartitionBalance1, 0)

          assert.equal(partitionBalance2, issuanceAmount-executedAmount)
          assert.equal(recipientPartitionBalance2, executedAmount)

          assert.equal(partitionBalance3, issuanceAmount-holdAmount)
          assert.equal(recipientPartitionBalance3, holdAmount)
        });
      });
    });
    describe("when hold can not be executed", function () {
      it("reverts", async function () {
        await this.validatorContract.releaseHold(this.token.address, this.holdId, { from: notary });

        this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, this.holdId);
        assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_RELEASED_BY_NOTARY);

        await expectRevert.unspecified(this.validatorContract.executeHold(this.token.address, this.holdId, holdAmount, EMPTY_BYTE32, { from: notary }));
      });
    });
  });

  // SET TOKEN CONTROLLERS

  describe("setTokenControllers", function () {
    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );

      await setSelfHoldsActivated(
        this.validatorContract,
        this.token,
        controller,
        true
      )
      await assertSelfHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
      await assertHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
    });
    describe("when the caller is the token contract owner", function () {
      it("sets the operators as token controllers", async function () {
        await assertIsTokenController(
          this.validatorContract,
          this.token,
          controller,
          true,
        );

        await assertIsTokenController(
          this.validatorContract,
          this.token,
          tokenController1,
          false,
        );
        await addTokenController(
          this.validatorContract,
          this.token,
          owner,
          tokenController1
        );
        await assertIsTokenController(
          this.validatorContract,
          this.token,
          tokenController1,
          true,
        );
      });
    });
    describe("when the caller is an other token controller", function () {
      it("sets the operators as token controllers", async function () {
        await assertIsTokenController(
          this.validatorContract,
          this.token,
          controller,
          true,
        );

        await assertIsTokenController(
          this.validatorContract,
          this.token,
          tokenController1,
          false,
        );
        await addTokenController(
          this.validatorContract,
          this.token,
          owner,
          tokenController1
        );
        await assertIsTokenController(
          this.validatorContract,
          this.token,
          tokenController1,
          true,
        );

        await assertIsTokenController(
          this.validatorContract,
          this.token,
          tokenController2,
          false,
        );
        await addTokenController(
          this.validatorContract,
          this.token,
          tokenController1,
          tokenController2
        );
        await assertIsTokenController(
          this.validatorContract,
          this.token,
          tokenController2,
          true,
        );
      });
    });
    describe("when the caller is neither the token contract owner nor a token controller", function () {
      it("reverts", async function () {
        await expectRevert.unspecified(
          addTokenController(
            this.validatorContract,
            this.token,
            unknown,
            tokenController1
          )
        );
      });
    });
  });
  
  // PRE-HOLDS
  describe("pre-hold", function () {
    beforeEach(async function () {
      await this.token.issueByPartition(
        partition1,
        tokenHolder,
        issuanceAmount,
        VALID_CERTIFICATE,
        { from: controller }
      );

      await setSelfHoldsActivated(
        this.validatorContract,
        this.token,
        controller,
        true
      )
      await assertSelfHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
      await assertHoldsActivated(
        this.validatorContract,
        this.token,
        true
      );
    });

    describe("when pre-hold can be created", function () {
      it("creates a pre-hold", async function () {
        const initialBalance = await this.token.balanceOf(recipient)
        const initialPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)

        const initialBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, recipient)
        const initialBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, recipient)

        const initialSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, recipient)
        const initialSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, recipient)

        const initialTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
        const initialTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)

        const time = await this.clock.getTime();
        const holdId = newHoldId();
        const secretHashPair = newSecretHashPair();
        await this.validatorContract.preHoldFor(this.token.address, holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller })

        const finalBalance = await this.token.balanceOf(recipient)
        const finalPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)

        const finalBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, recipient)
        const finalBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, recipient)

        const finalSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, recipient)
        const finalSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, recipient)

        const finalTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
        const finalTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)

        assert.equal(initialBalance, 0)
        assert.equal(finalBalance, 0)
        assert.equal(initialPartitionBalance, 0)
        assert.equal(finalPartitionBalance, 0)

        assert.equal(initialBalanceOnHold, 0)
        assert.equal(initialBalanceOnHoldByPartition, 0)
        assert.equal(finalBalanceOnHold, 0)
        assert.equal(finalBalanceOnHoldByPartition, 0)

        assert.equal(initialSpendableBalance, 0)
        assert.equal(initialSpendableBalanceByPartition, 0)
        assert.equal(finalSpendableBalance, 0)
        assert.equal(finalSpendableBalanceByPartition, 0)

        assert.equal(initialTotalSupplyOnHold, 0)
        assert.equal(initialTotalSupplyOnHoldByPartition, 0)
        assert.equal(finalTotalSupplyOnHold, 0)
        assert.equal(finalTotalSupplyOnHoldByPartition, 0)

        this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, holdId);
        assert.equal(this.holdData[0], partition1);
        assert.equal(this.holdData[1], ZERO_ADDRESS);
        assert.equal(this.holdData[2], recipient);
        assert.equal(this.holdData[3], notary);
        assert.equal(parseInt(this.holdData[4]), holdAmount);
        assert.isAtLeast(parseInt(this.holdData[5]), parseInt(time)+SECONDS_IN_AN_HOUR);
        assert.isBelow(parseInt(this.holdData[5]), parseInt(time)+SECONDS_IN_AN_HOUR+100);
        assert.equal(this.holdData[6], secretHashPair.hash);
        assert.equal(this.holdData[7], EMPTY_BYTE32);
        assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_ORDERED);
      });
      it("emits an event", async function () {
        const holdId = newHoldId();
        const secretHashPair = newSecretHashPair();
        const time = await this.clock.getTime();
        const { logs } = await this.validatorContract.preHoldFor(this.token.address, holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller })

        assert.equal(logs[0].event, "HoldCreated");
        assert.equal(logs[0].args.token, this.token.address);
        assert.equal(logs[0].args.holdId, holdId);
        assert.equal(logs[0].args.partition, partition1);
        assert.equal(logs[0].args.sender, ZERO_ADDRESS);
        assert.equal(logs[0].args.recipient, recipient);
        assert.equal(logs[0].args.notary, notary);
        assert.equal(logs[0].args.value, holdAmount);
        assert.isAtLeast(parseInt(logs[0].args.expiration), parseInt(time)+SECONDS_IN_AN_HOUR);
        assert.isBelow(parseInt(logs[0].args.expiration), parseInt(time)+SECONDS_IN_AN_HOUR+100);
        assert.equal(logs[0].args.secretHash, secretHashPair.hash);
      });
      it("creates a pre-hold with expiration time", async function () {
        const time = parseInt(await this.clock.getTime());
        const holdId = newHoldId();
        const secretHashPair = newSecretHashPair();
        await this.validatorContract.preHoldForWithExpirationDate(this.token.address, holdId, recipient, notary, partition1, holdAmount, time+SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller })

        this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, holdId);
        assert.equal(this.holdData[0], partition1);
        assert.equal(this.holdData[1], ZERO_ADDRESS);
        assert.equal(this.holdData[2], recipient);
        assert.equal(this.holdData[3], notary);
        assert.equal(parseInt(this.holdData[4]), holdAmount);
        assert.equal(parseInt(this.holdData[5]), time+SECONDS_IN_AN_HOUR);
        assert.equal(this.holdData[6], secretHashPair.hash);
        assert.equal(this.holdData[7], EMPTY_BYTE32);
        assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_ORDERED);
      });
      it("creates and releases a pre-hold", async function () {
        const time = parseInt(await this.clock.getTime());
        const holdId = newHoldId();
        const secretHashPair = newSecretHashPair();
        await this.validatorContract.preHoldForWithExpirationDate(this.token.address, holdId, recipient, notary, partition1, holdAmount, time+SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller })
        await this.validatorContract.releaseHold(this.token.address, holdId, { from: notary });

        this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, holdId);
        assert.equal(this.holdData[0], partition1);
        assert.equal(this.holdData[1], ZERO_ADDRESS);
        assert.equal(this.holdData[2], recipient);
        assert.equal(this.holdData[3], notary);
        assert.equal(parseInt(this.holdData[4]), holdAmount);
        assert.equal(parseInt(this.holdData[5]), time+SECONDS_IN_AN_HOUR);
        assert.equal(this.holdData[6], secretHashPair.hash);
        assert.equal(this.holdData[7], EMPTY_BYTE32);
        assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_RELEASED_BY_NOTARY);
      });
      it("creates and renews a pre-hold", async function () {
        const time = parseInt(await this.clock.getTime());
        const holdId = newHoldId();
        const secretHashPair = newSecretHashPair();
        await this.validatorContract.preHoldForWithExpirationDate(this.token.address, holdId, recipient, notary, partition1, holdAmount, time+SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller })
        await this.validatorContract.renewHold(this.token.address, holdId, SECONDS_IN_A_DAY, { from: controller });

        this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, holdId);
        assert.equal(this.holdData[0], partition1);
        assert.equal(this.holdData[1], ZERO_ADDRESS);
        assert.equal(this.holdData[2], recipient);
        assert.equal(this.holdData[3], notary);
        assert.equal(parseInt(this.holdData[4]), holdAmount);
        assert.isAtLeast(parseInt(this.holdData[5]), time+SECONDS_IN_A_DAY-1);
        assert.isBelow(parseInt(this.holdData[5]), time+SECONDS_IN_A_DAY+100);
        assert.equal(this.holdData[6], secretHashPair.hash);
        assert.equal(this.holdData[7], EMPTY_BYTE32);
        assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_ORDERED);
      });
      it("creates a pre-hold and fails renewing it", async function () {
        const time = parseInt(await this.clock.getTime());
        const holdId = newHoldId();
        const secretHashPair = newSecretHashPair();
        await this.validatorContract.preHoldForWithExpirationDate(this.token.address, holdId, recipient, notary, partition1, holdAmount, time+SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller })
        await expectRevert.unspecified(this.validatorContract.renewHold(this.token.address, holdId, SECONDS_IN_A_DAY, { from: recipient }));
      });
      it("creates and executes pre-hold", async function () {
        const initialBalance = await this.token.balanceOf(recipient)
        const initialPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)

        const initialBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, recipient)
        const initialBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, recipient)

        const initialSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, recipient)
        const initialSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, recipient)

        const initialTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
        const initialTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)

        const time = await this.clock.getTime();
        const holdId = newHoldId();
        const secretHashPair = newSecretHashPair();
        await this.validatorContract.preHoldFor(this.token.address, holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller })
        await this.validatorContract.executeHold(this.token.address, holdId, holdAmount, secretHashPair.secret, { from: recipient })

        const finalBalance = await this.token.balanceOf(recipient)
        const finalPartitionBalance = await this.token.balanceOfByPartition(partition1, recipient)

        const finalBalanceOnHold = await this.validatorContract.balanceOnHold(this.token.address, recipient)
        const finalBalanceOnHoldByPartition = await this.validatorContract.balanceOnHoldByPartition(this.token.address, partition1, recipient)

        const finalSpendableBalance = await this.validatorContract.spendableBalanceOf(this.token.address, recipient)
        const finalSpendableBalanceByPartition = await this.validatorContract.spendableBalanceOfByPartition(this.token.address, partition1, recipient)

        const finalTotalSupplyOnHold = await this.validatorContract.totalSupplyOnHold(this.token.address)
        const finalTotalSupplyOnHoldByPartition = await this.validatorContract.totalSupplyOnHoldByPartition(this.token.address, partition1)

        assert.equal(initialBalance, 0)
        assert.equal(finalBalance, holdAmount)
        assert.equal(initialPartitionBalance, 0)
        assert.equal(finalPartitionBalance, holdAmount)

        assert.equal(initialBalanceOnHold, 0)
        assert.equal(initialBalanceOnHoldByPartition, 0)
        assert.equal(finalBalanceOnHold, 0)
        assert.equal(finalBalanceOnHoldByPartition, 0)

        assert.equal(initialSpendableBalance, 0)
        assert.equal(initialSpendableBalanceByPartition, 0)
        assert.equal(finalSpendableBalance, holdAmount)
        assert.equal(finalSpendableBalanceByPartition, holdAmount)

        assert.equal(initialTotalSupplyOnHold, 0)
        assert.equal(initialTotalSupplyOnHoldByPartition, 0)
        assert.equal(finalTotalSupplyOnHold, 0)
        assert.equal(finalTotalSupplyOnHoldByPartition, 0)

        this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, holdId);
        assert.equal(this.holdData[0], partition1);
        assert.equal(this.holdData[1], ZERO_ADDRESS);
        assert.equal(this.holdData[2], recipient);
        assert.equal(this.holdData[3], notary);
        assert.equal(parseInt(this.holdData[4]), holdAmount);
        assert.isAtLeast(parseInt(this.holdData[5]), parseInt(time)+SECONDS_IN_AN_HOUR);
        assert.isBelow(parseInt(this.holdData[5]), parseInt(time)+SECONDS_IN_AN_HOUR+100);
        assert.equal(this.holdData[6], secretHashPair.hash);
        assert.equal(this.holdData[7], secretHashPair.secret);
        assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_EXECUTED);
      });
      it("creates and executes pre-hold in 2 times", async function () {
        const initialBalance = await this.token.balanceOf(recipient)

        const time = await this.clock.getTime();
        const holdId = newHoldId();
        const secretHashPair = newSecretHashPair();
        await this.validatorContract.preHoldFor(this.token.address, holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: controller })
        await this.validatorContract.executeHoldAndKeepOpen(this.token.address, holdId, holdAmount-100, secretHashPair.secret, { from: recipient })

        const intermediateBalance = await this.token.balanceOf(recipient)

        this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, holdId);
        assert.equal(this.holdData[0], partition1);
        assert.equal(this.holdData[1], ZERO_ADDRESS);
        assert.equal(this.holdData[2], recipient);
        assert.equal(this.holdData[3], notary);
        assert.equal(parseInt(this.holdData[4]), 100);
        assert.isAtLeast(parseInt(this.holdData[5]), parseInt(time)+SECONDS_IN_AN_HOUR);
        assert.isBelow(parseInt(this.holdData[5]), parseInt(time)+SECONDS_IN_AN_HOUR+100);
        assert.equal(this.holdData[6], secretHashPair.hash);
        assert.equal(this.holdData[7], secretHashPair.secret);
        assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_EXECUTED_AND_KEPT_OPEN);

        await this.validatorContract.executeHold(this.token.address, holdId, 100, secretHashPair.secret, { from: recipient })

        const finalBalance = await this.token.balanceOf(recipient)
        
        assert.equal(initialBalance, 0)
        assert.equal(intermediateBalance, holdAmount-100)
        assert.equal(finalBalance, holdAmount)

        this.holdData = await this.validatorContract.retrieveHoldData(this.token.address, holdId);
        assert.equal(this.holdData[0], partition1);
        assert.equal(this.holdData[1], ZERO_ADDRESS);
        assert.equal(this.holdData[2], recipient);
        assert.equal(this.holdData[3], notary);
        assert.equal(parseInt(this.holdData[4]), 100);
        assert.isAtLeast(parseInt(this.holdData[5]), parseInt(time)+SECONDS_IN_AN_HOUR);
        assert.isBelow(parseInt(this.holdData[5]), parseInt(time)+SECONDS_IN_AN_HOUR+100);
        assert.equal(this.holdData[6], secretHashPair.hash);
        assert.equal(this.holdData[7], secretHashPair.secret);
        assert.equal(parseInt(this.holdData[8]), HOLD_STATUS_EXECUTED);
      });
    });
    describe("when pre-hold can not be created", function () {
      describe("when expiration date is not valid", function () {
        it("reverts", async function () {
          const time = parseInt(await this.clock.getTime());
          const holdId = newHoldId();
          const secretHashPair = newSecretHashPair();
          await expectRevert.unspecified(this.validatorContract.preHoldForWithExpirationDate(this.token.address, holdId, recipient, notary, partition1, holdAmount, time-1, secretHashPair.hash, { from: controller }))
        });
      });
      describe("when caller is not a minter", function () {
        it("reverts", async function () {
          const holdId = newHoldId();
          const secretHashPair = newSecretHashPair();
          await expectRevert.unspecified(this.validatorContract.preHoldFor(this.token.address, holdId, recipient, notary, partition1, holdAmount, SECONDS_IN_AN_HOUR, secretHashPair.hash, { from: notary }));
        });
      });
    });
  });

});
