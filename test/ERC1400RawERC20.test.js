const { shouldFail } = require('openzeppelin-test-helpers');

const { soliditySha3 } = require("web3-utils");

const ERC1820Registry = artifacts.require('ERC1820Registry');
const ERC1400RawERC20 = artifacts.require('ERC1400RawERC20');
const ERC1400TokensValidator = artifacts.require('ERC1400TokensValidator');

const ERC1820_ACCEPT_MAGIC = 'ERC1820_ACCEPT_MAGIC';

const ERC20_INTERFACE_NAME = 'ERC20Token';
const ERC1400_TOKENS_VALIDATOR = 'ERC1400TokensValidator';

const ZERO_BYTES32 = '0x0000000000000000000000000000000000000000000000000000000000000000';
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTE = '0x';

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

const VALID_CERTIFICATE = '0x1000000000000000000000000000000000000000000000000000000000000000';

const INVALID_CERTIFICATE_VALIDATOR = '0x3300000000000000000000000000000000000000000000000000000000000000';

const issuanceAmount = 1000000000;

const assertBalance = async (
    _contract,
    _tokenHolder,
    _amount
  ) => {
    const balance = await _contract.balanceOf(_tokenHolder);
    assert.equal(balance, _amount);
  };

contract('ERC1400RawERC20', function ([owner, operator, controller, tokenHolder, recipient, unknown]) {
  // ERC20 RETROCOMPATIBILITY

  describe('ERC20 retrocompatibility', function () {

    before(async function () {
      this.registry = await ERC1820Registry.at('0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24');
    });

    beforeEach(async function () {
      this.token = await ERC1400RawERC20.new('ERC1400RawERC20Token', 'DAU20', 1, [controller], CERTIFICATE_SIGNER, true);
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

    // ISSUE

    describe('issue', function () {
      describe('when the caller is a issuer', function () {
        describe('when the amount is a multiple of the granularity', function () {
          describe('when the recipient is not the zero address', function () {
            it('issues the requested amount', async function () {
              await this.token.issue(tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
            });
            it('emits a Transfer event [ERC20 retrocompatibility]', async function () {
              const { logs } = await this.token.issue(tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });

              assert.equal(logs.length, 3);

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
            });
          });
        });
      });
    });

    // TRANSFERWITHDATA

    describe('transferWithData', function () {
      const to = recipient;
      beforeEach(async function () {
        await this.token.issue(tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
      });
      describe('when the amount is a multiple of the granularity', function () {
        describe('when the recipient is not the zero address', function () {
          describe('when the sender has enough balance', function () {
            const amount = issuanceAmount;
            describe('when the recipient is a regular address', function () {
              it('transfers the requested amount', async function () {
                await this.token.transferWithData(to, amount, VALID_CERTIFICATE, { from: tokenHolder });
                const senderBalance = await this.token.balanceOf(tokenHolder);
                assert.equal(senderBalance, issuanceAmount - amount);

                const recipientBalance = await this.token.balanceOf(to);
                assert.equal(recipientBalance, amount);
              });

              it('emits a Transfer event [ERC20 retrocompatibility]', async function () {
                const { logs } = await this.token.transferWithData(to, amount, VALID_CERTIFICATE, { from: tokenHolder });

                assert.equal(logs.length, 3);

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
              });
            });
          });
        });
      });
    });

    // REDEEM

    describe('redeem', function () {
      beforeEach(async function () {
        await this.token.issue(tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
      });

      describe('when the amount is a multiple of the granularity', function () {
        describe('when the redeemer has enough balance', function () {
          const amount = issuanceAmount;

          it('redeems the requested amount', async function () {
            await this.token.redeem(amount, VALID_CERTIFICATE, { from: tokenHolder });
            const senderBalance = await this.token.balanceOf(tokenHolder);
            assert.equal(senderBalance, issuanceAmount - amount);
          });

          it('emits a Transfer event [ERC20 retrocompatibility]', async function () {
            const { logs } = await this.token.redeem(amount, VALID_CERTIFICATE, { from: tokenHolder });

            assert.equal(logs.length, 3);

            assert.equal(logs[0].event, 'Checked');
            assert.equal(logs[0].args.sender, tokenHolder);

            assert.equal(logs[1].event, 'Redeemed');
            assert.equal(logs[1].args.operator, tokenHolder);
            assert.equal(logs[1].args.from, tokenHolder);
            assert.equal(logs[1].args.value, amount);
            assert.equal(logs[1].args.data, VALID_CERTIFICATE);
            assert.equal(logs[1].args.operatorData, null);

            assert.equal(logs[2].event, 'Transfer');
            assert.equal(logs[2].args.from, tokenHolder);
            assert.equal(logs[2].args.to, ZERO_ADDRESS);
            assert.equal(logs[2].args.value, amount);
          });
        });
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
        const to = recipient;
        beforeEach(async function () {
            await this.token.issue(tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
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
                describe('when the amount is a multiple of the granularity', function () {
                    describe('when the recipient is not the zero address', function () {
                        describe('when the sender has enough balance', function () {
                            const amount = issuanceAmount;
                            
                            it('transfers the requested amount', async function () {
                                await this.token.transfer(recipient, amount, { from: tokenHolder });
                                const senderBalance = await this.token.balanceOf(tokenHolder);
                                assert.equal(senderBalance, issuanceAmount - amount);
                                
                                const recipientBalance = await this.token.balanceOf(recipient);
                                assert.equal(recipientBalance, amount);
                            });
                            
                            it('emits a Transfer event', async function () {
                                const { logs } = await this.token.transfer(recipient, amount, { from: tokenHolder });
                                
                                assert.equal(logs.length, 2);
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
                        this.token = await ERC1400RawERC20.new('ERC1400RawToken', 'DAU', 2, [], CERTIFICATE_SIGNER, true);
                        await this.token.issue(tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
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
        describe('when token has no withelist', function () {
            const amount = issuanceAmount;

            it('transfers the requested amount', async function () {
                await this.token.transfer(recipient, amount, { from: tokenHolder });
                const senderBalance = await this.token.balanceOf(tokenHolder);
                assert.equal(senderBalance, issuanceAmount - amount);
                
                const recipientBalance = await this.token.balanceOf(recipient);
                assert.equal(recipientBalance, amount);
            });         
        });
    });

    // TRANSFERFROM
    
    describe('transferFrom', function () {
        const approvedAmount = 10000;
        beforeEach(async function () {
            await this.token.issue(tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
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
            describe('when the recipient is whitelisted', function () {
                describe('when the operator is approved', function () {
                    beforeEach(async function () {
                        await this.token.approve(operator, approvedAmount, { from: tokenHolder });
                    });
                    describe('when the amount is a multiple of the granularity', function () {
                        describe('when the recipient is not the zero address', function () {                            
                            describe('when the sender has enough balance', function () {
                                const amount = 500;
                                
                                it('transfers the requested amount', async function () {
                                    await this.token.transferFrom(tokenHolder, recipient, amount, { from: operator });
                                    const senderBalance = await this.token.balanceOf(tokenHolder);
                                    assert.equal(senderBalance, issuanceAmount - amount);
                                    
                                    const recipientBalance = await this.token.balanceOf(recipient);
                                    assert.equal(recipientBalance, amount);
                                    
                                    assert.equal(await this.token.allowance(tokenHolder, operator), approvedAmount - amount);
                                });
                                
                                it('emits a Transfer event', async function () {
                                    const { logs } = await this.token.transferFrom(tokenHolder, recipient, amount, { from: operator });
                                    // await this.token.transferFrom(tokenHolder, recipient, amount, { from: operator });
                                    
                                    assert.equal(logs.length, 2);
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
                            this.token = await ERC1400RawERC20.new('ERC1400RawToken', 'DAU', 2, [], CERTIFICATE_SIGNER, true);
                            await this.token.issue(tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
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
                            const senderBalance = await this.token.balanceOf(tokenHolder);
                            assert.equal(senderBalance, issuanceAmount - amount);
                            
                            const recipientBalance = await this.token.balanceOf(recipient);
                            assert.equal(recipientBalance, amount);
                        });
                    });
                    describe('when the operator is not approved and not authorized', function () {
                        it('reverts', async function () {
                            await shouldFail.reverting(this.token.transferFrom(tokenHolder, recipient, amount, { from: operator }));
                        });
                    });
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
            const amount = 500;

            beforeEach(async function () {
                await this.token.approve(operator, approvedAmount, { from: tokenHolder });
            });
            
            it('transfers the requested amount', async function () {
                await this.token.transferFrom(tokenHolder, recipient, amount, { from: operator });
                await assertBalance(this.token, tokenHolder, issuanceAmount - amount);
                await assertBalance(this.token, recipient, amount);
                
                assert.equal(await this.token.allowance(tokenHolder, operator), approvedAmount - amount);
            });
        });
    });

  // MIGRATE
  describe('migrate', function () {
    const transferAmount = 300;

    beforeEach(async function () {
      this.migratedToken = await ERC1400RawERC20.new('ERC1400RawERC20Token', 'DAU20', 1, [controller], CERTIFICATE_SIGNER, true);
      await this.token.issue(tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });
    describe('when the sender is the contract owner', function () {
      describe('when the contract is not migrated', function () {
        it('can transfer tokens', async function () {
          await assertBalance(this.token, tokenHolder, issuanceAmount);
          await assertBalance(this.token, recipient, 0);

          await this.token.transfer(recipient, transferAmount, { from: tokenHolder });

          await assertBalance(this.token, tokenHolder, issuanceAmount - transferAmount);
          await assertBalance(this.token, recipient, transferAmount);
        });
      });
      describe('when the contract is migrated definitely', function () {
        it('can not transfer tokens', async function () {
            let interface20Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC20_INTERFACE_NAME));
            assert.equal(interface20Implementer, this.token.address);

            await this.token.migrate(this.migratedToken.address, true, { from: owner });

            interface20Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC20_INTERFACE_NAME));
            assert.equal(interface20Implementer, this.migratedToken.address);

            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);

            await shouldFail.reverting(this.token.transfer(recipient, transferAmount, { from: tokenHolder }));
        });
      });
      describe('when the contract is migrated, but not definitely', function () {
        it('can transfer tokens', async function () {
            let interface20Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC20_INTERFACE_NAME));
            assert.equal(interface20Implementer, this.token.address);

            await this.token.migrate(this.migratedToken.address, false, { from: owner });

            interface20Implementer = await this.registry.getInterfaceImplementer(this.token.address, soliditySha3(ERC20_INTERFACE_NAME));
            assert.equal(interface20Implementer, this.migratedToken.address);

            await assertBalance(this.token, tokenHolder, issuanceAmount);
            await assertBalance(this.token, recipient, 0);

            await this.token.transfer(recipient, transferAmount, { from: tokenHolder });

            await assertBalance(this.token, tokenHolder, issuanceAmount - transferAmount);
            await assertBalance(this.token, recipient, transferAmount);
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
});

contract('ERC1400RawERC20 with validator hook', function ([owner, operator, controller, tokenHolder, recipient, unknown]) {

    // HOOKS
    before(async function () {
        this.registry = await ERC1820Registry.at('0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24');
    });
  
    beforeEach(async function () {
        this.token = await ERC1400RawERC20.new('ERC1400RawERC20Token', 'DAU20', 1, [controller], CERTIFICATE_SIGNER, true);
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
  
      beforeEach(async function () {
        await this.token.setHookContract(this.validatorContract.address, ERC1400_TOKENS_VALIDATOR, { from: owner });
        await this.token.issue(tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
      });
      afterEach(async function () {
        await this.token.setHookContract(ZERO_ADDRESS, ERC1400_TOKENS_VALIDATOR, { from: owner });
      });
      describe('when the transfer is successfull', function () {
        it('transfers the requested amount', async function () {
          await this.token.transferWithData(recipient, amount, VALID_CERTIFICATE, { from: tokenHolder });
          await assertBalance(this.token, tokenHolder, issuanceAmount - amount);
          await assertBalance(this.token, recipient, amount);
        });
      });
      describe('when the transfer fails', function () {
        it('sender hook reverts', async function () {        
          // Default sender hook failure data for the mock only: 0x3300000000000000000000000000000000000000000000000000000000000000
          await shouldFail.reverting(this.token.transferWithData(recipient, amount, INVALID_CERTIFICATE_VALIDATOR, { from: tokenHolder }));
        });
      });
    });
  
  });