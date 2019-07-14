import { shouldFail } from 'openzeppelin-test-helpers';

const ERC1400ERC20 = artifacts.require('ERC1400ERC20');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTE = '0x';

const CERTIFICATE_SIGNER = '0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630';

const VALID_CERTIFICATE = '0x1000000000000000000000000000000000000000000000000000000000000000';

const partition1 = '0x5265736572766564000000000000000000000000000000000000000000000000'; // Reserved in hex
const partition2 = '0x4973737565640000000000000000000000000000000000000000000000000000'; // Issued in hex
const partition3 = '0x4c6f636b65640000000000000000000000000000000000000000000000000000'; // Locked in hex
const partitions = [partition1, partition2, partition3];

const issuanceAmount = 1000000;

var totalSupply;
var balance;
var balanceByPartition;

const assertBalanceOf = async (
  _contract,
  _tokenHolder,
  _partition,
  _amount
) => {
  await assertBalance(_contract, _tokenHolder, _amount);
  await assertBalanceOfByPartition(_contract, _tokenHolder, _partition, _amount);
};

const assertBalance = async (
  _contract,
  _tokenHolder,
  _amount
) => {
  balance = await _contract.balanceOf(_tokenHolder);
  assert.equal(balance, _amount);
};

const assertBalanceOfByPartition = async (
  _contract,
  _tokenHolder,
  _partition,
  _amount
) => {
  balanceByPartition = await _contract.balanceOfByPartition(_partition, _tokenHolder);
  assert.equal(balanceByPartition, _amount);
};

const assertTotalSupply = async (_contract, _amount) => {
  totalSupply = await _contract.totalSupply();
  assert.equal(totalSupply, _amount);
};

contract('ERC1400ERC20', function ([owner, operator, controller, tokenHolder, recipient, unknown]) {
  beforeEach(async function () {
    this.token = await ERC1400ERC20.new('ERC1400ERC20Token', 'DAU20', 1, [controller], CERTIFICATE_SIGNER, partitions);
  });

  // SETWHITELISTED

  describe('setWhitelisted', function () {
    describe('when sender is a controller', function () {
      describe('when targeted address is not the zero address', function () {
        it('adds/removes the address from whitelist', async function () {
          assert(!(await this.token.whitelisted(tokenHolder)));
          await this.token.setWhitelisted(tokenHolder, true, { from: controller });
          assert(await this.token.whitelisted(tokenHolder));
          await this.token.setWhitelisted(tokenHolder, false, { from: controller });
          assert(!(await this.token.whitelisted(tokenHolder)));
        });
      });
      describe('when targeted address is the zero address', function () {
        it('reverts', async function () {
          await shouldFail.reverting(this.token.setWhitelisted(ZERO_ADDRESS, true, { from: controller }));
        });
      });
    });
    describe('when sender is not a controller', function () {
      it('reverts', async function () {
        await shouldFail.reverting(this.token.setWhitelisted(tokenHolder, true, { from: unknown }));
      });
    });
  });

  // TRANSFERWITHDATA

  describe('transferWithData', function () {
    const to = recipient;
    const amount = 10;
    beforeEach(async function () {
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });
    it('transfers the requested amount', async function () {
      await this.token.transferWithData(to, amount, VALID_CERTIFICATE, { from: tokenHolder });
      const senderBalance = await this.token.balanceOf(tokenHolder);
      assert.equal(senderBalance, issuanceAmount - amount);

      const recipientBalance = await this.token.balanceOf(to);
      assert.equal(recipientBalance, amount);
    });

    it('emits a Transfer event', async function () {
      const { logs } = await this.token.transferWithData(to, amount, VALID_CERTIFICATE, { from: tokenHolder });

      assert.equal(logs.length, 4);

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

      assert.equal(logs[3].event, 'TransferByPartition');
      assert.equal(logs[3].args.operator, tokenHolder);
      assert.equal(logs[3].args.to, to);
      assert.equal(logs[3].args.value, amount);
      assert.equal(logs[3].args.data, VALID_CERTIFICATE);
      assert.equal(logs[3].args.operatorData, null);
    });
  });

  // REDEEM

  describe('redeem', function () {
    const redeemAmount = 300;
    beforeEach(async function () {
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });
    it('redeems the requested amount', async function () {
      await this.token.redeemByPartition(partition1, redeemAmount, VALID_CERTIFICATE, { from: tokenHolder });

      await assertTotalSupply(this.token, issuanceAmount - redeemAmount);
      await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount - redeemAmount);
    });
    it('emits a Transfer event', async function () {
      const { logs } = await this.token.redeemByPartition(partition1, redeemAmount, VALID_CERTIFICATE, { from: tokenHolder });

      assert.equal(logs.length, 4);

      assert.equal(logs[0].event, 'Checked');
      assert.equal(logs[0].args.sender, tokenHolder);

      assert.equal(logs[1].event, 'Redeemed');
      assert.equal(logs[1].args.operator, tokenHolder);
      assert.equal(logs[1].args.from, tokenHolder);
      assert.equal(logs[1].args.value, redeemAmount);
      assert.equal(logs[1].args.data, VALID_CERTIFICATE);
      assert.equal(logs[1].args.operatorData, null);

      assert.equal(logs[2].event, 'Transfer');
      assert.equal(logs[2].args.from, tokenHolder);
      assert.equal(logs[2].args.to, ZERO_ADDRESS);
      assert.equal(logs[2].args.value, redeemAmount);

      assert.equal(logs[3].event, 'RedeemedByPartition');
      assert.equal(logs[3].args.partition, partition1);
      assert.equal(logs[3].args.operator, tokenHolder);
      assert.equal(logs[3].args.from, tokenHolder);
      assert.equal(logs[3].args.value, redeemAmount);
      assert.equal(logs[3].args.data, VALID_CERTIFICATE);
      assert.equal(logs[3].args.operatorData, null);
    });

  });

  // ISSUE

  describe('issue', function () {
    it('issues the requested amount', async function () {
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });

      await assertTotalSupply(this.token, issuanceAmount);
      await assertBalanceOf(this.token, tokenHolder, partition1, issuanceAmount);
    });
    it('emits a Transfer event', async function () {
      const { logs } = await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });

      assert.equal(logs.length, 4);

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

      assert.equal(logs[3].event, 'IssuedByPartition');
      assert.equal(logs[3].args.partition, partition1);
      assert.equal(logs[3].args.operator, owner);
      assert.equal(logs[3].args.to, tokenHolder);
      assert.equal(logs[3].args.value, issuanceAmount);
      assert.equal(logs[3].args.data, VALID_CERTIFICATE);
      assert.equal(logs[3].args.operatorData, null);
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
      await this.token.setWhitelisted(tokenHolder, true, { from: controller });
      await this.token.setWhitelisted(to, true, { from: controller });
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });

    describe('when the sender and the recipient are whitelisted', function () {
      describe('when the amount is a multiple of the granularity', function () {
        describe('when the recipient is not the zero address', function () {
          describe('when the sender does not have enough balance', function () {
            const amount = issuanceAmount + 1;

            it('reverts', async function () {
              await shouldFail.reverting(this.token.transfer(to, amount, { from: tokenHolder }));
            });
          });

          describe('when the sender has enough balance', function () {
            const amount = issuanceAmount;

            it('transfers the requested amount', async function () {
              await this.token.transfer(to, amount, { from: tokenHolder });
              const senderBalance = await this.token.balanceOf(tokenHolder);
              assert.equal(senderBalance, issuanceAmount - amount);

              const recipientBalance = await this.token.balanceOf(to);
              assert.equal(recipientBalance, amount);
            });

            it('emits a Transfer event', async function () {
              const { logs } = await this.token.transfer(to, amount, { from: tokenHolder });

              assert.equal(logs.length, 3);

              assert.equal(logs[0].event, 'TransferWithData');
              assert.equal(logs[0].args.operator, tokenHolder);
              assert.equal(logs[0].args.from, tokenHolder);
              assert.equal(logs[0].args.to, to);
              assert.equal(logs[0].args.value, amount);
              assert.equal(logs[0].args.data, null);
              assert.equal(logs[0].args.operatorData, null);

              assert.equal(logs[1].event, 'Transfer');
              assert.equal(logs[1].args.from, tokenHolder);
              assert.equal(logs[1].args.to, to);
              assert.equal(logs[1].args.value, amount);

              assert.equal(logs[2].event, 'TransferByPartition');
              assert.equal(logs[2].args.fromPartition, partition1);
              assert.equal(logs[2].args.operator, tokenHolder);
              assert.equal(logs[2].args.from, tokenHolder);
              assert.equal(logs[2].args.to, to);
              assert.equal(logs[2].args.value, amount);
              assert.equal(logs[2].args.data, null);
              assert.equal(logs[2].args.operatorData, null);
            });
          });
        });

        describe('when the recipient is the zero address', function () {
          const amount = issuanceAmount;
          const to = ZERO_ADDRESS;

          it('reverts', async function () {
            await shouldFail.reverting(this.token.transfer(to, amount, { from: tokenHolder }));
          });
        });
      });
      describe('when the amount is not a multiple of the granularity', function () {
        it('reverts', async function () {
          this.token = await ERC1400ERC20.new('ERC1400RawToken', 'DAU', 2, [], CERTIFICATE_SIGNER, partitions);
          await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
          await shouldFail.reverting(this.token.transfer(to, 3, { from: tokenHolder }));
        });
      });
    });
    describe('when the sender is not whitelisted', function () {
      const amount = issuanceAmount;

      it('reverts', async function () {
        await this.token.setWhitelisted(tokenHolder, false, { from: controller });
        await shouldFail.reverting(this.token.transfer(to, amount, { from: tokenHolder }));
      });
    });
    describe('when the recipient is not whitelisted', function () {
      const amount = issuanceAmount;

      it('reverts', async function () {
        await this.token.setWhitelisted(to, false, { from: controller });
        await shouldFail.reverting(this.token.transfer(to, amount, { from: tokenHolder }));
      });
    });
  });

  // TRANSFERFROM

  describe('transferFrom', function () {
    const to = recipient;
    const approvedAmount = 10000;
    beforeEach(async function () {
      await this.token.setWhitelisted(tokenHolder, true, { from: controller });
      await this.token.setWhitelisted(to, true, { from: controller });
      await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
    });

    describe('when the sender and the recipient are whitelisted', function () {
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

            describe('when the sender has enough balance', function () {
              const amount = 500;

              it('transfers the requested amount', async function () {
                await this.token.transferFrom(tokenHolder, to, amount, { from: operator });
                const senderBalance = await this.token.balanceOf(tokenHolder);
                assert.equal(senderBalance, issuanceAmount - amount);

                const recipientBalance = await this.token.balanceOf(to);
                assert.equal(recipientBalance, amount);

                assert.equal(await this.token.allowance(tokenHolder, operator), approvedAmount - amount);
              });

              it('emits a sent + a transfer event', async function () {
                const { logs } = await this.token.transferFrom(tokenHolder, to, amount, { from: operator });

                assert.equal(logs.length, 3);

                assert.equal(logs[0].event, 'TransferWithData');
                assert.equal(logs[0].args.operator, operator);
                assert.equal(logs[0].args.from, tokenHolder);
                assert.equal(logs[0].args.to, to);
                assert.equal(logs[0].args.value, amount);
                assert.equal(logs[0].args.data, null);
                assert.equal(logs[0].args.operatorData, null);

                assert.equal(logs[1].event, 'Transfer');
                assert.equal(logs[1].args.from, tokenHolder);
                assert.equal(logs[1].args.to, to);
                assert.equal(logs[1].args.value, amount);

                assert.equal(logs[2].event, 'TransferByPartition');
                assert.equal(logs[2].args.fromPartition, partition1);
                assert.equal(logs[2].args.operator, operator);
                assert.equal(logs[2].args.from, tokenHolder);
                assert.equal(logs[2].args.to, to);
                assert.equal(logs[2].args.value, amount);
                assert.equal(logs[2].args.data, null);
                assert.equal(logs[2].args.operatorData, null);
              });
            });
          });

          describe('when the recipient is the zero address', function () {
            const amount = issuanceAmount;
            const to = ZERO_ADDRESS;

            it('reverts', async function () {
              await shouldFail.reverting(this.token.transferFrom(tokenHolder, to, amount, { from: operator }));
            });
          });
        });
        describe('when the amount is not a multiple of the granularity', function () {
          it('reverts', async function () {
            this.token = await ERC1400ERC20.new('ERC1400RawToken', 'DAU', 2, [], CERTIFICATE_SIGNER, partitions);
            await this.token.issueByPartition(partition1, tokenHolder, issuanceAmount, VALID_CERTIFICATE, { from: owner });
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
            assert.equal(senderBalance, issuanceAmount - amount);

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
    describe('when the sender is not whitelisted', function () {
      const amount = approvedAmount;
      it('reverts', async function () {
        await this.token.setWhitelisted(tokenHolder, false, { from: controller });
        await shouldFail.reverting(this.token.transferFrom(tokenHolder, to, amount, { from: operator }));
      });
    });
    describe('when the recipient is not whitelisted', function () {
      const amount = approvedAmount;
      it('reverts', async function () {
        await this.token.setWhitelisted(to, false, { from: controller });
        await shouldFail.reverting(this.token.transferFrom(tokenHolder, to, amount, { from: operator }));
      });
    });
  });
});
