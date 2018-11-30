import shouldFail from 'openzeppelin-solidity/test/helpers/shouldFail.js';

const ERC1400 = artifacts.require('ERC1400Mock');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTE = '0x';

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

const initialSupply = 1000000000;

const tranche1 = "0x5072654973737565640000000000000000000000000000000000000000000000"; // PreIssued in hex
const tranche2 = "0x4973737565640000000000000000000000000000000000000000000000000000"; // Issued in hex
const tranche3 = "0x4c6f636b65640000000000000000000000000000000000000000000000000000"; // dAuriel3 in hex

var totalSupply;
var balance;
var balanceByTranche;

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
      await this.token.setDefaultTranches([tranche1, tranche2, tranche3], { from: investor });

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
        await shouldFail.reverting(this.token.addDefaultOperator(operator, { from: unknown }));
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
        await shouldFail.reverting(this.token.addDefaultOperatorByTranche(tranche1, operator, { from: unknown }));
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

  // DEFAULTOPERATORS

  describe('defaultOperators', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });
    describe('when the token is controllable', function () {
      it('returns the list of defaultOperators', async function () {
        assert(await this.token.isControllable());
        const defaultOperators = await this.token.defaultOperators();

        assert.equal(defaultOperators.length, 1);
        assert.equal(defaultOperators[0], defaultOperator);
      });
    });
    describe('when the token is not controllable', function () {
      it('returns an empty list', async function () {
        assert(await this.token.isControllable());
        await this.token.renounceControl({ from: owner });
        assert(!(await this.token.isControllable()));

        const defaultOperators = await this.token.defaultOperators();

        assert.equal(defaultOperators.length, 0);
      });
    });
  });

  // DEFAULTOPERATORS

  describe('defaultOperatorsByTranche', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await this.token.addDefaultOperatorByTranche(tranche3, operator, { from: owner });
    });
    describe('when the token is controllable', function () {
      it('returns the list of defaultOperators', async function () {
        assert(await this.token.isControllable());
        const defaultOperators = await this.token.defaultOperatorsByTranche(tranche3);

        assert.equal(defaultOperators.length, 1);
        assert.equal(defaultOperators[0], operator);
      });
    });
    describe('when the token is not controllable', function () {
      it('returns an empty list', async function () {
        assert(await this.token.isControllable());
        await this.token.renounceControl({ from: owner });
        assert(!(await this.token.isControllable()));

        const defaultOperators = await this.token.defaultOperatorsByTranche(tranche3);

        assert.equal(defaultOperators.length, 0);
      });
    });
  });


  // SET/GET DOCUMENT

  describe('set/getDocument', function () {
    const documentName = "Document Name";
    const documentURI = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."; // SHA-256 of documentURI
    const documentHash = "0x1c81c608a616183cc4a38c09ecc944eb77eaff465dd87aae0290177f2b70b6f8"; // SHA-256 of documentURI + '0x'

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });

    describe('setDocument', function () {
      describe('when sender is the contract owner', function () {
        it('attaches the document to the token', async function () {
          await this.token.setDocument(documentName, documentURI, documentHash, { from: owner });
          const doc = await this.token.getDocument(documentName);
          assert.equal(documentURI, doc[0]);
          assert.equal(documentHash, doc[1]);
        });
      });
      describe('when sender is not the contract owner', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.setDocument(documentName, documentURI, documentHash, { from: unknown }));
        });
      });
    });
    describe('getDocument', function () {
      describe('when docuemnt exists', function () {
        it('returns the document', async function () {
          await this.token.setDocument(documentName, documentURI, documentHash, { from: owner });
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

  // ISSUEBYTRANCHE

  describe('issueByTranche', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });
    const issuanceAmount = 1000;

    describe('when sender is the minter', function () {
      describe('when token is issuable', function () {
        it('issues the requested amount', async function () {
          await this.token.issueByTranche(tranche1, investor, issuanceAmount, "", { from: owner });

          totalSupply = await this.token.totalSupply();
          balance = await this.token.balanceOf(investor);
          balanceByTranche = await this.token.balanceOfByTranche(tranche1, investor);

          assert.equal(totalSupply, issuanceAmount);
          assert.equal(balance, issuanceAmount);
          assert.equal(balanceByTranche, issuanceAmount);
        });
        it('emits a issuedByTranche event', async function () {
          const { logs } = await this.token.issueByTranche(tranche1, investor, issuanceAmount, "", { from: owner });

          assert.equal(logs.length, 2);

          assert.equal(logs[0].event, 'Minted');
          assert.equal(logs[0].args.operator, owner);
          assert.equal(logs[0].args.to, investor);
          assert(logs[0].args.amount.eq(issuanceAmount));
          assert.equal(logs[0].args.data, ZERO_BYTE);
          assert.equal(logs[0].args.operatorData, ZERO_BYTE);

          assert.equal(logs[1].event, 'IssuedByTranche');
          assert.equal(logs[1].args.tranche, tranche1);
          assert.equal(logs[1].args.operator, owner);
          assert.equal(logs[1].args.to, investor);
          assert(logs[1].args.amount.eq(issuanceAmount));
          assert.equal(logs[1].args.data, ZERO_BYTE);
          assert.equal(logs[1].args.operatorData, ZERO_BYTE);
        });
      });
      describe('when token is not issuable', function () {
        it('reverts', async function () {
          await this.token.renounceIssuance({ from: owner });
          await shouldFail.reverting(this.token.issueByTranche(tranche1, investor, issuanceAmount, "", { from: owner }));
        });
      });
    });
    describe('when sender is not the minter', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.issueByTranche(tranche1, investor, issuanceAmount, "", { from: unknown }));
      });
    });

  });

  // REDEEMBYTRANCHE

  describe('redeemByTranche', function () {
    const issuanceAmount = 1000;
    const redeemAmount = 300;

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await this.token.issueByTranche(tranche1, investor, issuanceAmount, "", { from: owner });
    });

    describe('when the redeemer has enough balance for this tranche', function () {
      it('redeems the requested amount', async function () {
        await this.token.redeemByTranche(tranche1, redeemAmount, "", { from: investor });

        totalSupply = await this.token.totalSupply();
        balance = await this.token.balanceOf(investor);
        balanceByTranche = await this.token.balanceOfByTranche(tranche1, investor);

        assert.equal(totalSupply, issuanceAmount - redeemAmount);
        assert.equal(balance, issuanceAmount - redeemAmount);
        assert.equal(balanceByTranche, issuanceAmount - redeemAmount);
      });
      it('emits a redeemedByTranche event', async function () {
        const { logs } = await this.token.redeemByTranche(tranche1, redeemAmount, "", { from: investor });

        assert.equal(logs.length, 2);

        assert.equal(logs[0].event, 'Burned');
        assert.equal(logs[0].args.operator, investor);
        assert.equal(logs[0].args.from, investor);
        assert(logs[0].args.amount.eq(redeemAmount));
        assert.equal(logs[0].args.operatorData, ZERO_BYTE);

        assert.equal(logs[1].event, 'RedeemedByTranche');
        assert.equal(logs[1].args.tranche, tranche1);
        assert.equal(logs[1].args.operator, investor);
        assert.equal(logs[1].args.from, investor);
        assert(logs[1].args.amount.eq(redeemAmount));
        assert.equal(logs[1].args.data, ZERO_BYTE);
        assert.equal(logs[1].args.operatorData, ZERO_BYTE);
      });
    });
    describe('when the redeemer has enough balance for this tranche', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.redeemByTranche(tranche2, redeemAmount, "", { from: investor }));
      });
    });

  });

  // OPERATOREDEEMBYTRANCHE

  describe('operatorRedeemByTranche', function () {
    const issuanceAmount = 1000;
    const redeemAmount = 300;

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await this.token.issueByTranche(tranche1, investor, issuanceAmount, "", { from: owner });
    });

    describe('when the sender is an operator for this tranche', function () {
      describe('when the redeemer has enough balance for this tranche', function () {
        it('redeems the requested amount', async function () {
          await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
          await this.token.operatorRedeemByTranche(tranche1, investor, redeemAmount, "", "", { from: operator });

          totalSupply = await this.token.totalSupply();
          balance = await this.token.balanceOf(investor);
          balanceByTranche = await this.token.balanceOfByTranche(tranche1, investor);

          assert.equal(totalSupply, issuanceAmount - redeemAmount);
          assert.equal(balance, issuanceAmount - redeemAmount);
          assert.equal(balanceByTranche, issuanceAmount - redeemAmount);
        });
        it('emits a redeemedByTranche event', async function () {
          await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
          const { logs } = await this.token.operatorRedeemByTranche(tranche1, investor, redeemAmount, "", "", { from: operator });

          assert.equal(logs.length, 2);

          assert.equal(logs[0].event, 'Burned');
          assert.equal(logs[0].args.operator, operator);
          assert.equal(logs[0].args.from, investor);
          assert(logs[0].args.amount.eq(redeemAmount));
          assert.equal(logs[0].args.operatorData, ZERO_BYTE);

          assert.equal(logs[1].event, 'RedeemedByTranche');
          assert.equal(logs[1].args.tranche, tranche1);
          assert.equal(logs[1].args.operator, operator);
          assert.equal(logs[1].args.from, investor);
          assert(logs[1].args.amount.eq(redeemAmount));
          assert.equal(logs[1].args.data, ZERO_BYTE);
          assert.equal(logs[1].args.operatorData, ZERO_BYTE);
        });
      });
      describe('when the redeemer does not have enough balance for this tranche', function () {
        it('reverts', async function () {
          it('redeems the requested amount', async function () {
            await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });

            await shouldFail.reverting(this.token.operatorRedeemByTranche(tranche1, investor, issuanceAmount + 1, "", "", { from: operator }));
          });
        });
      });
    });
    describe('when the sender is a global operator', function () {
      it('redeems the requested amount', async function () {
        await this.token.authorizeOperator(operator, { from: investor });
        await this.token.operatorRedeemByTranche(tranche1, investor, redeemAmount, "", "", { from: operator });

        totalSupply = await this.token.totalSupply();
        balance = await this.token.balanceOf(investor);
        balanceByTranche = await this.token.balanceOfByTranche(tranche1, investor);

        assert.equal(totalSupply, issuanceAmount - redeemAmount);
        assert.equal(balance, issuanceAmount - redeemAmount);
        assert.equal(balanceByTranche, issuanceAmount - redeemAmount);
      });
    });
    describe('when the sender is not an operator', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.operatorRedeemByTranche(tranche1, investor, redeemAmount, "", "", { from: operator }));
      });
    });

  });

  // SENDBYTRANCHE

  describe('sendByTranche', function () {
    const issuanceAmount = 1000;
    const sendAmount = 300;

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await this.token.issueByTranche(tranche1, investor, issuanceAmount, "", { from: owner });
    });

    describe('when the sender has enough balance for this tranche', function () {
      it('sends the requested amount', async function () {
        balance = await this.token.balanceOf(investor);
        balanceByTranche = await this.token.balanceOfByTranche(tranche1, investor);
        assert.equal(balance, issuanceAmount);
        assert.equal(balanceByTranche, issuanceAmount);

        balance = await this.token.balanceOf(recipient);
        balanceByTranche = await this.token.balanceOfByTranche(tranche1, recipient);
        assert.equal(balance, 0);
        assert.equal(balanceByTranche, 0);

        await this.token.sendByTranche(tranche1, recipient, sendAmount, "", { from: investor });

        balance = await this.token.balanceOf(investor);
        balanceByTranche = await this.token.balanceOfByTranche(tranche1, investor);
        assert.equal(balance, issuanceAmount - sendAmount);
        assert.equal(balanceByTranche, issuanceAmount - sendAmount);

        balance = await this.token.balanceOf(recipient);
        balanceByTranche = await this.token.balanceOfByTranche(tranche1, recipient);
        assert.equal(balance, sendAmount);
        assert.equal(balanceByTranche, sendAmount);
      });
      it('emits a sentByTranche event', async function () {
        const { logs } = await this.token.sendByTranche(tranche1, recipient, sendAmount, "", { from: investor });

        assert.equal(logs.length, 2);

        assert.equal(logs[0].event, 'Sent');
        assert.equal(logs[0].args.operator, investor);
        assert.equal(logs[0].args.from, investor);
        assert.equal(logs[0].args.to, recipient);
        assert(logs[0].args.amount.eq(sendAmount));
        assert.equal(logs[0].args.data, ZERO_BYTE);
        assert.equal(logs[0].args.operatorData, ZERO_BYTE);

        assert.equal(logs[1].event, 'SentByTranche');
        assert.equal(logs[1].args.fromTranche, tranche1);
        assert.equal(logs[1].args.operator, investor);
        assert.equal(logs[1].args.from, investor);
        assert.equal(logs[1].args.to, recipient);
        assert(logs[1].args.amount.eq(sendAmount));
        assert.equal(logs[1].args.data, ZERO_BYTE);
        assert.equal(logs[1].args.operatorData, ZERO_BYTE);
      });
    });
    describe('when the sender does not have enough balance for this tranche', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.sendByTranche(tranche2, recipient, sendAmount, "", { from: investor }));
      });
    });

  });

  // OPERATORSENDBYTRANCHE

  describe('operatorSendByTranche', function () {
    const issuanceAmount = 1000;
    const sendAmount = 300;

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await this.token.issueByTranche(tranche1, investor, issuanceAmount, "", { from: owner });
    });

    describe('when the sender is an operator for this tranche', function () {
      describe('when the sender has enough balance for this tranche', function () {
        it('sends the requested amount', async function () {
          balance = await this.token.balanceOf(investor);
          balanceByTranche = await this.token.balanceOfByTranche(tranche1, investor);
          assert.equal(balance, issuanceAmount);
          assert.equal(balanceByTranche, issuanceAmount);

          balance = await this.token.balanceOf(recipient);
          balanceByTranche = await this.token.balanceOfByTranche(tranche1, recipient);
          assert.equal(balance, 0);
          assert.equal(balanceByTranche, 0);

          await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
          await this.token.operatorSendByTranche(tranche1, investor, recipient, sendAmount, "", "", { from: operator });

          balance = await this.token.balanceOf(investor);
          balanceByTranche = await this.token.balanceOfByTranche(tranche1, investor);
          assert.equal(balance, issuanceAmount - sendAmount);
          assert.equal(balanceByTranche, issuanceAmount - sendAmount);

          balance = await this.token.balanceOf(recipient);
          balanceByTranche = await this.token.balanceOfByTranche(tranche1, recipient);
          assert.equal(balance, sendAmount);
          assert.equal(balanceByTranche, sendAmount);
        });
        it('emits a sentByTranche event', async function () {
          await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
          const { logs } = await this.token.operatorSendByTranche(tranche1, investor, recipient, sendAmount, "", "", { from: operator });

          assert.equal(logs.length, 2);

          assert.equal(logs[0].event, 'Sent');
          assert.equal(logs[0].args.operator, operator);
          assert.equal(logs[0].args.from, investor);
          assert.equal(logs[0].args.to, recipient);
          assert(logs[0].args.amount.eq(sendAmount));
          assert.equal(logs[0].args.data, ZERO_BYTE);
          assert.equal(logs[0].args.operatorData, ZERO_BYTE);

          assert.equal(logs[1].event, 'SentByTranche');
          assert.equal(logs[1].args.fromTranche, tranche1);
          assert.equal(logs[1].args.operator, operator);
          assert.equal(logs[1].args.from, investor);
          assert.equal(logs[1].args.to, recipient);
          assert(logs[1].args.amount.eq(sendAmount));
          assert.equal(logs[1].args.data, ZERO_BYTE);
          assert.equal(logs[1].args.operatorData, ZERO_BYTE);
        });
      });
      describe('when the sender does not have enough balance for this tranche', function () {
        it('reverts', async function () {
          await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
          await shouldFail.reverting(this.token.operatorSendByTranche(tranche1, investor, recipient, issuanceAmount + 1, "", "", { from: operator }));
        });
      });
    });
    describe('when the sender is a global operator', function () {
      it('redeems the requested amount', async function () {
        balance = await this.token.balanceOf(investor);
        balanceByTranche = await this.token.balanceOfByTranche(tranche1, investor);
        assert.equal(balance, issuanceAmount);
        assert.equal(balanceByTranche, issuanceAmount);

        balance = await this.token.balanceOf(recipient);
        balanceByTranche = await this.token.balanceOfByTranche(tranche1, recipient);
        assert.equal(balance, 0);
        assert.equal(balanceByTranche, 0);

        await this.token.authorizeOperator(operator, { from: investor });
        await this.token.operatorSendByTranche(tranche1, investor, recipient, sendAmount, "", "", { from: operator });

        balance = await this.token.balanceOf(investor);
        balanceByTranche = await this.token.balanceOfByTranche(tranche1, investor);
        assert.equal(balance, issuanceAmount - sendAmount);
        assert.equal(balanceByTranche, issuanceAmount - sendAmount);

        balance = await this.token.balanceOf(recipient);
        balanceByTranche = await this.token.balanceOfByTranche(tranche1, recipient);
        assert.equal(balance, sendAmount);
        assert.equal(balanceByTranche, sendAmount);
      });
    });
    describe('when the sender is not an operator', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.operatorSendByTranche(tranche1, investor, recipient, sendAmount, "", "", { from: operator }));
      });
    });

  });


});
