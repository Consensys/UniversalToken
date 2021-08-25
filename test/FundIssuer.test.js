/**
 ***************************************************************************************************************
 **************************************** CAUTION: work in progress ********************************************
 ***************************************************************************************************************
 *
 * CAUTION: This contract is a work in progress, tests are not finalized yet!
 *
 ***************************************************************************************************************
 **************************************** CAUTION: work in progress ********************************************
 ***************************************************************************************************************
 */

const { expectRevert } = require("@openzeppelin/test-helpers");
const { soliditySha3 } = require("web3-utils");
const { advanceTimeAndBlock } = require("./utils/time")

const FundIssuerContract = artifacts.require("FundIssuer");
const ERC1400 = artifacts.require("ERC1400");
const ERC1820Registry = artifacts.require("IERC1820Registry");

const ERC1400_TOKENS_RECIPIENT_INTERFACE = "ERC1400TokensRecipient";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ZERO_BYTE = "0x";
const ZERO_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

const TRUE_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000001";
const FALSE_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

const OFFCHAIN =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const ETHSTANDARD =
  "0x0000000000000000000000000000000000000000000000000000000000000001";
const ERC20STANDARD =
  "0x0000000000000000000000000000000000000000000000000000000000000002";
const ERC1400STANDARD =
  "0x0000000000000000000000000000000000000000000000000000000000000003";

const CYCLE_UNDEFINED =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const CYCLE_SUBSCRIPTION =
  "0x0000000000000000000000000000000000000000000000000000000000000001";
const CYCLE_VALUATION =
  "0x0000000000000000000000000000000000000000000000000000000000000002";
const CYCLE_PAYMENT =
  "0x0000000000000000000000000000000000000000000000000000000000000003";
const CYCLE_SETTLEMENT =
  "0x0000000000000000000000000000000000000000000000000000000000000004";
const CYCLE_FINALIZED =
  "0x0000000000000000000000000000000000000000000000000000000000000005";

const ORDER_UNDEFINED =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const ORDER_SUBSCRIBED =
  "0x0000000000000000000000000000000000000000000000000000000000000001";
const ORDER_PAID =
  "0x0000000000000000000000000000000000000000000000000000000000000002";
const ORDER_PAIDSETTLED =
  "0x0000000000000000000000000000000000000000000000000000000000000003";
const ORDER_UNPAIDSETTLED =
  "0x0000000000000000000000000000000000000000000000000000000000000004";
const ORDER_CANCELLED =
  "0x0000000000000000000000000000000000000000000000000000000000000005";
const ORDER_REJECTED =
  "0x0000000000000000000000000000000000000000000000000000000000000006";

const TYPE_UNDEFINED =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const TYPE_VALUE =
  "0x0000000000000000000000000000000000000000000000000000000000000001";
const TYPE_AMOUNT =
  "0x0000000000000000000000000000000000000000000000000000000000000002";

const NEW_CYCLE_CREATED_TRUE = true;
const NEW_CYCLE_CREATED_FALSE = false;

const INIT_RULES_TRUE = true;
const INIT_RULES_FALSE = false;

// const OFFCHAIN_BYTE = '00';
// const ERC20STANDARD_BYTE = '01';
// const ERC1400STANDARD_BYTE = '02';

// const mapStandardToByte = {};
// mapStandardToByte[OFFCHAIN] = OFFCHAIN_BYTE;
// mapStandardToByte[ERC20STANDARD] = OFFCHAIN_BYTE;
// mapStandardToByte[ERC1400STANDARD] = OFFCHAIN_BYTE;

const CERTIFICATE_SIGNER = "0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630";

const VALID_CERTIFICATE =
  "0x1000000000000000000000000000000000000000000000000000000000000000";

const partition0 =
  "0x0000000000000000000000000000000000000000000000000000000000000000"; // Empty hex

const partition1 =
  "0x7265736572766564000000000000000000000000000000000000000000000000"; // reserved in hex
const partition2 =
  "0x6973737565640000000000000000000000000000000000000000000000000000"; // issued in hex
const partition3 =
  "0x6c6f636b65640000000000000000000000000000000000000000000000000000"; // locked in hex
const partitions = [partition1, partition2, partition3];

const ALL_PARTITIONS =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

const MOCK_CERTIFICATE =
  "0x1000000000000000000000000000000000000000000000000000000000000000";
// const INMOCK_CERTIFICATE = '0x0000000000000000000000000000000000000000000000000000000000000000';

const orderCreationFlag =
  "0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
const orderPaymentFlag =
  "0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"; // Flag to indicate a partition change
const partitionFlag =
  "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"; // Flag to indicate a partition change
const bypassFlag =
  "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

const ERC1820_ACCEPT_MAGIC = soliditySha3("ERC1820_ACCEPT_MAGIC");

const OFF_CHAIN_PAYMENT = 0;
const ETH_PAYMENT = 1;
const ERC20_PAYMENT = 2;
const ERC1400_PAYMENT = 3;

const ASSET_VALUE_UNKNOWN = 0;
const ASSET_VALUE_KNOWN = 1;

const STATE_PENDING = 1;
const STATE_EXECUTED = 2;
const STATE_FORCED = 3;
const STATE_CANCELLED = 4;

const TYPE_ESCROW = 0;
const TYPE_SWAP = 1;

const ACCEPTED_TRUE = true;
const ACCEPTED_FALSE = false;

const APPROVED_TRUE = true;
const APPROVED_FALSE = false;

const issuanceAmount = 1000;
const token1Amount = 10;
const token2Amount = 400;
const token3Amount = 400;
const token4Amount = 10;
const issuanceTokenId = 123456789;

const SECONDS_IN_A_WEEK = 86400 * 7;

const DEFAULT_SUBSCRIPTION_PERIOD_LENGTH = SECONDS_IN_A_WEEK;
const DEFAULT_VALUATION_PERIOD_LENGTH = SECONDS_IN_A_WEEK;
const DEFAULT_PAYMENT_PERIOD_LENGTH = SECONDS_IN_A_WEEK;

const assertBalanceOf = async (
  _contract,
  _tokenHolder,
  _amount,
  _balanceIsExact
) => {
  const balance = (await _contract.balanceOf(_tokenHolder)).toNumber();

  if (_balanceIsExact) {
    assert.equal(balance, _amount);
  } else {
    assert.equal(balance >= _amount, true);
  }
};

const assertBalanceOfByPartition = async (
  _contract,
  _tokenHolder,
  _partition,
  _amount
) => {
  const balanceByPartition = (
    await _contract.balanceOfByPartition(_partition, _tokenHolder)
  ).toNumber();
  assert.equal(balanceByPartition, _amount);
};

const assertTokenOf = async (_contract, _tokenHolder, _tokenId) => {
  const ownerOf = await _contract.ownerOf(_tokenId);

  assert.equal(ownerOf, _tokenHolder);
};

const assertERC20Allowance = async (
  _contract,
  _tokenHolder,
  _spender,
  _amount
) => {
  const allowance = (
    await _contract.allowance(_tokenHolder, _spender)
  ).toNumber();
  assert.equal(allowance, _amount);
};

const assertERC1400Allowance = async (
  _contract,
  _tokenHolder,
  _spender,
  _amount
) => {
  const allowance = (
    await _contract.allowanceByPartition(partition1, _tokenHolder, _spender)
  ).toNumber();
  assert.equal(allowance, _amount);
};

const assertERC721Allowance = async (_contract, _tokenHolder, _tokenId) => {
  const approvedOf = await _contract.getApproved(_tokenId);
  assert.equal(approvedOf, _tokenHolder);
};

const assertEtherBalance = async (_etherHolder, _balance, _balanceIsExact) => {
  const balance = await web3.eth.getBalance(_etherHolder);
  if (_balanceIsExact) {
    assert.equal(balance, _balance);
  } else {
    assert.equal(balance - _balance < 0.1);
  }
};

const assertAssetRules = async (
  _contract,
  _assetAddress,
  _assetClass,
  _firstStartTime,
  _subscriptionPeriodLength,
  _valuationPeriodLength,
  _paymentPeriodLength,
  _assetValueType,
  _assetValue,
  _reverseAssetValue,
  _paymentType,
  _paymentAddress,
  _paymentPartition,
  _fundAddress,
  _subscriptionsOpened
) => {
  const rules = await _contract.getAssetRules(_assetAddress, _assetClass);

  assert.equal(rules[0], _firstStartTime);
  assert.equal(rules[1], _subscriptionPeriodLength);
  assert.equal(rules[2], _valuationPeriodLength);
  assert.equal(rules[3], _paymentPeriodLength);
  assert.equal(rules[4].toNumber(), _paymentType);
  assert.equal(rules[5], _paymentAddress);
  assert.equal(rules[6], _paymentPartition);
  assert.equal(rules[7], _fundAddress);
  if (_subscriptionsOpened) {
    assert.equal(rules[8], TRUE_BYTES32);
  } else {
    assert.equal(rules[8], FALSE_BYTES32);
  }

  const assetValueRules = await _contract.getAssetValueRules(
    _assetAddress,
    _assetClass
  );
  assert.equal(assetValueRules[0].toNumber(), _assetValueType);
  assert.equal(assetValueRules[1], _assetValue);
  assert.equal(assetValueRules[2], _reverseAssetValue);
};

const assertCycle = async (
  _contract,
  _cycleIndex,
  _assetAddress,
  _assetClass,
  _startTime,
  _subscriptionPeriodLength,
  _valuationPeriodLength,
  _paymentPeriodLength,
  _paymentType,
  _paymentAddress,
  _paymentPartition,
  _finalized
) => {
  const cycle = await _contract.getCycle(_cycleIndex);

  assert.equal(cycle[0], _assetAddress);
  assert.equal(cycle[1], _assetClass);
  assert.equal(cycle[2], _startTime);
  assert.equal(cycle[3], _subscriptionPeriodLength);
  assert.equal(cycle[4], _valuationPeriodLength);
  assert.equal(cycle[5], _paymentPeriodLength);
  assert.equal(cycle[6].toNumber(), _paymentType);
  assert.equal(cycle[7], _paymentAddress);
  assert.equal(cycle[8], _paymentPartition);
  if (_finalized) {
    assert.equal(cycle[9], TRUE_BYTES32);
  } else {
    assert.equal(cycle[9], FALSE_BYTES32);
  }
};

const assertCycleState = async (
  _contract,
  _assetAddress,
  _assetClass,
  _state
) => {
  const cycleIndex = (
    await _contract.getLastCycleIndex(_assetAddress, _assetClass)
  ).toNumber();
  const cycleState = (await _contract.getCycleState(cycleIndex)).toNumber();

  assert.equal(cycleState, _state);
};

const assertCycleAssetValue = async (
  _contract,
  _cycleIndex,
  _assetValueType,
  _assetValue,
  _reverseAssetValue
) => {
  const valueData = await _contract.getCycleAssetValue(_cycleIndex);

  assert.equal(valueData[0], _assetValueType);
  assert.equal(valueData[1], _assetValue);
  assert.equal(valueData[2], _reverseAssetValue);
};

const assertOrder = async (
  _contract,
  _orderIndex,
  _cycleIndex,
  _investor,
  _value,
  _amount,
  _orderType,
  _state
) => {
  const order = await _contract.getOrder(_orderIndex);

  assert.equal(order[0].toNumber(), _cycleIndex);
  assert.equal(order[1], _investor);
  assert.equal(order[2], _value);
  assert.equal(order[3], _amount);
  assert.equal(order[4].toNumber(), _orderType);

  assert.equal(order[5].toNumber(), _state);
};

const addressToBytes32 = (_addr, _fillTo = 32) => {
  const _addr2 = _addr.substring(2);
  const arr1 = [];
  for (let n = 0, l = _addr2.length; n < l; n++) {
    arr1.push(_addr2[n]);
  }
  for (let m = _addr2.length; m < 2 * _fillTo; m++) {
    arr1.unshift(0);
  }
  return arr1.join("");
};

const NumToHexBytes32 = (_num, _fillTo = 32) => {
  const arr1 = [];
  const _str = _num.toString(16);
  for (let n = 0, l = _str.length; n < l; n++) {
    arr1.push(_str[n]);
  }
  for (let m = _str.length; m < 2 * _fillTo; m++) {
    arr1.unshift(0);
  }
  return arr1.join("");
};

const NumToNumBytes32 = (_num, _fillTo = 32) => {
  const arr1 = [];
  const _str = _num.toString();
  for (let n = 0, l = _str.length; n < l; n++) {
    arr1.push(_str[n]);
  }
  for (let m = _str.length; m < 2 * _fillTo; m++) {
    arr1.unshift(0);
  }
  return `0x${arr1.join("")}`;
};

const getOrderCreationData = (
  _assetAddress,
  _assetClass,
  _orderValue,
  _orderAmount,
  _orderType,
  isFake
) => {
  const flag = isFake ? partitionFlag : orderCreationFlag;
  const hexAssetAddress = addressToBytes32(_assetAddress);

  const hexAssetClass = _assetClass.substring(2);

  const hexOrderValue = NumToHexBytes32(_orderValue);
  const hexOrderAmount = NumToHexBytes32(_orderAmount);
  const hexOrderType = _orderType.substring(2);
  const orderData = `${hexOrderValue}${hexOrderAmount}${hexOrderType}`;

  return `${flag}${hexAssetAddress}${hexAssetClass}${orderData}`;
};

const getOrderPaymentData = (orderIndex, isFake) => {
  const flag = isFake ? partitionFlag : orderPaymentFlag;
  const hexOrderIndex = NumToHexBytes32(orderIndex);

  return `${flag}${hexOrderIndex}`;
};

const setAssetRules = async (
  _contract,
  _issuerAddress,
  _assetAddress,
  _assetClass,
  _firstStartTime,
  _subscriptionPeriodLength,
  _valuationPeriodLength,
  _paymentPeriodLength,
  _paymentType,
  _paymentAddress,
  _paymentPartition,
  _fundAddress,
  _subscriptionsOpened
) => {
  const chainTime = (await web3.eth.getBlock("latest")).timestamp;
  const firstStartTime = _firstStartTime || chainTime + 20;
  const subscriptionPeriodLength =
    _subscriptionPeriodLength || DEFAULT_SUBSCRIPTION_PERIOD_LENGTH;
  const valuationPeriodLength =
    _valuationPeriodLength || DEFAULT_VALUATION_PERIOD_LENGTH;
  const paymentPeriodLength =
    _paymentPeriodLength || DEFAULT_PAYMENT_PERIOD_LENGTH;

  await _contract.setAssetRules(
    _assetAddress,
    _assetClass,
    firstStartTime,
    subscriptionPeriodLength,
    valuationPeriodLength,
    paymentPeriodLength,
    _paymentType,
    _paymentAddress,
    _paymentPartition,
    _fundAddress,
    _subscriptionsOpened,
    { from: _issuerAddress }
  );

  await assertAssetRules(
    _contract,
    _assetAddress,
    _assetClass,
    firstStartTime,
    subscriptionPeriodLength,
    valuationPeriodLength,
    paymentPeriodLength,
    ASSET_VALUE_UNKNOWN,
    0,
    0,
    _paymentType,
    _paymentAddress,
    _paymentPartition,
    _fundAddress,
    _subscriptionsOpened
  );

  // Wait for 10 seconds, in order to be after the first start time (set to "chainTime + 1" by default)
  await advanceTimeAndBlock(30);
};

const subscribe = async (
  _contract,
  _assetAddress,
  _assetClass,
  _value,
  _amount,
  _orderType,
  _investorAddress,
  _setAssetRules,
  _issuerAddress,
  _fundAddress,
  _newCycle
) => {
  if (_setAssetRules) {
    await setAssetRules(
      _contract,
      _issuerAddress,
      _assetAddress,
      _assetClass,
      undefined,
      undefined,
      undefined,
      undefined,
      OFF_CHAIN_PAYMENT,
      ZERO_ADDRESS,
      ZERO_BYTES32,
      _fundAddress,
      true
    );
  }

  const initialNumberOfCycles = (await _contract.getNbCycles()).toNumber();
  const initialIndexOfAssetCycle = (
    await _contract.getLastCycleIndex(_assetAddress, _assetClass)
  ).toNumber();

  const initialNumberOfOrders = (await _contract.getNbOrders()).toNumber();
  const initialInvestorOrders = await _contract.getInvestorOrders(
    _investorAddress
  );

  await _contract.subscribe(
    _assetAddress,
    _assetClass,
    _value,
    _amount,
    _orderType,
    false, // executePaymentAtSubscription
    { from: _investorAddress }
  );

  const currentNumberOfCycles = (await _contract.getNbCycles()).toNumber();
  const currentIndexOfAssetCycle = (
    await _contract.getLastCycleIndex(_assetAddress, _assetClass)
  ).toNumber();

  if (_newCycle) {
    assert.equal(currentNumberOfCycles, initialNumberOfCycles + 1);
    assert.equal(currentIndexOfAssetCycle, initialNumberOfCycles + 1);
  } else {
    assert.equal(currentNumberOfCycles, initialNumberOfCycles);
    assert.equal(currentIndexOfAssetCycle, initialIndexOfAssetCycle);
  }

  const currentNumberOfOrders = (await _contract.getNbOrders()).toNumber();
  const currentInvestorOrders = await _contract.getInvestorOrders(
    _investorAddress
  );
  assert.equal(currentNumberOfOrders, initialNumberOfOrders + 1);
  assert.equal(currentInvestorOrders.length, initialInvestorOrders.length + 1);

  const cycleIndex = (
    await _contract.getLastCycleIndex(_assetAddress, _assetClass)
  ).toNumber();

  await assertOrder(
    _contract,
    currentInvestorOrders[currentInvestorOrders.length - 1].toNumber(),
    cycleIndex,
    _investorAddress,
    _value,
    _amount,
    _orderType,
    ORDER_SUBSCRIBED
  );
};

const launchCycleForAssetClass = async (
  _contract,
  _assetAddress,
  _assetClass,
  _firstStartTime,
  _subscriptionPeriodLength,
  _valuationPeriodLength,
  _paymentPeriodLength,
  _paymentType,
  _paymentAddress,
  _paymentPartition,
  _subscriptionsOpened
) => {
  const chainTime = (await web3.eth.getBlock("latest")).timestamp;
  const firstStartTime = _firstStartTime || chainTime;
  const subscriptionPeriodLength =
    _subscriptionPeriodLength || SECONDS_IN_A_WEEK;
  const valuationPeriodLength = _valuationPeriodLength || SECONDS_IN_A_WEEK;
  const paymentPeriodLength = _paymentPeriodLength || SECONDS_IN_A_WEEK;

  // const initialNumberOfCycles = (await _contract.getNbCycles()).toNumber();
  // const initialNumberOfAssetCycles = (await _contract.getLastCycleIndex(_assetAddress, _assetClass)).toNumber();

  // await _contract.setAssetRules(
  //   _assetAddress,
  //   _assetClass,
  //   firstStartTime,
  //   subscriptionPeriodLength,
  //   valuationPeriodLength,
  //   paymentPeriodLength,
  //   _paymentType,
  //   _paymentAddress,
  //   _paymentPartition,
  //   _subscriptionsOpened
  // );

  // const currentNumberOfCycles = (await _contract.getNbCycles()).toNumber();
  // const currentNumberOfAssetCycles = (await _contract.getLastCycleIndex(_assetAddress, _assetClass)).toNumber();
  // assert.equal(currentNumberOfCycles, initialNumberOfCycles + 1);
  // assert.equal(initialNumberOfAssetCycles, currentNumberOfAssetCycles + 1);

  await assertCycle(
    _contract,
    currentNumberOfAssetCycles,
    _assetAddress,
    _assetClass,
    firstStartTime,
    subscriptionPeriodLength,
    valuationPeriodLength,
    paymentPeriodLength,
    _paymentType,
    _paymentAddress,
    _paymentPartition,
    false
  );
};

contract("Fund issuance", function ([
  owner,
  tokenController1,
  tokenController2,
  fund,
  oracle,
  tokenHolder1,
  tokenHolder2,
  recipient1,
  recipient2,
  unknown,
]) {
  before(async function () {
    this.registry = await ERC1820Registry.at(
      "0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24"
    );
  });

  // EXECUTEPAYMENTASINVESTOR

  describe("executePaymentAsInvestor", function () {
    beforeEach(async function () {
      this.asset = await ERC1400.new(
        "ERC1400Token",
        "DAU",
        1,
        [owner],
        partitions,
        { from: tokenController1 }
      );
      this.fic = await FundIssuerContract.new();

      this.assetValue = 1000;

      // await setAssetRules(
      //   this.fic,
      //   this.tokenController1,
      //   this.asset.address,
      //   partition1,
      //   undefined,
      //   undefined,
      //   undefined,
      //   undefined,
      //   _paymentType,
      //   _paymentAddress,
      //   _paymentPartition,
      //   fund,
      //   true
      // );
    });
    describe("when function is called by the investor", function () {
      describe("when payment is made with ether", function () {
        beforeEach(async function () {
          await setAssetRules(
            this.fic,
            tokenController1,
            this.asset.address,
            partition1,
            undefined,
            undefined,
            undefined,
            undefined,
            ETH_PAYMENT,
            ZERO_ADDRESS,
            ZERO_BYTES32,
            fund,
            true
          );

          await subscribe(
            this.fic,
            this.asset.address,
            partition1,
            0,
            1000,
            TYPE_AMOUNT,
            tokenHolder1,
            INIT_RULES_FALSE,
            tokenController1,
            fund,
            NEW_CYCLE_CREATED_TRUE
          );
        });
        describe("when asset value is of type Unknown", function () {
          describe("when cycle is at least in payment period", function () {
            beforeEach(async function () {
              await assertCycleState(
                this.fic,
                this.asset.address,
                partition1,
                CYCLE_SUBSCRIPTION
              );

              // Wait until after the end of the first subscription period
              await advanceTimeAndBlock(DEFAULT_SUBSCRIPTION_PERIOD_LENGTH + 1);
              await assertCycleState(
                this.fic,
                this.asset.address,
                partition1,
                CYCLE_VALUATION
              );

              const cycleIndex = (
                await this.fic.getLastCycleIndex(this.asset.address, partition1)
              ).toNumber();
              await this.fic.valuate(cycleIndex, this.assetValue, 0, {
                from: tokenController1,
              });
              await assertCycleAssetValue(
                this.fic,
                cycleIndex,
                ASSET_VALUE_UNKNOWN,
                this.assetValue,
                0
              );

              // Wait until after the end of the first valuation period
              await advanceTimeAndBlock(DEFAULT_VALUATION_PERIOD_LENGTH + 1);
              await assertCycleState(
                this.fic,
                this.asset.address,
                partition1,
                CYCLE_PAYMENT
              );
            });
            describe("when order is of type amount", function () {
              describe("when asset value is not nil", function () {
                describe("when payment is not bypassed", function () {
                  describe("when payment value is correct", function () {
                    describe("when order state is Subscribed", function () {
                      it("updates the order state to Paid", async function () {
                        const currentInvestorOrders = await this.fic.getInvestorOrders(
                          tokenHolder1
                        );
                        const orderIndex = currentInvestorOrders[
                          currentInvestorOrders.length - 1
                        ].toNumber();
                        const amountAndValue = await this.fic.getOrderAmountAndValue(
                          orderIndex
                        );

                        const amount = amountAndValue[0].toNumber();
                        const value = amountAndValue[1].toNumber();

                        await assertOrder(
                          this.fic,
                          orderIndex,
                          1,
                          tokenHolder1,
                          0,
                          amount,
                          TYPE_AMOUNT,
                          ORDER_SUBSCRIBED
                        );

                        await this.fic.executePaymentAsInvestor(orderIndex, {
                          from: tokenHolder1,
                          value: value,
                        });

                        await assertOrder(
                          this.fic,
                          orderIndex,
                          1,
                          tokenHolder1,
                          value,
                          amount,
                          TYPE_AMOUNT,
                          ORDER_PAID
                        );
                      });
                    });
                    describe("when order state is UnpaidSettled", function () {
                      describe("when cycle is not finalized", function () {
                        it("reverts", async function () {});
                      });
                      describe("when cycle is finalized", function () {
                        it("reverts", async function () {});
                      });
                    });
                    describe("when order state is neither Subscribed nor UnpaidSettled", function () {
                      it("reverts", async function () {});
                    });
                  });
                  describe("when payment value is not correct", function () {
                    it("reverts", async function () {});
                  });
                });
                describe("when payment is bypassed", function () {
                  it("reverts", async function () {});
                });
              });
              describe("when reverse asset value is not nil", function () {
                it("reverts", async function () {});
              });
            });
            describe("when order is of type value", function () {
              describe("when asset value is not nil", function () {
                it("reverts", async function () {});
              });
              describe("when reverse asset value is not nil", function () {
                it("reverts", async function () {});
              });
            });
          });
          describe("when cycle is not at least in payment period", function () {
            it("reverts", async function () {});
          });
        });
        describe("when asset value is of type Known", function () {
          describe("when cycle is at least in subscription period", function () {
            it("reverts", async function () {});
          });
          describe("when cycle is not at least in subscription period", function () {
            it("reverts", async function () {});
          });
        });
      });
      describe("when payment is made with erc20", function () {
        describe("when payment value is correct", function () {
          it("reverts", async function () {});
        });
        describe("when payment value is not correct", function () {
          it("reverts", async function () {});
        });
      });
      describe("when payment is made with erc1400 through allowance", function () {
        describe("when payment value is correct", function () {
          it("reverts", async function () {});
        });
        describe("when payment value is not correct", function () {
          it("reverts", async function () {});
        });
      });
      describe("when payment is made with erc1400 through hook", function () {
        describe("when payment value is correct", function () {
          describe("when payment succeeds", function () {
            it("reverts", async function () {});
          });
          describe("when payment type is not correct", function () {
            it("reverts", async function () {});
          });
          describe("when payment address is not correct", function () {
            it("reverts", async function () {});
          });
          describe("when payment partition is not correct", function () {
            it("reverts", async function () {});
          });
        });
        describe("when payment value is not correct", function () {
          it("reverts", async function () {});
        });
      });
      describe("when payment is done off-chain", function () {
        it("reverts", async function () {});
      });
    });
    describe("when function is not called by the investor", function () {
      it("reverts", async function () {});
    });
  });

  // REJECTORDER

  describe("rejectOrder", function () {
    beforeEach(async function () {
      this.asset = await ERC1400.new(
        "ERC1400Token",
        "DAU",
        1,
        [owner],
        partitions,
        { from: tokenController1 }
      );
      this.fic = await FundIssuerContract.new();
      await subscribe(
        this.fic,
        this.asset.address,
        partition1,
        0,
        1000,
        TYPE_AMOUNT,
        tokenHolder1,
        INIT_RULES_TRUE,
        tokenController1,
        fund,
        NEW_CYCLE_CREATED_TRUE
      );
    });
    describe("when order exists and can still be rejected", function () {
      describe("when valuation period is not over", function () {
        describe("when message sender is the token controller", function () {
          describe("when the order has not been settled", function () {
            describe("when the order needs to be rejected", function () {
              describe("when order has not been paid yet", function () {
                describe("when we are in the subscription period", function () {
                  it("rejects the order", async function () {
                    const orderIndex = (
                      await this.fic.getInvestorOrders(tokenHolder1)
                    )[0].toNumber();
                    const cycleIndex = (
                      await this.fic.getLastCycleIndex(
                        this.asset.address,
                        partition1
                      )
                    ).toNumber();
                    await assertOrder(
                      this.fic,
                      orderIndex,
                      cycleIndex,
                      tokenHolder1,
                      0,
                      1000,
                      TYPE_AMOUNT,
                      ORDER_SUBSCRIBED
                    );
                    await this.fic.rejectOrder(orderIndex, true, {
                      from: tokenController1,
                    });
                    await assertOrder(
                      this.fic,
                      orderIndex,
                      cycleIndex,
                      tokenHolder1,
                      0,
                      1000,
                      TYPE_AMOUNT,
                      ORDER_REJECTED
                    );
                  });
                });
                describe("when we are in the valuation period", function () {
                  it("rejects the order", async function () {
                    const orderIndex = (
                      await this.fic.getInvestorOrders(tokenHolder1)
                    )[0].toNumber();
                    const cycleIndex = (
                      await this.fic.getLastCycleIndex(
                        this.asset.address,
                        partition1
                      )
                    ).toNumber();
                    await assertOrder(
                      this.fic,
                      orderIndex,
                      cycleIndex,
                      tokenHolder1,
                      0,
                      1000,
                      TYPE_AMOUNT,
                      ORDER_SUBSCRIBED
                    );

                    await assertCycleState(
                      this.fic,
                      this.asset.address,
                      partition1,
                      CYCLE_SUBSCRIPTION
                    );

                    // Wait until after the end of the first subscription period
                    await advanceTimeAndBlock(
                      DEFAULT_SUBSCRIPTION_PERIOD_LENGTH + 1
                    );

                    await assertCycleState(
                      this.fic,
                      this.asset.address,
                      partition1,
                      CYCLE_VALUATION
                    );

                    await this.fic.rejectOrder(orderIndex, true, {
                      from: tokenController1,
                    });
                    await assertOrder(
                      this.fic,
                      orderIndex,
                      cycleIndex,
                      tokenHolder1,
                      0,
                      1000,
                      TYPE_AMOUNT,
                      ORDER_REJECTED
                    );
                  });
                });
              });
              describe("when order had already been paid", function () {
                // XXX
              });
            });
            describe("when the order rejection needs to be cancelled", function () {
              it("cancels the rejection", async function () {
                const orderIndex = (
                  await this.fic.getInvestorOrders(tokenHolder1)
                )[0].toNumber();
                const cycleIndex = (
                  await this.fic.getLastCycleIndex(
                    this.asset.address,
                    partition1
                  )
                ).toNumber();
                await assertOrder(
                  this.fic,
                  orderIndex,
                  cycleIndex,
                  tokenHolder1,
                  0,
                  1000,
                  TYPE_AMOUNT,
                  ORDER_SUBSCRIBED
                );
                await this.fic.rejectOrder(orderIndex, true, {
                  from: tokenController1,
                });
                await assertOrder(
                  this.fic,
                  orderIndex,
                  cycleIndex,
                  tokenHolder1,
                  0,
                  1000,
                  TYPE_AMOUNT,
                  ORDER_REJECTED
                );
                await this.fic.rejectOrder(orderIndex, false, {
                  from: tokenController1,
                });
                await assertOrder(
                  this.fic,
                  orderIndex,
                  cycleIndex,
                  tokenHolder1,
                  0,
                  1000,
                  TYPE_AMOUNT,
                  ORDER_SUBSCRIBED
                );
              });
            });
          });
          describe("when the order has been settled", function () {
            describe("when the order has been paid", function () {
              it("reverts", async function () {});
            });
            describe("when the order has not been paid", function () {
              it("reverts", async function () {});
            });
          });
        });
        describe("when message sender is not the token controller", function () {
          it("reverts", async function () {});
        });
      });
      describe("when subscription period is over", function () {
        it("reverts", async function () {});
      });
    });
    describe("when order can not be rejected", function () {
      describe("when order doesnt exist", function () {
        it("reverts", async function () {});
      });
      describe("when order has already been settled", function () {
        describe("when order has been paid", function () {
          it("reverts", async function () {});
        });
        describe("when order has not been paid", function () {
          it("reverts", async function () {});
        });
      });
      describe("when order has been cancelled", function () {
        it("reverts", async function () {});
      });
      describe("when order has already been rejected", function () {
        it("reverts", async function () {});
      });
    });
  });

  // PARAMETERS

  describe("parameters", function () {
    beforeEach(async function () {
      this.fic = await FundIssuerContract.new();
    });
    describe("implementerFund", function () {
      it("returns the contract address", async function () {
        let interfaceFundImplementer = await this.registry.getInterfaceImplementer(
          this.fic.address,
          soliditySha3(ERC1400_TOKENS_RECIPIENT_INTERFACE)
        );
        assert.equal(interfaceFundImplementer, this.fic.address);
      });
    });
  });

  // CANIMPLEMENTINTERFACE

  describe("canImplementInterfaceForAddress", function () {
    beforeEach(async function () {
      this.fic = await FundIssuerContract.new();
    });
    describe("when interface hash is correct", function () {
      it("returns ERC1820_ACCEPT_MAGIC", async function () {
        const canImplement = await this.fic.canImplementInterfaceForAddress(
          soliditySha3(ERC1400_TOKENS_RECIPIENT_INTERFACE),
          ZERO_ADDRESS
        );
        assert.equal(ERC1820_ACCEPT_MAGIC, canImplement);
      });
    });
    describe("when interface hash is not correct", function () {
      it("returns empty bytes32", async function () {
        const canImplement = await this.fic.canImplementInterfaceForAddress(
          soliditySha3("FakeInterfaceName"),
          ZERO_ADDRESS
        );
        assert.equal(ZERO_BYTES32, canImplement);
      });
    });
  });

  // CANRECEIVE

  describe("canReceive", function () {
    beforeEach(async function () {
      this.fic = await FundIssuerContract.new();
      this.asset = await ERC1400.new(
        "ERC1400Token",
        "DAU",
        1,
        [owner],
        partitions,
        { from: tokenController1 }
      );
      this.orderCreationFlag = getOrderCreationData(
        this.asset.address,
        partition1,
        500,
        0,
        TYPE_VALUE
      );
      this.orderPaymentFlag = getOrderPaymentData(1);
    });
    describe("when operatorData is not empty", function () {
      describe("when data has the correct length", function () {
        describe("when data has the right format", function () {
          describe("when data is formatted for an order creation", function () {
            it("returns true", async function () {
              const answer = await this.fic.canReceive(
                "0x00000000",
                partition1,
                unknown,
                unknown,
                unknown,
                1,
                this.orderCreationFlag,
                MOCK_CERTIFICATE
              );
              assert.equal(answer, true);
            });
          });
          describe("when data is formatted for an order payment", function () {
            it("returns true", async function () {
              const answer = await this.fic.canReceive(
                "0x00000000",
                partition1,
                unknown,
                unknown,
                unknown,
                1,
                this.orderPaymentFlag,
                MOCK_CERTIFICATE
              );
              assert.equal(answer, true);
            });
          });
          describe("when data is formatted for a hook bypass", function () {
            it("returns true", async function () {
              const answer = await this.fic.canReceive(
                "0x00000000",
                partition1,
                unknown,
                unknown,
                unknown,
                1,
                bypassFlag,
                MOCK_CERTIFICATE
              );
              assert.equal(answer, true);
            });
          });
        });
        describe("when data does not have the right format", function () {
          it("returns false", async function () {
            const answer = await this.fic.canReceive(
              "0x00000000",
              partition1,
              unknown,
              unknown,
              unknown,
              1,
              partitionFlag,
              MOCK_CERTIFICATE
            );
            assert.equal(answer, false);
          });
        });
      });
      describe("when data does not have the correct length", function () {
        it("returns false", async function () {
          const answer = await this.fic.canReceive(
            "0x00000000",
            partition1,
            unknown,
            unknown,
            unknown,
            1,
            this.orderPaymentFlag.substring(
              0,
              this.orderPaymentFlag.length - 1
            ),
            MOCK_CERTIFICATE
          );
          assert.equal(answer, false);
        });
      });
    });
    describe("when operatorData is empty", function () {
      it("returns false", async function () {
        const answer = await this.fic.canReceive(
          "0x00000000",
          partition1,
          unknown,
          unknown,
          unknown,
          1,
          this.orderPaymentFlag,
          ZERO_BYTE
        );
        assert.equal(answer, false);
      });
    });
  });

  // SETASSETRULES

  describe("setAssetRules", function () {
    beforeEach(async function () {
      this.asset = await ERC1400.new(
        "ERC1400Token",
        "DAU",
        1,
        [owner],
        partitions,
        { from: tokenController1 }
      );
      this.fic = await FundIssuerContract.new();
    });
    describe("when caller is the token controller", function () {
      describe("when first start time is valid", function () {
        describe("when periods are valid", function () {
          describe("when rules are not already defined", function () {
            it("sets asset rules", async function () {
              await setAssetRules(
                this.fic,
                tokenController1,
                this.asset.address,
                partition1,
                undefined,
                undefined,
                undefined,
                undefined,
                OFF_CHAIN_PAYMENT,
                ZERO_ADDRESS,
                ZERO_BYTES32,
                fund,
                true
              );
            });
          });
          describe("when rules are already defined", function () {
            it("updates asset rules", async function () {
              await setAssetRules(
                this.fic,
                tokenController1,
                this.asset.address,
                partition1,
                undefined,
                undefined,
                undefined,
                undefined,
                OFF_CHAIN_PAYMENT,
                ZERO_ADDRESS,
                ZERO_BYTES32,
                fund,
                true
              );
              this.paymentToken = await ERC1400.new(
                "ERC1400Token",
                "DAU",
                1,
                [owner],
                partitions,
                { from: tokenController1 }
              );
              const chainTime = (await web3.eth.getBlock("latest")).timestamp;
              await setAssetRules(
                this.fic,
                tokenController1,
                this.asset.address,
                partition2,
                chainTime + 2 * SECONDS_IN_A_WEEK,
                2 * SECONDS_IN_A_WEEK,
                2 * SECONDS_IN_A_WEEK,
                2 * SECONDS_IN_A_WEEK,
                ERC1400_PAYMENT,
                this.paymentToken.address,
                partition3,
                tokenHolder2,
                false
              );
            });
          });
        });
        describe("when periods are not valid", function () {
          describe("when subscriptionPeriodLength is nil", function () {
            it("reverts", async function () {
              const chainTime = (await web3.eth.getBlock("latest")).timestamp;
              await expectRevert.unspecified(
                this.fic.setAssetRules(
                  this.asset.address,
                  partition1,
                  chainTime + 1,
                  0,
                  1,
                  1,
                  OFF_CHAIN_PAYMENT,
                  ZERO_ADDRESS,
                  ZERO_BYTES32,
                  fund,
                  true,
                  { from: tokenController1 }
                )
              );
            });
          });
          describe("when valuationPeriodLength is nil", function () {
            it("reverts", async function () {
              const chainTime = (await web3.eth.getBlock("latest")).timestamp;
              await expectRevert.unspecified(
                this.fic.setAssetRules(
                  this.asset.address,
                  partition1,
                  chainTime + 1,
                  1,
                  0,
                  1,
                  OFF_CHAIN_PAYMENT,
                  ZERO_ADDRESS,
                  ZERO_BYTES32,
                  fund,
                  true,
                  { from: tokenController1 }
                )
              );
            });
          });
          describe("when paymentPeriodLength is nil", function () {
            it("reverts", async function () {
              const chainTime = (await web3.eth.getBlock("latest")).timestamp;
              await expectRevert.unspecified(
                this.fic.setAssetRules(
                  this.asset.address,
                  partition1,
                  chainTime + 1,
                  1,
                  1,
                  0,
                  OFF_CHAIN_PAYMENT,
                  ZERO_ADDRESS,
                  ZERO_BYTES32,
                  fund,
                  true,
                  { from: tokenController1 }
                )
              );
            });
          });
        });
      });
      describe("when first start time is not valid", function () {
        it("reverts", async function () {
          const chainTime = (await web3.eth.getBlock("latest")).timestamp;

          await expectRevert.unspecified(
            setAssetRules(
              this.fic,
              tokenController1,
              this.asset.address,
              partition1,
              chainTime - 1,
              undefined,
              undefined,
              undefined,
              OFF_CHAIN_PAYMENT,
              ZERO_ADDRESS,
              ZERO_BYTES32,
              fund,
              true
            )
          );
        });
      });
    });
    describe("when caller is not the token controller", function () {
      it("reverts", async function () {
        const chainTime = (await web3.eth.getBlock("latest")).timestamp;
        await expectRevert.unspecified(
          setAssetRules(
            this.fic,
            tokenController2,
            this.asset.address,
            partition1,
            undefined,
            undefined,
            undefined,
            undefined,
            OFF_CHAIN_PAYMENT,
            ZERO_ADDRESS,
            ZERO_BYTES32,
            fund,
            true
          )
        );
      });
    });
  });

  // SUBSCRIBE

  describe("subscribe", function () {
    beforeEach(async function () {
      this.asset = await ERC1400.new(
        "ERC1400Token",
        "DAU",
        1,
        [owner],
        partitions,
        { from: tokenController1 }
      );
      this.fic = await FundIssuerContract.new();
    });
    describe("when the current cycle is in subscription period", function () {
      describe("when the current period is correct", function () {
        describe("when order is of type value", function () {
          describe("when value is not nil", function () {
            describe("when asset value is unknown", function () {
              it("creates 2 new orders", async function () {
                await subscribe(
                  this.fic,
                  this.asset.address,
                  partition1,
                  1000,
                  0,
                  TYPE_VALUE,
                  tokenHolder1,
                  INIT_RULES_TRUE,
                  tokenController1,
                  fund,
                  NEW_CYCLE_CREATED_TRUE
                );
                await subscribe(
                  this.fic,
                  this.asset.address,
                  partition1,
                  1000,
                  0,
                  TYPE_VALUE,
                  tokenHolder2,
                  INIT_RULES_FALSE,
                  tokenController1,
                  fund,
                  NEW_CYCLE_CREATED_FALSE
                );
              });
            });
            describe("when asset value is already known", function () {
              describe("when payment is made at the same time as the subscription", function () {
                // XXX
              });
              describe("when payment is not made at the same time as the subscription", function () {
                // XXX
              });
            });
          });
          describe("when value is nil", function () {
            it("reverts", async function () {
              await expectRevert.unspecified(
                subscribe(
                  this.fic,
                  this.asset.address,
                  partition1,
                  0, // value
                  1000, // amount
                  TYPE_VALUE,
                  tokenHolder1,
                  INIT_RULES_TRUE,
                  tokenController1,
                  fund,
                  NEW_CYCLE_CREATED_TRUE
                )
              );
            });
          });
        });
        describe("when order is of type amount", function () {
          describe("when amount is not nil", function () {
            it("creates a new order", async function () {
              await subscribe(
                this.fic,
                this.asset.address,
                partition1,
                0,
                1000,
                TYPE_AMOUNT,
                tokenHolder1,
                INIT_RULES_TRUE,
                tokenController1,
                fund,
                NEW_CYCLE_CREATED_TRUE
              );
            });
          });
          describe("when amount is nil", function () {
            it("reverts", async function () {
              await expectRevert.unspecified(
                subscribe(
                  this.fic,
                  this.asset.address,
                  partition1,
                  1000, // value
                  0, // amount
                  TYPE_AMOUNT,
                  tokenHolder1,
                  INIT_RULES_TRUE,
                  tokenController1,
                  fund,
                  NEW_CYCLE_CREATED_TRUE
                )
              );
            });
          });
        });
      });
      describe("when the current period is not a subscription period (before first start time)", function () {
        it("reverts", async function () {
          const chainTime = (await web3.eth.getBlock("latest")).timestamp;

          await setAssetRules(
            this.fic,
            tokenController1,
            this.asset.address,
            partition1,
            chainTime + 10000,
            undefined,
            undefined,
            undefined,
            OFF_CHAIN_PAYMENT,
            ZERO_ADDRESS,
            ZERO_BYTES32,
            fund,
            true
          );

          await expectRevert.unspecified(
            subscribe(
              this.fic,
              this.asset.address,
              partition1,
              1000,
              0,
              TYPE_VALUE,
              tokenHolder1,
              INIT_RULES_FALSE,
              tokenController1,
              fund,
              NEW_CYCLE_CREATED_TRUE
            )
          );
        });
      });
    });
    describe("when the current cycle is not in subscription period", function () {
      describe("when rules are defined for the asset", function () {
        describe("when subscriptions are open", function () {
          describe("when cycle is the first cycle for this asset", function () {
            it("creates a new order", async function () {
              await subscribe(
                this.fic,
                this.asset.address,
                partition1,
                1000,
                0,
                TYPE_VALUE,
                tokenHolder1,
                INIT_RULES_TRUE,
                tokenController1,
                fund,
                NEW_CYCLE_CREATED_TRUE
              );
            });
            it("creates 3 orders", async function () {
              await subscribe(
                this.fic,
                this.asset.address,
                partition1,
                1000,
                0,
                TYPE_VALUE,
                tokenHolder1,
                INIT_RULES_TRUE,
                tokenController1,
                fund,
                NEW_CYCLE_CREATED_TRUE
              );
              await subscribe(
                this.fic,
                this.asset.address,
                partition1,
                1000,
                0,
                TYPE_VALUE,
                tokenHolder2,
                INIT_RULES_FALSE,
                tokenController1,
                fund,
                NEW_CYCLE_CREATED_FALSE
              );
              this.asset2 = await ERC1400.new(
                "ERC1400Token",
                "DAU",
                1,
                [owner],
                partitions,
                { from: tokenController2 }
              );
              await subscribe(
                this.fic,
                this.asset2.address,
                partition2,
                0,
                5000,
                TYPE_AMOUNT,
                tokenHolder2,
                INIT_RULES_TRUE,
                tokenController2,
                fund,
                NEW_CYCLE_CREATED_TRUE
              );
            });
          });
          describe("when cycle is not the first cycle for this asset", function () {
            it("creates 3 orders", async function () {
              await subscribe(
                this.fic,
                this.asset.address,
                partition1,
                1000,
                0,
                TYPE_VALUE,
                tokenHolder1,
                INIT_RULES_TRUE,
                tokenController1,
                fund,
                NEW_CYCLE_CREATED_TRUE
              );

              await assertCycleState(
                this.fic,
                this.asset.address,
                partition1,
                CYCLE_SUBSCRIPTION
              );

              // Wait until after the end of the first subsciption period
              await advanceTimeAndBlock(DEFAULT_SUBSCRIPTION_PERIOD_LENGTH + 1);

              await assertCycleState(
                this.fic,
                this.asset.address,
                partition1,
                CYCLE_VALUATION
              );

              await subscribe(
                this.fic,
                this.asset.address,
                partition1,
                1000,
                0,
                TYPE_VALUE,
                tokenHolder2,
                INIT_RULES_FALSE,
                tokenController1,
                fund,
                NEW_CYCLE_CREATED_TRUE
              );
            });
          });
        });
        describe("when subscriptions are not open", function () {
          it("reverts", async function () {
            await setAssetRules(
              this.fic,
              tokenController1,
              this.asset.address,
              partition1,
              undefined,
              undefined,
              undefined,
              undefined,
              OFF_CHAIN_PAYMENT,
              ZERO_ADDRESS,
              ZERO_BYTES32,
              fund,
              false
            );

            await expectRevert.unspecified(
              subscribe(
                this.fic,
                this.asset.address,
                partition1,
                1000,
                0,
                TYPE_VALUE,
                tokenHolder1,
                INIT_RULES_FALSE,
                tokenController1,
                fund,
                NEW_CYCLE_CREATED_TRUE
              )
            );
          });
        });
      });
      describe("when rules are not defined for the asset", function () {
        it("reverts", async function () {
          await expectRevert.unspecified(
            subscribe(
              this.fic,
              this.asset.address,
              partition1,
              1000,
              0,
              TYPE_VALUE,
              tokenHolder1,
              INIT_RULES_FALSE,
              tokenController1,
              fund,
              NEW_CYCLE_CREATED_TRUE
            )
          );
        });
      });
    });
  });

  // CANCELORDER

  describe("cancelOrder", function () {
    beforeEach(async function () {
      this.asset = await ERC1400.new(
        "ERC1400Token",
        "DAU",
        1,
        [owner],
        partitions,
        { from: tokenController1 }
      );
      this.fic = await FundIssuerContract.new();
      await subscribe(
        this.fic,
        this.asset.address,
        partition1,
        0,
        1000,
        TYPE_AMOUNT,
        tokenHolder1,
        INIT_RULES_TRUE,
        tokenController1,
        fund,
        NEW_CYCLE_CREATED_TRUE
      );
    });
    describe("when order exists and can still be cancelled", function () {
      describe("when subscription period is not over", function () {
        describe("when message sender is the investor", function () {
          describe("when order has not been paid yet", function () {
            it("cancels the order", async function () {
              const orderIndex = (
                await this.fic.getInvestorOrders(tokenHolder1)
              )[0].toNumber();
              const cycleIndex = (
                await this.fic.getLastCycleIndex(this.asset.address, partition1)
              ).toNumber();
              await assertOrder(
                this.fic,
                orderIndex,
                cycleIndex,
                tokenHolder1,
                0,
                1000,
                TYPE_AMOUNT,
                ORDER_SUBSCRIBED
              );
              await assertCycleState(
                this.fic,
                this.asset.address,
                partition1,
                CYCLE_SUBSCRIPTION
              );
              await this.fic.cancelOrder(orderIndex, { from: tokenHolder1 });
              await assertOrder(
                this.fic,
                orderIndex,
                cycleIndex,
                tokenHolder1,
                0,
                1000,
                TYPE_AMOUNT,
                ORDER_CANCELLED
              );
            });
          });
          describe("when order had already been paid", function () {
            // XXX
          });
        });
        describe("when message sender is not the investor", function () {
          it("reverts", async function () {
            const orderIndex = (
              await this.fic.getInvestorOrders(tokenHolder1)
            )[0].toNumber();
            await expectRevert.unspecified(
              this.fic.cancelOrder(orderIndex, { from: tokenHolder2 })
            );
          });
        });
      });
      describe("when subscription period is over", function () {
        it("reverts", async function () {
          await assertCycleState(
            this.fic,
            this.asset.address,
            partition1,
            CYCLE_SUBSCRIPTION
          );

          // Wait until after the end of the first subsciption period
          await advanceTimeAndBlock(DEFAULT_SUBSCRIPTION_PERIOD_LENGTH + 1);

          await assertCycleState(
            this.fic,
            this.asset.address,
            partition1,
            CYCLE_VALUATION
          );

          const orderIndex = (
            await this.fic.getInvestorOrders(tokenHolder1)
          )[0].toNumber();
          await expectRevert.unspecified(
            this.fic.cancelOrder(orderIndex, { from: tokenHolder1 })
          );
        });
      });
    });
    describe("when order can not be rejected", function () {
      describe("when order doesnt exist", function () {
        it("reverts", async function () {
          await expectRevert.unspecified(
            this.fic.cancelOrder(999999, { from: tokenHolder1 })
          );
        });
      });
      describe("when order has already been settled", function () {
        describe("when order has been paid", function () {
          it("reverts", async function () {
            // XXX
          });
        });
        describe("when order has not been paid", function () {
          it("reverts", async function () {
            // XXX
          });
        });
      });
      describe("when order has been cancelled", function () {
        it("reverts", async function () {
          // XXX
        });
      });
      describe("when order has already been rejected", function () {
        it("reverts", async function () {
          // XXX
        });
      });
    });
  });

  // VALUATE

  describe("valuate", function () {
    beforeEach(async function () {
      this.asset = await ERC1400.new(
        "ERC1400Token",
        "DAU",
        1,
        [owner],
        partitions,
        { from: tokenController1 }
      );
      this.fic = await FundIssuerContract.new();
      await subscribe(
        this.fic,
        this.asset.address,
        partition1,
        0,
        1000,
        TYPE_AMOUNT,
        tokenHolder1,
        INIT_RULES_TRUE,
        tokenController1,
        fund,
        NEW_CYCLE_CREATED_TRUE
      );
    });
    describe("when we are in the valuation period", function () {
      beforeEach(async function () {
        await assertCycleState(
          this.fic,
          this.asset.address,
          partition1,
          CYCLE_SUBSCRIPTION
        );
        // Wait until after the end of the first subscription period
        await advanceTimeAndBlock(DEFAULT_SUBSCRIPTION_PERIOD_LENGTH + 1);
        await assertCycleState(
          this.fic,
          this.asset.address,
          partition1,
          CYCLE_VALUATION
        );
      });
      describe("when cycle is of type unknown", function () {
        describe("when the provided values are valid", function () {
          describe("when the sender is a price oracle", function () {
            it("sets the valuation", async function () {
              const cycleIndex = (
                await this.fic.getLastCycleIndex(this.asset.address, partition1)
              ).toNumber();

              await assertCycleAssetValue(
                this.fic,
                cycleIndex,
                ASSET_VALUE_UNKNOWN,
                0,
                0
              );

              await this.fic.valuate(cycleIndex, 1000, 0, {
                from: tokenController1,
              });

              await assertCycleAssetValue(
                this.fic,
                cycleIndex,
                ASSET_VALUE_UNKNOWN,
                1000,
                0
              );
            });
            it("sets the reverse valuation", async function () {
              const cycleIndex = (
                await this.fic.getLastCycleIndex(this.asset.address, partition1)
              ).toNumber();

              await assertCycleAssetValue(
                this.fic,
                cycleIndex,
                ASSET_VALUE_UNKNOWN,
                0,
                0
              );

              await this.fic.valuate(cycleIndex, 0, 1000, {
                from: tokenController1,
              });

              await assertCycleAssetValue(
                this.fic,
                cycleIndex,
                ASSET_VALUE_UNKNOWN,
                0,
                1000
              );
            });
            it("sets the valuation twice", async function () {
              const cycleIndex = (
                await this.fic.getLastCycleIndex(this.asset.address, partition1)
              ).toNumber();

              await assertCycleAssetValue(
                this.fic,
                cycleIndex,
                ASSET_VALUE_UNKNOWN,
                0,
                0
              );

              await this.fic.valuate(cycleIndex, 1000, 0, {
                from: tokenController1,
              });

              await assertCycleAssetValue(
                this.fic,
                cycleIndex,
                ASSET_VALUE_UNKNOWN,
                1000,
                0
              );

              await this.fic.valuate(cycleIndex, 0, 500, {
                from: tokenController1,
              });

              await assertCycleAssetValue(
                this.fic,
                cycleIndex,
                ASSET_VALUE_UNKNOWN,
                0,
                500
              );
            });
          });
          describe("when the sender is not a price oracle", function () {
            it("reverts", async function () {
              const cycleIndex = (
                await this.fic.getLastCycleIndex(this.asset.address, partition1)
              ).toNumber();

              await assertCycleAssetValue(
                this.fic,
                cycleIndex,
                ASSET_VALUE_UNKNOWN,
                0,
                0
              );

              await expectRevert.unspecified(
                this.fic.valuate(cycleIndex, 1000, 0, {
                  from: tokenController2,
                })
              );
            });
          });
        });
        describe("when the provided values are not valid", function () {
          it("reverts", async function () {
            const cycleIndex = (
              await this.fic.getLastCycleIndex(this.asset.address, partition1)
            ).toNumber();

            await assertCycleAssetValue(
              this.fic,
              cycleIndex,
              ASSET_VALUE_UNKNOWN,
              0,
              0
            );

            await expectRevert.unspecified(
              this.fic.valuate(cycleIndex, 1000, 1000, {
                from: tokenController1,
              })
            );
          });
        });
      });
      describe("when cycle is of type known", function () {
        it("set the valuation", async function () {
          this.asset2 = await ERC1400.new(
            "ERC1400Token",
            "DAU",
            1,
            [owner],
            partitions,
            { from: tokenController1 }
          );
          this.fic = await FundIssuerContract.new();
          await setAssetRules(
            this.fic,
            tokenController1,
            this.asset2.address,
            partition1,
            undefined,
            undefined,
            undefined,
            undefined,
            OFF_CHAIN_PAYMENT,
            ZERO_ADDRESS,
            ZERO_BYTES32,
            fund,
            true
          );
          await this.fic.setAssetValueRules(
            this.asset2.address,
            partition1,
            ASSET_VALUE_KNOWN,
            1000,
            0,
            { from: tokenController1 }
          );
          await this.fic.subscribe(
            this.asset2.address,
            partition1,
            0,
            1000,
            TYPE_AMOUNT,
            false, // executePaymentAtSubscription
            { from: tokenHolder1 }
          );
          await assertCycleState(
            this.fic,
            this.asset2.address,
            partition1,
            CYCLE_SUBSCRIPTION
          );
          // Wait until after the end of the first subscription period
          await advanceTimeAndBlock(DEFAULT_SUBSCRIPTION_PERIOD_LENGTH + 1);
          await assertCycleState(
            this.fic,
            this.asset2.address,
            partition1,
            CYCLE_VALUATION
          );

          const cycleIndex = (
            await this.fic.getLastCycleIndex(this.asset2.address, partition1)
          ).toNumber();

          await assertCycleAssetValue(
            this.fic,
            cycleIndex,
            ASSET_VALUE_KNOWN,
            1000,
            0
          );

          await expectRevert.unspecified(
            this.fic.valuate(cycleIndex, 0, 1000, { from: tokenController1 })
          );
        });
      });
    });
    describe("when we are in the subscription period", function () {
      beforeEach(async function () {
        await assertCycleState(
          this.fic,
          this.asset.address,
          partition1,
          CYCLE_SUBSCRIPTION
        );
      });
      it("reverts", async function () {
        const cycleIndex = (
          await this.fic.getLastCycleIndex(this.asset.address, partition1)
        ).toNumber();

        await assertCycleAssetValue(
          this.fic,
          cycleIndex,
          ASSET_VALUE_UNKNOWN,
          0,
          0
        );

        await expectRevert.unspecified(
          this.fic.valuate(cycleIndex, 1000, 0, { from: tokenController1 })
        );
      });
    });
    describe("when we are in the payment period", function () {
      beforeEach(async function () {
        await assertCycleState(
          this.fic,
          this.asset.address,
          partition1,
          CYCLE_SUBSCRIPTION
        );
        // Wait until after the end of the first valuation period
        await advanceTimeAndBlock(
          DEFAULT_SUBSCRIPTION_PERIOD_LENGTH +
            DEFAULT_VALUATION_PERIOD_LENGTH +
            1
        );
        await assertCycleState(
          this.fic,
          this.asset.address,
          partition1,
          CYCLE_PAYMENT
        );
      });
      it("reverts", async function () {
        const cycleIndex = (
          await this.fic.getLastCycleIndex(this.asset.address, partition1)
        ).toNumber();

        await assertCycleAssetValue(
          this.fic,
          cycleIndex,
          ASSET_VALUE_UNKNOWN,
          0,
          0
        );

        await expectRevert.unspecified(
          this.fic.valuate(cycleIndex, 1000, 0, { from: tokenController1 })
        );
      });
    });
  });
});
