import shouldFail from 'openzeppelin-solidity/test/helpers/shouldFail.js';

const ERC777 = artifacts.require('ERC777Mock');
const ERC820Registry = artifacts.require('ERC820Registry');
const ERC777TokensSender = artifacts.require('ERC777TokensSenderMock');
const ERC777TokensRecipient = artifacts.require('ERC777TokensRecipientMock');

const ERC777ERC20 = artifacts.require('ERC777ERC20Mock');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTE = '0x';

const VALID_CERTIFICATE = '0x1000000000000000000000000000000000000000000000000000000000000000';

const INVALID_CERTIFICATE_SENDER = '0x1100000000000000000000000000000000000000000000000000000000000000';
const INVALID_CERTIFICATE_RECIPIENT = '0x2200000000000000000000000000000000000000000000000000000000000000';

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

const initialSupply = 1000000000;

contract('ERC777 without hooks', function ([owner, operator, defaultOperator, tokenHolder, recipient, unknown]) {
  // ADDITIONNAL MOCK TESTS

  describe('Additionnal mock tests', function () {
    beforeEach(async function () {
      this.token = await ERC777.new('ERC777Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });

    describe('contract creation', function () {
      it('fails deploying the contract if granularity is lower than 1', async function () {
        await shouldFail.reverting(ERC777.new('ERC777Token', 'DAU', 0, [defaultOperator], CERTIFICATE_SIGNER));
      });
    });

    describe('_isRegularAddress', function () {
      it('returns true when address is correct', async function () {
        assert(await this.token.isRegularAddress(owner));
      });
      it('returns true when address is non zero', async function () {
        assert(await this.token.isRegularAddress(owner));
      });
      it('returns false when address is ZERO_ADDRESS', async function () {
        assert(!(await this.token.isRegularAddress(ZERO_ADDRESS)));
      });
    });
  });

  // BASIC FUNCTIONNALITIES

  describe('parameters', function () {
    beforeEach(async function () {
      this.token = await ERC777.new('ERC777Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });

    describe('name', function () {
      it('returns the name of the token', async function () {
        const name = await this.token.name();

        assert.equal(name, 'ERC777Token');
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
        await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
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
          await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
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

    describe('defaultOperators', function () {
      describe('when the token is not controllable [ERC777-version]', function () {
        it('returns the list of defaultOperators', async function () {
          const defaultOperators = await this.token.defaultOperators();

          assert.equal(defaultOperators.length, 1);
          assert.equal(defaultOperators[0], defaultOperator);
        });
      });
      describe('when the token is not controllable [ERC1400-version]', function () {
        it('returns an empty list', async function () {
          const defaultOperators = await this.token.defaultOperatorsMock(false);

          assert.equal(defaultOperators.length, 0);
        });
      });
    });

    describe('authorizeOperator', function () {
      describe('when sender authorizes an operator', function () {
        it('authorizes the operator', async function () {
          assert(!(await this.token.isOperatorFor(operator, tokenHolder)));
          await this.token.authorizeOperator(operator, { from: tokenHolder });
          assert(await this.token.isOperatorFor(operator, tokenHolder));
        });
        it('emits a authorized event', async function () {
          const { logs } = await this.token.authorizeOperator(operator, { from: tokenHolder });

          assert.equal(logs.length, 1);
          assert.equal(logs[0].event, 'AuthorizedOperator');
          assert.equal(logs[0].args.operator, operator);
          assert.equal(logs[0].args.tokenHolder, tokenHolder);
        });
      });
    });

    describe('revokeOperator', function () {
      describe('when sender revokes an operator', function () {
        it('revokes the operator (when operator is not the default operator)', async function () {
          assert(!(await this.token.isOperatorFor(operator, tokenHolder)));
          await this.token.authorizeOperator(operator, { from: tokenHolder });
          assert(await this.token.isOperatorFor(operator, tokenHolder));

          await this.token.revokeOperator(operator, { from: tokenHolder });

          assert(!(await this.token.isOperatorFor(operator, tokenHolder)));
        });
        it('revokes the operator (when operator is the default operator)', async function () {
          assert(await this.token.isOperatorFor(defaultOperator, tokenHolder));
          await this.token.revokeOperator(defaultOperator, { from: tokenHolder });
          assert(!(await this.token.isOperatorFor(defaultOperator, tokenHolder)));
        });
        it('emits a revoked event', async function () {
          const { logs } = await this.token.revokeOperator(defaultOperator, { from: tokenHolder });

          assert.equal(logs.length, 1);
          assert.equal(logs[0].event, 'RevokedOperator');
          assert.equal(logs[0].args.operator, defaultOperator);
          assert.equal(logs[0].args.tokenHolder, tokenHolder);
        });
      });
    });

    describe('isOperatorFor', function () {
      it('when operator is tokenHolder', async function () {
        assert(await this.token.isOperatorFor(tokenHolder, tokenHolder));
      });
      it('when operator is authorized by tokenHolder', async function () {
        await this.token.authorizeOperator(operator, { from: tokenHolder });
        assert(await this.token.isOperatorFor(operator, tokenHolder));
      });
      it('when operator is defaultOperator', async function () {
        assert(await this.token.isOperatorFor(defaultOperator, tokenHolder));
      });
      it('when is a revoked operator', async function () {
        await this.token.revokeOperator(defaultOperator, { from: tokenHolder });
        assert(!(await this.token.isOperatorFor(defaultOperator, tokenHolder)));
      });
    });

    // DEFAULTOPERATOR

    describe('addDefaultOperator', function () {
      describe('when the caller is the contract owner', function () {
        describe('when the operator is not already a default operator', function () {
          it('adds the operator to default operators', async function () {
            const defaultOperators1 = await this.token.defaultOperators();
            assert.equal(defaultOperators1.length, 1);
            assert.equal(defaultOperators1[0], defaultOperator);
            await this.token.addDefaultOperator(operator, { from: owner });
            const defaultOperators2 = await this.token.defaultOperators();
            assert.equal(defaultOperators2.length, 2);
            assert.equal(defaultOperators2[0], defaultOperator);
            assert.equal(defaultOperators2[1], operator);
            assert(await this.token.isOperatorFor(operator, unknown));
          });
        });
        describe('when the operator is already a default operator', function () {
          it('reverts', async function () {
            await this.token.addDefaultOperator(operator, { from: owner });
            const defaultOperators = await this.token.defaultOperators();
            assert.equal(defaultOperators.length, 2);
            assert.equal(defaultOperators[0], defaultOperator);
            assert.equal(defaultOperators[1], operator);
            await shouldFail.reverting(this.token.addDefaultOperator(operator, { from: owner }));
          });
        });
      });
      describe('when the caller is not the contract owner', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.addDefaultOperator(operator, { from: unknown }));
        });
      });
    });

    describe('removeDefaultOperator', function () {
      describe('when the caller is the contract owner', function () {
        describe('when the operator is already a default operator', function () {
          it('removes the operator from default operators (initial default operator)', async function () {
            const defaultOperators1 = await this.token.defaultOperators();
            assert.equal(defaultOperators1.length, 1);
            assert.equal(defaultOperators1[0], defaultOperator);
            await this.token.removeDefaultOperator(defaultOperator, { from: owner });
            const defaultOperators2 = await this.token.defaultOperators();
            assert.equal(defaultOperators2.length, 0);
            assert(!(await this.token.isOperatorFor(defaultOperator, unknown)));
          });
          it('removes the operator from default operators (new default operator)', async function () {
            await this.token.addDefaultOperator(operator, { from: owner });
            const defaultOperators1 = await this.token.defaultOperators();
            assert.equal(defaultOperators1.length, 2);
            assert.equal(defaultOperators1[0], defaultOperator);
            assert.equal(defaultOperators1[1], operator);
            assert(await this.token.isOperatorFor(operator, unknown));
            await this.token.removeDefaultOperator(operator, { from: owner });
            const defaultOperators2 = await this.token.defaultOperators();
            assert.equal(defaultOperators2.length, 1);
            assert.equal(defaultOperators1[0], defaultOperator);
            assert(!(await this.token.isOperatorFor(operator, unknown)));
          });
        });
        describe('when the operator is not already a default operator', function () {
          it('reverts', async function () {
            const defaultOperators = await this.token.defaultOperators();
            assert.equal(defaultOperators.length, 1);
            assert.equal(defaultOperators[0], defaultOperator);
            await shouldFail.reverting(this.token.removeDefaultOperator(operator, { from: owner }));
          });
        });
      });
      describe('when the caller is not the contract owner', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.removeDefaultOperator(defaultOperator, { from: unknown }));
        });
      });
    });

    // MINT

    describe('mint', function () {
      describe('when the caller is a minter', function () {
        describe('when the amount is a multiple of the granularity', function () {
          describe('when the recipient is not the zero address', function () {
            it('mints the requested amount', async function () {
              await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });

              const totalSupply = await this.token.totalSupply();
              const balance = await this.token.balanceOf(tokenHolder);

              assert.equal(totalSupply, initialSupply);
              assert.equal(balance, initialSupply);
            });
            it('emits a sent event', async function () {
              const { logs } = await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });

              assert.equal(logs.length, 2);

              assert.equal(logs[0].event, 'Checked');
              assert.equal(logs[0].args.sender, owner);

              assert.equal(logs[1].event, 'Minted');
              assert.equal(logs[1].args.operator, owner);
              assert.equal(logs[1].args.to, tokenHolder);
              assert(logs[1].args.amount.eq(initialSupply));
              assert.equal(logs[1].args.data, VALID_CERTIFICATE);
              assert.equal(logs[1].args.operatorData, ZERO_BYTE);
            });
          });
          describe('when the recipient is the zero address', function () {
            it('reverts', async function () {
              await shouldFail.reverting(this.token.mint(ZERO_ADDRESS, initialSupply, VALID_CERTIFICATE, { from: owner }));
            });
          });
        });
        describe('when the amount is not a multiple of the granularity', function () {
          it('reverts', async function () {
            this.token = await ERC777.new('ERC777Token', 'DAU', 2, [], CERTIFICATE_SIGNER);
            await shouldFail.reverting(this.token.mint(tokenHolder, 3, VALID_CERTIFICATE, { from: owner }));
          });
        });
      });
      describe('when the caller is not a minter', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: unknown }));
        });
      });
    });

    // OPERATORMINT

    describe('operatorMint', function () {
      describe('when the caller is a minter', function () {
        describe('when the amount is a multiple of the granularity', function () {
          describe('when the recipient is not the zero address', function () {
            it('mints the requested amount', async function () {
              await this.token.operatorMint(tokenHolder, initialSupply, '', VALID_CERTIFICATE, { from: owner });
            });
          });
        });
      });
    });

    // SENDTO

    describe('sendTo', function () {
      const to = recipient;
      beforeEach(async function () {
        await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
      });
      describe('when the amount is a multiple of the granularity', function () {
        describe('when the recipient is not the zero address', function () {
          describe('when the sender has enough balance', function () {
            const amount = initialSupply;
            describe('when the recipient is a regular address', function () {
              it('transfers the requested amount', async function () {
                await this.token.sendTo(to, amount, VALID_CERTIFICATE, { from: tokenHolder });
                const senderBalance = await this.token.balanceOf(tokenHolder);
                assert.equal(senderBalance, initialSupply - amount);

                const recipientBalance = await this.token.balanceOf(to);
                assert.equal(recipientBalance, amount);
              });

              it('emits a sent event', async function () {
                const { logs } = await this.token.sendTo(to, amount, VALID_CERTIFICATE, { from: tokenHolder });

                assert.equal(logs.length, 2);

                assert.equal(logs[0].event, 'Checked');
                assert.equal(logs[0].args.sender, tokenHolder);

                assert.equal(logs[1].event, 'Sent');
                assert.equal(logs[1].args.operator, tokenHolder);
                assert.equal(logs[1].args.from, tokenHolder);
                assert.equal(logs[1].args.to, to);
                assert(logs[1].args.amount.eq(amount));
                assert.equal(logs[1].args.data, VALID_CERTIFICATE);
                assert.equal(logs[1].args.operatorData, ZERO_BYTE);
              });
            });
            describe('when the recipient is not a regular address', function () {
              it('reverts', async function () {
                await shouldFail.reverting(this.token.sendTo(this.token.address, amount, VALID_CERTIFICATE, { from: tokenHolder }));
              });
            });
          });
          describe('when the sender does not have enough balance', function () {
            const amount = initialSupply + 1;

            it('reverts', async function () {
              await shouldFail.reverting(this.token.sendTo(to, amount, VALID_CERTIFICATE, { from: tokenHolder }));
            });
          });
        });

        describe('when the recipient is the zero address', function () {
          const amount = initialSupply;
          const to = ZERO_ADDRESS;

          it('reverts', async function () {
            await shouldFail.reverting(this.token.sendTo(to, amount, VALID_CERTIFICATE, { from: tokenHolder }));
          });
        });
      });
      describe('when the amount is not a multiple of the granularity', function () {
        it('reverts', async function () {
          this.token = await ERC777.new('ERC777Token', 'DAU', 2, [], CERTIFICATE_SIGNER);
          await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
          await shouldFail.reverting(this.token.sendTo(to, 3, VALID_CERTIFICATE, { from: tokenHolder }));
        });
      });
    });

    // OPERATORSENDTO

    describe('operatorSendTo', function () {
      const to = recipient;
      beforeEach(async function () {
        await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
      });
      describe('when the operator is approved', function () {
        beforeEach(async function () {
          await this.token.authorizeOperator(operator, { from: tokenHolder });
        });
        describe('when the amount is a multiple of the granularity', function () {
          describe('when the recipient is not the zero address', function () {
            describe('when the sender does not have enough balance', function () {
              const amount = initialSupply + 1;

              it('reverts', async function () {
                await shouldFail.reverting(this.token.operatorSendTo(tokenHolder, to, amount, '', VALID_CERTIFICATE, { from: operator }));
              });
            });

            describe('when the sender has enough balance + the sender is not specified', function () {
              const amount = initialSupply;

              it('transfers the requested amount from operator address', async function () {
                await this.token.sendTo(operator, amount, VALID_CERTIFICATE, { from: tokenHolder });

                await this.token.operatorSendTo(ZERO_ADDRESS, to, amount, '', VALID_CERTIFICATE, { from: operator });
                const senderBalance = await this.token.balanceOf(operator);
                assert.equal(senderBalance, initialSupply - amount);

                const recipientBalance = await this.token.balanceOf(to);
                assert.equal(recipientBalance, amount);
              });
            });

            describe('when the sender has enough balance', function () {
              const amount = initialSupply;

              it('transfers the requested amount', async function () {
                await this.token.operatorSendTo(tokenHolder, to, amount, '', VALID_CERTIFICATE, { from: operator });
                const senderBalance = await this.token.balanceOf(tokenHolder);
                assert.equal(senderBalance, initialSupply - amount);

                const recipientBalance = await this.token.balanceOf(to);
                assert.equal(recipientBalance, amount);
              });

              it('emits a sent event [with ERC20 retrocompatibility]', async function () {
                const { logs } = await this.token.operatorSendTo(tokenHolder, to, amount, '', VALID_CERTIFICATE, { from: operator });

                assert.equal(logs.length, 2);

                assert.equal(logs[0].event, 'Checked');
                assert.equal(logs[0].args.sender, operator);

                assert.equal(logs[1].event, 'Sent');
                assert.equal(logs[1].args.operator, operator);
                assert.equal(logs[1].args.from, tokenHolder);
                assert.equal(logs[1].args.to, to);
                assert(logs[1].args.amount.eq(amount));
                assert.equal(logs[1].args.data, ZERO_BYTE);
                assert.equal(logs[1].args.operatorData, VALID_CERTIFICATE);
              });
            });
          });

          describe('when the recipient is the zero address', function () {
            const amount = initialSupply;
            const to = ZERO_ADDRESS;

            it('reverts', async function () {
              await shouldFail.reverting(this.token.operatorSendTo(tokenHolder, to, amount, '', VALID_CERTIFICATE, { from: operator }));
            });
          });
        });
        describe('when the amount is not a multiple of the granularity', function () {
          it('reverts', async function () {
            this.token = await ERC777.new('ERC777Token', 'DAU', 2, [], CERTIFICATE_SIGNER);
            await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
            await shouldFail.reverting(this.token.operatorSendTo(tokenHolder, to, 3, '', VALID_CERTIFICATE, { from: operator }));
          });
        });
      });
      describe('when the operator is not approved', function () {
        it('reverts', async function () {
          const amount = initialSupply;
          await shouldFail.reverting(this.token.operatorSendTo(tokenHolder, to, amount, '', VALID_CERTIFICATE, { from: operator }));
        });
      });
    });

    // BURN

    describe('burn', function () {
      beforeEach(async function () {
        await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
      });

      describe('when the amount is a multiple of the granularity', function () {
        describe('when the burner has enough balance', function () {
          const amount = initialSupply;

          it('burns the requested amount', async function () {
            await this.token.burn(amount, VALID_CERTIFICATE, { from: tokenHolder });
            const senderBalance = await this.token.balanceOf(tokenHolder);
            assert.equal(senderBalance, initialSupply - amount);
          });

          it('emits a burned event [with ERC20 retrocompatibility]', async function () {
            const { logs } = await this.token.burn(amount, VALID_CERTIFICATE, { from: tokenHolder });

            assert.equal(logs.length, 2);

            assert.equal(logs[0].event, 'Checked');
            assert.equal(logs[0].args.sender, tokenHolder);

            assert.equal(logs[1].event, 'Burned');
            assert.equal(logs[1].args.operator, tokenHolder);
            assert.equal(logs[1].args.from, tokenHolder);
            assert(logs[1].args.amount.eq(amount));
            assert.equal(logs[1].args.data, VALID_CERTIFICATE);
            assert.equal(logs[1].args.operatorData, ZERO_BYTE);
          });
        });
        describe('when the burner does not have enough balance', function () {
          const amount = initialSupply + 1;

          it('reverts', async function () {
            await shouldFail.reverting(this.token.burn(amount, VALID_CERTIFICATE, { from: tokenHolder }));
          });
        });
      });
      describe('when the amount is not a multiple of the granularity', function () {
        it('reverts', async function () {
          this.token = await ERC777.new('ERC777Token', 'DAU', 2, [], CERTIFICATE_SIGNER);
          await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
          await shouldFail.reverting(this.token.burn(3, VALID_CERTIFICATE, { from: tokenHolder }));
        });
      });
    });

    // OPERATORBURN

    describe('operatorBurn', function () {
      beforeEach(async function () {
        await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
      });

      beforeEach(async function () {
        await this.token.authorizeOperator(operator, { from: tokenHolder });
      });
      describe('when the amount is a multiple of the granularity', function () {
        describe('when the burner is not the zero address', function () {
          describe('when the burner does not have enough balance', function () {
            const amount = initialSupply + 1;

            it('reverts', async function () {
              await shouldFail.reverting(this.token.operatorBurn(tokenHolder, amount, '', VALID_CERTIFICATE, { from: operator }));
            });
          });

          describe('when the burner has enough balance + the burner is not specified', function () {
            const amount = initialSupply;

            it('burns the requested amount from operator address', async function () {
              await this.token.sendTo(operator, amount, VALID_CERTIFICATE, { from: tokenHolder });

              await this.token.operatorBurn(ZERO_ADDRESS, amount, '', VALID_CERTIFICATE, { from: operator });
              const senderBalance = await this.token.balanceOf(operator);
              assert.equal(senderBalance, initialSupply - amount);
            });
          });

          describe('when the burner has enough balance', function () {
            const amount = initialSupply;

            it('burns the requested amount', async function () {
              await this.token.operatorBurn(tokenHolder, amount, '', VALID_CERTIFICATE, { from: operator });
              const senderBalance = await this.token.balanceOf(tokenHolder);
              assert.equal(senderBalance, initialSupply - amount);
            });

            it('emits a burned event [with ERC20 retrocompatibility]', async function () {
              const { logs } = await this.token.operatorBurn(tokenHolder, amount, '', VALID_CERTIFICATE, { from: operator });

              assert.equal(logs.length, 2);

              assert.equal(logs[0].event, 'Checked');
              assert.equal(logs[0].args.sender, operator);

              assert.equal(logs[1].event, 'Burned');
              assert.equal(logs[1].args.operator, operator);
              assert.equal(logs[1].args.from, tokenHolder);
              assert(logs[1].args.amount.eq(amount));
              assert.equal(logs[1].args.data, ZERO_BYTE);
              assert.equal(logs[1].args.operatorData, VALID_CERTIFICATE);
            });
          });
        });

        describe('when the burner is the zero address', function () {
          it('reverts', async function () {
            const amount = initialSupply;
            await shouldFail.reverting(this.token.operatorBurnMock(ZERO_ADDRESS, amount, '', '', { from: operator }));
          });
        });
      });
      describe('when the amount is not a multiple of the granularity', function () {
        it('reverts', async function () {
          this.token = await ERC777.new('ERC777Token', 'DAU', 2, [], CERTIFICATE_SIGNER);
          await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
          await shouldFail.reverting(this.token.operatorBurn(tokenHolder, 3, '', VALID_CERTIFICATE, { from: operator }));
        });
      });
    });
  });
});

contract('ERC777 with hooks', function ([owner, operator, defaultOperator, tokenHolder, recipient, unknown]) {
  // HOOKS

  describe('hooks', function () {
    const amount = initialSupply;
    const to = recipient;

    beforeEach(async function () {
      this.token = await ERC777.new('ERC777Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      this.registry = await ERC820Registry.at('0x820b586C8C28125366C998641B09DCbE7d4cBF06');

      this.senderContract = await ERC777TokensSender.new('ERC777TokensSender', { from: tokenHolder });
      await this.registry.setManager(tokenHolder, this.senderContract.address, { from: tokenHolder });
      await this.senderContract.setERC820Implementer({ from: tokenHolder });

      this.recipientContract = await ERC777TokensRecipient.new('ERC777TokensRecipient', { from: recipient });
      await this.registry.setManager(recipient, this.recipientContract.address, { from: recipient });
      await this.recipientContract.setERC820Implementer({ from: recipient });

      await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
    });
    describe('when the transfer is successfull', function () {
      it('transfers the requested amount', async function () {
        await this.token.sendTo(to, amount, VALID_CERTIFICATE, { from: tokenHolder });
        const senderBalance = await this.token.balanceOf(tokenHolder);
        assert.equal(senderBalance, initialSupply - amount);

        const recipientBalance = await this.token.balanceOf(to);
        assert.equal(recipientBalance, amount);
      });
    });
    describe('when the transfer fails', function () {
      it('sender hook reverts', async function () {
        // Default sender hook failure data for the mock only: 0x1100000000000000000000000000000000000000000000000000000000000000
        await shouldFail.reverting(this.token.sendTo(to, amount, INVALID_CERTIFICATE_SENDER, { from: tokenHolder }));
      });
      it('recipient hook reverts', async function () {
        // Default recipient hook failure data for the mock only: 0x2200000000000000000000000000000000000000000000000000000000000000
        await shouldFail.reverting(this.token.sendTo(to, amount, INVALID_CERTIFICATE_RECIPIENT, { from: tokenHolder }));
      });
    });
  });
});

contract('ERC777ERC20', function ([owner, operator, defaultOperator, tokenHolder, recipient, unknown]) {
  // ERC20 RETROCOMPATIBILITY

  describe('ERC20 retrocompatibility', function () {
    beforeEach(async function () {
      this.token = await ERC777ERC20.new('ERC777ERC20Token', 'DAU20', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });

    // MINT

    describe('mint', function () {
      describe('when the caller is a minter', function () {
        describe('when the amount is a multiple of the granularity', function () {
          describe('when the recipient is not the zero address', function () {
            it('mints the requested amount', async function () {
              await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
            });
            it('emits a sent event [with ERC20 retrocompatibility]', async function () {
              const { logs } = await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });

              assert.equal(logs.length, 3);

              assert.equal(logs[0].event, 'Checked');
              assert.equal(logs[0].args.sender, owner);

              assert.equal(logs[1].event, 'Minted');
              assert.equal(logs[1].args.operator, owner);
              assert.equal(logs[1].args.to, tokenHolder);
              assert(logs[1].args.amount.eq(initialSupply));
              assert.equal(logs[1].args.data, VALID_CERTIFICATE);
              assert.equal(logs[1].args.operatorData, ZERO_BYTE);

              assert.equal(logs[2].event, 'Transfer');
              assert.equal(logs[2].args.from, ZERO_ADDRESS);
              assert.equal(logs[2].args.to, tokenHolder);
              assert(logs[2].args.value.eq(initialSupply));
            });
            it('emits a sent event [without ERC20 retrocompatibility]', async function () {
              await this.token.setERC20compatibility(false, { from: owner });
              const { logs } = await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });

              assert.equal(logs.length, 2);

              assert.equal(logs[0].event, 'Checked');
              assert.equal(logs[0].args.sender, owner);

              assert.equal(logs[1].event, 'Minted');
              assert.equal(logs[1].args.operator, owner);
              assert.equal(logs[1].args.to, tokenHolder);
              assert(logs[1].args.amount.eq(initialSupply));
              assert.equal(logs[1].args.data, VALID_CERTIFICATE);
              assert.equal(logs[1].args.operatorData, ZERO_BYTE);
            });
          });
        });
      });
    });

    // SENDTO

    describe('sendTo', function () {
      const to = recipient;
      beforeEach(async function () {
        await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
      });
      describe('when the amount is a multiple of the granularity', function () {
        describe('when the recipient is not the zero address', function () {
          describe('when the sender has enough balance', function () {
            const amount = initialSupply;
            describe('when the recipient is a regular address', function () {
              it('transfers the requested amount', async function () {
                await this.token.sendTo(to, amount, VALID_CERTIFICATE, { from: tokenHolder });
                const senderBalance = await this.token.balanceOf(tokenHolder);
                assert.equal(senderBalance, initialSupply - amount);

                const recipientBalance = await this.token.balanceOf(to);
                assert.equal(recipientBalance, amount);
              });

              it('emits a sent event [with ERC20 retrocompatibility]', async function () {
                const { logs } = await this.token.sendTo(to, amount, VALID_CERTIFICATE, { from: tokenHolder });

                assert.equal(logs.length, 3);

                assert.equal(logs[0].event, 'Checked');
                assert.equal(logs[0].args.sender, tokenHolder);

                assert.equal(logs[1].event, 'Sent');
                assert.equal(logs[1].args.operator, tokenHolder);
                assert.equal(logs[1].args.from, tokenHolder);
                assert.equal(logs[1].args.to, to);
                assert(logs[1].args.amount.eq(amount));
                assert.equal(logs[1].args.data, VALID_CERTIFICATE);
                assert.equal(logs[1].args.operatorData, ZERO_BYTE);

                assert.equal(logs[2].event, 'Transfer');
                assert.equal(logs[2].args.from, tokenHolder);
                assert.equal(logs[2].args.to, to);
                assert(logs[2].args.value.eq(amount));
              });

              it('emits a sent event [without ERC20 retrocompatibility]', async function () {
                await this.token.setERC20compatibility(false, { from: owner });
                const { logs } = await this.token.sendTo(to, amount, VALID_CERTIFICATE, { from: tokenHolder });

                assert.equal(logs.length, 2);

                assert.equal(logs[0].event, 'Checked');
                assert.equal(logs[0].args.sender, tokenHolder);

                assert.equal(logs[1].event, 'Sent');
                assert.equal(logs[1].args.operator, tokenHolder);
                assert.equal(logs[1].args.from, tokenHolder);
                assert.equal(logs[1].args.to, to);
                assert(logs[1].args.amount.eq(amount));
                assert.equal(logs[1].args.data, VALID_CERTIFICATE);
                assert.equal(logs[1].args.operatorData, ZERO_BYTE);
              });
            });
          });
        });
      });
    });

    // BURN

    describe('burn', function () {
      beforeEach(async function () {
        await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
      });

      describe('when the amount is a multiple of the granularity', function () {
        describe('when the burner has enough balance', function () {
          const amount = initialSupply;

          it('burns the requested amount', async function () {
            await this.token.burn(amount, VALID_CERTIFICATE, { from: tokenHolder });
            const senderBalance = await this.token.balanceOf(tokenHolder);
            assert.equal(senderBalance, initialSupply - amount);
          });

          it('emits a burned event [with ERC20 retrocompatibility]', async function () {
            const { logs } = await this.token.burn(amount, VALID_CERTIFICATE, { from: tokenHolder });

            assert.equal(logs.length, 3);

            assert.equal(logs[0].event, 'Checked');
            assert.equal(logs[0].args.sender, tokenHolder);

            assert.equal(logs[1].event, 'Burned');
            assert.equal(logs[1].args.operator, tokenHolder);
            assert.equal(logs[1].args.from, tokenHolder);
            assert(logs[1].args.amount.eq(amount));
            assert.equal(logs[1].args.data, VALID_CERTIFICATE);
            assert.equal(logs[1].args.operatorData, ZERO_BYTE);

            assert.equal(logs[2].event, 'Transfer');
            assert.equal(logs[2].args.from, tokenHolder);
            assert.equal(logs[2].args.to, ZERO_ADDRESS);
            assert(logs[2].args.value.eq(amount));
          });
          it('emits a burned event [without ERC20 retrocompatibility]', async function () {
            await this.token.setERC20compatibility(false, { from: owner });
            const { logs } = await this.token.burn(amount, VALID_CERTIFICATE, { from: tokenHolder });

            assert.equal(logs.length, 2);

            assert.equal(logs[0].event, 'Checked');
            assert.equal(logs[0].args.sender, tokenHolder);

            assert.equal(logs[1].event, 'Burned');
            assert.equal(logs[1].args.operator, tokenHolder);
            assert.equal(logs[1].args.from, tokenHolder);
            assert(logs[1].args.amount.eq(amount));
            assert.equal(logs[1].args.data, VALID_CERTIFICATE);
            assert.equal(logs[1].args.operatorData, ZERO_BYTE);
          });
        });
      });
    });

    // DECIMALS

    describe('decimals', function () {
      describe('when the ERC20 retrocompatibility is activated', function () {
        it('returns the decimals the token', async function () {
          const decimals = await this.token.decimals();

          assert.equal(decimals, 18);
        });
      });
      describe('when the ERC20 retrocompatibility is not activated', function () {
        it('reverts', async function () {
          await this.token.setERC20compatibility(false, { from: owner });
          await shouldFail.reverting(this.token.decimals());
        });
      });
    });

    // APPROVE

    describe('approve', function () {
      const amount = 100;
      describe('when the ERC20 retrocompatibility is activated', function () {
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
            assert(logs[0].args.value.eq(amount));
          });
        });
        describe('when the operator to approve is the zero address', function () {
          it('reverts', async function () {
            await shouldFail.reverting(this.token.approve(ZERO_ADDRESS, amount, { from: tokenHolder }));
          });
        });
      });
      describe('when the ERC20 retrocompatibility is not activated', function () {
        it('reverts', async function () {
          await this.token.setERC20compatibility(false, { from: owner });
          await shouldFail.reverting(this.token.approve(operator, amount, { from: tokenHolder }));
        });
        it('reverts', async function () {
          await this.token.setERC20compatibility(false, { from: owner });
          await shouldFail.reverting(this.token.allowance(tokenHolder, operator), amount);
        });
      });
    });

    // TRANSFER

    describe('transfer', function () {
      const to = recipient;
      beforeEach(async function () {
        await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
      });

      describe('when the ERC20 retrocompatibility is activated', function () {
        describe('when the amount is a multiple of the granularity', function () {
          describe('when the recipient is not the zero address', function () {
            describe('when the sender does not have enough balance', function () {
              const amount = initialSupply + 1;

              it('reverts', async function () {
                await shouldFail.reverting(this.token.transfer(to, amount, { from: tokenHolder }));
              });
            });

            describe('when the sender has enough balance', function () {
              const amount = initialSupply;

              it('transfers the requested amount', async function () {
                await this.token.transfer(to, amount, { from: tokenHolder });
                const senderBalance = await this.token.balanceOf(tokenHolder);
                assert.equal(senderBalance, initialSupply - amount);

                const recipientBalance = await this.token.balanceOf(to);
                assert.equal(recipientBalance, amount);
              });

              it('emits a sent + a transfer event', async function () {
                const { logs } = await this.token.transfer(to, amount, { from: tokenHolder });

                assert.equal(logs.length, 2);
                assert.equal(logs[0].event, 'Sent');
                assert.equal(logs[0].args.operator, tokenHolder);
                assert.equal(logs[0].args.from, tokenHolder);
                assert.equal(logs[0].args.to, to);
                assert(logs[0].args.amount.eq(amount));
                assert.equal(logs[0].args.data, ZERO_BYTE);
                assert.equal(logs[0].args.operatorData, ZERO_BYTE);

                assert.equal(logs[1].event, 'Transfer');
                assert.equal(logs[1].args.from, tokenHolder);
                assert.equal(logs[1].args.to, to);
                assert(logs[1].args.value.eq(amount));
              });
            });
          });

          describe('when the recipient is the zero address', function () {
            const amount = initialSupply;
            const to = ZERO_ADDRESS;

            it('reverts', async function () {
              await shouldFail.reverting(this.token.transfer(to, amount, { from: tokenHolder }));
            });
          });
        });
        describe('when the amount is not a multiple of the granularity', function () {
          it('reverts', async function () {
            this.token = await ERC777ERC20.new('ERC777Token', 'DAU', 2, [], CERTIFICATE_SIGNER);
            await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
            await shouldFail.reverting(this.token.transfer(to, 3, { from: tokenHolder }));
          });
        });
      });
      describe('when the ERC20 retrocompatibility is not activated', function () {
        const amount = initialSupply;

        it('reverts', async function () {
          await this.token.setERC20compatibility(false, { from: owner });
          await shouldFail.reverting(this.token.transfer(to, amount, { from: tokenHolder }));
        });
      });
    });

    // TRANSFERFROM

    describe('transferFrom', function () {
      const to = recipient;
      const approvedAmount = 10000;
      beforeEach(async function () {
        await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
      });

      describe('when the ERC20 retrocompatibility is activated', function () {
        describe('when the operator is approved', function () {
          beforeEach(async function () {
            // await this.token.authorizeOperator(operator, { from: tokenHolder});
            await this.token.approve(operator, approvedAmount, { from: tokenHolder });
          });
          describe('when the amount is a multiple of the granularity', function () {
            describe('when the recipient is not the zero address', function () {
              describe('when the sender does not have enough balance', function () {
                const amount = approvedAmount + 1;

                it('reverts', async function () {
                  await shouldFail.reverting(this.token.transferFrom(tokenHolder, to, amount, { from: operator }));
                });
              });

              describe('when the sender has enough balance + the sender is not specified', function () {
                const amount = 500;

                it('transfers the requested amount from operator address', async function () {
                  await this.token.transfer(operator, approvedAmount, { from: tokenHolder });

                  await this.token.transferFrom(ZERO_ADDRESS, to, amount, { from: operator });
                  const senderBalance = await this.token.balanceOf(operator);
                  assert.equal(senderBalance, approvedAmount - amount);

                  const recipientBalance = await this.token.balanceOf(to);
                  assert.equal(recipientBalance, amount);
                });
              });

              describe('when the sender has enough balance', function () {
                const amount = 500;

                it('transfers the requested amount', async function () {
                  await this.token.transferFrom(tokenHolder, to, amount, { from: operator });
                  const senderBalance = await this.token.balanceOf(tokenHolder);
                  assert.equal(senderBalance, initialSupply - amount);

                  const recipientBalance = await this.token.balanceOf(to);
                  assert.equal(recipientBalance, amount);

                  assert.equal(await this.token.allowance(tokenHolder, operator), approvedAmount - amount);
                });

                it('emits a sent + a transfer event', async function () {
                  const { logs } = await this.token.transferFrom(tokenHolder, to, amount, { from: operator });
                  // await this.token.transferFrom(tokenHolder, to, amount, { from: operator });

                  assert.equal(logs.length, 2);
                  assert.equal(logs[0].event, 'Sent');
                  assert.equal(logs[0].args.operator, operator);
                  assert.equal(logs[0].args.from, tokenHolder);
                  assert.equal(logs[0].args.to, to);
                  assert(logs[0].args.amount.eq(amount));
                  assert.equal(logs[0].args.data, ZERO_BYTE);
                  assert.equal(logs[0].args.operatorData, ZERO_BYTE);

                  assert.equal(logs[1].event, 'Transfer');
                  assert.equal(logs[1].args.from, tokenHolder);
                  assert.equal(logs[1].args.to, to);
                  assert(logs[1].args.value.eq(amount));

                  assert(true);
                });
              });
            });

            describe('when the recipient is the zero address', function () {
              const amount = initialSupply;
              const to = ZERO_ADDRESS;

              it('reverts', async function () {
                await shouldFail.reverting(this.token.transferFrom(tokenHolder, to, amount, { from: operator }));
              });
            });
          });
          describe('when the amount is not a multiple of the granularity', function () {
            it('reverts', async function () {
              this.token = await ERC777ERC20.new('ERC777Token', 'DAU', 2, [], CERTIFICATE_SIGNER);
              await this.token.mint(tokenHolder, initialSupply, VALID_CERTIFICATE, { from: owner });
              await shouldFail.reverting(this.token.transferFrom(tokenHolder, to, 3, { from: operator }));
            });
          });
        });
        describe('when the operator is not approved', function () {
          const amount = approvedAmount;
          describe('when the operator is not approved but authorized', function () {
            it('transfers the requested amount', async function () {
              await this.token.authorizeOperator(operator, { from: tokenHolder });
              assert.equal(await this.token.allowance(tokenHolder, operator), 0);

              await this.token.transferFrom(tokenHolder, to, amount, { from: operator });
              const senderBalance = await this.token.balanceOf(tokenHolder);
              assert.equal(senderBalance, initialSupply - amount);

              const recipientBalance = await this.token.balanceOf(to);
              assert.equal(recipientBalance, amount);
            });
          });
          describe('when the operator is not approved and not authorized', function () {
            it('reverts', async function () {
              await shouldFail.reverting(this.token.transferFrom(tokenHolder, to, amount, { from: operator }));
            });
          });
        });
      });
      describe('when the ERC20 retrocompatibility is not activated', function () {
        const amount = approvedAmount;
        it('reverts', async function () {
          await this.token.setERC20compatibility(false, { from: owner });
          await shouldFail.reverting(this.token.transferFrom(tokenHolder, to, amount, { from: operator }));
        });
      });
    });
  });
});
