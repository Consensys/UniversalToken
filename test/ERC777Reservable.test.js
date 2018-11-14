import { assertRevert } from 'openzeppelin-solidity/test/helpers/assertRevert.js';

// Mock:
const ERC777ReservableMock = artifacts.require('ERC777ReservableMock');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTE = '0x';

const data = '0x00000000000000000000000000000000000270000000000000000000000000000000000000000000000000000000000'

const initialSupply = 1000000000;

const tokensToReserve = 100000;
const validUntil = 2000;

const minShares = 0;
const maxShares = initialSupply;
const burnLeftOver = false;
const certificateSigner = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

var Status = {
  "Created": 0, 
  "Validated": 1, 
  "Cancelled": 2
};

contract('ERC777ReservableMock', function ([owner, operator, defaultOperator, investor, recipient, unknown]) {
  describe('ERC777Reservable functionalities', function () {
    beforeEach(async function () {
      this.token = await ERC777ReservableMock.new('ERC777ReservableToken', 'DAU', 1, [defaultOperator], minShares, maxShares, burnLeftOver, certificateSigner);
    });

    describe('name', function () {
      it('returns the name of the token', async function () {
        const name = await this.token.name();

        assert.equal(name, 'ERC777ReservableToken');
      });
    });

    describe('symbol', function () {
      it('returns the symbol of the token', async function () {
        const symbol = await this.token.symbol();

        assert.equal(symbol, 'DAU');
      });
    });

    describe('granularity', function () {
      it('returns the granularity of tokens', async function () {
        const granularity = await this.token.granularity();

        assert.equal(granularity, 1);
      });
    });

    describe('balanceOf', function () {
      describe('when the requested account has no tokens', function () {
        it('returns zero', async function () {
          const balance = await this.token.balanceOf(unknown);

          assert.equal(balance, 0);
        });
      });
    });

    describe('when the requested account has some tokens', function () {
      it('returns the total amount of tokens', async function () {
        await this.token.mint(investor, initialSupply, '', { from: owner });
        const balance = (await this.token.balanceOf(investor));

        assert.equal(balance, initialSupply);
      });
    });

    describe('defaultOperators', function () {
      it('returns the list of defaultOperators', async function () {
        const defaultOperators = (await this.token.defaultOperators());

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
    });

    describe('reserveTokens', function () {
      describe('when the sale is opened', function () {
        describe('when the amount is greater than 0', function () {
          describe('when the reservered total is less than or equal to the total supply', function () {

            it('reserve tokens', async function () {
              await this.token.reserveTokens(tokensToReserve, validUntil, '', { from: investor });
              const reservations = (await this.token.getReservation(investor, 0));      
            });

            it('emits a "TokensReserved" event', async function() {  
              const { logs } = (await this.token.reserveTokens(tokensToReserve, validUntil, '', { from: investor }));
              assert.equal(logs[0].event, 'TokensReserved');
            });

          });

          describe('when the reservered total is greater than the total supply', function () {

            it('reverts', async function () {
              const totalSupply = (await this.token.totalSupply());
              const greaterThanTotalSupply = totalSupply.toNumber() + 1;
              await assertRevert(this.token.reserveTokens(greaterThanTotalSupply, validUntil, '', { from: investor }));
            });

          });
        });

        describe('when the amount is equal to 0', function () {

          it('reverts', async function () {
            await assertRevert(this.token.reserveTokens(0, validUntil, '', { from: investor }));
          });

        });
      });

      describe('when the sale is not opened', function () {
        it('reverts', async function () {
          await this.token.reserveTokens(tokensToReserve, validUntil, '', { from: owner });
          await this.token.validateReservation(owner, 0, { from: owner });
          await this.token.endSale();
          await assertRevert(this.token.validateReservation(owner, 0, { from: owner }));
        });
      });

    });

    describe('validateReservation', function () {
      let index = 0;

        describe('when the sale is opened', function () {
          describe('when the sender is the owner', function () {
            describe('when the owner has at least one reservation', function () {
              describe('when the reservation has an expected status', function () {
                describe('when the validity of the reservation is greater than 0', function () {
                  describe('when the validity of the reservation is in the past', function () {
                    
                    it('validate the reservation', async function () {
                      await this.token.reserveTokens(tokensToReserve, validUntil, '', { from: owner });
                      await this.token.validateReservation(owner, index, { from: owner });
                    });

                    it('emits a "ReservationValidated" event', async function() {  
                      await this.token.reserveTokens(tokensToReserve, validUntil, '', { from: owner });
                      const { logs } = (await this.token.validateReservation(owner, index, { from: owner }));
                      assert.equal(logs[0].event, 'ReservationValidated');
                    });
                    
                  });

                  describe('when the validity of the reservation is in the future', function () {
                    
                    it('reverts', async function () {
                      const posteriorToNow = (await web3.eth.getBlock('latest').timestamp) + 10;
                      await this.token.reserveTokens(tokensToReserve, posteriorToNow, '', { from: owner });
                      await assertRevert(this.token.validateReservation(owner, index, { from: owner }));
                    });
                    
                  });
                });

                describe('when the validity of the reservation is equal to 0', function () {
                    
                  it('reverts', async function () {
                    await this.token.reserveTokens(tokensToReserve, 0, '', { from: owner });
                    await assertRevert(this.token.validateReservation(owner, index, { from: owner }));
                  });
                  
                });
              });

              describe('when the reservation has an unexpected status', function () {
                 
                // TODO 
                /*
                it('reverts', async function () {
                });
                */
                
              });
            });

            describe('when the validation is not preceded by any reservation', function () {
                    
              it('reverts', async function () {
                await assertRevert(this.token.validateReservation(owner, index, { from: owner }));
              });
              
            });
          });

           describe('when the sender is not the owner', function () {
                    
            it('reverts', async function () {
              await this.token.reserveTokens(tokensToReserve, validUntil, '', { from: investor });
              await assertRevert(this.token.validateReservation(owner, index, { from: owner }));
            });
            
          });
        });

        describe('when the sale is not opened', function () {     
          it('reverts', async function () {
            await this.token.reserveTokens(tokensToReserve, validUntil, '', { from: owner });
            await this.token.validateReservation(owner, 0, { from: owner });
            await this.token.endSale();
            await assertRevert(this.token.validateReservation(owner, 0, { from: owner }));
          }); 
        });

    });

    describe('endSale', function () {
      it('ends the sale', async function () {
        await this.token.reserveTokens(tokensToReserve, validUntil, '', { from: owner });
        await this.token.validateReservation(owner, 0, { from: owner });
      });

      it('emits a "SaleEnded" event', async function() { 
        await this.token.reserveTokens(tokensToReserve, validUntil, '', { from: owner });
        await this.token.validateReservation(owner, 0, { from: owner });
        const { logs } = await this.token.endSale();
        assert.equal(logs[2].event, 'SaleEnded');
      });
    });

  });
});