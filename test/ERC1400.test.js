import shouldFail from 'openzeppelin-solidity/test/helpers/shouldFail.js';

const ERC1400 = artifacts.require('ERC1400Mock');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTE = '0x';

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

const initialSupply = 1000000000;

const tranche1 = "0x6441757269656c31000000000000000000000000000000000000000000000000";// dAuriel1 in hex
const tranche2 = "0x6441757269656c32000000000000000000000000000000000000000000000000";// dAuriel2 in hex
const tranche3 = "0x6441757269656c33000000000000000000000000000000000000000000000000";// dAuriel3 in hex

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

  // SETDEFAULTTRANCHES

  describe('setDefaultTranches', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });
    it('sets defaults tranche', async function () {
      await this.token.setDefaultTranches(["dAuriel1", "dAuriel2", "dAuriel3"], { from: investor });

      const defaultTranches = await this.token.getDefaultTranches(investor);

      assert.equal(defaultTranches.length, 3);
      assert.equal(defaultTranches[0], tranche1); // dAuriel1 in hex
      assert.equal(defaultTranches[1], tranche2); // dAuriel2 in hex
      assert.equal(defaultTranches[2], tranche3); // dAuriel3 in hex
    });

  });

  // AUTHORIZE OPERATOR BY TRANCHE

  describe('authorizeOperatorByTranche', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });
    it('authorizes operator for tranche', async function () {
      await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
      assert(await this.token.isOperatorForTranche(tranche1, operator, investor));
    });
  });

  // ADD DEFAULT OPERATOR

  describe('addDefaultOperator', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });
    describe('when sender is the contract owner', function () {
      describe('when token is controllable', function () {
        it('adds the default operator', async function () {
          assert(await this.token.isControllable());
          assert(!(await this.token.isOperatorFor(operator, investor)));
          await this.token.addDefaultOperator(operator, { from: owner });
          assert(await this.token.isOperatorFor(operator, investor));
        });
      });
      describe('when token is not controllable', function () {
        it('reverts', async function () {
          await this.token.removeDefaultOperator(defaultOperator, { from: owner });
          await this.token.renounceControl({ from: owner });
          assert(!(await this.token.isControllable()));

          await shouldFail.reverting(this.token.addDefaultOperator(operator, { from: owner }));
        });
      });
    });
    describe('when sender is not the contract owner', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.addDefaultOperator(operator, { from: investor }));
      });
    });
  });

  // REMOVE DEFAULT OPERATOR

  describe('removeDefaultOperator', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });
    describe('when operator is default operator', function () {
      it('removes the default operator', async function () {
        assert(!(await this.token.isOperatorFor(operator, investor)));
        await this.token.addDefaultOperator(operator, { from: owner });
        assert(await this.token.isOperatorFor(operator, investor));
        await this.token.removeDefaultOperator(operator, { from: owner });
        assert(!(await this.token.isOperatorFor(operator, investor)));
      });
    });
    describe('when operator is not default operator', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.removeDefaultOperator(operator, { from: owner }));
      });
    });
  });

  // ADD DEFAULT OPERATOR BY TRANCHE

  describe('addDefaultOperatorByTranche', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });
    describe('when sender is the contract owner', function () {
      describe('when token is controllable', function () {
        it('adds the default operator', async function () {
          assert(await this.token.isControllable());
          assert(!(await this.token.isOperatorForTranche(tranche1, operator, investor)));
          await this.token.addDefaultOperatorByTranche(tranche1, operator, { from: owner });
          assert(await this.token.isOperatorForTranche(tranche1, operator, investor));
        });
      });
      describe('when token is not controllable', function () {
        it('reverts', async function () {
          await this.token.removeDefaultOperator(defaultOperator, { from: owner });
          await this.token.renounceControl({ from: owner });
          assert(!(await this.token.isControllable()));

          await shouldFail.reverting(this.token.addDefaultOperatorByTranche(tranche1, operator, { from: owner }));
        });
      });
    });
    describe('when sender is not the contract owner', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.addDefaultOperatorByTranche(tranche1, operator, { from: investor }));
      });
    });
  });

  // REMOVE DEFAULT OPERATOR BY TRANCHE

  describe('removeDefaultOperatorByTranche', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });
    describe('when operator is default operator', function () {
      it('removes the default operator', async function () {
        assert(!(await this.token.isOperatorForTranche(tranche1, operator, investor)));
        await this.token.addDefaultOperatorByTranche(tranche1, operator, { from: owner });
        assert(await this.token.isOperatorForTranche(tranche1, operator, investor));
        await this.token.removeDefaultOperatorByTranche(tranche1, operator, { from: owner });
        assert(!(await this.token.isOperatorForTranche(tranche1, operator, investor)));
      });
    });
    describe('when operator is not default operator', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.removeDefaultOperatorByTranche(tranche1, operator, { from: owner }));
      });
    });
  });

  // AUTHORIZE OPERATOR BY TRANCHE

  describe('authorizeOperatorByTranche', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });
    it('authorizes the operator', async function () {
      assert(!(await this.token.isOperatorForTranche(tranche1, operator, investor)));
      await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
      assert(await this.token.isOperatorForTranche(tranche1, operator, investor));
    });
    it('emits an authorized event', async function () {
      const { logs } = await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });

      assert.equal(logs.length, 1);
      assert.equal(logs[0].event, 'AuthorizedOperatorByTranche');
      assert.equal(logs[0].args.tranche, tranche1);
      assert.equal(logs[0].args.operator, operator);
      assert.equal(logs[0].args.tokenHolder, investor);
    });
  });

  // REVOKE OPERATOR BY TRANCHE

  describe('revokeOperatorByTranche', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });
    describe('when operator is not default operator', function () {
      it('revokes the operator', async function () {
        await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
        assert(await this.token.isOperatorForTranche(tranche1, operator, investor));
        await this.token.revokeOperatorByTranche(tranche1, operator, { from: investor });
        assert(!(await this.token.isOperatorForTranche(tranche1, operator, investor)));
      });
      it('emits a revoked event', async function () {
        await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
        const { logs } = await this.token.revokeOperatorByTranche(tranche1, operator, { from: investor });

        assert.equal(logs.length, 1);
        assert.equal(logs[0].event, 'RevokedOperatorByTranche');
        assert.equal(logs[0].args.tranche, tranche1);
        assert.equal(logs[0].args.operator, operator);
        assert.equal(logs[0].args.tokenHolder, investor);
      });
    });
    describe('when operator is default operator', function () {
      describe('when token is not controllable', function () {
        it('revokes the operator', async function () {
          await this.token.removeDefaultOperator(defaultOperator, { from: owner });
          await this.token.renounceControl({ from: owner });
          assert(!(await this.token.isControllable()));

          await this.token.fakeAddDefaultOperatorByTranche(tranche1, operator, { from: owner });
          assert(await this.token.isOperatorForTranche(tranche1, operator, investor));

          await this.token.revokeOperatorByTranche(tranche1, defaultOperator, { from: investor });
          assert(!(await this.token.isOperatorForTranche(tranche1, defaultOperator, investor)));
        });
      });
      describe('when token is controllable', function () {
        it('can not revoke the operator', async function () {
          await this.token.addDefaultOperatorByTranche(tranche1, defaultOperator, { from: owner });
          assert(await this.token.isOperatorForTranche(tranche1, defaultOperator, investor));
          assert(await this.token.isControllable());

          await this.token.revokeOperatorByTranche(tranche1, defaultOperator, { from: investor });
          assert(await this.token.isOperatorForTranche(tranche1, defaultOperator, investor));
        });
      });
    });
  });

});
