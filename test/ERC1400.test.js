import shouldFail from 'openzeppelin-solidity/test/helpers/shouldFail.js';

const ERC1400 = artifacts.require('ERC1400Mock');
const ERC1410 = artifacts.require('ERC1410Mock');
const ERC820Registry = artifacts.require('ERC820Registry');
const ERC777TokensSender = artifacts.require('ERC777TokensSenderMock');
const ERC777TokensRecipient = artifacts.require('ERC777TokensRecipientMock');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTE = '0x';

const EMPTY_BYTE32 = '0x0000000000000000000000000000000000000000000000000000000000000000';

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

const VALID_CERTIFICATE = '0x1000000000000000000000000000000000000000000000000000000000000000';
const INVALID_CERTIFICATE = '0x0000000000000000000000000000000000000000000000000000000000000000';

const INVALID_CERTIFICATE_SENDER = '0x1100000000000000000000000000000000000000000000000000000000000000';
const INVALID_CERTIFICATE_RECIPIENT = '0x2200000000000000000000000000000000000000000000000000000000000000';

const tranche1 = '0x5072654973737565640000000000000000000000000000000000000000000000'; // PreIssued in hex
const tranche2 = '0x4973737565640000000000000000000000000000000000000000000000000000'; // Issued in hex
const tranche3 = '0x4c6f636b65640000000000000000000000000000000000000000000000000000'; // dAuriel3 in hex
const tranches = [tranche1, tranche2, tranche3];

// const ESC_A1 = '0xa1'; // Transfer Verified - On-Chain approval for restricted token
const ESC_A2 = '0xa2'; // Transfer Verified - Off-Chain approval for restricted token
const ESC_A3 = '0xa3'; // Transfer Blocked - Sender lockup period not ended
const ESC_A4 = '0xa4'; // Transfer Blocked - Sender balance insufficient
const ESC_A5 = '0xa5'; // Transfer Blocked - Sender not eligible
const ESC_A6 = '0xa6'; // Transfer Blocked - Receiver not eligible
// const ESC_A7 = '0xa7'; // Transfer Blocked - Identity restriction
// const ESC_A8 = '0xa8'; // Transfer Blocked - Token restriction
const ESC_A9 = '0xa9'; // Transfer Blocked - Token granularity

const issuanceAmount = 1000;

var totalSupply;
var balance;
var balanceByTranche;

const assertSendEvent = (
  _logs,
  _fromTranche,
  _operator,
  _from,
  _to,
  _amount,
  _data,
  _operatorData
) => {
  var i = 0;
  if (_logs.length === 3) {
    assert.equal(_logs[0].event, 'Checked');
    assert.equal(_logs[0].args.sender, _operator);
    i = 1;
  }

  assert.equal(_logs[i].event, 'Sent');
  assert.equal(_logs[i].args.operator, _operator);
  assert.equal(_logs[i].args.from, _from);
  assert.equal(_logs[i].args.to, _to);
  assert(_logs[i].args.amount.eq(_amount));
  assert.equal(_logs[i].args.data, _data);
  assert.equal(_logs[i].args.operatorData, _operatorData);

  assert.equal(_logs[i + 1].event, 'SentByTranche');
  assert.equal(_logs[i + 1].args.fromTranche, _fromTranche);
  assert.equal(_logs[i + 1].args.operator, _operator);
  assert.equal(_logs[i + 1].args.from, _from);
  assert.equal(_logs[i + 1].args.to, _to);
  assert(_logs[i + 1].args.amount.eq(_amount));
  assert.equal(_logs[i + 1].args.data, _data);
  assert.equal(_logs[i + 1].args.operatorData, _operatorData);
};

const assertBurnEvent = (
  _logs,
  _fromTranche,
  _operator,
  _from,
  _amount,
  _data,
  _operatorData
) => {
  var i = 0;
  if (_logs.length === 3) {
    assert.equal(_logs[0].event, 'Checked');
    assert.equal(_logs[0].args.sender, _operator);
    i = 1;
  }

  assert.equal(_logs[i].event, 'Burned');
  assert.equal(_logs[i].args.operator, _operator);
  assert.equal(_logs[i].args.from, _from);
  assert(_logs[i].args.amount.eq(_amount));
  assert.equal(_logs[i].args.data, _data);
  assert.equal(_logs[i].args.operatorData, _operatorData);

  assert.equal(_logs[i + 1].event, 'RedeemedByTranche');
  assert.equal(_logs[i + 1].args.tranche, _fromTranche);
  assert.equal(_logs[i + 1].args.operator, _operator);
  assert.equal(_logs[i + 1].args.from, _from);
  assert(_logs[i + 1].args.amount.eq(_amount));
  assert.equal(_logs[i + 1].args.data, _data);
  assert.equal(_logs[i + 1].args.operatorData, _operatorData);
};

const assertBalances = async (
  _contract,
  _tokenHolder,
  _tranches,
  _amounts
) => {
  var totalBalance = 0;
  for (var i = 0; i < _tranches.length; i++) {
    totalBalance += _amounts[i];
    await assertBalanceOfByTranche(_contract, _tokenHolder, _tranches[i], _amounts[i]);
  }
  await assertBalance(_contract, _tokenHolder, totalBalance);
};

const assertBalanceOf = async (
  _contract,
  _tokenHolder,
  _tranche,
  _amount
) => {
  await assertBalance(_contract, _tokenHolder, _amount);
  await assertBalanceOfByTranche(_contract, _tokenHolder, _tranche, _amount);
};

const assertBalanceOfByTranche = async (
  _contract,
  _tokenHolder,
  _tranche,
  _amount
) => {
  balanceByTranche = await _contract.balanceOfByTranche(_tranche, _tokenHolder);
  assert.equal(balanceByTranche, _amount);
};

const assertBalance = async (
  _contract,
  _tokenHolder,
  _amount
) => {
  balance = await _contract.balanceOf(_tokenHolder);
  assert.equal(balance, _amount);
};

const assertTotalSupply = async (_contract, _amount) => {
  totalSupply = await _contract.totalSupply();
  assert.equal(totalSupply, _amount);
};

const assertEscResponse = async (
  _response,
  _escCode,
  _additionalCode,
  _destinationTranche
) => {
  assert.equal(_response[0], _escCode);
  assert.equal(_response[1], _additionalCode);
  assert.equal(_response[2], _destinationTranche);
};

const authorizeOperatorForTranches = async (
  _contract,
  _operator,
  _investor,
  _tranches
) => {
  for (var i = 0; i < _tranches.length; i++) {
    await _contract.authorizeOperatorByTranche(_tranches[i], _operator, { from: _investor });
  }
};

const issueOnMultipleTranches = async (
  _contract,
  _owner,
  _recipient,
  _tranches,
  _amounts
) => {
  for (var i = 0; i < _tranches.length; i++) {
    await _contract.issueByTranche(_tranches[i], _recipient, _amounts[i], VALID_CERTIFICATE, { from: _owner });
  }
};

contract('ERC1400', function ([owner, operator, defaultOperator, investor, recipient, unknown]) {
  describe('parameters', function () {
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

  // CANSEND

  describe('canSend', function () {
    var localGranularity = 10;
    const amount = 10 * localGranularity;

    before(async function () {
      this.registry = await ERC820Registry.at('0x820b586C8C28125366C998641B09DCbE7d4cBF06');

      this.senderContract = await ERC777TokensSender.new('ERC777TokensSender', { from: investor });
      await this.registry.setManager(investor, this.senderContract.address, { from: investor });
      await this.senderContract.setERC820Implementer({ from: investor });

      this.recipientContract = await ERC777TokensRecipient.new('ERC777TokensRecipient', { from: recipient });
      await this.registry.setManager(recipient, this.recipientContract.address, { from: recipient });
      await this.recipientContract.setERC820Implementer({ from: recipient });
    });

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1410Token', 'DAU', localGranularity, [defaultOperator], CERTIFICATE_SIGNER);
      await this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });

    describe('when certificate is valid', function () {
      describe('when balance is sufficient', function () {
        describe('when receiver is not the zero address', function () {
          describe('when sender is eligible', function () {
            describe('when receiver is eligible', function () {
              describe('when the amount is a multiple of the granularity', function () {
                it('returns Ethereum status code A2', async function () {
                  const response = await this.token.canSend(
                    tranche1, recipient, amount, VALID_CERTIFICATE, { from: investor });
                  await assertEscResponse(response, ESC_A2, EMPTY_BYTE32, tranche1);
                });
              });
              describe('when the amount is not a multiple of the granularity', function () {
                it('returns Ethereum status code A9', async function () {
                  const response = await this.token.canSend(
                    tranche1, recipient, 1, VALID_CERTIFICATE, { from: investor });
                  await assertEscResponse(response, ESC_A9, EMPTY_BYTE32, tranche1);
                });
              });
            });
            describe('when receiver is not eligible', function () {
              it('returns Ethereum status code A6', async function () {
                const response = await this.token.canSend(
                  tranche1, recipient, amount, INVALID_CERTIFICATE_RECIPIENT, { from: investor });
                await assertEscResponse(response, ESC_A6, EMPTY_BYTE32, tranche1);
              });
            });
          });
          describe('when sender is not eligible', function () {
            it('returns Ethereum status code A5', async function () {
              const response = await this.token.canSend(
                tranche1, recipient, amount, INVALID_CERTIFICATE_SENDER, { from: investor });
              await assertEscResponse(response, ESC_A5, EMPTY_BYTE32, tranche1);
            });
          });
        });
        describe('when receiver is the zero address', function () {
          it('returns Ethereum status code A6', async function () {
            const response = await this.token.canSend(
              tranche1, ZERO_ADDRESS, amount, VALID_CERTIFICATE, { from: investor });
            await assertEscResponse(response, ESC_A6, EMPTY_BYTE32, tranche1);
          });
        });
      });
      describe('when balance is not sufficient', function () {
        it('returns Ethereum status code A4 (insuficient global balance)', async function () {
          const response = await this.token.canSend(
            tranche1, recipient, issuanceAmount + localGranularity, VALID_CERTIFICATE, { from: investor });
          await assertEscResponse(response, ESC_A4, EMPTY_BYTE32, tranche1);
        });
        it('returns Ethereum status code A4 (insuficient tranche balance)', async function () {
          await this.token.issueByTranche(
            tranche2, investor, localGranularity, VALID_CERTIFICATE, { from: owner });
          const response = await this.token.canSend(
            tranche2, recipient, amount, VALID_CERTIFICATE, { from: investor });
          await assertEscResponse(response, ESC_A4, EMPTY_BYTE32, tranche2);
        });
      });
    });
    describe('when certificate is not valid', function () {
      it('returns Ethereum status code A3', async function () {
        const response = await this.token.canSend(
          tranche1, recipient, amount, INVALID_CERTIFICATE, { from: investor });
        await assertEscResponse(response, ESC_A3, EMPTY_BYTE32, tranche1);
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
        describe('when operator has not already been added', function () {
          it('adds the default operator', async function () {
            assert(await this.token.isControllable());
            assert(!(await this.token.isOperatorForTranche(tranche1, operator, investor)));
            await this.token.addDefaultOperatorByTranche(tranche1, operator, { from: owner });
            assert(await this.token.isOperatorForTranche(tranche1, operator, investor));
          });
        });
        describe('when operator has already been added', function () {
          it('reverts', async function () {
            await this.token.addDefaultOperatorByTranche(tranche1, operator, { from: owner });
            assert(await this.token.isOperatorForTranche(tranche1, operator, investor));

            await shouldFail.reverting(this.token.addDefaultOperatorByTranche(tranche1, operator, { from: owner }));
          });
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
    describe('when operator is the only default operator', function () {
      it('removes the default operator', async function () {
        assert(!(await this.token.isOperatorForTranche(tranche1, operator, investor)));
        await this.token.addDefaultOperatorByTranche(tranche1, operator, { from: owner });
        assert(await this.token.isOperatorForTranche(tranche1, operator, investor));
        await this.token.removeDefaultOperatorByTranche(tranche1, operator, { from: owner });
        assert(!(await this.token.isOperatorForTranche(tranche1, operator, investor)));
      });
    });
    describe('when operator is one of the default operators', function () {
      it('removes the default operator', async function () {
        assert(!(await this.token.isOperatorForTranche(tranche1, operator, investor)));
        await this.token.addDefaultOperatorByTranche(tranche1, operator, { from: owner });
        assert(await this.token.isOperatorForTranche(tranche1, operator, investor));
        await this.token.addDefaultOperatorByTranche(tranche1, unknown, { from: owner });
        assert(await this.token.isOperatorForTranche(tranche1, unknown, investor));
        await this.token.removeDefaultOperatorByTranche(tranche1, unknown, { from: owner });
        assert(!(await this.token.isOperatorForTranche(tranche1, unknown, investor)));
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
    const documentName = 'Document Name';
    const documentURI = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit,sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.'; // SHA-256 of documentURI
    const documentHash = '0x1c81c608a616183cc4a38c09ecc944eb77eaff465dd87aae0290177f2b70b6f8'; // SHA-256 of documentURI + '0x'

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

    describe('when sender is the minter', function () {
      describe('when token is issuable', function () {
        it('issues the requested amount', async function () {
          await this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: owner });

          await assertTotalSupply(this.token, issuanceAmount);
          await assertBalanceOf(this.token, investor, tranche1, issuanceAmount);
        });
        it('issues twice the requested amount', async function () {
          await this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: owner });
          await this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: owner });

          await assertTotalSupply(this.token, 2 * issuanceAmount);
          await assertBalanceOf(this.token, investor, tranche1, 2 * issuanceAmount);
        });
        it('emits a issuedByTranche event', async function () {
          const { logs } = await this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: owner });

          assert.equal(logs.length, 3);

          assert.equal(logs[0].event, 'Checked');
          assert.equal(logs[0].args.sender, owner);

          assert.equal(logs[1].event, 'Minted');
          assert.equal(logs[1].args.operator, owner);
          assert.equal(logs[1].args.to, investor);
          assert(logs[1].args.amount.eq(issuanceAmount));
          assert.equal(logs[1].args.data, VALID_CERTIFICATE);
          assert.equal(logs[1].args.operatorData, ZERO_BYTE);

          assert.equal(logs[2].event, 'IssuedByTranche');
          assert.equal(logs[2].args.tranche, tranche1);
          assert.equal(logs[2].args.operator, owner);
          assert.equal(logs[2].args.to, investor);
          assert(logs[2].args.amount.eq(issuanceAmount));
          assert.equal(logs[2].args.data, VALID_CERTIFICATE);
          assert.equal(logs[2].args.operatorData, ZERO_BYTE);
        });
      });
      describe('when token is not issuable', function () {
        it('reverts', async function () {
          assert(await this.token.isIssuable());
          await this.token.renounceIssuance({ from: owner });
          assert(!(await this.token.isIssuable()));
          await shouldFail.reverting(this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: owner }));
        });
      });
    });
    describe('when sender is not the minter', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: unknown }));
      });
    });
  });

  // REDEEMBYTRANCHE

  describe('redeemByTranche', function () {
    const redeemAmount = 300;

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });

    describe('when the redeemer has enough balance for this tranche', function () {
      it('redeems the requested amount', async function () {
        await this.token.redeemByTranche(tranche1, redeemAmount, VALID_CERTIFICATE, { from: investor });

        await assertTotalSupply(this.token, issuanceAmount - redeemAmount);
        await assertBalanceOf(this.token, investor, tranche1, issuanceAmount - redeemAmount);
      });
      it('emits a redeemedByTranche event', async function () {
        const { logs } = await this.token.redeemByTranche(tranche1, redeemAmount, VALID_CERTIFICATE, { from: investor });

        assert.equal(logs.length, 3);

        assertBurnEvent(logs, tranche1, investor, investor, redeemAmount, VALID_CERTIFICATE, ZERO_BYTE);
      });
    });
    describe('when the redeemer has enough balance for this tranche', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.redeemByTranche(tranche2, redeemAmount, VALID_CERTIFICATE, { from: investor }));
      });
    });
  });

  // OPERATOREDEEMBYTRANCHE

  describe('operatorRedeemByTranche', function () {
    const redeemAmount = 300;

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });

    describe('when the sender is an operator for this tranche', function () {
      describe('when the redeemer has enough balance for this tranche', function () {
        it('redeems the requested amount', async function () {
          await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
          await this.token.operatorRedeemByTranche(tranche1, investor, redeemAmount, '', VALID_CERTIFICATE, { from: operator });

          await assertTotalSupply(this.token, issuanceAmount - redeemAmount);
          await assertBalanceOf(this.token, investor, tranche1, issuanceAmount - redeemAmount);
        });
        it('emits a redeemedByTranche event', async function () {
          await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
          const { logs } = await this.token.operatorRedeemByTranche(tranche1, investor, redeemAmount, '', VALID_CERTIFICATE, { from: operator });

          assert.equal(logs.length, 3);

          assertBurnEvent(logs, tranche1, operator, investor, redeemAmount, ZERO_BYTE, VALID_CERTIFICATE);
        });
      });
      describe('when the redeemer does not have enough balance for this tranche', function () {
        it('reverts', async function () {
          it('redeems the requested amount', async function () {
            await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });

            await shouldFail.reverting(this.token.operatorRedeemByTranche(tranche1, investor, issuanceAmount + 1, '', VALID_CERTIFICATE, { from: operator }));
          });
        });
      });
    });
    describe('when the sender is a global operator', function () {
      it('redeems the requested amount', async function () {
        await this.token.authorizeOperator(operator, { from: investor });
        await this.token.operatorRedeemByTranche(tranche1, investor, redeemAmount, '', VALID_CERTIFICATE, { from: operator });

        await assertTotalSupply(this.token, issuanceAmount - redeemAmount);
        await assertBalanceOf(this.token, investor, tranche1, issuanceAmount - redeemAmount);
      });
    });
    describe('when the sender is not an operator', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.operatorRedeemByTranche(tranche1, investor, redeemAmount, '', VALID_CERTIFICATE, { from: operator }));
      });
    });
  });

  // SENDBYTRANCHE

  describe('sendByTranche', function () {
    const sendAmount = 300;

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });

    describe('when the sender has enough balance for this tranche', function () {
      it('sends the requested amount', async function () {
        await assertBalanceOf(this.token, investor, tranche1, issuanceAmount);
        await assertBalanceOf(this.token, recipient, tranche1, 0);

        await this.token.sendByTranche(tranche1, recipient, sendAmount, VALID_CERTIFICATE, { from: investor });
        await this.token.sendByTranche(tranche1, recipient, 0, VALID_CERTIFICATE, { from: investor });

        await assertBalanceOf(this.token, investor, tranche1, issuanceAmount - sendAmount);
        await assertBalanceOf(this.token, recipient, tranche1, sendAmount);
      });
      it('emits a sentByTranche event', async function () {
        const { logs } = await this.token.sendByTranche(tranche1, recipient, sendAmount, VALID_CERTIFICATE, { from: investor });

        assert.equal(logs.length, 3);

        assertSendEvent(logs, tranche1, investor, investor, recipient, sendAmount, VALID_CERTIFICATE, ZERO_BYTE);
      });
    });
    describe('when the sender does not have enough balance for this tranche', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.sendByTranche(tranche2, recipient, sendAmount, VALID_CERTIFICATE, { from: investor }));
      });
    });
  });

  // OPERATORSENDBYTRANCHE

  describe('operatorSendByTranche', function () {
    const sendAmount = 300;

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });

    describe('when the sender is an operator for this tranche', function () {
      describe('when the sender has enough balance for this tranche', function () {
        describe('when tranche does not change', function () {
          it('sends the requested amount (when sender is specified)', async function () {
            await assertBalanceOf(this.token, investor, tranche1, issuanceAmount);
            await assertBalanceOf(this.token, recipient, tranche1, 0);

            await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
            await this.token.operatorSendByTranche(tranche1, investor, recipient, sendAmount, '', VALID_CERTIFICATE, { from: operator });

            await assertBalanceOf(this.token, investor, tranche1, issuanceAmount - sendAmount);
            await assertBalanceOf(this.token, recipient, tranche1, sendAmount);
          });
          it('sends the requested amount (when sender is not specified)', async function () {
            await assertBalanceOf(this.token, investor, tranche1, issuanceAmount);
            await assertBalanceOf(this.token, recipient, tranche1, 0);

            await this.token.operatorSendByTranche(tranche1, ZERO_ADDRESS, recipient, sendAmount, '', VALID_CERTIFICATE, { from: investor });

            await assertBalanceOf(this.token, investor, tranche1, issuanceAmount - sendAmount);
            await assertBalanceOf(this.token, recipient, tranche1, sendAmount);
          });
          it('emits a sentByTranche event', async function () {
            await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
            const { logs } = await this.token.operatorSendByTranche(tranche1, investor, recipient, sendAmount, '', VALID_CERTIFICATE, { from: operator });

            assert.equal(logs.length, 3);

            assertSendEvent(logs, tranche1, operator, investor, recipient, sendAmount, ZERO_BYTE, VALID_CERTIFICATE);
          });
        });
        describe('when tranche changes', function () {
          it('sends the requested amount', async function () {
            await assertBalanceOf(this.token, investor, tranche1, issuanceAmount);
            await assertBalanceOf(this.token, recipient, tranche2, 0);

            await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
            await this.token.operatorSendByTranche(tranche1, investor, recipient, sendAmount, tranche2, VALID_CERTIFICATE, { from: operator });

            await assertBalanceOf(this.token, investor, tranche1, issuanceAmount - sendAmount);
            await assertBalanceOf(this.token, recipient, tranche2, sendAmount);
          });
          it('converts the requested amount (when sender is specified)', async function () {
            await assertBalance(this.token, investor, issuanceAmount);
            await assertBalanceOfByTranche(this.token, investor, tranche1, issuanceAmount);
            await assertBalanceOfByTranche(this.token, investor, tranche2, 0);

            await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
            await this.token.operatorSendByTranche(tranche1, investor, investor, sendAmount, tranche2, VALID_CERTIFICATE, { from: operator });

            await assertBalance(this.token, investor, issuanceAmount);
            await assertBalanceOfByTranche(this.token, investor, tranche1, issuanceAmount - sendAmount);
            await assertBalanceOfByTranche(this.token, investor, tranche2, sendAmount);
          });
          it('converts the requested amount (when sender is not specified)', async function () {
            await assertBalance(this.token, investor, issuanceAmount);
            await assertBalanceOfByTranche(this.token, investor, tranche1, issuanceAmount);
            await assertBalanceOfByTranche(this.token, investor, tranche2, 0);

            await this.token.operatorSendByTranche(tranche1, ZERO_ADDRESS, investor, sendAmount, tranche2, VALID_CERTIFICATE, { from: investor });

            await assertBalance(this.token, investor, issuanceAmount);
            await assertBalanceOfByTranche(this.token, investor, tranche1, issuanceAmount - sendAmount);
            await assertBalanceOfByTranche(this.token, investor, tranche2, sendAmount);
          });
          it('emits a changedTranche event', async function () {
            await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
            const { logs } = await this.token.operatorSendByTranche(tranche1, investor, recipient, sendAmount, tranche2, VALID_CERTIFICATE, { from: operator });

            assert.equal(logs.length, 4);

            assertSendEvent([logs[0], logs[1], logs[2]], tranche1, operator, investor, recipient, sendAmount, tranche2, VALID_CERTIFICATE);

            assert.equal(logs[3].event, 'ChangedTranche');
            assert.equal(logs[3].args.fromTranche, tranche1);
            assert.equal(logs[3].args.toTranche, tranche2);
            assert(logs[3].args.amount.eq(sendAmount));
          });
        });
      });
      describe('when the sender does not have enough balance for this tranche', function () {
        it('reverts', async function () {
          await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
          await shouldFail.reverting(this.token.operatorSendByTranche(tranche1, investor, recipient, issuanceAmount + 1, '', VALID_CERTIFICATE, { from: operator }));
        });
      });
    });
    describe('when the sender is a global operator', function () {
      it('redeems the requested amount', async function () {
        await assertBalanceOf(this.token, investor, tranche1, issuanceAmount);
        await assertBalanceOf(this.token, recipient, tranche1, 0);

        await this.token.authorizeOperator(operator, { from: investor });
        await this.token.operatorSendByTranche(tranche1, investor, recipient, sendAmount, '', VALID_CERTIFICATE, { from: operator });

        await assertBalanceOf(this.token, investor, tranche1, issuanceAmount - sendAmount);
        await assertBalanceOf(this.token, recipient, tranche1, sendAmount);
      });
    });
    describe('when the sender is not an operator', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.operatorSendByTranche(tranche1, investor, recipient, sendAmount, '', VALID_CERTIFICATE, { from: operator }));
      });
    });
  });

  // SENDBYTRANCHES - MULTIPLE TRANCHES

  describe('sendByTranches - multiple tranches', function () {
    const sendAmount1 = 300;
    const sendAmount2 = 243;
    const sendAmount3 = 671;
    const sendAmounts = [sendAmount1, sendAmount2, sendAmount3];

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await issueOnMultipleTranches(this.token, owner, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);
    });

    describe('when the number of amounts matches the number of tranches', function () {
      describe('when the sender has enough balance for those tranches', function () {
        it('sends the requested amounts', async function () {
          await assertBalances(this.token, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);
          await assertBalances(this.token, recipient, tranches, [0, 0, 0]);

          await this.token.sendByTranches(tranches, recipient, sendAmounts, VALID_CERTIFICATE, { from: investor });

          await assertBalances(this.token, investor, tranches, [
            issuanceAmount - sendAmount1,
            issuanceAmount - sendAmount2,
            issuanceAmount - sendAmount3]
          );
          await assertBalances(this.token, recipient, tranches, [sendAmount1, sendAmount2, sendAmount3]);
        });
        it('emits sentByTranches events', async function () {
          const { logs } = await this.token.sendByTranches(tranches, recipient, sendAmounts, VALID_CERTIFICATE, { from: investor });

          assert.equal(logs.length, 1 + 2 * sendAmounts.length);

          assertSendEvent([logs[0], logs[1], logs[2]], tranches[0], investor, investor, recipient, sendAmounts[0], VALID_CERTIFICATE, ZERO_BYTE);
          assertSendEvent([logs[3], logs[4]], tranches[1], investor, investor, recipient, sendAmounts[1], VALID_CERTIFICATE, ZERO_BYTE);
          assertSendEvent([logs[5], logs[6]], tranches[2], investor, investor, recipient, sendAmounts[2], VALID_CERTIFICATE, ZERO_BYTE);
        });
      });
      describe('when the sender does not have enough balance for those tranches', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.sendByTranches(tranches, recipient, [sendAmount1, issuanceAmount + 1, sendAmount3], VALID_CERTIFICATE, { from: investor }));
        });
      });
    });
    describe('when the number of amounts does not match the number of tranches', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.sendByTranches(tranches, recipient, [sendAmount1, sendAmount2], VALID_CERTIFICATE, { from: investor }));
      });
    });
  });

  // OPERATORSENDBYTRANCHES - MULTIPLE TRANCHES

  describe('operatorSendByTranches - multiple tranches', function () {
    const sendAmount1 = 300;
    const sendAmount2 = 243;
    const sendAmount3 = 671;
    const sendAmounts = [sendAmount1, sendAmount2, sendAmount3];

    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await issueOnMultipleTranches(this.token, owner, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);
    });

    describe('when the number of amounts matches the number of tranches', function () {
      describe('when the sender is an operator for all tranches', function () {
        describe('when the sender has enough balance for those tranches', function () {
          it('sends the requested amounts (when sender is specified)', async function () {
            await assertBalances(this.token, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);
            await assertBalances(this.token, recipient, tranches, [0, 0, 0]);

            await authorizeOperatorForTranches(this.token, operator, investor, tranches);
            await this.token.operatorSendByTranches(tranches, investor, recipient, sendAmounts, '', VALID_CERTIFICATE, { from: operator });

            await assertBalances(this.token, investor, tranches, [
              issuanceAmount - sendAmount1,
              issuanceAmount - sendAmount2,
              issuanceAmount - sendAmount3]
            );
            await assertBalances(this.token, recipient, tranches, sendAmounts);
          });
          it('sends the requested amounts (when sender is not specified)', async function () {
            await assertBalances(this.token, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);
            await assertBalances(this.token, recipient, tranches, [0, 0, 0]);

            await this.token.operatorSendByTranches(tranches, ZERO_ADDRESS, recipient, sendAmounts, '', VALID_CERTIFICATE, { from: investor });

            await assertBalances(this.token, investor, tranches, [
              issuanceAmount - sendAmount1,
              issuanceAmount - sendAmount2,
              issuanceAmount - sendAmount3]
            );
            await assertBalances(this.token, recipient, tranches, sendAmounts);
          });
          it('emits sentByTranches events', async function () {
            await authorizeOperatorForTranches(this.token, operator, investor, tranches);
            const { logs } = await this.token.operatorSendByTranches(tranches, investor, recipient, sendAmounts, '', VALID_CERTIFICATE, { from: operator });

            assert.equal(logs.length, 1 + 2 * sendAmounts.length);

            assertSendEvent([logs[0], logs[1], logs[2]], tranches[0], operator, investor, recipient, sendAmounts[0], ZERO_BYTE, VALID_CERTIFICATE);
            assertSendEvent([logs[3], logs[4]], tranches[1], operator, investor, recipient, sendAmounts[1], ZERO_BYTE, VALID_CERTIFICATE);
            assertSendEvent([logs[5], logs[6]], tranches[2], operator, investor, recipient, sendAmounts[2], ZERO_BYTE, VALID_CERTIFICATE);
          });
        });
        describe('when the sender does not have enough balance for those tranches', function () {
          it('reverts', async function () {
            await authorizeOperatorForTranches(this.token, operator, investor, tranches);
            await shouldFail.reverting(this.token.operatorSendByTranches(tranches, investor, recipient, [sendAmount1, issuanceAmount + 1, sendAmount3], '', VALID_CERTIFICATE, { from: operator }));
          });
        });
      });
      describe('when the sender is a global operator', function () {
        it('sends the requested amounts', async function () {
          await assertBalances(this.token, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);
          await assertBalances(this.token, recipient, tranches, [0, 0, 0]);

          await this.token.authorizeOperator(operator, { from: investor });
          await this.token.operatorSendByTranches(tranches, investor, recipient, sendAmounts, '', VALID_CERTIFICATE, { from: operator });

          await assertBalances(this.token, investor, tranches, [
            issuanceAmount - sendAmount1,
            issuanceAmount - sendAmount2,
            issuanceAmount - sendAmount3]
          );
          await assertBalances(this.token, recipient, tranches, [sendAmount1, sendAmount2, sendAmount3]);
        });
      });
      describe('when the sender is not an operator for all tranches', function () {
        it('reverts', async function () {
          await this.token.authorizeOperatorByTranche(tranche1, operator, { from: investor });
          await this.token.authorizeOperatorByTranche(tranche2, operator, { from: investor });
          await shouldFail.reverting(this.token.operatorSendByTranches(tranches, investor, recipient, sendAmounts, '', VALID_CERTIFICATE, { from: operator }));
        });
      });
    });
    describe('when the number of amounts does not match the number of tranches', function () {
      it('reverts', async function () {
        await authorizeOperatorForTranches(this.token, operator, investor, tranches);
        await shouldFail.reverting(this.token.operatorSendByTranches(tranches, investor, recipient, [sendAmount1, sendAmount2], '', VALID_CERTIFICATE, { from: operator }));
      });
    });
  });

  // TRANCHESOF

  describe('tranchesOf', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });
    describe('when investor owes no tokens', function () {
      it('returns empty list', async function () {
        const tranchesOf = await this.token.tranchesOf(investor);
        assert.equal(tranchesOf.length, 0);
      });
    });
    describe('when investor owes tokens of 1 tranche', function () {
      it('returns tranche', async function () {
        await this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: owner });
        const tranchesOf = await this.token.tranchesOf(investor);
        assert.equal(tranchesOf.length, 1);
        assert.equal(tranchesOf[0], tranche1);
      });
    });
    describe('when investor owes tokens of 3 tranches', function () {
      it('returns list of 3 tranches', async function () {
        await issueOnMultipleTranches(this.token, owner, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);
        const tranchesOf = await this.token.tranchesOf(investor);
        assert.equal(tranchesOf.length, 3);
        assert.equal(tranchesOf[0], tranche1);
        assert.equal(tranchesOf[1], tranche2);
        assert.equal(tranchesOf[2], tranche3);
      });
    });
  });

  // TOTALTRANCHES

  describe('totalTranches', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
    });
    describe('when no tokens are issued', function () {
      it('returns empty list', async function () {
        const tranchesOf = await this.token.totalTranches();
        assert.equal(tranchesOf.length, 0);
      });
    });
    describe('when tokens are issued for 1 tranche', function () {
      it('returns tranche', async function () {
        await this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: owner });
        const tranchesOf = await this.token.totalTranches();
        assert.equal(tranchesOf.length, 1);
        assert.equal(tranchesOf[0], tranche1);
      });
    });
    describe('when tokens are issued for 3 tranches', function () {
      it('returns list of 3 tranches', async function () {
        await this.token.issueByTranche(tranche1, investor, issuanceAmount, VALID_CERTIFICATE, { from: owner });
        await this.token.issueByTranche(tranche2, recipient, issuanceAmount, VALID_CERTIFICATE, { from: owner });
        await this.token.issueByTranche(tranche3, unknown, issuanceAmount, VALID_CERTIFICATE, { from: owner });
        const tranchesOf = await this.token.totalTranches();
        assert.equal(tranchesOf.length, 3);
        assert.equal(tranchesOf[0], tranche1);
        assert.equal(tranchesOf[1], tranche2);
        assert.equal(tranchesOf[2], tranche3);
      });
    });
  });

  // SENDTO

  describe('sendTo', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await issueOnMultipleTranches(this.token, owner, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);
    });
    describe('when defaultTranches have been defined', function () {
      describe('when the sender has enough balance for those defaultTanches', function () {
        it('transfers the requested amount', async function () {
          await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
          await assertBalances(this.token, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);

          await this.token.sendTo(recipient, 2.5 * issuanceAmount, VALID_CERTIFICATE, { from: investor });

          await assertBalances(this.token, investor, tranches, [0, 0.5 * issuanceAmount, 0]);
          await assertBalances(this.token, recipient, tranches, [issuanceAmount, 0.5 * issuanceAmount, issuanceAmount]);
        });
        it('emits a sent event', async function () {
          await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
          const { logs } = await this.token.sendTo(recipient, 2.5 * issuanceAmount, VALID_CERTIFICATE, { from: investor });

          assert.equal(logs.length, 1 + 2 * tranches.length);

          assertSendEvent([logs[0], logs[1], logs[2]], tranche3, investor, investor, recipient, issuanceAmount, VALID_CERTIFICATE, ZERO_BYTE);
          assertSendEvent([logs[3], logs[4]], tranche1, investor, investor, recipient, issuanceAmount, VALID_CERTIFICATE, ZERO_BYTE);
          assertSendEvent([logs[5], logs[6]], tranche2, investor, investor, recipient, 0.5 * issuanceAmount, VALID_CERTIFICATE, ZERO_BYTE);
        });
      });
      describe('when the sender does not have enough balance for those defaultTanches', function () {
        it('reverts', async function () {
          await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
          await shouldFail.reverting(this.token.sendTo(recipient, 3.5 * issuanceAmount, VALID_CERTIFICATE, { from: investor }));
        });
      });
    });
    describe('when defaultTranches have not been defined', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.sendTo(recipient, 2.5 * issuanceAmount, VALID_CERTIFICATE, { from: investor }));
      });
    });
  });

  // OPERATORSENDTO

  describe('operatorSendTo', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await issueOnMultipleTranches(this.token, owner, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);
    });
    describe('when the operator is approved', function () {
      beforeEach(async function () {
        await this.token.authorizeOperator(operator, { from: investor });
      });
      describe('when defaultTranches have been defined', function () {
        describe('when the sender has enough balance for those defaultTanches', function () {
          it('transfers the requested amount (when sender is specified)', async function () {
            await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
            await assertBalances(this.token, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);

            await this.token.operatorSendTo(investor, recipient, 2.5 * issuanceAmount, '', VALID_CERTIFICATE, { from: operator });

            await assertBalances(this.token, investor, tranches, [0, 0.5 * issuanceAmount, 0]);
            await assertBalances(this.token, recipient, tranches, [issuanceAmount, 0.5 * issuanceAmount, issuanceAmount]);
          });
          it('transfers the requested amount (when sender is not specified)', async function () {
            await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
            await assertBalances(this.token, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);

            await this.token.operatorSendTo(ZERO_ADDRESS, recipient, 2.5 * issuanceAmount, '', VALID_CERTIFICATE, { from: investor });

            await assertBalances(this.token, investor, tranches, [0, 0.5 * issuanceAmount, 0]);
            await assertBalances(this.token, recipient, tranches, [issuanceAmount, 0.5 * issuanceAmount, issuanceAmount]);
          });
          it('emits a sent event', async function () {
            await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
            const { logs } = await this.token.operatorSendTo(investor, recipient, 2.5 * issuanceAmount, '', VALID_CERTIFICATE, { from: operator });

            assert.equal(logs.length, 1 + 2 * tranches.length);

            assertSendEvent([logs[0], logs[1], logs[2]], tranche3, operator, investor, recipient, issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE);
            assertSendEvent([logs[3], logs[4]], tranche1, operator, investor, recipient, issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE);
            assertSendEvent([logs[5], logs[6]], tranche2, operator, investor, recipient, 0.5 * issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE);
          });
        });
        describe('when the sender does not have enough balance for those defaultTanches', function () {
          it('reverts', async function () {
            await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
            await shouldFail.reverting(this.token.operatorSendTo(investor, recipient, 3.5 * issuanceAmount, '', VALID_CERTIFICATE, { from: operator }));
          });
        });
      });
      describe('when defaultTranches have not been defined', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.operatorSendTo(investor, recipient, 2.5 * issuanceAmount, '', VALID_CERTIFICATE, { from: operator }));
        });
      });
    });
    describe('when the operator is not approved', function () {
      it('reverts', async function () {
        await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
        await shouldFail.reverting(this.token.operatorSendTo(investor, recipient, 2.5 * issuanceAmount, '', VALID_CERTIFICATE, { from: operator }));
      });
    });
  });

  // BURN

  describe('burn', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await issueOnMultipleTranches(this.token, owner, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);
    });
    describe('when defaultTranches have been defined', function () {
      describe('when the sender has enough balance for those defaultTanches', function () {
        it('redeeems the requested amount', async function () {
          await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
          await assertBalances(this.token, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);

          await this.token.burn(2.5 * issuanceAmount, VALID_CERTIFICATE, { from: investor });

          await assertBalances(this.token, investor, tranches, [0, 0.5 * issuanceAmount, 0]);
        });
        it('emits a redeemedByTranche events', async function () {
          await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
          const { logs } = await this.token.burn(2.5 * issuanceAmount, VALID_CERTIFICATE, { from: investor });

          assert.equal(logs.length, 1 + 2 * tranches.length);

          assertBurnEvent([logs[0], logs[1], logs[2]], tranche3, investor, investor, issuanceAmount, VALID_CERTIFICATE, ZERO_BYTE);
          assertBurnEvent([logs[3], logs[4]], tranche1, investor, investor, issuanceAmount, VALID_CERTIFICATE, ZERO_BYTE);
          assertBurnEvent([logs[5], logs[6]], tranche2, investor, investor, 0.5 * issuanceAmount, VALID_CERTIFICATE, ZERO_BYTE);
        });
      });
      describe('when the sender does not have enough balance for those defaultTanches', function () {
        it('reverts', async function () {
          await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
          await shouldFail.reverting(this.token.burn(3.5 * issuanceAmount, VALID_CERTIFICATE, { from: investor }));
        });
      });
    });
    describe('when defaultTranches have not been defined', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.burn(2.5 * issuanceAmount, VALID_CERTIFICATE, { from: investor }));
      });
    });
  });

  // OPERATORBURN

  describe('operatorBurn', function () {
    beforeEach(async function () {
      this.token = await ERC1400.new('ERC1400Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER);
      await issueOnMultipleTranches(this.token, owner, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);
    });
    describe('when the operator is approved', function () {
      beforeEach(async function () {
        await this.token.authorizeOperator(operator, { from: investor });
      });
      describe('when defaultTranches have been defined', function () {
        describe('when the sender has enough balance for those defaultTanches', function () {
          it('redeems the requested amount (when sender is specified)', async function () {
            await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
            await assertBalances(this.token, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);

            await this.token.operatorBurn(investor, 2.5 * issuanceAmount, '', VALID_CERTIFICATE, { from: operator });

            await assertBalances(this.token, investor, tranches, [0, 0.5 * issuanceAmount, 0]);
          });
          it('redeems the requested amount (when sender is not specified)', async function () {
            await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
            await assertBalances(this.token, investor, tranches, [issuanceAmount, issuanceAmount, issuanceAmount]);

            await this.token.operatorBurn(ZERO_ADDRESS, 2.5 * issuanceAmount, '', VALID_CERTIFICATE, { from: investor });

            await assertBalances(this.token, investor, tranches, [0, 0.5 * issuanceAmount, 0]);
          });
          it('emits redeemedByTranche events', async function () {
            await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
            const { logs } = await this.token.operatorBurn(investor, 2.5 * issuanceAmount, '', VALID_CERTIFICATE, { from: operator });

            assert.equal(logs.length, 1 + 2 * tranches.length);

            assertBurnEvent([logs[0], logs[1], logs[2]], tranche3, operator, investor, issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE);
            assertBurnEvent([logs[3], logs[4]], tranche1, operator, investor, issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE);
            assertBurnEvent([logs[5], logs[6]], tranche2, operator, investor, 0.5 * issuanceAmount, ZERO_BYTE, VALID_CERTIFICATE);
          });
        });
        describe('when the sender does not have enough balance for those defaultTanches', function () {
          it('reverts', async function () {
            await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
            await shouldFail.reverting(this.token.operatorBurn(investor, 3.5 * issuanceAmount, '', VALID_CERTIFICATE, { from: operator }));
          });
        });
      });
      describe('when defaultTranches have not been defined', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.operatorBurn(investor, 2.5 * issuanceAmount, '', VALID_CERTIFICATE, { from: operator }));
        });
      });
    });
    describe('when the operator is not approved', function () {
      it('reverts', async function () {
        await this.token.setDefaultTranches([tranche3, tranche1, tranche2], { from: investor });
        await shouldFail.reverting(this.token.operatorBurn(investor, 2.5 * issuanceAmount, '', VALID_CERTIFICATE, { from: operator }));
      });
    });
  });

  // ERC1410 - BURN

  describe('ERC1410 - burn', function () {
    beforeEach(async function () {
      this.token = await ERC1410.new('ERC1410Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER, investor, 1000);
    });
    it('burn function is disactivated', async function () {
      await assertBalance(this.token, investor, 1000);
      await this.token.burn(500, VALID_CERTIFICATE, { from: investor });
      await assertBalance(this.token, investor, 1000);
    });
  });

  // ERC1410 - OPERATORBURN

  describe('ERC1410 - operatorBurn', function () {
    beforeEach(async function () {
      this.token = await ERC1410.new('ERC1410Token', 'DAU', 1, [defaultOperator], CERTIFICATE_SIGNER, investor, 1000);
    });
    it('operatorBurn function is disactivated', async function () {
      await this.token.authorizeOperator(operator, { from: investor });

      await assertBalance(this.token, investor, 1000);
      await this.token.operatorBurn(investor, 500, '', VALID_CERTIFICATE, { from: operator });
      await assertBalance(this.token, investor, 1000);
    });
  });
});
