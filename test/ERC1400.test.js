import shouldFail from 'openzeppelin-solidity/test/helpers/shouldFail.js';

const ERC1400 = artifacts.require('ERC1400Mock');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTE = '0x';

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

const initialSupply = 1000000000;

contract('ERC1400', function ([owner, operator, defaultOperator, investor, recipient, unknown]) {
  describe('ERC1400 functionalities', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
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
  });
});
