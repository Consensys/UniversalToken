import shouldFail from 'openzeppelin-solidity/test/helpers/shouldFail.js';

const ERC777 = artifacts.require('ERC777');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTE = '0x';

const initialSupply = 1000000000;

contract('ERC777', function ([owner, operator, defaultOperator, investor, recipient, unknown]) {
  describe('ERC777 functionalities', function () {
    beforeEach(async function () {
      this.token = await ERC777.new('ERC777Token', 'DAU', 1, [defaultOperator]);
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
        await this.token.mint(investor, initialSupply, '', { from: owner });
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
          await this.token.mint(investor, initialSupply, '', { from: owner });
          const balance = await this.token.balanceOf(investor);

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
      it('returns the list of defaultOperators', async function () {
        const defaultOperators = await this.token.defaultOperators();

        assert.equal(defaultOperators.length, 1);
        assert.equal(defaultOperators[0], defaultOperator);
      });
    });

    describe('authorizeOperator', function () {
      describe('when sender authorizes an operator', function () {
        it('authorizes the operator', async function () {
          assert(!(await this.token.isOperatorFor(operator, investor)));
          assert(await this.token.isOperatorFor(defaultOperator, investor));

          await this.token.authorizeOperator(operator, { from: investor });

          assert(await this.token.isOperatorFor(operator, investor));
          assert(await this.token.isOperatorFor(defaultOperator, investor));
        });
      });
      // describe('when sender authorizes himself', function () {
      //   it('reverts', async function () {
      //     await shouldFail.reverting(this.token.authorizeOperator(investor, { from: investor }));
      //   });
      // });
    });

    describe('revokeOperator', function () {
      describe('when sender revokes an operator', function () {
        it('revokes the operator', async function () {
          assert(!(await this.token.isOperatorFor(operator, investor)));
          assert(await this.token.isOperatorFor(defaultOperator, investor));

          await this.token.authorizeOperator(operator, { from: investor });

          assert(await this.token.isOperatorFor(operator, investor));
          assert(await this.token.isOperatorFor(defaultOperator, investor));

          await this.token.revokeOperator(operator, { from: investor });

          assert(!(await this.token.isOperatorFor(operator, investor)));
          assert(await this.token.isOperatorFor(defaultOperator, investor));

          await this.token.revokeOperator(defaultOperator, { from: investor });

          assert(!(await this.token.isOperatorFor(operator, investor)));
          assert(!(await this.token.isOperatorFor(defaultOperator, investor)));
        });
      });
      // describe('when sender revokes himself', function () {
      //   it('reverts', async function () {
      //     await shouldFail.reverting(this.token.revokeOperator(investor, { from: investor }));
      //   });
      // });
    });

    describe('mint', function () {
      describe('when the caller is a minter', function () {
        describe('when the amount is a multiple of the granularity', function () {
          describe('when the recipient is not the zero address', function () {
            it('mints the requested amount', async function () {
              await this.token.mint(investor, initialSupply, '', { from: owner });
            });
            it('emits a sent event [with ERC20 retrocompatibility]', async function () {
              const { logs } = await this.token.mint(investor, initialSupply, '', { from: owner });

              assert.equal(logs.length, 2);
              assert.equal(logs[0].event, 'Minted');
              assert.equal(logs[0].args.operator, owner);
              assert.equal(logs[0].args.to, investor);
              assert(logs[0].args.amount.eq(initialSupply));
              assert.equal(logs[0].args.data, ZERO_BYTE);
              assert.equal(logs[0].args.operatorData, ZERO_BYTE);

              assert.equal(logs[1].event, 'Transfer');
              assert.equal(logs[1].args.from, ZERO_ADDRESS);
              assert.equal(logs[1].args.to, investor);
              assert(logs[1].args.value.eq(initialSupply));
            });
            it('emits a sent event [without ERC20 retrocompatibility]', async function () {
              await this.token.setERC20compatibility(false, { from: owner });
              const { logs } = await this.token.mint(investor, initialSupply, '', { from: owner });

              assert.equal(logs.length, 1);
              assert.equal(logs[0].event, 'Minted');
              assert.equal(logs[0].args.operator, owner);
              assert.equal(logs[0].args.to, investor);
              assert(logs[0].args.amount.eq(initialSupply));
              assert.equal(logs[0].args.data, ZERO_BYTE);
              assert.equal(logs[0].args.operatorData, ZERO_BYTE);
            });
          });
          describe('when the recipient is the zero address', function () {
            it('reverts', async function () {
              await shouldFail.reverting(this.token.mint(ZERO_ADDRESS, initialSupply, '', { from: owner }));
            });
          });
        });
        describe('when the amount is not a multiple of the granularity', function () {
          it('reverts', async function () {
            this.token = await ERC777.new('ERC777Token', 'DAU', 2, []);
            await shouldFail.reverting(this.token.mint(investor, 3, '', { from: owner }));
          });
        });
      });
      describe('when the caller is not a minter', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.mint(investor, initialSupply, '', { from: unknown }));
        });
      });
    });

    describe('sendTo', function () {
      const to = recipient;
      beforeEach(async function () {
        await this.token.mint(investor, initialSupply, '', { from: owner });
      });
      describe('when the amount is a multiple of the granularity', function () {
        describe('when the recipient is not the zero address', function () {
          describe('when the sender does not have enough balance', function () {
            const amount = initialSupply + 1;

            it('reverts', async function () {
              await shouldFail.reverting(this.token.sendTo(to, amount, '', { from: investor }));
            });
          });

          describe('when the sender has enough balance', function () {
            const amount = initialSupply;

            it('transfers the requested amount', async function () {
              await this.token.sendTo(to, amount, '', { from: investor });
              const senderBalance = await this.token.balanceOf(investor);
              assert.equal(senderBalance, initialSupply - amount);

              const recipientBalance = await this.token.balanceOf(to);
              assert.equal(recipientBalance, amount);
            });

            it('emits a sent event [with ERC20 retrocompatibility]', async function () {
              const { logs } = await this.token.sendTo(to, amount, '', { from: investor });

              assert.equal(logs.length, 2);
              assert.equal(logs[0].event, 'Sent');
              assert.equal(logs[0].args.operator, investor);
              assert.equal(logs[0].args.from, investor);
              assert.equal(logs[0].args.to, to);
              assert(logs[0].args.amount.eq(amount));
              assert.equal(logs[0].args.data, ZERO_BYTE);
              assert.equal(logs[0].args.operatorData, ZERO_BYTE);

              assert.equal(logs[1].event, 'Transfer');
              assert.equal(logs[1].args.from, investor);
              assert.equal(logs[1].args.to, to);
              assert(logs[1].args.value.eq(amount));
            });

            it('emits a sent event [without ERC20 retrocompatibility]', async function () {
              await this.token.setERC20compatibility(false, { from: owner });
              const { logs } = await this.token.sendTo(to, amount, '', { from: investor });

              assert.equal(logs.length, 1);
              assert.equal(logs[0].event, 'Sent');
              assert.equal(logs[0].args.operator, investor);
              assert.equal(logs[0].args.from, investor);
              assert.equal(logs[0].args.to, to);
              assert(logs[0].args.amount.eq(amount));
              assert.equal(logs[0].args.data, ZERO_BYTE);
              assert.equal(logs[0].args.operatorData, ZERO_BYTE);
            });
          });
        });

        describe('when the recipient is the zero address', function () {
          const amount = initialSupply;
          const to = ZERO_ADDRESS;

          it('reverts', async function () {
            await shouldFail.reverting(this.token.sendTo(to, amount, '', { from: investor }));
          });
        });
      });
      describe('when the amount is not a multiple of the granularity', function () {
        it('reverts', async function () {
          this.token = await ERC777.new('ERC777Token', 'DAU', 2, []);
          await this.token.mint(investor, initialSupply, '', { from: owner });
          await shouldFail.reverting(this.token.sendTo(to, 3, '', { from: investor }));
        });
      });
    });

    describe('operatorSendTo', function () {
      const to = recipient;
      beforeEach(async function () {
        await this.token.mint(investor, initialSupply, '', { from: owner });
      });
      describe('when the operator is approved', function () {
        beforeEach(async function () {
          await this.token.authorizeOperator(operator, { from: investor });
        });
        describe('when the amount is a multiple of the granularity', function () {
          describe('when the recipient is not the zero address', function () {
            describe('when the sender does not have enough balance', function () {
              const amount = initialSupply + 1;

              it('reverts', async function () {
                await shouldFail.reverting(this.token.operatorSendTo(investor, to, amount, '', '', { from: operator }));
              });
            });

            describe('when the sender has enough balance + the sender is not specified', function () {
              const amount = initialSupply;

              it('transfers the requested amount from operator address', async function () {
                await this.token.sendTo(operator, amount, '', { from: investor });

                await this.token.operatorSendTo(ZERO_ADDRESS, to, amount, '', '', { from: operator });
                const senderBalance = await this.token.balanceOf(operator);
                assert.equal(senderBalance, initialSupply - amount);

                const recipientBalance = await this.token.balanceOf(to);
                assert.equal(recipientBalance, amount);
              });
            });

            describe('when the sender has enough balance', function () {
              const amount = initialSupply;

              it('transfers the requested amount', async function () {
                await this.token.operatorSendTo(investor, to, amount, '', '', { from: operator });
                const senderBalance = await this.token.balanceOf(investor);
                assert.equal(senderBalance, initialSupply - amount);

                const recipientBalance = await this.token.balanceOf(to);
                assert.equal(recipientBalance, amount);
              });

              it('emits a sent event [with ERC20 retrocompatibility]', async function () {
                const { logs } = await this.token.operatorSendTo(investor, to, amount, '', '', { from: operator });

                assert.equal(logs.length, 2);
                assert.equal(logs[0].event, 'Sent');
                assert.equal(logs[0].args.operator, operator);
                assert.equal(logs[0].args.from, investor);
                assert.equal(logs[0].args.to, to);
                assert(logs[0].args.amount.eq(amount));
                assert.equal(logs[0].args.data, ZERO_BYTE);
                assert.equal(logs[0].args.operatorData, ZERO_BYTE);

                assert.equal(logs[1].event, 'Transfer');
                assert.equal(logs[1].args.from, investor);
                assert.equal(logs[1].args.to, to);
                assert(logs[1].args.value.eq(amount));
              });
              it('emits a sent event [without ERC20 retrocompatibility]', async function () {
                await this.token.setERC20compatibility(false, { from: owner });
                const { logs } = await this.token.operatorSendTo(investor, to, amount, '', '', { from: operator });

                assert.equal(logs.length, 1);
                assert.equal(logs[0].event, 'Sent');
                assert.equal(logs[0].args.operator, operator);
                assert.equal(logs[0].args.from, investor);
                assert.equal(logs[0].args.to, to);
                assert(logs[0].args.amount.eq(amount));
                assert.equal(logs[0].args.data, ZERO_BYTE);
                assert.equal(logs[0].args.operatorData, ZERO_BYTE);
              });
            });
          });

          describe('when the recipient is the zero address', function () {
            const amount = initialSupply;
            const to = ZERO_ADDRESS;

            it('reverts', async function () {
              await shouldFail.reverting(this.token.operatorSendTo(investor, to, amount, '', '', { from: operator }));
            });
          });
        });
        describe('when the amount is not a multiple of the granularity', function () {
          it('reverts', async function () {
            this.token = await ERC777.new('ERC777Token', 'DAU', 2, []);
            await this.token.mint(investor, initialSupply, '', { from: owner });
            await shouldFail.reverting(this.token.operatorSendTo(investor, to, 3, '', '', { from: operator }));
          });
        });
      });
      describe('when the operator is not approved', function () {
        it('reverts', async function () {
          const amount = initialSupply;
          await shouldFail.reverting(this.token.operatorSendTo(investor, to, amount, '', '', { from: operator }));
        });
      });
    });

    describe('burn', function () {
      const to = recipient;
      beforeEach(async function () {
        await this.token.mint(investor, initialSupply, '', { from: owner });
      });

      describe('when the amount is a multiple of the granularity', function () {
        describe('when the burner does not have enough balance', function () {
          const amount = initialSupply + 1;

          it('reverts', async function () {
            await shouldFail.reverting(this.token.burn(amount, '', { from: investor }));
          });
        });

        describe('when the burner has enough balance', function () {
          const amount = initialSupply;

          it('burns the requested amount', async function () {
            await this.token.burn(amount, '', { from: investor });
            const senderBalance = await this.token.balanceOf(investor);
            assert.equal(senderBalance, initialSupply - amount);
          });

          it('emits a burned event [with ERC20 retrocompatibility]', async function () {
            const { logs } = await this.token.burn(amount, '', { from: investor });

            assert.equal(logs.length, 2);
            assert.equal(logs[0].event, 'Burned');
            assert.equal(logs[0].args.operator, investor);
            assert.equal(logs[0].args.from, investor);
            assert(logs[0].args.amount.eq(amount));
            assert.equal(logs[0].args.operatorData, ZERO_BYTE);

            assert.equal(logs[1].event, 'Transfer');
            assert.equal(logs[1].args.from, investor);
            assert.equal(logs[1].args.to, ZERO_ADDRESS);
            assert(logs[1].args.value.eq(amount));
          });
          it('emits a burned event [without ERC20 retrocompatibility]', async function () {
            await this.token.setERC20compatibility(false, { from: owner });
            const { logs } = await this.token.burn(amount, '', { from: investor });

            assert.equal(logs.length, 1);
            assert.equal(logs[0].event, 'Burned');
            assert.equal(logs[0].args.operator, investor);
            assert.equal(logs[0].args.from, investor);
            assert(logs[0].args.amount.eq(amount));
            assert.equal(logs[0].args.operatorData, ZERO_BYTE);
          });
        });
      });
      describe('when the amount is not a multiple of the granularity', function () {
        it('reverts', async function () {
          this.token = await ERC777.new('ERC777Token', 'DAU', 2, []);
          await this.token.mint(investor, initialSupply, '', { from: owner });
          await shouldFail.reverting(this.token.burn(3, '', { from: investor }));
        });
      });
    });

    describe('operatorBurn', function () {
      const to = recipient;
      beforeEach(async function () {
        await this.token.mint(investor, initialSupply, '', { from: owner });
      });

      beforeEach(async function () {
        await this.token.authorizeOperator(operator, { from: investor });
      });
      describe('when the amount is a multiple of the granularity', function () {
        describe('when the burner is not the zero address', function () {
          describe('when the burner does not have enough balance', function () {
            const amount = initialSupply + 1;

            it('reverts', async function () {
              await shouldFail.reverting(this.token.operatorBurn(investor, amount, '', { from: operator }));
            });
          });

          describe('when the burner has enough balance + the burner is not specified', function () {
            const amount = initialSupply;

            it('burns the requested amount from operator address', async function () {
              await this.token.sendTo(operator, amount, '', { from: investor });

              await this.token.operatorBurn(ZERO_ADDRESS, amount, '', { from: operator });
              const senderBalance = await this.token.balanceOf(operator);
              assert.equal(senderBalance, initialSupply - amount);
            });
          });

          describe('when the burner has enough balance', function () {
            const amount = initialSupply;

            it('burns the requested amount', async function () {
              await this.token.operatorBurn(investor, amount, '', { from: operator });
              const senderBalance = await this.token.balanceOf(investor);
              assert.equal(senderBalance, initialSupply - amount);
            });

            it('emits a burned event [with ERC20 retrocompatibility]', async function () {
              const { logs } = await this.token.operatorBurn(investor, amount, '', { from: operator });

              assert.equal(logs.length, 2);
              assert.equal(logs[0].event, 'Burned');
              assert.equal(logs[0].args.operator, operator);
              assert.equal(logs[0].args.from, investor);
              assert(logs[0].args.amount.eq(amount));
              assert.equal(logs[0].args.operatorData, ZERO_BYTE);

              assert.equal(logs[1].event, 'Transfer');
              assert.equal(logs[1].args.from, investor);
              assert.equal(logs[1].args.to, ZERO_ADDRESS);
              assert(logs[1].args.value.eq(amount));
            });
            it('emits a burned event [without ERC20 retrocompatibility]', async function () {
              await this.token.setERC20compatibility(false, { from: owner });
              const { logs } = await this.token.operatorBurn(investor, amount, '', { from: operator });

              assert.equal(logs.length, 1);
              assert.equal(logs[0].event, 'Burned');
              assert.equal(logs[0].args.operator, operator);
              assert.equal(logs[0].args.from, investor);
              assert(logs[0].args.amount.eq(amount));
              assert.equal(logs[0].args.operatorData, ZERO_BYTE);
            });
          });
        });

        describe('when the burner is the zero address', function () {
          // Can never happen with this implementation
        });
      });
      describe('when the amount is not a multiple of the granularity', function () {
        it('reverts', async function () {
          this.token = await ERC777.new('ERC777Token', 'DAU', 2, []);
          await this.token.mint(investor, initialSupply, '', { from: owner });
          await shouldFail.reverting(this.token.operatorBurn(investor, 3, '', { from: operator }));
        });
      });
    });
  });

  describe('ERC20 retrocompatibility', function () {
    beforeEach(async function () {
      this.token = await ERC777.new('ERC777Token', 'DAU', 1, [defaultOperator]);
    });

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

    describe('approve', function () {
      const amount = 100;
      describe('when the ERC20 retrocompatibility is activated', function () {
        describe('when sender approves an operator', function () {
          it('approves the operator', async function () {
            assert.equal(await this.token.allowance(investor, operator), 0);

            await this.token.approve(operator, amount, { from: investor });

            assert.equal(await this.token.allowance(investor, operator), amount);
          });
          it('emits an approval event', async function () {
            const { logs } = await this.token.approve(operator, amount, { from: investor });

            assert.equal(logs.length, 1);
            assert.equal(logs[0].event, 'Approval');
            assert.equal(logs[0].args.owner, investor);
            assert.equal(logs[0].args.spender, operator);
            assert(logs[0].args.value.eq(amount));
          });
        });
        describe('when the operator to approve is the zero address', function () {
          it('reverts', async function () {
            await shouldFail.reverting(this.token.approve(ZERO_ADDRESS, amount, { from: investor }));
          });
        });
      });
      describe('when the ERC20 retrocompatibility is not activated', function () {
        it('reverts', async function () {
          await this.token.setERC20compatibility(false, { from: owner });
          await shouldFail.reverting(this.token.approve(operator, amount, { from: investor }));
        });
      });
    });

    describe('transfer', function () {
      const to = recipient;
      beforeEach(async function () {
        await this.token.mint(investor, initialSupply, '', { from: owner });
      });

      describe('when the ERC20 retrocompatibility is activated', function () {
        describe('when the amount is a multiple of the granularity', function () {
          describe('when the recipient is not the zero address', function () {
            describe('when the sender does not have enough balance', function () {
              const amount = initialSupply + 1;

              it('reverts', async function () {
                await shouldFail.reverting(this.token.transfer(to, amount, { from: investor }));
              });
            });

            describe('when the sender has enough balance', function () {
              const amount = initialSupply;

              it('transfers the requested amount', async function () {
                await this.token.transfer(to, amount, { from: investor });
                const senderBalance = await this.token.balanceOf(investor);
                assert.equal(senderBalance, initialSupply - amount);

                const recipientBalance = await this.token.balanceOf(to);
                assert.equal(recipientBalance, amount);
              });

              it('emits a sent + a transfer event', async function () {
                const { logs } = await this.token.transfer(to, amount, { from: investor });

                assert.equal(logs.length, 2);
                assert.equal(logs[0].event, 'Sent');
                assert.equal(logs[0].args.operator, investor);
                assert.equal(logs[0].args.from, investor);
                assert.equal(logs[0].args.to, to);
                assert(logs[0].args.amount.eq(amount));
                assert.equal(logs[0].args.data, ZERO_BYTE);
                assert.equal(logs[0].args.operatorData, ZERO_BYTE);

                assert.equal(logs[1].event, 'Transfer');
                assert.equal(logs[1].args.from, investor);
                assert.equal(logs[1].args.to, to);
                assert(logs[1].args.value.eq(amount));
              });
            });
          });

          describe('when the recipient is the zero address', function () {
            const amount = initialSupply;
            const to = ZERO_ADDRESS;

            it('reverts', async function () {
              await shouldFail.reverting(this.token.transfer(to, amount, { from: investor }));
            });
          });
        });
        describe('when the amount is not a multiple of the granularity', function () {
          it('reverts', async function () {
            this.token = await ERC777.new('ERC777Token', 'DAU', 2, []);
            await this.token.mint(investor, initialSupply, '', { from: owner });
            await shouldFail.reverting(this.token.transfer(to, 3, { from: investor }));
          });
        });
      });
      describe('when the ERC20 retrocompatibility is not activated', function () {
        const amount = initialSupply;

        it('reverts', async function () {
          await this.token.setERC20compatibility(false, { from: owner });
          await shouldFail.reverting(this.token.transfer(to, amount, { from: investor }));
        });
      });
    });

    describe('transferFrom', function () {
      const to = recipient;
      const approvedAmount = 10000;
      beforeEach(async function () {
        await this.token.mint(investor, initialSupply, '', { from: owner });
      });

      describe('when the ERC20 retrocompatibility is activated', function () {
        describe('when the operator is approved', function () {
          beforeEach(async function () {
            // await this.token.authorizeOperator(operator, { from: investor});
            await this.token.approve(operator, approvedAmount, { from: investor });
          });
          describe('when the amount is a multiple of the granularity', function () {
            describe('when the recipient is not the zero address', function () {
              describe('when the sender does not have enough balance', function () {
                const amount = approvedAmount + 1;

                it('reverts', async function () {
                  await shouldFail.reverting(this.token.transferFrom(investor, to, amount, { from: operator }));
                });
              });

              describe('when the sender has enough balance + the sender is not specified', function () {
                const amount = 500;

                it('transfers the requested amount from operator address', async function () {
                  await this.token.transfer(operator, approvedAmount, { from: investor });

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
                  await this.token.transferFrom(investor, to, amount, { from: operator });
                  const senderBalance = await this.token.balanceOf(investor);
                  assert.equal(senderBalance, initialSupply - amount);

                  const recipientBalance = await this.token.balanceOf(to);
                  assert.equal(recipientBalance, amount);

                  assert.equal(await this.token.allowance(investor, operator), approvedAmount - amount);
                });

                it('emits a sent + a transfer event', async function () {
                  const { logs } = await this.token.transferFrom(investor, to, amount, { from: operator });
                  // await this.token.transferFrom(investor, to, amount, { from: operator });

                  assert.equal(logs.length, 2);
                  assert.equal(logs[0].event, 'Sent');
                  assert.equal(logs[0].args.operator, operator);
                  assert.equal(logs[0].args.from, investor);
                  assert.equal(logs[0].args.to, to);
                  assert(logs[0].args.amount.eq(amount));
                  assert.equal(logs[0].args.data, ZERO_BYTE);
                  assert.equal(logs[0].args.operatorData, ZERO_BYTE);

                  assert.equal(logs[1].event, 'Transfer');
                  assert.equal(logs[1].args.from, investor);
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
                await shouldFail.reverting(this.token.transferFrom(investor, to, amount, { from: operator }));
              });
            });
          });
          describe('when the amount is not a multiple of the granularity', function () {
            it('reverts', async function () {
              this.token = await ERC777.new('ERC777Token', 'DAU', 2, []);
              await this.token.mint(investor, initialSupply, '', { from: owner });
              await shouldFail.reverting(this.token.transferFrom(investor, to, 3, { from: operator }));
            });
          });
        });
        describe('when the operator is not approved', function () {
          const amount = approvedAmount;
          describe('when the operator is not approved but authorized', function () {
            it('transfers the requested amount', async function () {
              await this.token.authorizeOperator(operator, { from: investor });
              assert.equal(await this.token.allowance(investor, operator), 0);

              await this.token.transferFrom(investor, to, amount, { from: operator });
              const senderBalance = await this.token.balanceOf(investor);
              assert.equal(senderBalance, initialSupply - amount);

              const recipientBalance = await this.token.balanceOf(to);
              assert.equal(recipientBalance, amount);
            });
          });
          describe('when the operator is not approved and not authorized', function () {
            it('reverts', async function () {
              await shouldFail.reverting(this.token.transferFrom(investor, to, amount, { from: operator }));
            });
          });
        });
      });
      describe('when the ERC20 retrocompatibility is not activated', function () {
        const amount = approvedAmount;
        it('reverts', async function () {
          await this.token.setERC20compatibility(false, { from: owner });
          await shouldFail.reverting(this.token.transferFrom(investor, to, amount, { from: operator }));
        });
      });
    });
  });
});
