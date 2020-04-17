const { shouldFail } = require('openzeppelin-test-helpers');

const { soliditySha3 } = require("web3-utils");

const ERC1400Raw = artifacts.require('ERC1400RawMock');
const ERC1820Registry = artifacts.require('ERC1820Registry');
const ERC1400TokensSender = artifacts.require('ERC1400TokensSenderMock');
const ERC1400TokensRecipient = artifacts.require('ERC1400TokensRecipientMock');

const ERC1400_TOKENS_SENDER = 'ERC1400TokensSender';
const ERC1400_TOKENS_RECIPIENT = 'ERC1400TokensRecipient';

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTE = '0x';

const VALID_CERTIFICATE = '0x1000000000000000000000000000000000000000000000000000000000000000';

const INVALID_CERTIFICATE_SENDER = '0x1100000000000000000000000000000000000000000000000000000000000000';
const INVALID_CERTIFICATE_RECIPIENT = '0x2200000000000000000000000000000000000000000000000000000000000000';

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

const initialSupply = 1000000000;

contract('ERC1400Raw without hooks', function ([owner, operator, controller, controller_alternative1, controller_alternative2, tokenHolder, recipient, unknown]) {
  // ADDITIONNAL MOCK TESTS

  describe('Additionnal mock tests', function () {
    beforeEach(async function () {
      this.token = await ERC1400Raw.new('ERC1400RawToken', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true);
    });

    describe('contract creation', function () {
      it('fails deploying the contract if granularity is lower than 1', async function () {
        await shouldFail.reverting(ERC1400Raw.new('ERC1400RawToken', 'DAU', 0, [controller], CERTIFICATE_SIGNER, true));
      });
    });

  });

  // BASIC FUNCTIONNALITIES

  describe('parameters', function () {
    beforeEach(async function () {
      this.token = await ERC1400Raw.new('ERC1400RawToken', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true);
    });

    describe('name', function () {
      it('returns the name of the token', async function () {
        const name = await this.token.name();

        assert.equal(name, 'ERC1400RawToken');
      });
    });

    describe('symbol', function () {
      it('returns the symbol of the token', async function () {
        const symbol = await this.token.symbol();

        assert.equal(symbol, 'DAU');
      });
    });

    describe('total supply', function () {
      it('returns the total amount of tokens', async function () {
        await this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
        const totalSupply = await this.token.totalSupply();

        assert.equal(totalSupply, initialSupply);
      });
    });

    describe('balanceOf', function () {
      describe('when the requested account has no tokens', function () {
        it('returns zero', async function () {
          const balance = await this.token.balanceOf(unknown);

          assert.equal(balance, 0);
        });
      });

      describe('when the requested account has some tokens', function () {
        it('returns the total amount of tokens', async function () {
          await this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
          const balance = await this.token.balanceOf(tokenHolder);

          assert.equal(balance, initialSupply);
        });
      });
    });

    describe('granularity', function () {
      it('returns the granularity of tokens', async function () {
        const granularity = await this.token.granularity();

        assert.equal(granularity, 1);
      });
    });

    describe('controllers', function () {
      it('returns the list of controllers', async function () {
        const controllers = await this.token.controllers();

        assert.equal(controllers.length, 1);
        assert.equal(controllers[0], controller);
      });
    });

    describe('authorizeOperator', function () {
      describe('when sender authorizes an operator', function () {
        it('authorizes the operator', async function () {
          assert.isTrue(!(await this.token.isOperator(operator, tokenHolder)));
          await this.token.authorizeOperator(operator, { from: tokenHolder });
          assert.isTrue(await this.token.isOperator(operator, tokenHolder));
        });
        it('emits a authorized event', async function () {
          const { logs } = await this.token.authorizeOperator(operator, { from: tokenHolder });

          assert.equal(logs.length, 1);
          assert.equal(logs[0].event, 'AuthorizedOperator');
          assert.equal(logs[0].args.operator, operator);
          assert.equal(logs[0].args.tokenHolder, tokenHolder);
        });
      });
      describe('when sender authorizes himself', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.authorizeOperator(tokenHolder, { from: tokenHolder }));
        });
      });
    });

    describe('revokeOperator', function () {
      describe('when sender revokes an operator', function () {
        it('revokes the operator (when operator is not the controller)', async function () {
          assert.isTrue(!(await this.token.isOperator(operator, tokenHolder)));
          await this.token.authorizeOperator(operator, { from: tokenHolder });
          assert.isTrue(await this.token.isOperator(operator, tokenHolder));

          await this.token.revokeOperator(operator, { from: tokenHolder });

          assert.isTrue(!(await this.token.isOperator(operator, tokenHolder)));
        });
        it('emits a revoked event', async function () {
          const { logs } = await this.token.revokeOperator(controller, { from: tokenHolder });

          assert.equal(logs.length, 1);
          assert.equal(logs[0].event, 'RevokedOperator');
          assert.equal(logs[0].args.operator, controller);
          assert.equal(logs[0].args.tokenHolder, tokenHolder);
        });
      });
      describe('when sender revokes himself', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.revokeOperator(tokenHolder, { from: tokenHolder }));
        });
      });
    });

    describe('isOperator', function () {
      it('when operator is tokenHolder', async function () {
        assert.isTrue(await this.token.isOperator(tokenHolder, tokenHolder));
      });
      it('when operator is authorized by tokenHolder', async function () {
        await this.token.authorizeOperator(operator, { from: tokenHolder });
        assert.isTrue(await this.token.isOperator(operator, tokenHolder));
      });
      it('when is a revoked operator', async function () {
        await this.token.revokeOperator(controller, { from: tokenHolder });
        assert.isTrue(!(await this.token.isOperator(controller, tokenHolder)));
      });
    });

    // SET CONTROLLERS

    describe('setControllers', function () {
      describe('when the caller is the contract owner', function () {
        it('sets the operators as controllers', async function () {
          const controllers1 = await this.token.controllers();
          assert.equal(controllers1.length, 1);
          assert.equal(controllers1[0], controller);
          assert.isTrue(!(await this.token.isOperator(controller, unknown)));
          assert.isTrue(!(await this.token.isOperator(controller_alternative1, unknown)));
          assert.isTrue(!(await this.token.isOperator(controller_alternative2, unknown)));
          await this.token.setControllable(true, { from: owner });
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
          await this.token.setControllable(false, { from: owner });
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

    // ISSUE

    describe('issue', function () {
      describe('when the caller is a issuer', function () {
        describe('when the amount is a multiple of the granularity', function () {
          describe('when the recipient is not the zero address', function () {
            it('issues the requested amount', async function () {
              await this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });

              const totalSupply = await this.token.totalSupply();
              const balance = await this.token.balanceOf(tokenHolder);

              assert.equal(totalSupply, initialSupply);
              assert.equal(balance, initialSupply);
            });
            it('emits a sent event', async function () {
              const { logs } = await this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });

              assert.equal(logs.length, 2);

              assert.equal(logs[0].event, 'Checked');
              assert.equal(logs[0].args.sender, owner);

              assert.equal(logs[1].event, 'Issued');
              assert.equal(logs[1].args.operator, owner);
              assert.equal(logs[1].args.to, tokenHolder);
              assert.equal(logs[1].args.value, initialSupply);
              assert.equal(logs[1].args.data, VALID_CERTIFICATE);
              assert.equal(logs[1].args.operatorData, null);
            });
          });
          describe('when the recipient is the zero address', function () {
            it('reverts', async function () {
              await shouldFail.reverting(this.token.issue(ZERO_ADDRESS, initialSupply, VALID_CERTIFICATE, { from: owner }));
            });
          });
        });
        describe('when the amount is not a multiple of the granularity', function () {
          it('reverts', async function () {
            this.token = await ERC1400Raw.new('ERC1400RawToken', 'DAU', 2, [], CERTIFICATE_SIGNER, true);
            await shouldFail.reverting(this.token.issue(tokenHolder, 3, VALID_CERTIFICATE, { from: owner }));
          });
        });
      });
      describe('when the caller is not a issuer', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: unknown }));
        });
      });
    });

    // TRANSFERWITHDATA

    describe('transferWithData', function () {
      const to = recipient;
      beforeEach(async function () {
        await this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
      });
      describe('when the amount is a multiple of the granularity', function () {
        describe('when the recipient is not the zero address', function () {
          describe('when the sender has enough balance', function () {
            const amount = initialSupply;
            it('transfers the requested amount', async function () {
              await this.token.transferWithData(to, amount, VALID_CERTIFICATE, { from: tokenHolder });
              const senderBalance = await this.token.balanceOf(tokenHolder);
              assert.equal(senderBalance, initialSupply - amount);

              const recipientBalance = await this.token.balanceOf(to);
              assert.equal(recipientBalance, amount);
            });

            it('emits a sent event', async function () {
              const { logs } = await this.token.transferWithData(to, amount, VALID_CERTIFICATE, { from: tokenHolder });

              assert.equal(logs.length, 2);

              assert.equal(logs[0].event, 'Checked');
              assert.equal(logs[0].args.sender, tokenHolder);

              assert.equal(logs[1].event, 'TransferWithData');
              assert.equal(logs[1].args.operator, tokenHolder);
              assert.equal(logs[1].args.from, tokenHolder);
              assert.equal(logs[1].args.to, to);
              assert.equal(logs[1].args.value, amount);
              assert.equal(logs[1].args.data, VALID_CERTIFICATE);
              assert.equal(logs[1].args.operatorData, null);
            });
          });
          describe('when the sender does not have enough balance', function () {
            const amount = initialSupply + 1;

            it('reverts', async function () {
              await shouldFail.reverting(this.token.transferWithData(to, amount, VALID_CERTIFICATE, { from: tokenHolder }));
            });
          });
        });

        describe('when the recipient is the zero address', function () {
          const amount = initialSupply;
          const to = ZERO_ADDRESS;

          it('reverts', async function () {
            await shouldFail.reverting(this.token.transferWithData(to, amount, VALID_CERTIFICATE, { from: tokenHolder }));
          });
        });
      });
      describe('when the amount is not a multiple of the granularity', function () {
        it('reverts', async function () {
          this.token = await ERC1400Raw.new('ERC1400RawToken', 'DAU', 2, [], CERTIFICATE_SIGNER, true);
          await this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
          await shouldFail.reverting(this.token.transferWithData(to, 3, VALID_CERTIFICATE, { from: tokenHolder }));
        });
      });
    });

    // TRANSFERFROMWITHDATA

    describe('transferFromWithData', function () {
      const to = recipient;
      beforeEach(async function () {
        await this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
      });
      describe('when the operator is approved', function () {
        beforeEach(async function () {
          await this.token.authorizeOperator(operator, { from: tokenHolder });
        });
        describe('when the amount is a multiple of the granularity', function () {
          describe('when the recipient is not the zero address', function () {

            describe('when the sender has enough balance', function () {
              const amount = initialSupply;

              it('transfers the requested amount', async function () {
                await this.token.transferFromWithData(tokenHolder, to, amount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });
                const senderBalance = await this.token.balanceOf(tokenHolder);
                assert.equal(senderBalance, initialSupply - amount);

                const recipientBalance = await this.token.balanceOf(to);
                assert.equal(recipientBalance, amount);
              });

              it('emits a sent event [with ERC20 retrocompatibility]', async function () {
                const { logs } = await this.token.transferFromWithData(tokenHolder, to, amount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

                assert.equal(logs.length, 2);

                assert.equal(logs[0].event, 'Checked');
                assert.equal(logs[0].args.sender, operator);

                assert.equal(logs[1].event, 'TransferWithData');
                assert.equal(logs[1].args.operator, operator);
                assert.equal(logs[1].args.from, tokenHolder);
                assert.equal(logs[1].args.to, to);
                assert.equal(logs[1].args.value, amount);
                assert.equal(logs[1].args.data, null);
                assert.equal(logs[1].args.operatorData, VALID_CERTIFICATE);
              });
            });
            describe('when the sender does not have enough balance', function () {
              const amount = initialSupply + 1;

              it('reverts', async function () {
                await shouldFail.reverting(this.token.transferFromWithData(tokenHolder, to, amount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
              });
            });
          });

          describe('when the recipient is the zero address', function () {
            const amount = initialSupply;
            const to = ZERO_ADDRESS;

            it('reverts', async function () {
              await shouldFail.reverting(this.token.transferFromWithData(tokenHolder, to, amount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
            });
          });
        });
        describe('when the amount is not a multiple of the granularity', function () {
          it('reverts', async function () {
            this.token = await ERC1400Raw.new('ERC1400RawToken', 'DAU', 2, [], CERTIFICATE_SIGNER, true);
            await this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
            await shouldFail.reverting(this.token.transferFromWithData(tokenHolder, to, 3, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
          });
        });
      });
      describe('when the operator is not approved', function () {
        it('reverts', async function () {
          const amount = initialSupply;
          await shouldFail.reverting(this.token.transferFromWithData(tokenHolder, to, amount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
        });
      });
    });

    // REDEEM

    describe('redeem', function () {
      beforeEach(async function () {
        await this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
      });

      describe('when the amount is a multiple of the granularity', function () {
        describe('when the redeemer has enough balance', function () {
          const amount = initialSupply;

          it('redeems the requested amount', async function () {
            await this.token.redeem(amount, VALID_CERTIFICATE, { from: tokenHolder });
            const senderBalance = await this.token.balanceOf(tokenHolder);
            assert.equal(senderBalance, initialSupply - amount);
          });

          it('emits a redeemed event [with ERC20 retrocompatibility]', async function () {
            const { logs } = await this.token.redeem(amount, VALID_CERTIFICATE, { from: tokenHolder });

            assert.equal(logs.length, 2);

            assert.equal(logs[0].event, 'Checked');
            assert.equal(logs[0].args.sender, tokenHolder);

            assert.equal(logs[1].event, 'Redeemed');
            assert.equal(logs[1].args.operator, tokenHolder);
            assert.equal(logs[1].args.from, tokenHolder);
            assert.equal(logs[1].args.value, amount);
            assert.equal(logs[1].args.data, VALID_CERTIFICATE);
            assert.equal(logs[1].args.operatorData, null);
          });
        });
        describe('when the redeemer does not have enough balance', function () {
          const amount = initialSupply + 1;

          it('reverts', async function () {
            await shouldFail.reverting(this.token.redeem(amount, VALID_CERTIFICATE, { from: tokenHolder }));
          });
        });
      });
      describe('when the amount is not a multiple of the granularity', function () {
        it('reverts', async function () {
          this.token = await ERC1400Raw.new('ERC1400RawToken', 'DAU', 2, [], CERTIFICATE_SIGNER, true);
          await this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
          await shouldFail.reverting(this.token.redeem(3, VALID_CERTIFICATE, { from: tokenHolder }));
        });
      });
    });

    // REDEEMFROM

    describe('redeemFrom', function () {
      beforeEach(async function () {
        await this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
      });

      beforeEach(async function () {
        await this.token.authorizeOperator(operator, { from: tokenHolder });
      });
      describe('when the amount is a multiple of the granularity', function () {
        describe('when the redeemer is not the zero address', function () {
          describe('when the redeemer does not have enough balance', function () {
            const amount = initialSupply + 1;

            it('reverts', async function () {
              await shouldFail.reverting(this.token.redeemFrom(tokenHolder, amount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
            });
          });

          describe('when the redeemer has enough balance', function () {
            const amount = initialSupply;

            it('redeems the requested amount', async function () {
              await this.token.redeemFrom(tokenHolder, amount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });
              const senderBalance = await this.token.balanceOf(tokenHolder);
              assert.equal(senderBalance, initialSupply - amount);
            });

            it('emits a redeemed event [with ERC20 retrocompatibility]', async function () {
              const { logs } = await this.token.redeemFrom(tokenHolder, amount, ZERO_BYTE, VALID_CERTIFICATE, { from: operator });

              assert.equal(logs.length, 2);

              assert.equal(logs[0].event, 'Checked');
              assert.equal(logs[0].args.sender, operator);

              assert.equal(logs[1].event, 'Redeemed');
              assert.equal(logs[1].args.operator, operator);
              assert.equal(logs[1].args.from, tokenHolder);
              assert.equal(logs[1].args.value, amount);
              assert.equal(logs[1].args.data, null);
              assert.equal(logs[1].args.operatorData, VALID_CERTIFICATE);
            });
          });
        });

        describe('when the redeemer is the zero address', function () {
          it('reverts', async function () {
            const amount = initialSupply;
            await shouldFail.reverting(this.token.redeemFromMock(ZERO_ADDRESS, amount, ZERO_BYTE, ZERO_BYTE, { from: operator }));
          });
        });
      });
      describe('when the amount is not a multiple of the granularity', function () {
        it('reverts', async function () {
          this.token = await ERC1400Raw.new('ERC1400RawToken', 'DAU', 2, [], CERTIFICATE_SIGNER, true);
          await this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
          await shouldFail.reverting(this.token.redeemFrom(tokenHolder, 3, ZERO_BYTE, VALID_CERTIFICATE, { from: operator }));
        });
      });
    });
  });
});

contract('ERC1400Raw with sender and recipient hooks', function ([owner, operator, controller, tokenHolder, recipient, unknown]) {
  // HOOKS

  describe('hooks', function () {
    const amount = initialSupply;
    const to = recipient;

    beforeEach(async function () {
      this.token = await ERC1400Raw.new('ERC1400RawToken', 'DAU', 1, [controller], CERTIFICATE_SIGNER, true);
      this.registry = await ERC1820Registry.at('0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24');

      this.senderContract = await ERC1400TokensSender.new({ from: tokenHolder });
      await this.registry.setInterfaceImplementer(tokenHolder, soliditySha3(ERC1400_TOKENS_SENDER), this.senderContract.address, { from: tokenHolder });

      this.recipientContract = await ERC1400TokensRecipient.new({ from: recipient });
      await this.registry.setInterfaceImplementer(recipient, soliditySha3(ERC1400_TOKENS_RECIPIENT), this.recipientContract.address, { from: recipient });

      await this.token.issue(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
    });
    afterEach(async function () {
        await this.registry.setInterfaceImplementer(tokenHolder, soliditySha3(ERC1400_TOKENS_SENDER), ZERO_ADDRESS , { from: tokenHolder });
        await this.registry.setInterfaceImplementer(recipient, soliditySha3(ERC1400_TOKENS_RECIPIENT), ZERO_ADDRESS, { from: recipient });
    });
    describe('when the transfer is successfull', function () {
      it('transfers the requested amount', async function () {
        await this.token.transferWithData(to, amount, VALID_CERTIFICATE, { from: tokenHolder });
        const senderBalance = await this.token.balanceOf(tokenHolder);
        assert.equal(senderBalance, initialSupply - amount);

        const recipientBalance = await this.token.balanceOf(to);
        assert.equal(recipientBalance, amount);
      });
    });
    describe('when the transfer fails', function () {
      it('sender hook reverts', async function () {
        // Default sender hook failure data for the mock only: 0x1100000000000000000000000000000000000000000000000000000000000000
        await shouldFail.reverting(this.token.transferWithData(to, amount, INVALID_CERTIFICATE_SENDER, { from: tokenHolder }));
      });
      it('recipient hook reverts', async function () {
        // Default recipient hook failure data for the mock only: 0x2200000000000000000000000000000000000000000000000000000000000000
        await shouldFail.reverting(this.token.transferWithData(to, amount, INVALID_CERTIFICATE_RECIPIENT, { from: tokenHolder }));
      });
    });
  });
});
