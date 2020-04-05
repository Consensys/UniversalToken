const { shouldFail } = require('openzeppelin-test-helpers');

const { soliditySha3 } = require("web3-utils");

const ERC1400 = artifacts.require('ERC1400');
const ERC1400Partition = artifacts.require('ERC1400PartitionMock');
const ERC1820Registry = artifacts.require('ERC1820Registry');
const ERC1400TokensSender = artifacts.require('ERC1400TokensSenderMock');
const ERC1400TokensValidator = artifacts.require('ERC1400TokensValidator');
const ERC1400TokensRecipient = artifacts.require('ERC1400TokensRecipientMock');
const ERC1400TokensChecker = artifacts.require('ERC1400TokensChecker');

const ERC1820_ACCEPT_MAGIC = 'ERC1820_ACCEPT_MAGIC';

const ERC20_INTERFACE_NAME = 'ERC20Token';
const ERC1400_INTERFACE_NAME = 'ERC1400Token';

const ERC1400_TOKENS_SENDER = 'ERC1400TokensSender';
const ERC1400_TOKENS_RECIPIENT = 'ERC1400TokensRecipient';
const ERC1400_TOKENS_VALIDATOR = 'ERC1400TokensValidator';
const ERC1400_TOKENS_CHECKER = 'ERC1400TokensChecker';

const ZERO_BYTES32 = '0x0000000000000000000000000000000000000000000000000000000000000000';
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTE = '0x';

const EMPTY_BYTE32 = '0x0000000000000000000000000000000000000000000000000000000000000000';

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';
const CERTIFICATE_SIGNER_ALTERNATIVE1 = '0xca35b7d915458ef540ade6068dfe2f44e8fa733c';
const CERTIFICATE_SIGNER_ALTERNATIVE2 = '0x14723a09acff6d2a60dcdf7aa4aff308fddc160c';
const certificateSigners = [CERTIFICATE_SIGNER, CERTIFICATE_SIGNER_ALTERNATIVE1, CERTIFICATE_SIGNER_ALTERNATIVE2];

const VALID_CERTIFICATE = '0x1000000000000000000000000000000000000000000000000000000000000000';
const INVALID_CERTIFICATE = '0x0000000000000000000000000000000000000000000000000000000000000000';

const INVALID_CERTIFICATE_SENDER = '0x1100000000000000000000000000000000000000000000000000000000000000';
const INVALID_CERTIFICATE_RECIPIENT = '0x2200000000000000000000000000000000000000000000000000000000000000';
const INVALID_CERTIFICATE_VALIDATOR = '0x3300000000000000000000000000000000000000000000000000000000000000';

const partitionFlag = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'; // Flag to indicate a partition change
const otherFlag = '0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'; // Other flag
const partition1_short = '5265736572766564000000000000000000000000000000000000000000000000'; // Reserved in hex
const partition2_short = '4973737565640000000000000000000000000000000000000000000000000000'; // Issued in hex
const partition3_short = '4c6f636b65640000000000000000000000000000000000000000000000000000'; // Locked in hex
const changeToPartition1 = partitionFlag.concat(partition1_short);
const changeToPartition2 = partitionFlag.concat(partition2_short);
const changeToPartition3 = partitionFlag.concat(partition3_short);
const doNotChangePartition = otherFlag.concat(partition2_short);
const partition1 = '0x'.concat(partition1_short);
const partition2 = '0x'.concat(partition2_short);
const partition3 = '0x'.concat(partition3_short);

const partitions = [partition1, partition2, partition3];
const reversedPartitions = [partition3, partition1, partition2];

const documentName = '0x446f63756d656e74204e616d6500000000000000000000000000000000000000';

const ESC_00 = '0x00'; // Transfer verifier not setup
// const ESC_A1 = '0xa1'; // Transfer Verified - On-Chain approval for restricted token
const ESC_A2 = '0xa2'; // Transfer Verified - Off-Chain approval for restricted token
const ESC_A3 = '0xa3'; // Transfer Blocked - Sender lockup period not ended
const ESC_A4 = '0xa4'; // Transfer Blocked - Sender balance insufficient
const ESC_A5 = '0xa5'; // Transfer Blocked - Sender not eligible
const ESC_A6 = '0xa6'; // Transfer Blocked - Receiver not eligible
const ESC_A7 = '0xa7'; // Transfer Blocked - Identity restriction
// const ESC_A8 = '0xa8'; // Transfer Blocked - Token restriction
const ESC_A9 = '0xa9'; // Transfer Blocked - Token granularity

const issuanceAmount = 1000;

var totalSupply;
var balance;
var balanceByPartition;

var defaultPartitions;

const assertTransferEvent = (
  _logs,
  _fromPartition,
  _operator,
  _from,
  _to,
  _amount,
  _data,
  _operatorData
) => {
  var i = 0;
  if (_logs.length === 3) {
    assert.equal(_logs[0].event, 'Checked');
    assert.equal(_logs[0].args.sender, _operator);
    i = 1;
  }

  assert.equal(_logs[i].event, 'TransferWithData');
  assert.equal(_logs[i].args.operator, _operator);
  assert.equal(_logs[i].args.from, _from);
  assert.equal(_logs[i].args.to, _to);
  assert.equal(_logs[i].args.value, _amount);
  assert.equal(_logs[i].args.data, _data);
  assert.equal(_logs[i].args.operatorData, _operatorData);

  assert.equal(_logs[i + 1].event, 'TransferByPartition');
  assert.equal(_logs[i + 1].args.fromPartition, _fromPartition);
  assert.equal(_logs[i + 1].args.operator, _operator);
  assert.equal(_logs[i + 1].args.from, _from);
  assert.equal(_logs[i + 1].args.to, _to);
  assert.equal(_logs[i + 1].args.value, _amount);
  assert.equal(_logs[i + 1].args.data, _data);
  assert.equal(_logs[i + 1].args.operatorData, _operatorData);
};

const assertBurnEvent = (
  _logs,
  _fromPartition,
  _operator,
  _from,
  _amount,
  _data,
  _operatorData
) => {
  var i = 0;
  if (_logs.length === 3) {
    assert.equal(_logs[0].event, 'Checked');
    assert.equal(_logs[0].args.sender, _operator);
    i = 1;
  }

  assert.equal(_logs[i].event, 'Redeemed');
  assert.equal(_logs[i].args.operator, _operator);
  assert.equal(_logs[i].args.from, _from);
  assert.equal(_logs[i].args.value, _amount);
  assert.equal(_logs[i].args.data, _data);
  assert.equal(_logs[i].args.operatorData, _operatorData);

  assert.equal(_logs[i + 1].event, 'RedeemedByPartition');
  assert.equal(_logs[i + 1].args.partition, _fromPartition);
  assert.equal(_logs[i + 1].args.operator, _operator);
  assert.equal(_logs[i + 1].args.from, _from);
  assert.equal(_logs[i + 1].args.value, _amount);
  assert.equal(_logs[i + 1].args.data, _data);
  assert.equal(_logs[i + 1].args.operatorData, _operatorData);
};

const assertBalances = async (
  _contract,
  _tokenHolder,
  _partitions,
  _amounts
) => {
  var totalBalance = 0;
  for (var i = 0; i < _partitions.length; i++) {
    totalBalance += _amounts[i];
    await assertBalanceOfByPartition(_contract, _tokenHolder, _partitions[i], _amounts[i]);
  }
  await assertBalance(_contract, _tokenHolder, totalBalance);
};

const assertBalanceOf = async (
  _contract,
  _tokenHolder,
  _partition,
  _amount
) => {
  await assertBalance(_contract, _tokenHolder, _amount);
  await assertBalanceOfByPartition(_contract, _tokenHolder, _partition, _amount);
};

const assertBalanceOfByPartition = async (
  _contract,
  _tokenHolder,
  _partition,
  _amount
) => {
  balanceByPartition = await _contract.balanceOfByPartition(_partition, _tokenHolder);
  assert.equal(balanceByPartition, _amount);
};

const assertBalance = async (
  _contract,
  _tokenHolder,
  _amount
) => {
  balance = await _contract.balanceOf(_tokenHolder);
  assert.equal(balance, _amount);
};

const assertTotalSupply = async (_contract, _amount) => {
  totalSupply = await _contract.totalSupply();
  assert.equal(totalSupply, _amount);
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

const authorizeOperatorForPartitions = async (
  _contract,
  _operator,
  _tokenHolder,
  _partitions
) => {
  for (var i = 0; i < _partitions.length; i++) {
    await _contract.authorizeOperatorByPartition(_partitions[i], _operator, { from: _tokenHolder });
  }
};

const issueOnMultiplePartitions = async (
  _contract,
  _owner,
  _recipient,
  _partitions,
  _amounts
) => {
  for (var i = 0; i < _partitions.length; i++) {
    await _contract.issueByPartition(_partitions[i], _recipient, _amounts[i], VALID_CERTIFICATE, { from: _owner });
  }
};

contract('ERC1400', function ([owner, operator, controller, controller_alternative1, controller_alternative2, tokenHolder, recipient, unknown]) {
  before(async function () {
    this.registry = await ERC1820Registry.at('0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24');
  });

  describe('parameters', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    describe('name', function () {
      it('returns the name of the token', async function () {
        const name = await this.token.name();

        assert.equal(name, 'ERC1400Token');
      });
    });

    describe('symbol', function () {
      it('returns the symbol of the token', async function () {
        const symbol = await this.token.symbol();

        assert.equal(symbol, 'DAU');
      });
    });

    describe('implementer1400', function () {
      it('returns the contract address', async function () {
        let interface1400Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_INTERFACE_NAME));
        assert.equal(interface1400Implementer, this.token.address);
      });
    });

    describe('implementer20', function () {
      it('returns the zero address', async function () {
        let interface20Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC20_INTERFACE_NAME));
        assert.equal(interface20Implementer, ZERO_ADDRESS);
      });
    });
  });

  // CANIMPLEMENTINTERFACE

  describe('canImplementInterfaceForAddress', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    describe('when interface hash is correct', function () {
      it('returns ERC1820_ACCEPT_MAGIC', async function () {
        const canImplement = await this.token.canImplementInterfaceForAddress(soliditySha3(ERC1400_INTERFACE_NAME), ZERO_ADDRESS);          
        assert.equal(soliditySha3(ERC1820_ACCEPT_MAGIC), canImplement);
      });
    });
    describe('when interface hash is not correct', function () {
      it('returns ERC1820_ACCEPT_MAGIC', async function () {
        const canImplement = await this.token.canImplementInterfaceForAddress(soliditySha3('FakeToken'), ZERO_ADDRESS);
        assert.equal(ZERO_BYTES32, canImplement);
      });
    });
  });

  // CANTRANSFER

  describe('canTransferByPartition/canOperatorTransferByPartition', function () {
    var localGranularity = 10;
    const amount = 10 * localGranularity;

    before(async function () {
      this.senderContract = await ERC1400TokensSender.new({ from: tokenHolder });
      await this.registry.setInterfaceImplementer(tokenHolder, soliditySha3(ERC1400_TOKENS_SENDER), this.senderContract.address, { from: tokenHolder });

      this.validatorContract = await ERC1400TokensValidator.new(true, false, { from: owner });

      this.recipientContract = await ERC1400TokensRecipient.new({ from: recipient });
      await this.registry.setInterfaceImplementer(recipient, soliditySha3(ERC1400_TOKENS_RECIPIENT), this.recipientContract.address, { from: recipient });
    });
    after(async function () {
      await this.registry.setInterfaceImplementer(tokenHolder, soliditySha3(ERC1400_TOKENS_SENDER), ZERO_ADDRESS , { from: tokenHolder });
      await this.registry.setInterfaceImplementer(recipient, soliditySha3(ERC1400_TOKENS_RECIPIENT), ZERO_ADDRESS, { from: recipient });
    });

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400PartitionToken', 'DAU', localGranularity, [controller], CERTIFICATE_SIGNER, true, partitions);
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });

      await this.token.setHookContract(this.validatorContract.address, ERC1400_TOKENS_VALIDATOR, { from: owner });
    });

    describe('when certificate is valid', function () {
      describe('when checker has been setup', function () {
        before(async function () {
          this.checkerContract = await ERC1400TokensChecker.new({ from: owner });
        });
        beforeEach(async function () {
          await this.token.setHookContract(this.checkerContract.address, ERC1400_TOKENS_CHECKER, { from: owner });
        });
        describe('when the operator is authorized', function () {
          describe('when balance is sufficient', function () {
            describe('when receiver is not the zero address', function () {
              describe('when sender is eligible', function () {
                describe('when validator is ok', function () {
                  describe('when receiver is eligible', function () {
                      describe('when the amount is a multiple of the granularity', function () {
                        it('returns Ethereum status code A2 (canTransferByPartition)', async function () {
                          const response = await this.token.canTransferByPartition(
                            partition1, recipient, amount, VALID_CERTIFICATE, { from: tokenHolder });
                          await assertEscResponse(response, ESC_A2, EMPTY_BYTE32, partition1);
  
                        });
                        it('returns Ethereum status code A2 (canOperatorTransferByPartition)', async function () {
                          const response = await this.token.canOperatorTransferByPartition(
                            partition1, tokenHolder, recipient, amount, ZERO_BYTE, VALID_CERTIFICATE, { from: tokenHolder });
                          await assertEscResponse(response, ESC_A2, EMPTY_BYTE32, partition1);
                        });
                      });
                      describe('when the amount is not a multiple of the granularity', function () {
                        it('returns Ethereum status code A9', async function () {
                          const response = await this.token.canTransferByPartition(
                            partition1, recipient, 1, VALID_CERTIFICATE, { from: tokenHolder });
                          await assertEscResponse(response, ESC_A9, EMPTY_BYTE32, partition1);
                        });
                      });
                    });
                  describe('when receiver is not eligible', function () {
                      it('returns Ethereum status code A6', async function () {
                        const response = await this.token.canTransferByPartition(
                          partition1, recipient, amount, INVALID_CERTIFICATE_RECIPIENT, { from: tokenHolder });
                        await assertEscResponse(response, ESC_A6, EMPTY_BYTE32, partition1);
                      });
                  });
                });
                describe('when validator is not ok', function () {
                  it('returns Ethereum status code A3 (canTransferByPartition)', async function () {
                      const response = await this.token.canTransferByPartition(
                        partition1, recipient, amount, INVALID_CERTIFICATE_VALIDATOR, { from: tokenHolder });
                      await assertEscResponse(response, ESC_A3, EMPTY_BYTE32, partition1);
                  });
                });
              });
              describe('when sender is not eligible', function () {
                it('returns Ethereum status code A5', async function () {
                  const response = await this.token.canTransferByPartition(
                    partition1, recipient, amount, INVALID_CERTIFICATE_SENDER, { from: tokenHolder });
                  await assertEscResponse(response, ESC_A5, EMPTY_BYTE32, partition1);
                });
              });
            });
            describe('when receiver is the zero address', function () {
              it('returns Ethereum status code A6', async function () {
                const response = await this.token.canTransferByPartition(
                  partition1, ZERO_ADDRESS, amount, VALID_CERTIFICATE, { from: tokenHolder });
                await assertEscResponse(response, ESC_A6, EMPTY_BYTE32, partition1);
              });
            });
          });
          describe('when balance is not sufficient', function () {
            it('returns Ethereum status code A4 (insuficient global balance)', async function () {
              const response = await this.token.canTransferByPartition(
                partition1, recipient, issuanceAmount + localGranularity, VALID_CERTIFICATE, { from: tokenHolder });
              await assertEscResponse(response, ESC_A4, EMPTY_BYTE32, partition1);
            });
            it('returns Ethereum status code A4 (insuficient partition balance)', async function () {
              await this.token.issueByPartition(
                partition2, tokenHolder, localGranularity, VALID_CERTIFICATE, { from: owner });
              const response = await this.token.canTransferByPartition(
                partition2, recipient, amount, VALID_CERTIFICATE, { from: tokenHolder });
              await assertEscResponse(response, ESC_A4, EMPTY_BYTE32, partition2);
            });
          });
        });
        describe('when the operator is not authorized', function () {
          it('returns Ethereum status code A7 (canOperatorTransferByPartition)', async function () {
            const response = await this.token.canOperatorTransferByPartition(
              partition1, operator, recipient, amount, ZERO_BYTE, VALID_CERTIFICATE, { from: tokenHolder });
            await assertEscResponse(response, ESC_A7, EMPTY_BYTE32, partition1);
          });
        });
      });
      describe('when checker has not been setup', function () {
        it('returns empty Ethereum status code 00 (canTransferByPartition)', async function () {
          const response = await this.token.canTransferByPartition(
            partition1, recipient, amount, VALID_CERTIFICATE, { from: tokenHolder });
          await assertEscResponse(response, ESC_00, EMPTY_BYTE32, partition1);
        });
      });
    });
    describe('when certificate is not valid', function () {
      it('returns Ethereum status code A3 (canTransferByPartition)', async function () {
        const response = await this.token.canTransferByPartition(
          partition1, recipient, amount, INVALID_CERTIFICATE, { from: tokenHolder });
        await assertEscResponse(response, ESC_A3, EMPTY_BYTE32, partition1);
      });
      it('returns Ethereum status code A3 (canOperatorTransferByPartition)', async function () {
        const response = await this.token.canOperatorTransferByPartition(
          partition1, tokenHolder, recipient, amount, ZERO_BYTE, INVALID_CERTIFICATE, { from: tokenHolder });
        await assertEscResponse(response, ESC_A3, EMPTY_BYTE32, partition1);
      });
    });
  });

  // AUTHORIZE OPERATOR BY PARTITION

  describe('authorizeOperatorByPartition', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    it('authorizes operator for partition', async function () {
      await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
      assert.isTrue(await this.token.isOperatorForPartition(partition1, operator, tokenHolder));
    });
  });

  // SET CONTROLLERS

  describe('setControllers', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    describe('when the caller is the contract owner', function () {
      it('sets the operators as controllers', async function () {
        const controllers1 = await this.token.controllers();
        assert.equal(controllers1.length, 1);
        assert.equal(controllers1[0], controller);
        assert.isTrue(await this.token.isOperator(controller, unknown));
        assert.isTrue(!(await this.token.isOperator(controller_alternative1, unknown)));
        assert.isTrue(!(await this.token.isOperator(controller_alternative2, unknown)));
        await this.token.setControllers([controller_alternative1, controller_alternative2], { from: owner });
        const controllers2 = await this.token.controllers();
        assert.equal(controllers2.length, 2);
        assert.equal(controllers2[0], controller_alternative1);
        assert.equal(controllers2[1], controller_alternative2);
        assert.isTrue(!(await this.token.isOperator(controller, unknown)));
        assert.isTrue(await this.token.isOperator(controller_alternative1, unknown));
        assert.isTrue(await this.token.isOperator(controller_alternative2, unknown));
        await this.token.renounceControl({ from: owner });
        assert.isTrue(!(await this.token.isOperator(controller_alternative1, unknown)));
        assert.isTrue(!(await this.token.isOperator(controller_alternative1, unknown)));
        assert.isTrue(!(await this.token.isOperator(controller_alternative2, unknown)));
      });
    });
    describe('when the caller is not the contract owner', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.setControllers([controller_alternative1, controller_alternative2], { from: unknown }));
      });
    });
  });

  // SET PARTITION CONTROLLERS

  describe('setPartitionControllers', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    describe('when the caller is the contract owner', function () {
      it('sets the operators as controllers for the specified partition', async function () {
        assert.isTrue(await this.token.isControllable());

        const controllers1 = await this.token.controllersByPartition(partition1);
        assert.equal(controllers1.length, 0);
        assert.isTrue(await this.token.isOperatorForPartition(partition1, controller, unknown));
        assert.isTrue(!(await this.token.isOperatorForPartition(partition1, controller_alternative1, unknown)));
        assert.isTrue(!(await this.token.isOperatorForPartition(partition1, controller_alternative2, unknown)));
        await this.token.setPartitionControllers(partition1, [controller_alternative1, controller_alternative2], { from: owner });
        const controllers2 = await this.token.controllersByPartition(partition1);
        assert.equal(controllers2.length, 2);
        assert.equal(controllers2[0], controller_alternative1);
        assert.equal(controllers2[1], controller_alternative2);
        assert.isTrue(await this.token.isOperatorForPartition(partition1, controller, unknown));
        assert.isTrue(await this.token.isOperatorForPartition(partition1, controller_alternative1, unknown));
        assert.isTrue(await this.token.isOperatorForPartition(partition1, controller_alternative2, unknown));
        await this.token.renounceControl({ from: owner });
        assert.isTrue(!(await this.token.isOperatorForPartition(partition1, controller_alternative1, unknown)));
        assert.isTrue(!(await this.token.isOperatorForPartition(partition1, controller_alternative1, unknown)));
        assert.isTrue(!(await this.token.isOperatorForPartition(partition1, controller_alternative2, unknown)));
      });
      it('removes the operators as controllers for the specified partition', async function () {
        assert.isTrue(await this.token.isControllable());

        const controllers1 = await this.token.controllersByPartition(partition1);
        assert.equal(controllers1.length, 0);
        assert.isTrue(await this.token.isOperatorForPartition(partition1, controller, unknown));
        assert.isTrue(!(await this.token.isOperatorForPartition(partition1, controller_alternative1, unknown)));
        assert.isTrue(!(await this.token.isOperatorForPartition(partition1, controller_alternative2, unknown)));
        await this.token.setPartitionControllers(partition1, [controller_alternative1, controller_alternative2], { from: owner });
        const controllers2 = await this.token.controllersByPartition(partition1);
        assert.equal(controllers2.length, 2);
        assert.equal(controllers2[0], controller_alternative1);
        assert.equal(controllers2[1], controller_alternative2);
        assert.isTrue(await this.token.isOperatorForPartition(partition1, controller, unknown));
        assert.isTrue(await this.token.isOperatorForPartition(partition1, controller_alternative1, unknown));
        assert.isTrue(await this.token.isOperatorForPartition(partition1, controller_alternative2, unknown));
        await this.token.setPartitionControllers(partition1, [controller_alternative2], { from: owner });
        const controllers3 = await this.token.controllersByPartition(partition1);
        assert.equal(controllers3.length, 1);
        assert.equal(controllers3[0], controller_alternative2);
        assert.isTrue(await this.token.isOperatorForPartition(partition1, controller, unknown));
        assert.isTrue(!(await this.token.isOperatorForPartition(partition1, controller_alternative1, unknown)));
        assert.isTrue(await this.token.isOperatorForPartition(partition1, controller_alternative2, unknown));
      });
    });
    describe('when the caller is not the contract owner', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.setPartitionControllers(partition1, [controller_alternative1, controller_alternative2], { from: unknown }));
      });
    });
  });

  // SET CERTIFICATE SIGNERS

  describe('setCertificateSigner', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    describe('when the caller is the contract owner', function () {
      it('sets the operators as certificate signers', async function () {
        assert.isTrue(await this.token.certificateSigners(CERTIFICATE_SIGNER));
        assert.isTrue(!(await this.token.certificateSigners(CERTIFICATE_SIGNER_ALTERNATIVE1)));
        assert.isTrue(!(await this.token.certificateSigners(CERTIFICATE_SIGNER_ALTERNATIVE2)));
        await this.token.setCertificateSigner(CERTIFICATE_SIGNER, false, { from: owner });
        await this.token.setCertificateSigner(CERTIFICATE_SIGNER_ALTERNATIVE1, false, { from: owner });
        await this.token.setCertificateSigner(CERTIFICATE_SIGNER_ALTERNATIVE2, true, { from: owner });
        assert.isTrue(!(await this.token.certificateSigners(CERTIFICATE_SIGNER)));
        assert.isTrue(!(await this.token.certificateSigners(CERTIFICATE_SIGNER_ALTERNATIVE1)));
        assert.isTrue(await this.token.certificateSigners(CERTIFICATE_SIGNER_ALTERNATIVE2));
      });
    });
    describe('when the caller is not the contract owner', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.setCertificateSigner(CERTIFICATE_SIGNER, true, { from: unknown }));
        await shouldFail.reverting(this.token.setCertificateSigner(CERTIFICATE_SIGNER_ALTERNATIVE1, true, { from: unknown }));
      });
    });
  });

  // SET CERTIFICATE CONTROLLER ACTIVATED

  describe('setCertificateControllerActivated', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    describe('when the sender is the contract owner', function () {
      it('deactivates the certificate controller', async function () {
        await this.token.setCertificateControllerActivated(false, { from: owner });
        assert.isTrue(!(await this.token.certificateControllerActivated()));
      });
      it('deactivates and reactivates the certificate controller', async function () {
        assert.isTrue(await this.token.certificateControllerActivated());
        await this.token.setCertificateControllerActivated(false, { from: owner });

        await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, INVALID_CERTIFICATE, { from: owner });
        await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });

        assert.isTrue(!(await this.token.certificateControllerActivated()));
        await this.token.setCertificateControllerActivated(true, { from: owner });
        assert.isTrue(await this.token.certificateControllerActivated());

        await shouldFail.reverting(this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, INVALID_CERTIFICATE, { from: owner }));
        await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
      });
    });
    describe('when the sender is not the contract owner', function () {
      it('reverts', async function () {
        await shouldFail.reverting(
          this.token.setCertificateControllerActivated(true, { from: unknown })
        );
      });
    });
  });

  // AUTHORIZE OPERATOR BY PARTITION

  describe('authorizeOperatorByPartition', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    it('authorizes the operator', async function () {
      assert.isTrue(!(await this.token.isOperatorForPartition(partition1, operator, tokenHolder)));
      await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
      assert.isTrue(await this.token.isOperatorForPartition(partition1, operator, tokenHolder));
    });
    it('emits an authorized event', async function () {
      const { logs } = await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });

      assert.equal(logs.length, 1);
      assert.equal(logs[0].event, 'AuthorizedOperatorByPartition');
      assert.equal(logs[0].args.partition, partition1);
      assert.equal(logs[0].args.operator, operator);
      assert.equal(logs[0].args.tokenHolder, tokenHolder);
    });
  });

  // APPROVE BY PARTITION

  describe('approveByPartition', function () {
    const amount = 100;
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    describe('when sender approves an operator for a given partition', function () {
      it('approves the operator', async function () {
        assert.equal(await this.token.allowanceByPartition(partition1, tokenHolder, operator), 0);

        await this.token.approveByPartition(partition1, operator, amount, { from: tokenHolder });

        assert.equal(await this.token.allowanceByPartition(partition1, tokenHolder, operator), amount);
      });
      it('emits an approval event', async function () {
        const { logs } = await this.token.approveByPartition(partition1, operator, amount, { from: tokenHolder });

        assert.equal(logs.length, 1);
        assert.equal(logs[0].event, 'ApprovalByPartition');
        assert.equal(logs[0].args.partition, partition1);
        assert.equal(logs[0].args.owner, tokenHolder);
        assert.equal(logs[0].args.spender, operator);
        assert.equal(logs[0].args.value, amount);
      });
    });
    describe('when the operator to approve is the zero address', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.approveByPartition(partition1, ZERO_ADDRESS, amount, { from: tokenHolder }));
      });
    });
  });

  // REVOKE OPERATOR BY PARTITION

  describe('revokeOperatorByPartition', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    describe('when operator is not controller', function () {
      it('revokes the operator', async function () {
        await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
        assert.isTrue(await this.token.isOperatorForPartition(partition1, operator, tokenHolder));
        await this.token.revokeOperatorByPartition(partition1, operator, { from: tokenHolder });
        assert.isTrue(!(await this.token.isOperatorForPartition(partition1, operator, tokenHolder)));
      });
      it('emits a revoked event', async function () {
        await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
        const { logs } = await this.token.revokeOperatorByPartition(partition1, operator, { from: tokenHolder });

        assert.equal(logs.length, 1);
        assert.equal(logs[0].event, 'RevokedOperatorByPartition');
        assert.equal(logs[0].args.partition, partition1);
        assert.equal(logs[0].args.operator, operator);
        assert.equal(logs[0].args.tokenHolder, tokenHolder);
      });
    });
  });

  // CONTROLLERS

  describe('controllers', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    describe('when the token is controllable', function () {
      it('returns the list of controllers', async function () {
        assert.isTrue(await this.token.isControllable());
        const controllers = await this.token.controllers();

        assert.equal(controllers.length, 1);
        assert.equal(controllers[0], controller);
      });
    });
  });

  // CONTROLLERSBYPARTITION

  describe('controllersByPartition', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
      await this.token.setPartitionControllers(partition3, [operator], { from: owner });
    });
    describe('when the token is controllable', function () {
      it('returns the list of controllers', async function () {
        assert.isTrue(await this.token.isControllable());
        const controllers = await this.token.controllersByPartition(partition3);

        assert.equal(controllers.length, 1);
        assert.equal(controllers[0], operator);
      });
    });
  });

  // SET/GET TOKEN DEFAULT PARTITIONS
  describe('defaultPartitions', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
      defaultPartitions = await this.token.getDefaultPartitions();
      assert.equal(defaultPartitions.length, 3);
      assert.equal(defaultPartitions[0], partition1);
      assert.equal(defaultPartitions[1], partition2);
      assert.equal(defaultPartitions[2], partition3);
    });
    describe('when the sender is the contract owner', function () {
      it('sets the list of token default partitions', async function () {
        await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
        defaultPartitions = await this.token.getDefaultPartitions();
        assert.equal(defaultPartitions.length, 3);
        assert.equal(defaultPartitions[0], partition3);
        assert.equal(defaultPartitions[1], partition1);
        assert.equal(defaultPartitions[2], partition2);
      });
    });
    describe('when the sender is not the contract owner', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.setDefaultPartitions(reversedPartitions, { from: unknown }));
      });
    });
  });

  // SET/GET DOCUMENT

  describe('set/getDocument', function () {
    const documentURI = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit,sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.'; // SHA-256 of documentURI
    const documentHash = '0x1c81c608a616183cc4a38c09ecc944eb77eaff465dd87aae0290177f2b70b6f8'; // SHA-256 of documentURI + '0x'

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });

    describe('setDocument', function () {
      describe('when sender is a controller', function () {
        it('attaches the document to the token', async function () {
          await this.token.setDocument(documentName, documentURI, documentHash, { from: controller });
          const doc = await this.token.getDocument(documentName);
          assert.equal(documentURI, doc[0]);
          assert.equal(documentHash, doc[1]);
        });
        it('emits a docuemnt event', async function () {
          const { logs } = await this.token.setDocument(documentName, documentURI, documentHash, { from: controller });

          assert.equal(logs.length, 1);
          assert.equal(logs[0].event, 'Document');
          assert.equal(logs[0].args.name, documentName);
          assert.equal(logs[0].args.uri, documentURI);
          assert.equal(logs[0].args.documentHash, documentHash);
        });
      });
      describe('when sender is not a controller', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.setDocument(documentName, documentURI, documentHash, { from: unknown }));
        });
      });
    });
    describe('getDocument', function () {
      describe('when docuemnt exists', function () {
        it('returns the document', async function () {
          await this.token.setDocument(documentName, documentURI, documentHash, { from: controller });
          const doc = await this.token.getDocument(documentName);
          assert.equal(documentURI, doc[0]);
          assert.equal(documentHash, doc[1]);
        });
      });
      describe('when docuemnt does not exist', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.getDocument(documentName));
        });
      });
    });
  });

  // ISSUEBYPARTITION

  describe('issueByPartition', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });

    describe('when sender is the issuer', function () {
      describe('when token is issuable', function () {
        it('issues the requested amount', async function () {
          await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });

          await assertTotalSupply(this.token, issuanceAmount);
          await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
        });
        it('issues twice the requested amount', async function () {
          await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
          await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });

          await assertTotalSupply(this.token, 2 * issuanceAmount);
          await assertBalanceOf(this.token, tokenHolder, partition1, 2 * issuanceAmount);
        });
        it('emits a issuedByPartition event', async function () {
          const { logs } = await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });

          assert.equal(logs.length, 3);

          assert.equal(logs[0].event, 'Checked');
          assert.equal(logs[0].args.sender, owner);

          assert.equal(logs[1].event, 'Issued');
          assert.equal(logs[1].args.operator, owner);
          assert.equal(logs[1].args.to, tokenHolder);
          assert.equal(logs[1].args.value, issuanceAmount);
          assert.equal(logs[1].args.data, VALID_CERTIFICATE);
          assert.equal(logs[1].args.operatorData, null);

          assert.equal(logs[2].event, 'IssuedByPartition');
          assert.equal(logs[2].args.partition, partition1);
          assert.equal(logs[2].args.operator, owner);
          assert.equal(logs[2].args.to, tokenHolder);
          assert.equal(logs[2].args.value, issuanceAmount);
          assert.equal(logs[2].args.data, VALID_CERTIFICATE);
          assert.equal(logs[2].args.operatorData, null);
        });
      });
      describe('when token is not issuable', function () {
        it('reverts', async function () {
          assert.isTrue(await this.token.isIssuable());
          await this.token.renounceIssuance({ from: owner });
          assert.isTrue(!(await this.token.isIssuable()));
          await shouldFail.reverting(this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner }));
        });
      });
    });
    describe('when sender is not the issuer', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: unknown }));
      });
    });
  });

  // REDEEMBYPARTITION

  describe('redeemByPartition', function () {
    const redeemAmount = 300;

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });

    describe('when the redeemer has enough balance for this partition', function () {
      it('redeems the requested amount', async function () {
        await this.token.redeemByPartition(partition1, redeemAmount, VALID_CERTIFICATE, { from: tokenHolder });

        await assertTotalSupply(this.token, issuanceAmount - redeemAmount);
        await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - redeemAmount);
      });
      it('emits a redeemedByPartition event', async function () {
        const { logs } = await this.token.redeemByPartition(partition1, redeemAmount, VALID_CERTIFICATE, { from: tokenHolder });

        assert.equal(logs.length, 3);

        assertBurnEvent(logs, partition1, tokenHolder, tokenHolder, redeemAmount, VALID_CERTIFICATE, null);
      });
    });
    describe('when the redeemer does not have enough balance for this partition', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.redeemByPartition(partition2, redeemAmount, VALID_CERTIFICATE, { from: tokenHolder }));
      });
    });
    describe('special case (_removeTokenFromPartition shall revert)', function () {
      it('reverts', async function () {
        await this.token.issueByPartition(partition2, owner, issuanceAmount, VALID_CERTIFICATE, { from: owner });
        await shouldFail.reverting(this.token.redeemByPartition(partition2, 0, VALID_CERTIFICATE, { from: tokenHolder }));
      });
    });
  });

  // OPERATOREDEEMBYPARTITION

  describe('operatorRedeemByPartition', function () {
    const redeemAmount = 300;

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });

    describe('when the sender is an operator for this partition', function () {
      describe('when the redeemer has enough balance for this partition', function () {
        it('redeems the requested amount', async function () {
          await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
          await this.token.operatorRedeemByPartition(partition1, tokenHolder, redeemAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

          await assertTotalSupply(this.token, issuanceAmount - redeemAmount);
          await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - redeemAmount);
        });
        it('emits a redeemedByPartition event', async function () {
          await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
          const { logs } = await this.token.operatorRedeemByPartition(partition1, tokenHolder, redeemAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

          assert.equal(logs.length, 3);

          assertBurnEvent(logs, partition1, operator, tokenHolder, redeemAmount, null, VALID_CERTIFICATE);
        });
      });
      describe('when the redeemer does not have enough balance for this partition', function () {
        it('reverts', async function () {
          it('redeems the requested amount', async function () {
            await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });

            await shouldFail.reverting(this.token.operatorRedeemByPartition(partition1, tokenHolder, issuanceAmount + 1, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
          });
        });
      });
    });
    describe('when the sender is a global operator', function () {
      it('redeems the requested amount', async function () {
        await this.token.authorizeOperator(operator, { from: tokenHolder });
        await this.token.operatorRedeemByPartition(partition1, tokenHolder, redeemAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

        await assertTotalSupply(this.token, issuanceAmount - redeemAmount);
        await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - redeemAmount);
      });
    });
    describe('when the sender is not an operator', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.operatorRedeemByPartition(partition1, tokenHolder, redeemAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
      });
    });
  });

  // TRANSFERBYPARTITION

  describe('transferByPartition', function () {
    const transferAmount = 300;

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });

    describe('when contract is not paused', function () {
      describe('when the sender has enough balance for this partition', function () {
        describe('when the transfer amount is not equal to 0', function () {
          it('transfers the requested amount', async function () {
            await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
            await assertBalanceOf(this.token, recipient, partition1, 0);
  
            await this.token.transferByPartition(partition1, recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder });
            await this.token.transferByPartition(partition1, recipient, 0, VALID_CERTIFICATE, { from: tokenHolder });
  
            await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - transferAmount);
            await assertBalanceOf(this.token, recipient, partition1, transferAmount);
          });
          it('emits a TransferByPartition event', async function () {
            const { logs } = await this.token.transferByPartition(partition1, recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder });
  
            assert.equal(logs.length, 3);
  
            assertTransferEvent(logs, partition1, tokenHolder, tokenHolder, recipient, transferAmount, VALID_CERTIFICATE, null);
          });
        });
        describe('when the transfer amount is equal to 0', function () {
          it('reverts', async function () {
            await shouldFail.reverting(this.token.transferByPartition(partition2, recipient, 0, VALID_CERTIFICATE, { from: tokenHolder }));
          });
        });
  
      });
      describe('when the sender does not have enough balance for this partition', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.transferByPartition(partition2, recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder }));
        });
      });
    });
    describe('when contract is paused', function () {
      beforeEach(async function () {
        this.validatorContract = await ERC1400TokensValidator.new(true, false, { from: owner });
        await this.token.setHookContract(this.validatorContract.address, ERC1400_TOKENS_VALIDATOR, { from: owner });
        let hookImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_TOKENS_VALIDATOR));
        assert.equal(hookImplementer, this.validatorContract.address);

        await this.validatorContract.pause({ from: owner });
      });
      it('reverts', async function () {
        await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);

        await shouldFail.reverting(this.token.transferByPartition(partition1, recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder }));
      });
    });
  });

  // OPERATORTRANSFERBYPARTITION

  describe('operatorTransferByPartition', function () {
    const transferAmount = 300;

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });

    describe('when the sender is approved for this partition', function () {
      describe('when approved amount is sufficient', function () {
        it('transfers the requested amount', async function () {
          await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
          await assertBalanceOf(this.token, recipient, partition1, 0);
          assert.equal(await this.token.allowanceByPartition(partition1, tokenHolder, operator), 0);
  
          const approvedAmount = 400;
          await this.token.approveByPartition(partition1, operator, approvedAmount, { from: tokenHolder });
          assert.equal(await this.token.allowanceByPartition(partition1, tokenHolder, operator), approvedAmount);
          await this.token.operatorTransferByPartition(partition1, tokenHolder, recipient, transferAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });
  
          await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - transferAmount);
          await assertBalanceOf(this.token, recipient, partition1, transferAmount);
          assert.equal(await this.token.allowanceByPartition(partition1, tokenHolder, operator), approvedAmount - transferAmount);
        });
      });
      describe('when approved amount is not sufficient', function () {
        it('reverts', async function () {
          await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
          await assertBalanceOf(this.token, recipient, partition1, 0);
          assert.equal(await this.token.allowanceByPartition(partition1, tokenHolder, operator), 0);
  
          const approvedAmount = 200;
          await this.token.approveByPartition(partition1, operator, approvedAmount, { from: tokenHolder });
          assert.equal(await this.token.allowanceByPartition(partition1, tokenHolder, operator), approvedAmount);
          await shouldFail.reverting(this.token.operatorTransferByPartition(partition1, tokenHolder, recipient, transferAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
        });
      });
    });
    describe('when the sender is an operator for this partition', function () {
      describe('when the sender has enough balance for this partition', function () {
        describe('when partition does not change', function () {
          it('transfers the requested amount', async function () {
            await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
            await assertBalanceOf(this.token, recipient, partition1, 0);

            await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
            await this.token.operatorTransferByPartition(partition1, tokenHolder, recipient, transferAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

            await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - transferAmount);
            await assertBalanceOf(this.token, recipient, partition1, transferAmount);
          });
          it('transfers the requested amount with attached data (without changePartition flag)', async function () {
            await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
            await assertBalanceOf(this.token, recipient, partition1, 0);

            await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
            await this.token.operatorTransferByPartition(partition1, tokenHolder, recipient, transferAmount, doNotChangePartition, VALID_CERTIFICATE, { from: operator });

            await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - transferAmount);
            await assertBalanceOf(this.token, recipient, partition1, transferAmount);
          });
          it('emits a TransferByPartition event', async function () {
            await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
            const { logs } = await this.token.operatorTransferByPartition(partition1, tokenHolder, recipient, transferAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

            assert.equal(logs.length, 3);

            assertTransferEvent(logs, partition1, operator, tokenHolder, recipient, transferAmount, null, VALID_CERTIFICATE);
          });
        });
        describe('when partition changes', function () {
          it('transfers the requested amount', async function () {
            await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
            await assertBalanceOf(this.token, recipient, partition2, 0);

            await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
            await this.token.operatorTransferByPartition(partition1, tokenHolder, recipient, transferAmount, changeToPartition2, VALID_CERTIFICATE, { from: operator });

            await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - transferAmount);
            await assertBalanceOf(this.token, recipient, partition2, transferAmount);
          });
          it('converts the requested amount', async function () {
            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalanceOfByPartition(this.token, tokenHolder, partition1, issuanceAmount);
            await assertBalanceOfByPartition(this.token, tokenHolder, partition2, 0);

            await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
            await this.token.operatorTransferByPartition(partition1, tokenHolder, tokenHolder, transferAmount, changeToPartition2, VALID_CERTIFICATE, { from: operator });

            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalanceOfByPartition(this.token, tokenHolder, partition1, issuanceAmount - transferAmount);
            await assertBalanceOfByPartition(this.token, tokenHolder, partition2, transferAmount);
          });
          it('emits a changedPartition event', async function () {
            await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
            const { logs } = await this.token.operatorTransferByPartition(partition1, tokenHolder, recipient, transferAmount, changeToPartition2, VALID_CERTIFICATE, { from: operator });

            assert.equal(logs.length, 4);

            assertTransferEvent([logs[0], logs[1], logs[2]], partition1, operator, tokenHolder, recipient, transferAmount, changeToPartition2, VALID_CERTIFICATE);

            assert.equal(logs[3].event, 'ChangedPartition');
            assert.equal(logs[3].args.fromPartition, partition1);
            assert.equal(logs[3].args.toPartition, partition2);
            assert.equal(logs[3].args.value, transferAmount);
          });
        });
      });
      describe('when the sender does not have enough balance for this partition', function () {
        it('reverts', async function () {
          await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
          await shouldFail.reverting(this.token.operatorTransferByPartition(partition1, tokenHolder, recipient, issuanceAmount + 1, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
        });
      });
    });
    describe('when the sender is a global operator', function () {
      it('redeems the requested amount', async function () {
        await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
        await assertBalanceOf(this.token, recipient, partition1, 0);

        await this.token.authorizeOperator(operator, { from: tokenHolder });
        await this.token.operatorTransferByPartition(partition1, tokenHolder, recipient, transferAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

        await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - transferAmount);
        await assertBalanceOf(this.token, recipient, partition1, transferAmount);
      });
    });
    describe('when the sender is neither an operator, nor approved', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.operatorTransferByPartition(partition1, tokenHolder, recipient, transferAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
      });
    });
  });

  // PARTITIONSOF

  describe('partitionsOf', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    describe('when tokenHolder owes no tokens', function () {
      it('returns empty list', async function () {
        const partitionsOf = await this.token.partitionsOf(tokenHolder);
        assert.equal(partitionsOf.length, 0);
      });
    });
    describe('when tokenHolder owes tokens of 1 partition', function () {
      it('returns partition', async function () {
        await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
        const partitionsOf = await this.token.partitionsOf(tokenHolder);
        assert.equal(partitionsOf.length, 1);
        assert.equal(partitionsOf[0], partition1);
      });
    });
    describe('when tokenHolder owes tokens of 3 partitions', function () {
      it('returns list of 3 partitions', async function () {
        await issueOnMultiplePartitions(this.token, owner, tokenHolder, partitions, [issuanceAmount, issuanceAmount, issuanceAmount]);
        const partitionsOf = await this.token.partitionsOf(tokenHolder);
        assert.equal(partitionsOf.length, 3);
        assert.equal(partitionsOf[0], partition1);
        assert.equal(partitionsOf[1], partition2);
        assert.equal(partitionsOf[2], partition3);
      });
    });
  });

  // TOTALPARTITIONS

  describe('totalPartitions', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    describe('when no tokens are issued', function () {
      it('returns empty list', async function () {
        const partitionsOf = await this.token.totalPartitions();
        assert.equal(partitionsOf.length, 0);
      });
    });
    describe('when tokens are issued for 1 partition', function () {
      it('returns partition', async function () {
        await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
        const partitionsOf = await this.token.totalPartitions();
        assert.equal(partitionsOf.length, 1);
        assert.equal(partitionsOf[0], partition1);
      });
    });
    describe('when tokens are issued for 3 partitions', function () {
      it('returns list of 3 partitions', async function () {
        await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
        await this.token.issueByPartition(partition2, recipient, issuanceAmount, VALID_CERTIFICATE, { from: owner });
        await this.token.issueByPartition(partition3, unknown, issuanceAmount, VALID_CERTIFICATE, { from: owner });
        const partitionsOf = await this.token.totalPartitions();
        assert.equal(partitionsOf.length, 3);
        assert.equal(partitionsOf[0], partition1);
        assert.equal(partitionsOf[1], partition2);
        assert.equal(partitionsOf[2], partition3);
      });
    });
  });

  // TRANSFERWITHDATA

  describe('transferWithData', function () {
    describe('when defaultPartitions have been defined', function () {
      beforeEach(async function () {
        this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
        await issueOnMultiplePartitions(this.token, owner, tokenHolder, partitions, [issuanceAmount, issuanceAmount, issuanceAmount]);
      });
      describe('when the sender has enough balance for those default partitions', function () {
        describe('when the sender has defined custom default partitions', function () {
          it('transfers the requested amount', async function () {
            await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
            await assertBalances(this.token, tokenHolder, partitions, [issuanceAmount, issuanceAmount, issuanceAmount]);

            await this.token.transferWithData(recipient, 2.5 * issuanceAmount, VALID_CERTIFICATE, { from: tokenHolder });

            await assertBalances(this.token, tokenHolder, partitions, [0, 0.5 * issuanceAmount, 0]);
            await assertBalances(this.token, recipient, partitions, [issuanceAmount, 0.5 * issuanceAmount, issuanceAmount]);
          });
          it('emits a sent event', async function () {
            await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
            const { logs } = await this.token.transferWithData(recipient, 2.5 * issuanceAmount, VALID_CERTIFICATE, { from: tokenHolder });

            assert.equal(logs.length, 1 + 2 * partitions.length);

            assertTransferEvent([logs[0], logs[1], logs[2]], partition3, tokenHolder, tokenHolder, recipient, issuanceAmount, VALID_CERTIFICATE, null);
            assertTransferEvent([logs[3], logs[4]], partition1, tokenHolder, tokenHolder, recipient, issuanceAmount, VALID_CERTIFICATE, null);
            assertTransferEvent([logs[5], logs[6]], partition2, tokenHolder, tokenHolder, recipient, 0.5 * issuanceAmount, VALID_CERTIFICATE, null);
          });
        });
        describe('when the sender has not defined custom default partitions', function () {
          it('transfers the requested amount', async function () {
            await assertBalances(this.token, tokenHolder, partitions, [issuanceAmount, issuanceAmount, issuanceAmount]);

            await this.token.transferWithData(recipient, 2.5 * issuanceAmount, VALID_CERTIFICATE, { from: tokenHolder });

            await assertBalances(this.token, tokenHolder, partitions, [0, 0, 0.5 * issuanceAmount]);
            await assertBalances(this.token, recipient, partitions, [issuanceAmount, issuanceAmount, 0.5 * issuanceAmount]);
          });
        });
      });
      describe('when the sender does not have enough balance for those default partitions', function () {
        it('reverts', async function () {
          await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
          await shouldFail.reverting(this.token.transferWithData(recipient, 3.5 * issuanceAmount, VALID_CERTIFICATE, { from: tokenHolder }));
        });
      });
    });
    describe('when defaultPartitions have not been defined', function () {
      it('reverts', async function () {
        this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, []);
        await issueOnMultiplePartitions(this.token, owner, tokenHolder, partitions, [issuanceAmount, issuanceAmount, issuanceAmount]);
        await shouldFail.reverting(this.token.transferWithData(recipient, 2.5 * issuanceAmount, VALID_CERTIFICATE, { from: tokenHolder }));
      });
    });
  });

  // TRANSFERBYDEFAULTPARTITION

  describe('_transferByDefaultPartitions', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    });
    describe('when the sender has enough balance for those default partitions', function () {
      it('transfers the requested amount (scenario1)', async function () {
        await this.token.issueByPartition(partitions[0], tokenHolder, 2*issuanceAmount, VALID_CERTIFICATE, { from: owner });
        await this.token.issueByPartition(partitions[2], tokenHolder, 2*issuanceAmount, VALID_CERTIFICATE, { from: owner });
        await this.token.setDefaultPartitions(partitions, { from: owner });
        await assertBalances(this.token, tokenHolder, partitions, [2*issuanceAmount, 0, 2*issuanceAmount]);
        await this.token.transferWithData(recipient, 2.5 * issuanceAmount, VALID_CERTIFICATE, { from: tokenHolder });
        await assertBalances(this.token, tokenHolder, partitions, [0, 0, 1.5*issuanceAmount]);
        await assertBalances(this.token, recipient, partitions, [2*issuanceAmount, 0, 0.5*issuanceAmount]);
      });
      it('transfers the requested amount (scenario2)', async function () {
        await this.token.issueByPartition(partitions[0], tokenHolder, 2*issuanceAmount, VALID_CERTIFICATE, { from: owner });
        await this.token.issueByPartition(partitions[1], tokenHolder, 2*issuanceAmount, VALID_CERTIFICATE, { from: owner });
        await this.token.setDefaultPartitions(partitions, { from: owner });
        await assertBalances(this.token, tokenHolder, partitions, [2*issuanceAmount, 2*issuanceAmount, 0]);
        await this.token.transferWithData(recipient, 2.5 * issuanceAmount, VALID_CERTIFICATE, { from: tokenHolder });
        await assertBalances(this.token, tokenHolder, partitions, [0, 1.5*issuanceAmount, 0]);
        await assertBalances(this.token, recipient, partitions, [2*issuanceAmount, 0.5*issuanceAmount, 0]);
      });

    });
  });

  // TRANSFERFROMWITHDATA

  describe('transferFromWithData', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
      await issueOnMultiplePartitions(this.token, owner, tokenHolder, partitions, [issuanceAmount, issuanceAmount, issuanceAmount]);
    });
    describe('when the operator is approved', function () {
      beforeEach(async function () {
        await this.token.authorizeOperator(operator, { from: tokenHolder });
      });
      describe('when defaultPartitions have been defined', function () {
        describe('when the sender has enough balance for those default partitions', function () {
          it('transfers the requested amount', async function () {
            await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
            await assertBalances(this.token, tokenHolder, partitions, [issuanceAmount, issuanceAmount, issuanceAmount]);

            await this.token.transferFromWithData(tokenHolder, recipient, 2.5 * issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

            await assertBalances(this.token, tokenHolder, partitions, [0, 0.5 * issuanceAmount, 0]);
            await assertBalances(this.token, recipient, partitions, [issuanceAmount, 0.5 * issuanceAmount, issuanceAmount]);
          });
          it('emits a sent event', async function () {
            await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
            const { logs } = await this.token.transferFromWithData(tokenHolder, recipient, 2.5 * issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

            assert.equal(logs.length, 1 + 2 * partitions.length);

            assertTransferEvent([logs[0], logs[1], logs[2]], partition3, operator, tokenHolder, recipient, issuanceAmount, null, VALID_CERTIFICATE);
            assertTransferEvent([logs[3], logs[4]], partition1, operator, tokenHolder, recipient, issuanceAmount, null, VALID_CERTIFICATE);
            assertTransferEvent([logs[5], logs[6]], partition2, operator, tokenHolder, recipient, 0.5 * issuanceAmount, null, VALID_CERTIFICATE);
          });
        });
        describe('when the sender does not have enough balance for those default partitions', function () {
          it('reverts', async function () {
            await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
            await shouldFail.reverting(this.token.transferFromWithData(tokenHolder, recipient, 3.5 * issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
          });
        });
      });
      describe('when defaultPartitions have not been defined', function () {
        it('reverts', async function () {
          await this.token.setDefaultPartitions([], { from: owner });
          await shouldFail.reverting(this.token.transferFromWithData(tokenHolder, recipient, 2.5 * issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
        });
      });
    });
    describe('when the operator is not approved', function () {
      it('reverts', async function () {
        await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
        await shouldFail.reverting(this.token.transferFromWithData(tokenHolder, recipient, 2.5 * issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
      });
    });
  });

  // REDEEM

  describe('redeem', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
      await issueOnMultiplePartitions(this.token, owner, tokenHolder, partitions, [issuanceAmount, issuanceAmount, issuanceAmount]);
    });
    describe('when defaultPartitions have been defined', function () {
      describe('when the sender has enough balance for those default partitions', function () {
        it('redeeems the requested amount', async function () {
          await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
          await assertBalances(this.token, tokenHolder, partitions, [issuanceAmount, issuanceAmount, issuanceAmount]);

          await this.token.redeem(2.5 * issuanceAmount, VALID_CERTIFICATE, { from: tokenHolder });

          await assertBalances(this.token, tokenHolder, partitions, [0, 0.5 * issuanceAmount, 0]);
        });
        it('emits a redeemedByPartition events', async function () {
          await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
          const { logs } = await this.token.redeem(2.5 * issuanceAmount, VALID_CERTIFICATE, { from: tokenHolder });

          assert.equal(logs.length, 1 + 2 * partitions.length);

          assertBurnEvent([logs[0], logs[1], logs[2]], partition3, tokenHolder, tokenHolder, issuanceAmount, VALID_CERTIFICATE, null);
          assertBurnEvent([logs[3], logs[4]], partition1, tokenHolder, tokenHolder, issuanceAmount, VALID_CERTIFICATE, null);
          assertBurnEvent([logs[5], logs[6]], partition2, tokenHolder, tokenHolder, 0.5 * issuanceAmount, VALID_CERTIFICATE, null);
        });
      });
      describe('when the sender does not have enough balance for those default partitions', function () {
        it('reverts', async function () {
          await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
          await shouldFail.reverting(this.token.redeem(3.5 * issuanceAmount, VALID_CERTIFICATE, { from: tokenHolder }));
        });
      });
    });
    describe('when defaultPartitions have not been defined', function () {
      it('reverts', async function () {
        await this.token.setDefaultPartitions([], { from: owner });
        await shouldFail.reverting(this.token.redeem(2.5 * issuanceAmount, VALID_CERTIFICATE, { from: tokenHolder }));
      });
    });
  });

  // REDEEMFROM

  describe('redeemFrom', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
      await issueOnMultiplePartitions(this.token, owner, tokenHolder, partitions, [issuanceAmount, issuanceAmount, issuanceAmount]);
    });
    describe('when the operator is approved', function () {
      beforeEach(async function () {
        await this.token.authorizeOperator(operator, { from: tokenHolder });
      });
      describe('when defaultPartitions have been defined', function () {
        describe('when the sender has enough balance for those default partitions', function () {
          it('redeems the requested amount', async function () {
            await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
            await assertBalances(this.token, tokenHolder, partitions, [issuanceAmount, issuanceAmount, issuanceAmount]);

            await this.token.redeemFrom(tokenHolder, 2.5 * issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

            await assertBalances(this.token, tokenHolder, partitions, [0, 0.5 * issuanceAmount, 0]);
          });
          it('emits redeemedByPartition events', async function () {
            await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
            const { logs } = await this.token.redeemFrom(tokenHolder, 2.5 * issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

            assert.equal(logs.length, 1 + 2 * partitions.length);

            assertBurnEvent([logs[0], logs[1], logs[2]], partition3, operator, tokenHolder, issuanceAmount, null, VALID_CERTIFICATE);
            assertBurnEvent([logs[3], logs[4]], partition1, operator, tokenHolder, issuanceAmount, null, VALID_CERTIFICATE);
            assertBurnEvent([logs[5], logs[6]], partition2, operator, tokenHolder, 0.5 * issuanceAmount, null, VALID_CERTIFICATE);
          });
        });
        describe('when the sender does not have enough balance for those default partitions', function () {
          it('reverts', async function () {
            await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
            await shouldFail.reverting(this.token.redeemFrom(tokenHolder, 3.5 * issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
          });
        });
      });
      describe('when defaultPartitions have not been defined', function () {
        it('reverts', async function () {
          await this.token.setDefaultPartitions([], { from: owner });
          await shouldFail.reverting(this.token.redeemFrom(tokenHolder, 2.5 * issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
        });
      });
    });
    describe('when the operator is not approved', function () {
      it('reverts', async function () {
        await this.token.setDefaultPartitions(reversedPartitions, { from: owner });
        await shouldFail.reverting(this.token.redeemFrom(tokenHolder, 2.5 * issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
      });
    });
  });

  // MIGRATE
  describe('migrate', function () {
    const transferAmount = 300;

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
      this.migratedToken = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });
    describe('when the sender is the contract owner', function () {
      describe('when the contract is not migrated', function () {
        it('can transfer tokens', async function () {
          await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
          await assertBalanceOf(this.token, recipient, partition1, 0);

          await this.token.transferByPartition(partition1, recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder });

          await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - transferAmount);
          await assertBalanceOf(this.token, recipient, partition1, transferAmount);
        });
    });
    describe('when the contract is migrated definitely', function () {
      it('can not transfer tokens', async function () {
        let interfaceImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_INTERFACE_NAME));
        assert.equal(interfaceImplementer, this.token.address);

        await this.token.migrate(this.migratedToken.address, true, { from: owner });

        interfaceImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_INTERFACE_NAME));
        assert.equal(interfaceImplementer, this.migratedToken.address);

        await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
        await assertBalanceOf(this.token, recipient, partition1, 0);

        await shouldFail.reverting(this.token.transferByPartition(partition1, recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder }));
      });
    });
    describe('when the contract is migrated, but not definitely', function () {
      it('can transfer tokens', async function () {
        let interfaceImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_INTERFACE_NAME));
        assert.equal(interfaceImplementer, this.token.address);

        await this.token.migrate(this.migratedToken.address, false, { from: owner });

        interfaceImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_INTERFACE_NAME));
        assert.equal(interfaceImplementer, this.migratedToken.address);

        await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
        await assertBalanceOf(this.token, recipient, partition1, 0);

        await this.token.transferByPartition(partition1, recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder });

        await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - transferAmount);
        await assertBalanceOf(this.token, recipient, partition1, transferAmount);
      });
    });
    });
    describe('when the sender is not the contract owner', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.migrate(this.migratedToken.address, true, { from: unknown }));
      });
    });
  });

});

contract('ERC1400Partition', function ([owner, operator, controller, controller_alternative1, controller_alternative2, tokenHolder, recipient, unknown]) {
  // ERC1400Partition - REDEEM

  describe('ERC1400Partition - redeem', function () {
    beforeEach(async function () {
      this.token = await ERC1400Partition.new('ERC1400PartitionToken', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions, tokenHolder, 1000);
    });
    // it('redeem function is deactivated', async function () {
    //   await assertBalance(this.token, tokenHolder, 1000);
    //   await this.token.redeem(500, VALID_CERTIFICATE, { from: tokenHolder });
    //   await assertBalance(this.token, tokenHolder, 1000);
    // });
    it('reverts', async function () {
      await assertBalance(this.token, tokenHolder, 1000);
      await shouldFail.reverting(this.token.redeem(500, VALID_CERTIFICATE, { from: tokenHolder }));
    });
  });

  // ERC1400Partition - REDEEMFROM

  describe('ERC1400Partition - redeemFrom', function () {
    beforeEach(async function () {
      this.token = await ERC1400Partition.new('ERC1400PartitionToken', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions, tokenHolder, 1000);
    });
    // it('redeemFrom function is deactivated', async function () {
    //   await this.token.authorizeOperator(operator, { from: tokenHolder });
    //   await assertBalance(this.token, tokenHolder, 1000);
    //   await this.token.redeemFrom(tokenHolder, 500, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });
    //   await assertBalance(this.token, tokenHolder, 1000);
    // });
    it('reverts', async function () {
      await this.token.authorizeOperator(operator, { from: tokenHolder });
      await assertBalance(this.token, tokenHolder, 1000);
      await shouldFail.reverting(this.token.redeemFrom(tokenHolder, 500, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
    });
  });
});

contract('ERC1400 with validator hook', function ([owner, operator, controller, tokenHolder, recipient, unknown]) {
  // HOOKS
  beforeEach(async function () {
    this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
    this.registry = await ERC1820Registry.at('0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24');
    this.validatorContract = await ERC1400TokensValidator.new(true, false, { from: owner });
  });

  describe('setHookContract', function () {
    describe('when the caller is the contract owner', function () {
      it('sets the validator hook', async function () {
        let hookImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_TOKENS_VALIDATOR));
        assert.equal(hookImplementer, ZERO_ADDRESS);

        await this.token.setHookContract(this.validatorContract.address, ERC1400_TOKENS_VALIDATOR, { from: owner });

        hookImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_TOKENS_VALIDATOR));
        assert.equal(hookImplementer, this.validatorContract.address);
      });
    });
    describe('when the caller is not the contract owner', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.setHookContract(this.validatorContract.address, ERC1400_TOKENS_VALIDATOR, { from: unknown }));
      });
    });
  });

  describe('hooks', function () {
    const amount = issuanceAmount;
    const to = recipient;

    beforeEach(async function () {
      await this.token.setHookContract(this.validatorContract.address, ERC1400_TOKENS_VALIDATOR, { from: owner });
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });
    afterEach(async function () {
      await this.token.setHookContract(ZERO_ADDRESS, ERC1400_TOKENS_VALIDATOR, { from: owner });
    });
    describe('when the transfer is successfull', function () {
      it('transfers the requested amount', async function () {
        await this.token.transferWithData(to, amount, VALID_CERTIFICATE, { from: tokenHolder });
        const senderBalance = await this.token.balanceOf(tokenHolder);
        assert.equal(senderBalance, issuanceAmount - amount);

        const recipientBalance = await this.token.balanceOf(to);
        assert.equal(recipientBalance, amount);
      });
    });
    describe('when the transfer fails', function () {
      it('sender hook reverts', async function () {        
        // Default sender hook failure data for the mock only: 0x1100000000000000000000000000000000000000000000000000000000000000
        await shouldFail.reverting(this.token.transferWithData(to, amount, INVALID_CERTIFICATE_VALIDATOR, { from: tokenHolder }));
      });
    });
  });

});