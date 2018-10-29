import { assertRevert } from 'openzeppelin-solidity/test/helpers/assertRevert.js';

const ERC777Reservable = artifacts.require('ERC777Reservable');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTE = '0x';

const initialSupply = 1000000000;

const minShares = 0;
const maxShares = initialSupply;
const burnLeftOver = false;
const certificateSigner = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

contract('ERC777Reservable', function ([owner, operator, defaultOperator, investor, recipient, unknown]) {
  describe('ERC777Reservable functionalities', function () {
    beforeEach(async function () {
      this.token = await ERC777Reservable.new('ERC777ReservableToken', 'DAU', 1, [defaultOperator], minShares, maxShares, burnLeftOver, certificateSigner);
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

    // describe('balanceOf', function () {
    //   describe('when the requested account has no tokens', function () {
    //     it('returns zero', async function () {
    //       const balance = await this.token.balanceOf(unknown);
    //
    //       assert.equal(balance, 0);
    //     });
    //   });
    //
    //   describe('when the requested account has some tokens', function () {
    //     it('returns the total amount of tokens', async function () {
    //       await this.token.mint(investor, initialSupply, '', '', { from: owner });
    //       const balance = await this.token.balanceOf(investor);
    //
    //       assert.equal(balance, initialSupply);
    //     });
    //   });
    // });

    // describe('total supply', function () {
    //   it('returns the total amount of tokens', async function () {
    //     await this.token.mint(investor, initialSupply, '', '', { from: owner });
    //     const totalSupply = await this.token.totalSupply();
    //
    //     assert.equal(totalSupply, initialSupply);
    //   });
    // });

  });
});
