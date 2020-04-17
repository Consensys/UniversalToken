const { shouldFail } = require('openzeppelin-test-helpers');

const { soliditySha3 } = require("web3-utils");

const ERC1820Registry = artifacts.require('ERC1820Registry');
const ERC1400ERC20 = artifacts.require('ERC1400ERC20');
const ERC1400TokensValidator = artifacts.require('ERC1400TokensValidator');
const BlacklistMock = artifacts.require('BlacklistMock.sol');

const ZERO_BYTES32 = '0x0000000000000000000000000000000000000000000000000000000000000000';
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTE = '0x';

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

const VALID_CERTIFICATE = '0x1000000000000000000000000000000000000000000000000000000000000000';

const partition1 = '0x5265736572766564000000000000000000000000000000000000000000000000'; // Reserved in hex
const partition2 = '0x4973737565640000000000000000000000000000000000000000000000000000'; // Issued in hex
const partition3 = '0x4c6f636b65640000000000000000000000000000000000000000000000000000'; // Locked in hex
const partitions = [partition1, partition2, partition3];

const issuanceAmount = 1000000;

var totalSupply;
var balance;
var balanceByPartition;

const ERC1820_ACCEPT_MAGIC = 'ERC1820_ACCEPT_MAGIC';

const ERC20_INTERFACE_NAME = 'ERC20Token';
const ERC1400_INTERFACE_NAME = 'ERC1400Token';
const ERC1400_TOKENS_VALIDATOR = 'ERC1400TokensValidator';

const assertBalanceOf = async (
  _contract,
  _tokenHolder,
  _partition,
  _amount
) => {
  await assertBalance(_contract, _tokenHolder, _amount);
  await assertBalanceOfByPartition(_contract, _tokenHolder, _partition, _amount);
};

const assertBalance = async (
  _contract,
  _tokenHolder,
  _amount
) => {
  balance = await _contract.balanceOf(_tokenHolder);
  assert.equal(balance, _amount);
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

const assertTotalSupply = async (_contract, _amount) => {
  totalSupply = await _contract.totalSupply();
  assert.equal(totalSupply, _amount);
};

contract('ERC1400ERC20', function ([owner, operator, controller, tokenHolder, recipient, unknown]) {

  before(async function () {
    this.registry = await ERC1820Registry.at('0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24');
  });
  beforeEach(async function () {
    this.token = await ERC1400ERC20.new('ERC1400ERC20Token', 'DAU20', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
  });

  // CANIMPLEMENTINTERFACE

  describe('canImplementInterfaceForAddress', function () {
    describe('when interface hash is correct', function () {
      it('returns ERC1820_ACCEPT_MAGIC', async function () {
        const canImplement = await this.token.canImplementInterfaceForAddress(soliditySha3(ERC20_INTERFACE_NAME), ZERO_ADDRESS);          
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

  // TRANSFERWITHDATA

  describe('transferWithData', function () {
    const to = recipient;
    const amount = 10;
    beforeEach(async function () {
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });
    it('transfers the requested amount', async function () {
      await this.token.transferWithData(to, amount, VALID_CERTIFICATE, { from: tokenHolder });
      const senderBalance = await this.token.balanceOf(tokenHolder);
      assert.equal(senderBalance, issuanceAmount - amount);

      const recipientBalance = await this.token.balanceOf(to);
      assert.equal(recipientBalance, amount);
    });

    it('emits a Transfer event', async function () {
      const { logs } = await this.token.transferWithData(to, amount, VALID_CERTIFICATE, { from: tokenHolder });

      assert.equal(logs.length, 4);

      assert.equal(logs[0].event, 'Checked');
      assert.equal(logs[0].args.sender, tokenHolder);

      assert.equal(logs[1].event, 'TransferWithData');
      assert.equal(logs[1].args.operator, tokenHolder);
      assert.equal(logs[1].args.from, tokenHolder);
      assert.equal(logs[1].args.to, to);
      assert.equal(logs[1].args.value, amount);
      assert.equal(logs[1].args.data, VALID_CERTIFICATE);
      assert.equal(logs[1].args.operatorData, null);

      assert.equal(logs[2].event, 'Transfer');
      assert.equal(logs[2].args.from, tokenHolder);
      assert.equal(logs[2].args.to, to);
      assert.equal(logs[2].args.value, amount);

      assert.equal(logs[3].event, 'TransferByPartition');
      assert.equal(logs[3].args.operator, tokenHolder);
      assert.equal(logs[3].args.to, to);
      assert.equal(logs[3].args.value, amount);
      assert.equal(logs[3].args.data, VALID_CERTIFICATE);
      assert.equal(logs[3].args.operatorData, null);
    });
  });

  // REDEEM

  describe('redeem', function () {
    const redeemAmount = 300;
    beforeEach(async function () {
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });
    it('redeems the requested amount', async function () {
      await this.token.redeemByPartition(partition1, redeemAmount, VALID_CERTIFICATE, { from: tokenHolder });

      await assertTotalSupply(this.token, issuanceAmount - redeemAmount);
      await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - redeemAmount);
    });
    it('emits a Transfer event', async function () {
      const { logs } = await this.token.redeemByPartition(partition1, redeemAmount, VALID_CERTIFICATE, { from: tokenHolder });

      assert.equal(logs.length, 4);

      assert.equal(logs[0].event, 'Checked');
      assert.equal(logs[0].args.sender, tokenHolder);

      assert.equal(logs[1].event, 'Redeemed');
      assert.equal(logs[1].args.operator, tokenHolder);
      assert.equal(logs[1].args.from, tokenHolder);
      assert.equal(logs[1].args.value, redeemAmount);
      assert.equal(logs[1].args.data, VALID_CERTIFICATE);
      assert.equal(logs[1].args.operatorData, null);

      assert.equal(logs[2].event, 'Transfer');
      assert.equal(logs[2].args.from, tokenHolder);
      assert.equal(logs[2].args.to, ZERO_ADDRESS);
      assert.equal(logs[2].args.value, redeemAmount);

      assert.equal(logs[3].event, 'RedeemedByPartition');
      assert.equal(logs[3].args.partition, partition1);
      assert.equal(logs[3].args.operator, tokenHolder);
      assert.equal(logs[3].args.from, tokenHolder);
      assert.equal(logs[3].args.value, redeemAmount);
      assert.equal(logs[3].args.data, VALID_CERTIFICATE);
      assert.equal(logs[3].args.operatorData, null);
    });

  });

  // ISSUE

  describe('issue', function () {
    it('issues the requested amount', async function () {
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });

      await assertTotalSupply(this.token, issuanceAmount);
      await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
    });
    it('emits a Transfer event', async function () {
      const { logs } = await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });

      assert.equal(logs.length, 4);

      assert.equal(logs[0].event, 'Checked');
      assert.equal(logs[0].args.sender, owner);

      assert.equal(logs[1].event, 'Issued');
      assert.equal(logs[1].args.operator, owner);
      assert.equal(logs[1].args.to, tokenHolder);
      assert.equal(logs[1].args.value, issuanceAmount);
      assert.equal(logs[1].args.data, VALID_CERTIFICATE);
      assert.equal(logs[1].args.operatorData, null);

      assert.equal(logs[2].event, 'Transfer');
      assert.equal(logs[2].args.from, ZERO_ADDRESS);
      assert.equal(logs[2].args.to, tokenHolder);
      assert.equal(logs[2].args.value, issuanceAmount);

      assert.equal(logs[3].event, 'IssuedByPartition');
      assert.equal(logs[3].args.partition, partition1);
      assert.equal(logs[3].args.operator, owner);
      assert.equal(logs[3].args.to, tokenHolder);
      assert.equal(logs[3].args.value, issuanceAmount);
      assert.equal(logs[3].args.data, VALID_CERTIFICATE);
      assert.equal(logs[3].args.operatorData, null);
    });
  });

  // DECIMALS

  describe('decimals', function () {
    it('returns the decimals the token', async function () {
      const decimals = await this.token.decimals();

      assert.equal(decimals, 18);
    });
  });

  // APPROVE

  describe('approve', function () {
    const amount = 100;
    describe('when sender approves an operator', function () {
      it('approves the operator', async function () {
        assert.equal(await this.token.allowance(tokenHolder, operator), 0);

        await this.token.approve(operator, amount, { from: tokenHolder });

        assert.equal(await this.token.allowance(tokenHolder, operator), amount);
      });
      it('emits an approval event', async function () {
        const { logs } = await this.token.approve(operator, amount, { from: tokenHolder });

        assert.equal(logs.length, 1);
        assert.equal(logs[0].event, 'Approval');
        assert.equal(logs[0].args.owner, tokenHolder);
        assert.equal(logs[0].args.spender, operator);
        assert.equal(logs[0].args.value, amount);
      });
    });
    describe('when the operator to approve is the zero address', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.approve(ZERO_ADDRESS, amount, { from: tokenHolder }));
      });
    });
  });

  // TRANSFER

  describe('transfer', function () {
    beforeEach(async function () {
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });

    describe('when token has a withlist', function () {
      beforeEach(async function () {
        this.validatorContract = await ERC1400TokensValidator.new(true, false, { from: owner });
        await this.token.setHookContract(this.validatorContract.address, ERC1400_TOKENS_VALIDATOR, { from: owner });
        let hookImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_TOKENS_VALIDATOR));
        assert.equal(hookImplementer, this.validatorContract.address);

        await this.validatorContract.addWhitelisted(tokenHolder, { from: owner });
        await this.validatorContract.addWhitelisted(recipient, { from: owner });
      });
      describe('when contract is not paused', function () {
        describe('when the sender and the recipient are whitelisted', function () {
          beforeEach(async function () {
            assert.equal(await this.validatorContract.isWhitelisted(tokenHolder), true);
            assert.equal(await this.validatorContract.isWhitelisted(recipient), true);
          });
          describe('when the amount is a multiple of the granularity', function () {
            describe('when the recipient is not the zero address', function () {  
              describe('when the sender has enough balance', function () {
                const amount = issuanceAmount;
    
                it('transfers the requested amount', async function () {
                  await this.token.transfer(recipient, amount, { from: tokenHolder });
                  await assertBalance(this.token, tokenHolder, issuanceAmount - amount);
                  await assertBalance(this.token, recipient, amount);
                });
    
                it('emits a Transfer event', async function () {
                  const { logs } = await this.token.transfer(recipient, amount, { from: tokenHolder });
    
                  assert.equal(logs.length, 3);
    
                  assert.equal(logs[0].event, 'TransferWithData');
                  assert.equal(logs[0].args.operator, tokenHolder);
                  assert.equal(logs[0].args.from, tokenHolder);
                  assert.equal(logs[0].args.to, recipient);
                  assert.equal(logs[0].args.value, amount);
                  assert.equal(logs[0].args.data, null);
                  assert.equal(logs[0].args.operatorData, null);
    
                  assert.equal(logs[1].event, 'Transfer');
                  assert.equal(logs[1].args.from, tokenHolder);
                  assert.equal(logs[1].args.to, recipient);
                  assert.equal(logs[1].args.value, amount);
    
                  assert.equal(logs[2].event, 'TransferByPartition');
                  assert.equal(logs[2].args.fromPartition, partition1);
                  assert.equal(logs[2].args.operator, tokenHolder);
                  assert.equal(logs[2].args.from, tokenHolder);
                  assert.equal(logs[2].args.to, recipient);
                  assert.equal(logs[2].args.value, amount);
                  assert.equal(logs[2].args.data, null);
                  assert.equal(logs[2].args.operatorData, null);
                });
              });
              describe('when the sender does not have enough balance', function () {
                const amount = issuanceAmount + 1;
    
                it('reverts', async function () {
                  await shouldFail.reverting(this.token.transfer(recipient, amount, { from: tokenHolder }));
                });
              });
            });
    
            describe('when the recipient is the zero address', function () {
              const amount = issuanceAmount;
    
              it('reverts', async function () {
                await shouldFail.reverting(this.token.transfer(ZERO_ADDRESS, amount, { from: tokenHolder }));
              });
            });
          });
          describe('when the amount is not a multiple of the granularity', function () {
            it('reverts', async function () {
              this.token = await ERC1400ERC20.new('ERC1400RawToken', 'DAU', 2, [], CERTIFICATE_SIGNER, true, partitions);
              await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
              await shouldFail.reverting(this.token.transfer(recipient, 3, { from: tokenHolder }));
            });
          });
        });
        describe('when the sender is not whitelisted', function () {
          const amount = issuanceAmount;
          
          beforeEach(async function () {
            await this.validatorContract.removeWhitelisted(tokenHolder, { from: owner });
  
            assert.equal(await this.validatorContract.isWhitelisted(tokenHolder), false);
            assert.equal(await this.validatorContract.isWhitelisted(recipient), true);
          });
          it('reverts', async function () {
            await shouldFail.reverting(this.token.transfer(recipient, amount, { from: tokenHolder }));
          });
        });
        describe('when the recipient is not whitelisted', function () {
          const amount = issuanceAmount;
    
          beforeEach(async function () {
            await this.validatorContract.removeWhitelisted(recipient, { from: owner });
  
            assert.equal(await this.validatorContract.isWhitelisted(tokenHolder), true);
            assert.equal(await this.validatorContract.isWhitelisted(recipient), false);
          });
          it('reverts', async function () {
            await shouldFail.reverting(this.token.transfer(recipient, amount, { from: tokenHolder }));
          });
        });
      });
      describe('when contract is paused', function () {
        beforeEach(async function () { 
          await this.validatorContract.pause({ from: owner });
        });
        it('reverts', async function () {
          await assertBalance(this.token, tokenHolder, issuanceAmount);
          await shouldFail.reverting(this.token.transfer(recipient, issuanceAmount, { from: tokenHolder }));
        });
      });
    });
    describe('when token has a blacklist', function () {
      beforeEach(async function () {
        this.validatorContract = await ERC1400TokensValidator.new(false, true, { from: owner });
        await this.token.setHookContract(this.validatorContract.address, ERC1400_TOKENS_VALIDATOR, { from: owner });
        let hookImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_TOKENS_VALIDATOR));
        assert.equal(hookImplementer, this.validatorContract.address);

        await this.validatorContract.addBlacklisted(tokenHolder, { from: owner });
        await this.validatorContract.addBlacklisted(recipient, { from: owner });
        assert.equal(await this.validatorContract.isBlacklisted(tokenHolder), true);
        assert.equal(await this.validatorContract.isBlacklisted(recipient), true);
      });
      describe('when the blacklist is activated', function () {
        describe('when both the sender and the recipient are blacklisted', function () {
          const amount = issuanceAmount;
    
          it('reverts', async function () {
            await shouldFail.reverting(this.token.transfer(recipient, amount, { from: tokenHolder }));
          });
        });
        describe('when the sender is blacklisted', function () {
          const amount = issuanceAmount;
    
          it('reverts', async function () {
            await this.validatorContract.removeBlacklisted(recipient, { from: owner });
            await shouldFail.reverting(this.token.transfer(recipient, amount, { from: tokenHolder }));
          });
        });
        describe('when the recipient is blacklisted', function () {
          const amount = issuanceAmount;
    
          it('reverts', async function () {
            await this.validatorContract.removeBlacklisted(tokenHolder, { from: owner });
            await shouldFail.reverting(this.token.transfer(recipient, amount, { from: tokenHolder }));
          });
        });
        describe('when neither the sender nor the recipient are blacklisted', function () {
          const amount = issuanceAmount;
    
          it('transfers the requested amount', async function () {
            await this.validatorContract.removeBlacklisted(tokenHolder, { from: owner });
            await this.validatorContract.removeBlacklisted(recipient, { from: owner });

            await this.token.transfer(recipient, amount, { from: tokenHolder });
            await assertBalance(this.token, tokenHolder, issuanceAmount - amount);
            await assertBalance(this.token, recipient, amount);
          });
        });
      });
      describe('when the blacklist is not activated', function () {
        beforeEach(async function () {
          await this.validatorContract.setBlacklistActivated(false, { from: owner });
        });
        describe('when both the sender and the recipient are blacklisted', function () {
          const amount = issuanceAmount;
    
          it('transfers the requested amount', async function () {
            await this.token.transfer(recipient, amount, { from: tokenHolder });
            await assertBalance(this.token, tokenHolder, issuanceAmount - amount);
            await assertBalance(this.token, recipient, amount);
          });
        });
      });
    });
    describe('when token has neither a whitelist, nor a blacklist', function () {
      const amount = issuanceAmount;
  
      it('transfers the requested amount', async function () {
        await this.token.transfer(recipient, amount, { from: tokenHolder });
        await assertBalance(this.token, tokenHolder, issuanceAmount - amount);
        await assertBalance(this.token, recipient, amount);
      });
    });
  });
  
  // BLACKLIST
  describe('addBlacklisted/renounceBlacklistAdmin', function () {
    beforeEach(async function () {
      this.validatorContract = await ERC1400TokensValidator.new(false, true, { from: owner });
      await this.token.setHookContract(this.validatorContract.address, ERC1400_TOKENS_VALIDATOR, { from: owner });
      let hookImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_TOKENS_VALIDATOR));
      assert.equal(hookImplementer, this.validatorContract.address);

      await this.validatorContract.addBlacklisted(tokenHolder, { from: owner });
      await this.validatorContract.addBlacklisted(recipient, { from: owner });
      assert.equal(await this.validatorContract.isBlacklisted(tokenHolder), true);
      assert.equal(await this.validatorContract.isBlacklisted(recipient), true);
    });
    describe('add/remove a blacklist admin', function () {
      describe('when caller is a blacklist admin', function () {
        it('adds a blacklist admin', async function () {
          assert.equal(await this.validatorContract.isBlacklistAdmin(unknown), false);
          await this.validatorContract.addBlacklistAdmin(unknown, { from: owner });
          assert.equal(await this.validatorContract.isBlacklistAdmin(unknown), true);
        });
        it('renounces blacklist admin', async function () {
          assert.equal(await this.validatorContract.isBlacklistAdmin(unknown), false);
          await this.validatorContract.addBlacklistAdmin(unknown, { from: owner });
          assert.equal(await this.validatorContract.isBlacklistAdmin(unknown), true);
          await this.validatorContract.renounceBlacklistAdmin({ from: unknown });
          assert.equal(await this.validatorContract.isBlacklistAdmin(unknown), false);
        });
      });
      describe('when caller is not a blacklist admin', function () {
        it('reverts', async function () {
          assert.equal(await this.validatorContract.isBlacklistAdmin(unknown), false);
          await shouldFail.reverting(this.validatorContract.addBlacklistAdmin(unknown, { from: unknown }));
          assert.equal(await this.validatorContract.isBlacklistAdmin(unknown), false);
        });
      });
    });
  });
  describe('onlyNotBlacklisted', function () {
    beforeEach(async function () {
      this.blacklistMock = await BlacklistMock.new({ from: owner });
    });
    describe('can not call function if blacklisted', function () {
      it('reverts', async function () {
        assert.equal(await this.blacklistMock.isBlacklisted(unknown), false);
        await this.blacklistMock.setBlacklistActivated(true, { from: unknown });
        await this.blacklistMock.addBlacklisted(unknown, { from: owner });
        assert.equal(await this.blacklistMock.isBlacklisted(unknown), true);

        await shouldFail.reverting(this.blacklistMock.setBlacklistActivated(true, { from: unknown }));
      });
    });
  });


  // TRANSFERFROM

  describe('transferFrom', function () {
    const approvedAmount = 10000;
    beforeEach(async function () {
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });

    describe('when token has a withelist', function () {
      beforeEach(async function () {
        this.validatorContract = await ERC1400TokensValidator.new(true, false, { from: owner });
        await this.token.setHookContract(this.validatorContract.address, ERC1400_TOKENS_VALIDATOR, { from: owner });
        let hookImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_TOKENS_VALIDATOR));
        assert.equal(hookImplementer, this.validatorContract.address);

        await this.validatorContract.addWhitelisted(tokenHolder, { from: owner });
        await this.validatorContract.addWhitelisted(recipient, { from: owner });
      });
      describe('when the sender and the recipient are whitelisted', function () {
        beforeEach(async function () {
          assert.equal(await this.validatorContract.isWhitelisted(tokenHolder), true);
          assert.equal(await this.validatorContract.isWhitelisted(recipient), true);
        });
        describe('when the operator is approved', function () {
          beforeEach(async function () {
            // await this.token.authorizeOperator(operator, { from: tokenHolder});
            await this.token.approve(operator, approvedAmount, { from: tokenHolder });
          });
          describe('when the amount is a multiple of the granularity', function () {
            describe('when the recipient is not the zero address', function () {  
              describe('when the sender has enough balance', function () {
                const amount = 500;
  
                it('transfers the requested amount', async function () {
                  await this.token.transferFrom(tokenHolder, recipient, amount, { from: operator });
                  await assertBalance(this.token, tokenHolder, issuanceAmount - amount);
                  await assertBalance(this.token, recipient, amount);
  
                  assert.equal(await this.token.allowance(tokenHolder, operator), approvedAmount - amount);
                });
  
                it('emits a sent + a transfer event', async function () {
                  const { logs } = await this.token.transferFrom(tokenHolder, recipient, amount, { from: operator });
  
                  assert.equal(logs.length, 3);
  
                  assert.equal(logs[0].event, 'TransferWithData');
                  assert.equal(logs[0].args.operator, operator);
                  assert.equal(logs[0].args.from, tokenHolder);
                  assert.equal(logs[0].args.to, recipient);
                  assert.equal(logs[0].args.value, amount);
                  assert.equal(logs[0].args.data, null);
                  assert.equal(logs[0].args.operatorData, null);
  
                  assert.equal(logs[1].event, 'Transfer');
                  assert.equal(logs[1].args.from, tokenHolder);
                  assert.equal(logs[1].args.to, recipient);
                  assert.equal(logs[1].args.value, amount);
  
                  assert.equal(logs[2].event, 'TransferByPartition');
                  assert.equal(logs[2].args.fromPartition, partition1);
                  assert.equal(logs[2].args.operator, operator);
                  assert.equal(logs[2].args.from, tokenHolder);
                  assert.equal(logs[2].args.to, recipient);
                  assert.equal(logs[2].args.value, amount);
                  assert.equal(logs[2].args.data, null);
                  assert.equal(logs[2].args.operatorData, null);
                });
              });
              describe('when the sender does not have enough balance', function () {
                const amount = approvedAmount + 1;
  
                it('reverts', async function () {
                  await shouldFail.reverting(this.token.transferFrom(tokenHolder, recipient, amount, { from: operator }));
                });
              });
            });
  
            describe('when the recipient is the zero address', function () {
              const amount = issuanceAmount;
  
              it('reverts', async function () {
                await shouldFail.reverting(this.token.transferFrom(tokenHolder, ZERO_ADDRESS, amount, { from: operator }));
              });
            });
          });
          describe('when the amount is not a multiple of the granularity', function () {
            it('reverts', async function () {
              this.token = await ERC1400ERC20.new('ERC1400RawToken', 'DAU', 2, [], CERTIFICATE_SIGNER, true, partitions);
              await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
              await shouldFail.reverting(this.token.transferFrom(tokenHolder, recipient, 3, { from: operator }));
            });
          });
        });
        describe('when the operator is not approved', function () {
          const amount = approvedAmount;
          describe('when the operator is not approved but authorized', function () {
            it('transfers the requested amount', async function () {
              await this.token.authorizeOperator(operator, { from: tokenHolder });
              assert.equal(await this.token.allowance(tokenHolder, operator), 0);
  
              await this.token.transferFrom(tokenHolder, recipient, amount, { from: operator });
              await assertBalance(this.token, tokenHolder, issuanceAmount - amount);
              await assertBalance(this.token, recipient, amount);
            });
          });
          describe('when the operator is not approved and not authorized', function () {
            it('reverts', async function () {
              await shouldFail.reverting(this.token.transferFrom(tokenHolder, recipient, amount, { from: operator }));
            });
          });
        });
      });
      describe('when the sender is not whitelisted', function () {
        const amount = approvedAmount;
        beforeEach(async function () {
          await this.validatorContract.removeWhitelisted(tokenHolder, { from: owner });

          assert.equal(await this.validatorContract.isWhitelisted(tokenHolder), false);
          assert.equal(await this.validatorContract.isWhitelisted(recipient), true);
        });
        it('reverts', async function () {
          await shouldFail.reverting(this.token.transferFrom(tokenHolder, recipient, amount, { from: operator }));
        });
      });
      describe('when the recipient is not whitelisted', function () {
        const amount = approvedAmount;
        beforeEach(async function () {
          await this.validatorContract.removeWhitelisted(recipient, { from: owner });

          assert.equal(await this.validatorContract.isWhitelisted(tokenHolder), true);
          assert.equal(await this.validatorContract.isWhitelisted(recipient), false);
        });
        it('reverts', async function () {
          await shouldFail.reverting(this.token.transferFrom(tokenHolder, recipient, amount, { from: operator }));
        });
      });
    });
    describe('when token has no withelist', function () {
      
    });
  });

  // WHITELIST - (section to check if certificate-based functions can still be called even when contract has a whitelist and a blacklist)
  describe('whitelist', function () {
    const redeemAmount = 50;
    const transferAmount = 300;
    beforeEach(async function () {
      this.validatorContract = await ERC1400TokensValidator.new(true, true, { from: owner });
      await this.token.setHookContract(this.validatorContract.address, ERC1400_TOKENS_VALIDATOR, { from: owner });
      let hookImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_TOKENS_VALIDATOR));
      assert.equal(hookImplementer, this.validatorContract.address);

      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });
    describe('can still call ERC1400 functions', function () {
      describe('can still call issueByPartition', function () {
        it('issues new tokens', async function () {
          await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
          await assertTotalSupply(this.token, 2*issuanceAmount);
          await assertBalanceOf(this.token, tokenHolder, partition1, 2*issuanceAmount);
        });
      });
      describe('can still call redeemByPartition', function () {
        it('redeems the requested amount', async function () {
          await this.token.redeemByPartition(partition1, redeemAmount, VALID_CERTIFICATE, { from: tokenHolder });
          await assertTotalSupply(this.token, issuanceAmount - redeemAmount);
          await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - redeemAmount);
        });
      });
      describe('can still call operatorRedeemByPartition', function () {
        it('redeems the requested amount', async function () {
          await this.token.authorizeOperatorByPartition(partition1, operator, { from: tokenHolder });
          await this.token.operatorRedeemByPartition(partition1, tokenHolder, redeemAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });
  
          await assertTotalSupply(this.token, issuanceAmount - redeemAmount);
          await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - redeemAmount);
        });
      });
      describe('can still call transferByPartition', function () {
        it('transfers the requested amount', async function () {
          await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
          await assertBalanceOf(this.token, recipient, partition1, 0);
  
          await this.token.transferByPartition(partition1, recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder });
  
          await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - transferAmount);
          await assertBalanceOf(this.token, recipient, partition1, transferAmount);
        });
      });
      describe('can still call operatorTransferByPartition', function () {
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
    });
    describe('can still call ERC1400Raw functions', function () {
      describe('can still call redeem', function () {
        it('redeeems the requested amount', async function () {
          await assertTotalSupply(this.token, issuanceAmount);
          await assertBalance(this.token, tokenHolder, issuanceAmount);

          await this.token.redeem(issuanceAmount, VALID_CERTIFICATE, { from: tokenHolder });

          await assertTotalSupply(this.token, 0);
          await assertBalance(this.token, tokenHolder, 0);
        });
      });
      describe('can still call redeemFrom', function () {
        it('redeems the requested amount', async function () {
          await assertTotalSupply(this.token, issuanceAmount);
          await assertBalance(this.token, tokenHolder, issuanceAmount);

          await this.token.authorizeOperator(operator, { from: tokenHolder });
          await this.token.redeemFrom(tokenHolder, issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

          await assertTotalSupply(this.token, 0);
          await assertBalance(this.token, tokenHolder, 0);
        });
      });
      describe('can still call transferWithData', function () {
        it('transfers the requested amount', async function () {
          await assertBalance(this.token, tokenHolder, issuanceAmount);
          await assertBalance(this.token, recipient, 0);

          await this.token.transferWithData(recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder });

          await assertBalance(this.token, tokenHolder, issuanceAmount - transferAmount);
          await assertBalance(this.token, recipient, transferAmount);
        });
      });
      describe('can still call transferFromWithData', function () {
        it('transfers the requested amount', async function () {
          await assertBalance(this.token, tokenHolder, issuanceAmount);
          await assertBalance(this.token, recipient, 0);

          await this.token.authorizeOperator(operator, { from: tokenHolder });
          await this.token.transferFromWithData(tokenHolder, recipient, transferAmount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

          await assertBalance(this.token, tokenHolder, issuanceAmount - transferAmount);
          await assertBalance(this.token, recipient, transferAmount);
        });
      });
    });
    describe('can not call ERC20 functions', function () {
      describe('can still call transferWithData', function () {
        it('transfers the requested amount', async function () {
          await assertBalance(this.token, tokenHolder, issuanceAmount);
          await assertBalance(this.token, recipient, 0);

          await shouldFail.reverting(this.token.transfer(recipient, issuanceAmount, { from: tokenHolder }));
        });
      });
      describe('can still call transferFromWithData', function () {
        it('transfers the requested amount', async function () {
          await assertBalance(this.token, tokenHolder, issuanceAmount);
          await assertBalance(this.token, recipient, 0);

          await this.token.authorizeOperator(operator, { from: tokenHolder });
          await shouldFail.reverting(this.token.transferFrom(tokenHolder, recipient, issuanceAmount, { from: operator }));
        });
      });
    });    

  });


  // MIGRATE
  describe('migrate', function () {
    const transferAmount = 300;

    beforeEach(async function () {
      this.migratedToken = await ERC1400ERC20.new('ERC1400ERC20Token', 'DAU20', 1, [controller], CERTIFICATE_SIGNER, true, partitions);
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
        let interface1400Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_INTERFACE_NAME));
        assert.equal(interface1400Implementer, this.token.address);
        let interface20Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC20_INTERFACE_NAME));
        assert.equal(interface20Implementer, this.token.address);

        await this.token.migrate(this.migratedToken.address, true, { from: owner });

        interface1400Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_INTERFACE_NAME));
        assert.equal(interface1400Implementer, this.migratedToken.address);
        interface20Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC20_INTERFACE_NAME));
        assert.equal(interface20Implementer, this.migratedToken.address);

        await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
        await assertBalanceOf(this.token, recipient, partition1, 0);

        await shouldFail.reverting(this.token.transferByPartition(partition1, recipient, transferAmount, VALID_CERTIFICATE, { from: tokenHolder }));
      });
    });
    describe('when the contract is migrated, but not definitely', function () {
      it('can transfer tokens', async function () {
        let interface1400Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_INTERFACE_NAME));
        assert.equal(interface1400Implementer, this.token.address);
        let interface20Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC20_INTERFACE_NAME));
        assert.equal(interface20Implementer, this.token.address);

        await this.token.migrate(this.migratedToken.address, false, { from: owner });

        interface1400Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_INTERFACE_NAME));
        assert.equal(interface1400Implementer, this.migratedToken.address);
        interface20Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC20_INTERFACE_NAME));
        assert.equal(interface20Implementer, this.migratedToken.address);

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

  // WHITELIST ACTIVATED

  describe('setWhitelistActivated', function () {
    beforeEach(async function () {
      this.validatorContract = await ERC1400TokensValidator.new(false, false, { from: owner });
      await this.token.setHookContract(this.validatorContract.address, ERC1400_TOKENS_VALIDATOR, { from: owner });
      let hookImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_TOKENS_VALIDATOR));
      assert.equal(hookImplementer, this.validatorContract.address);
    });
    describe('when the caller is the contract owner', function () {
      it('activates the whitelist', async function () {
        assert.equal(await this.validatorContract.isWhitelistActivated(), false);

        await this.validatorContract.setWhitelistActivated(true, { from: owner });
        assert.equal(await this.validatorContract.isWhitelistActivated(), true);

        await this.validatorContract.setWhitelistActivated(false, { from: owner });
        assert.equal(await this.validatorContract.isWhitelistActivated(), false);

        await this.validatorContract.setWhitelistActivated(true, { from: owner });
        assert.equal(await this.validatorContract.isWhitelistActivated(), true);
      });
    });
    describe('when the caller is not the contract owner', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.validatorContract.setWhitelistActivated(true, { from: unknown }));
      });
    });
  });

  // BLACKLIST ACTIVATED

  describe('setBlacklistActivated', function () {
    beforeEach(async function () {
      this.validatorContract = await ERC1400TokensValidator.new(false, false, { from: owner });
      await this.token.setHookContract(this.validatorContract.address, ERC1400_TOKENS_VALIDATOR, { from: owner });
      let hookImplementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC1400_TOKENS_VALIDATOR));
      assert.equal(hookImplementer, this.validatorContract.address);
    });
    describe('when the caller is the contract owner', function () {
      it('activates the whitelist', async function () {
        assert.equal(await this.validatorContract.isBlacklistActivated(), false);

        await this.validatorContract.setBlacklistActivated(true, { from: owner });
        assert.equal(await this.validatorContract.isBlacklistActivated(), true);

        await this.validatorContract.setBlacklistActivated(false, { from: owner });
        assert.equal(await this.validatorContract.isBlacklistActivated(), false);

        await this.validatorContract.setBlacklistActivated(true, { from: owner });
        assert.equal(await this.validatorContract.isBlacklistActivated(), true);
      });
    });
    describe('when the caller is not the contract owner', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.validatorContract.setBlacklistActivated(true, { from: unknown }));
      });
    });
  });

});
