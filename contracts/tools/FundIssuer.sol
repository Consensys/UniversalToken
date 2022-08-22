// SPDX-License-Identifier: Apache-2.0
/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./ERC1820Client.sol";
import "../interface/ERC1820Implementer.sol";

import "../extensions/userExtensions/IERC1400TokensRecipient.sol";
import "../ERC1400.sol";

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


/**
 * @title FundIssuer
 * @dev Fund issuance contract.
 * @dev Intended usage:
 * The purpose of the contract is to perform a fund issuance.
 *
 */
contract FundIssuer is ERC1820Client, IERC1400TokensRecipient, ERC1820Implementer {
  using SafeMath for uint256;

  bytes32 constant internal ORDER_SUBSCRIPTION_FLAG = 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc;
  bytes32 constant internal ORDER_PAYMENT_FLAG = 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd;

  bytes32 constant internal BYPASS_ACTION_FLAG = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

  string constant internal FUND_ISSUER = "FundIssuer";
  string constant internal ERC1400_TOKENS_RECIPIENT = "ERC1400TokensRecipient";

  enum CycleState {Undefined, Subscription, Valuation, Payment, Settlement, Finalized}

  enum OrderState {Undefined, Subscribed, Paid, PaidSettled, UnpaidSettled, Cancelled, Rejected}

  enum OrderType {Undefined, Value, Amount}

  enum Payment {OffChain, ETH, ERC20, ERC1400}

  enum AssetValue {Unknown, Known}

  struct AssetRules {
    bool defined;
    uint256 firstStartTime;
    uint256 subscriptionPeriodLength;
    uint256 valuationPeriodLength;
    uint256 paymentPeriodLength;
    AssetValue assetValueType;
    uint256 assetValue;
    uint256 reverseAssetValue;
    Payment paymentType;
    address paymentAddress;
    bytes32 paymentPartition;
    address fundAddress;
    bool subscriptionsOpened;
  }
  
  struct Cycle {
    address assetAddress;
    bytes32 assetClass;
    uint256 startTime;
    uint256 subscriptionPeriodLength;
    uint256 valuationPeriodLength;
    uint256 paymentPeriodLength;
    AssetValue assetValueType;
    uint256 assetValue;
    uint256 reverseAssetValue;
    Payment paymentType;
    address paymentAddress;
    bytes32 paymentPartition;
    address fundAddress;
    bool finalized;
  }

  struct Order {
    uint256 cycleIndex;
    address investor;
    uint256 value;
    uint256 amount;
    OrderType orderType;
    OrderState state;
  }

  // Mapping from (assetAddress, assetClass) to asset rules.
  mapping(address => mapping(bytes32 => AssetRules)) internal _assetRules;

  // Index of most recent cycle.
  uint256 internal _cycleIndex;

  // Mapping from cycle index to cycle.
  mapping(uint256 => Cycle) internal _cycles;

  // Mapping from (assetAddress, assetClass) to most recent cycle.
  mapping(address => mapping (bytes32 => uint256)) internal _lastCycleIndex;

  // Index of most recent order.
  uint256 internal _orderIndex;

  // Mapping from order index to order.
  mapping(uint256 => Order) internal _orders;

  // Mapping from cycle index to order list.
  mapping(uint256 => uint256[]) internal _cycleOrders;

  // Mapping from investor address to order list.
  mapping(address => uint256[]) internal _investorOrders;

  // Mapping from assetAddress to amount of escrowed ETH.
  mapping(address => uint256) internal _escrowedEth;

  // Mapping from (assetAddress, paymentAddress) to amount of escrowed ERC20.
  mapping(address => mapping (address => uint256)) internal _escrowedErc20;

  // Mapping from (assetAddress, paymentAddress, paymentPartition) to amount of escrowed ERC1400.
  mapping(address => mapping (address => mapping (bytes32 => uint256))) internal _escrowedErc1400;

  // Mapping from token to token controllers.
  mapping(address => address[]) internal _tokenControllers;

  // Mapping from (token, operator) to token controller status.
  mapping(address => mapping(address => bool)) internal _isTokenController;

  // Mapping from token to price oracles.
  mapping(address => address[]) internal _priceOracles;

  // Mapping from (token, operator) to price oracle status.
  mapping(address => mapping(address => bool)) internal _isPriceOracle;

  /**
   * @dev Modifier to verify if sender is a token controller.
   */
  modifier onlyTokenController(address tokenAddress) {
    require(_tokenController(msg.sender, tokenAddress),
      "Sender is not a token controller."
    );
    _;
  }

  /**
   * @dev Modifier to verify if sender is a price oracle.
   */
  modifier onlyPriceOracle(address assetAddress) {
    require(_checkPriceOracle(assetAddress, msg.sender), "Sender is not a price oracle.");
    _;
  }

  /**
   * [Swaps CONSTRUCTOR]
   * @dev Initialize Fund issuance contract + register
   * the contract implementation in ERC1820Registry.
   */
  constructor() {
    ERC1820Implementer._setInterface(FUND_ISSUER);
    ERC1820Implementer._setInterface(ERC1400_TOKENS_RECIPIENT);
    setInterfaceImplementation(ERC1400_TOKENS_RECIPIENT, address(this));
  }

 /**
   * [ERC1400TokensRecipient INTERFACE (1/2)]
   * @dev Indicate whether or not the fund issuance contract can receive the tokens or not. [USED FOR ERC1400 TOKENS ONLY]
   * @param data Information attached to the token transfer.
   * @param operatorData Information attached to the Swaps transfer, by the operator.
   * @return 'true' if the Swaps contract can receive the tokens, 'false' if not.
   */
  function canReceive(bytes calldata, bytes32, address, address, address, uint, bytes calldata  data, bytes calldata operatorData) external override pure returns(bool) {
    return(_canReceive(data, operatorData));
  }

  /**
   * [ERC1400TokensRecipient INTERFACE (2/2)]
   * @dev Hook function executed when tokens are sent to the fund issuance contract. [USED FOR ERC1400 TOKENS ONLY]
   * @param partition Name of the partition.
   * @param from Token holder.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the token transfer.
   * @param operatorData Information attached to the Swaps transfer, by the operator.
   */
  function tokensReceived(bytes calldata, bytes32 partition, address, address from, address to, uint value, bytes calldata data, bytes calldata operatorData) external override {
    require(interfaceAddr(msg.sender, "ERC1400Token") == msg.sender, "55"); // 0x55 funds locked (lockup period)

    require(to == address(this), "50"); // 0x50	transfer failure
    require(_canReceive(data, operatorData), "57"); // 0x57	invalid receiver

    bytes32 flag = _getTransferFlag(data);
    bytes memory erc1400TokenData = abi.encode(msg.sender, partition, value);

    if (flag == ORDER_SUBSCRIPTION_FLAG) {

      address assetAddress = _getAssetAddress(data);
      bytes32 assetClass = _getAssetClass(data);
      bytes memory orderData = _getOrderData(data);

      _subscribe(
        from,
        assetAddress,
        assetClass,
        orderData,
        true,
        erc1400TokenData
      );

    } else if (flag == ORDER_PAYMENT_FLAG) {
      uint256 orderIndex = _getOrderIndex(data);
      Order storage order = _orders[orderIndex];
      require(from == order.investor, "Payment sender is not the subscriber");

      _executePayment(orderIndex, erc1400TokenData, false);         
    }
  }


  /**
   * @dev Start a new subscription for a given asset in the fund issuance smart contract.
   * @param assetAddress Address of the token representing the asset.
   * @param assetClass Asset class.
   * @param subscriptionPeriodLength Length of subscription period.
   * @param valuationPeriodLength Length of valuation period.
   * @param paymentPeriodLength Length of payment period.
   * @param paymentType Type of payment (OFFCHAIN | ERC20 | ERC1400).
   * @param paymentAddress Address of the payment token (only used id paymentType <> OFFCHAIN).
   * @param paymentPartition Partition of the payment token (only used if paymentType is ERC1400).
   * @param subscriptionsOpened Set 'true' if subscriptions are opened, 'false' if not.
   */
  function setAssetRules(
    address assetAddress,
    bytes32 assetClass,
    uint256 firstStartTime,
    uint256 subscriptionPeriodLength,
    uint256 valuationPeriodLength,
    uint256 paymentPeriodLength,
    Payment paymentType,
    address paymentAddress,
    bytes32 paymentPartition,
    address fundAddress,
    bool subscriptionsOpened
  )
    external
    onlyTokenController(assetAddress)
  {
    AssetRules storage rules = _assetRules[assetAddress][assetClass];

    require(firstStartTime >= block.timestamp, "First cycle start can not be prior to now");

    require(subscriptionPeriodLength != 0 && valuationPeriodLength != 0 && paymentPeriodLength != 0, "Periods can not be nil");

    if(rules.defined) {
      rules.firstStartTime = firstStartTime;
      rules.subscriptionPeriodLength = subscriptionPeriodLength;
      rules.valuationPeriodLength = valuationPeriodLength;
      rules.paymentPeriodLength = paymentPeriodLength;
      // rules.assetValueType = assetValueType; // Can only be modified by the price oracle
      // rules.assetValue = assetValue; // Can only be modified by the price oracle
      // rules.reverseAssetValue = reverseAssetValue; // Can only be modified by the price oracle
      rules.paymentType = paymentType;
      rules.paymentAddress = paymentAddress;
      rules.paymentPartition = paymentPartition;
      rules.fundAddress = fundAddress;
      rules.subscriptionsOpened = subscriptionsOpened;
    } else {

      _assetRules[assetAddress][assetClass] = AssetRules({
        defined: true,
        firstStartTime: firstStartTime,
        subscriptionPeriodLength: subscriptionPeriodLength,
        valuationPeriodLength: valuationPeriodLength,
        paymentPeriodLength: paymentPeriodLength,
        assetValueType: AssetValue.Unknown,
        assetValue: 0,
        reverseAssetValue: 0,
        paymentType: paymentType,
        paymentAddress: paymentAddress,
        paymentPartition: paymentPartition,
        fundAddress: fundAddress,
        subscriptionsOpened: subscriptionsOpened
      });
    }

  }

  /**
   * @dev Set asset value rules for a given asset.
   * @param assetAddress Address of the token representing the asset.
   * @param assetClass Asset class.
   * @param assetValueType Asset value type.
   * @param assetValue Asset value.
   * @param reverseAssetValue Reverse asset value.
   */
  function setAssetValueRules(
    address assetAddress,
    bytes32 assetClass,
    AssetValue assetValueType,
    uint256 assetValue,
    uint256 reverseAssetValue
  )
    external
    onlyPriceOracle(assetAddress)
  {
    AssetRules storage rules = _assetRules[assetAddress][assetClass];

    require(rules.defined, "Rules not defined for this asset");

    require(assetValue == 0 || reverseAssetValue == 0, "Asset value can only be set in one direction");

    rules.assetValueType = assetValueType;
    rules.assetValue = assetValue;
    rules.reverseAssetValue = reverseAssetValue;
  }

  /**
   * @dev Start a new subscription for a given asset in the fund issuance smart contract.
   * @param assetAddress Address of the token representing the asset.
   * @param assetClass Asset class.
   * @return Index of new cycle.
   */
  function _startNewCycle(
    address assetAddress,
    bytes32 assetClass
  )
    internal
    returns(uint256)
  {
    AssetRules storage rules = _assetRules[assetAddress][assetClass];
    require(rules.defined, "Rules not defined for this asset");
    require(rules.subscriptionsOpened, "Subscriptions not opened for this asset");

    uint256 lastCycleIndex = _lastCycleIndex[assetAddress][assetClass];
    Cycle storage lastCycle = _cycles[lastCycleIndex];
    uint256 previousStartTime = (lastCycle.startTime != 0) ? lastCycle.startTime : rules.firstStartTime;

    _cycleIndex = _cycleIndex.add(1);

    _cycles[_cycleIndex] = Cycle({
      assetAddress: assetAddress,
      assetClass: assetClass,
      startTime: _getNextStartTime(previousStartTime, rules.subscriptionPeriodLength),
      subscriptionPeriodLength: rules.subscriptionPeriodLength,
      valuationPeriodLength: rules.valuationPeriodLength,
      paymentPeriodLength: rules.paymentPeriodLength,
      assetValueType: rules.assetValueType,
      assetValue: rules.assetValue,
      reverseAssetValue: rules.reverseAssetValue,
      paymentType: rules.paymentType,
      paymentAddress: rules.paymentAddress,
      paymentPartition: rules.paymentPartition,
      fundAddress: rules.fundAddress,
      finalized: false
    });

    _lastCycleIndex[assetAddress][assetClass] = _cycleIndex;

    return _cycleIndex;
  }

  /**
   * @dev Returns time of next cycle start.
   * @param previousStartTime Previous start time.
   * @param subscriptionPeriod Time between subscription period start and cut-off.
   * @return Time of next cycle start.
   */
  function _getNextStartTime(uint256 previousStartTime, uint256 subscriptionPeriod) internal view returns(uint256) {
    if(previousStartTime >= block.timestamp) {
      return previousStartTime;
    } else {
      return block.timestamp.sub((block.timestamp - previousStartTime).mod(subscriptionPeriod));
    }
  }

  /**
   * @dev Subscribe for a given asset, by creating an order.
   * @param assetAddress Address of the token representing the asset.
   * @param assetClass Asset class.
   * @param orderValue Value of assets to purchase (used in case order type is 'value').
   * @param orderAmount Amount of assets to purchase (used in case order type is 'amount').
   * @param orderType Order type (value | amount).
   */
  function subscribe(
    address assetAddress,
    bytes32 assetClass,
    uint256 orderValue,
    uint256 orderAmount,
    OrderType orderType,
    bool executePaymentAtSubscription
  )
    external
    payable
    returns(uint256)
  {
    bytes memory orderData = abi.encode(orderValue, orderAmount, orderType);

    return _subscribe(
      msg.sender,
      assetAddress,
      assetClass,
      orderData,
      executePaymentAtSubscription,
      new bytes(0)
    );
  }
  
  /**
   * @dev Subscribe for a given asset, by creating an order.
   * @param assetAddress Address of the token representing the asset.
   * @param assetClass Asset class.
   * @param orderData Encoded pack of variables for order (orderValue, orderAmount, orderType).
   * @param executePaymentAtSubscription 'true' if payment shall be executed at subscription, 'false' if not.
   * @param erc1400TokenData Encoded pack of variables for erc1400 token (paymentAddress, paymentPartition, paymentValue).
   */
  function _subscribe(
    address investor,
    address assetAddress,
    bytes32 assetClass,
    bytes memory orderData,
    bool executePaymentAtSubscription,
    bytes memory erc1400TokenData
  )
    internal
    returns(uint256)
  {
    uint256 lastIndex = _lastCycleIndex[assetAddress][assetClass];
    CycleState currentState = _getCycleState(lastIndex);

    if(currentState != CycleState.Subscription) {
      lastIndex = _startNewCycle(assetAddress, assetClass);
    }

    require(_getCycleState(lastIndex) == CycleState.Subscription, "Subscription can only be performed during subscription period");

    (uint256 value, uint256 amount, OrderType orderType) = abi.decode(orderData, (uint256, uint256, OrderType));

    require(value == 0 || amount == 0, "Order can not be of type amount and value at the same time");

    if(orderType == OrderType.Value) {
      require(value != 0, "Order value shall not be nil");
    } else if(orderType == OrderType.Amount) {
      require(amount != 0, "Order amount shall not be nil");
    } else {
      revert("Order type needs to be value or amount");
    }

    _orderIndex++;

    _orders[_orderIndex] = Order({
      cycleIndex: lastIndex,
      investor: investor,
      value: value,
      amount: amount,
      orderType: orderType,
      state: OrderState.Subscribed
    });

    _cycleOrders[lastIndex].push(_orderIndex);

    _investorOrders[investor].push(_orderIndex);

    Cycle storage cycle = _cycles[lastIndex];
    if(cycle.assetValueType == AssetValue.Known && executePaymentAtSubscription) {
      _executePayment(_orderIndex, erc1400TokenData, false);
    }

    return _orderIndex;
  }

  /**
   * @dev Cancel an order.
   * @param orderIndex Index of the order to cancel.
   */
  function cancelOrder(uint256 orderIndex) external {
    Order storage order = _orders[orderIndex];

    require(
      order.state == OrderState.Subscribed ||
      order.state == OrderState.Paid,
      "Only subscribed or paid orders can be cancelled"
    ); // This also checks if the order exists. Otherwise, we would have "order.state == OrderState.Undefined"

    require(_getCycleState(order.cycleIndex) < CycleState.Valuation, "Orders can only be cancelled before cut-off");

    require(msg.sender == order.investor);

    if(order.state == OrderState.Paid) {
      _releasePayment(orderIndex, order.investor);
    }

    order.state = OrderState.Cancelled;
  }

  /**
   * @dev Reject an order.
   * @param orderIndex Index of the order to reject.
   * @param rejected Set to 'true' if order shall be rejected, and set to 'false' if rejection shall be cancelled
   */
  function rejectOrder(uint256 orderIndex, bool rejected)
    external
  {
    Order storage order = _orders[orderIndex];
    
    require(
      order.state == OrderState.Subscribed ||
      order.state == OrderState.Paid ||
      order.state == OrderState.Rejected
      ,
      "Order rejection can only handled for subscribed or paid orders"
    ); // This also checks if the order exists. Otherwise, we would have "order.state == OrderState.Undefined"

    require(_getCycleState(order.cycleIndex) < CycleState.Payment , "Orders can only be rejected before beginning of payment phase");

    Cycle storage cycle = _cycles[order.cycleIndex];

    require(_tokenController(msg.sender, cycle.assetAddress),
      "Sender is not a token controller."
    );

    if(rejected) {
      if(order.state == OrderState.Paid) {
      _releasePayment(orderIndex, order.investor);
      }
      order.state = OrderState.Rejected;
    } else {
      order.state = OrderState.Subscribed;
    }
  }

  /**
   * @dev Set assetValue for a given asset.
   * @param cycleIndex Index of the cycle where assetValue needs to be set.
   * @param assetValue Units of cash required for a unit of asset.
   * @param reverseAssetValue Units of asset required for a unit of cash.
   */
  function valuate(
    uint256 cycleIndex,
    uint256 assetValue,
    uint256 reverseAssetValue
  )
    external
  {
    Cycle storage cycle = _cycles[cycleIndex];
    CycleState cycleState = _getCycleState(cycleIndex);

    require(cycleState > CycleState.Subscription && cycleState < CycleState.Payment , "AssetValue can only be set during valuation period");

    require(cycle.assetValueType == AssetValue.Unknown, "Asset value can only be set for a cycle of type unkonwn");

    require(assetValue == 0 || reverseAssetValue == 0, "Asset value can only be set in one direction");

    require(_checkPriceOracle(cycle.assetAddress, msg.sender), "Sender is not a price oracle.");
    
    cycle.assetValue = assetValue;
    cycle.reverseAssetValue = reverseAssetValue;
  }

  /**
   * @dev Execute payment for a given order.
   * @param orderIndex Index of the order to declare as paid.
   */
  function executePaymentAsInvestor(uint256 orderIndex) external payable {
    Order storage order = _orders[orderIndex];

    require(msg.sender == order.investor);

    _executePayment(orderIndex, new bytes(0), false);
  }

  /**
   * @dev Set payment as executed for a given order.
   * @param orderIndex Index of the order to declare as paid.
   * @param bypassPayment Bypass payment (in case payment has been performed off-chain)
   */
  function executePaymentAsController(uint256 orderIndex, bool bypassPayment) external {
    Order storage order = _orders[orderIndex];
    Cycle storage cycle = _cycles[order.cycleIndex];

    require(_tokenController(msg.sender, cycle.assetAddress),
      "Sender is not a token controller."
    );

    _executePayment(orderIndex, new bytes(0), bypassPayment);
  }

  /**
   * @dev Set payments as executed for a batch of given orders.
   * @param orderIndexes Indexes of the orders to declare as paid.
   * @param bypassPayment Bypass payment (in case payment has been performed off-chain)
   */
  function batchExecutePaymentsAsController(uint256[] calldata orderIndexes, bool bypassPayment)
    external
  {
    for (uint i = 0; i<orderIndexes.length; i++){
      Order storage order = _orders[orderIndexes[i]];
      Cycle storage cycle = _cycles[order.cycleIndex];

      require(_tokenController(msg.sender, cycle.assetAddress),
        "Sender is not a token controller."
      );

      _executePayment(orderIndexes[i], new bytes(0), bypassPayment);
    }
  }

  /**
   * @dev Pay for a given order.
   * @param orderIndex Index of the order to declare as paid.
   * @param erc1400TokenData Encoded pack of variables for erc1400 token (paymentAddress, paymentPartition, paymentValue).
   * @param bypassPayment Bypass payment (in case payment has been performed off-chain)
   */
  function _executePayment(
    uint256 orderIndex,
    bytes memory erc1400TokenData,
    bool bypassPayment
  )
    internal
  {
    Order storage order = _orders[orderIndex];
    Cycle storage cycle = _cycles[order.cycleIndex];

    require(
      order.state == OrderState.Subscribed ||
      order.state == OrderState.UnpaidSettled,
      "Order is neither in state Subscribed, nor UnpaidSettled"
    ); // This also checks if the order exists. Otherwise, we would have "order.state == OrderState.Undefined"

    require(!cycle.finalized, "Cycle is already finalized");

    if(cycle.assetValueType == AssetValue.Unknown) {
      require(_getCycleState(order.cycleIndex) >= CycleState.Payment , "Payment can only be performed after valuation period");
    } else {
      require(_getCycleState(order.cycleIndex) >= CycleState.Subscription , "Payment can only be performed after start of subscription period");
    }

    require(order.orderType == OrderType.Value || order.orderType == OrderType.Amount, "Invalid order type");

    (uint256 amount, uint256 value) = _getOrderAmountAndValue(orderIndex);
    order.amount = amount;
    order.value = value;

    if(!bypassPayment) {
      if (cycle.paymentType == Payment.ETH) {
        require(msg.value == value, "Amount of ETH is not correct");
        _escrowedEth[cycle.assetAddress] += value;
      } else if (cycle.paymentType == Payment.ERC20) {
        ERC20(cycle.paymentAddress).transferFrom(msg.sender, address(this), value);
        _escrowedErc20[cycle.assetAddress][cycle.paymentAddress] += value;
      } else if(cycle.paymentType == Payment.ERC1400 && erc1400TokenData.length == 0) {
        ERC1400(cycle.paymentAddress).operatorTransferByPartition(cycle.paymentPartition, msg.sender, address(this), value, abi.encodePacked(BYPASS_ACTION_FLAG), abi.encodePacked(BYPASS_ACTION_FLAG));
        _escrowedErc1400[cycle.assetAddress][cycle.paymentAddress][cycle.paymentPartition] += value;
      } else if(cycle.paymentType == Payment.ERC1400 && erc1400TokenData.length != 0) {
        (address erc1400TokenAddress, bytes32 erc1400TokenPartition, uint256 erc1400PaymentValue) = abi.decode(erc1400TokenData, (address, bytes32, uint256));
        require(erc1400PaymentValue == value, "wrong payment value");
        require(Payment.ERC1400 == cycle.paymentType, "ERC1400 payment is not accecpted for this asset");
        require(erc1400TokenAddress == cycle.paymentAddress, "wrong payment token address");
        require(erc1400TokenPartition == cycle.paymentPartition, "wrong payment token partition");
        _escrowedErc1400[cycle.assetAddress][cycle.paymentAddress][cycle.paymentPartition] += value;
      } else {
        revert("off-chain payment needs to be bypassed");
      }
    }

    if(order.state == OrderState.UnpaidSettled) {
      _releasePayment(orderIndex, cycle.fundAddress);
      order.state = OrderState.PaidSettled;
    } else {
      order.state = OrderState.Paid;
    }
  }

  /**
   * @dev Retrieve order amount and order value calculated based on cycle valuation.
   * @param orderIndex Index of the order.
   * @return Order amount.
   * @return Order value.
   */
  function _getOrderAmountAndValue(uint256 orderIndex) internal view returns(uint256, uint256) {
    Order storage order = _orders[orderIndex];
    Cycle storage cycle = _cycles[order.cycleIndex];

    uint256 value;
    uint256 amount;
    if(order.orderType == OrderType.Value) {
      value = order.value;
      if(cycle.assetValue != 0) {
        amount = value.div(cycle.assetValue);
      } else {
        amount = value.mul(cycle.reverseAssetValue);
      }
    }
    
    if(order.orderType == OrderType.Amount) {
      amount = order.amount;
      if(cycle.assetValue != 0) {
        value = amount.mul(cycle.assetValue);
      } else {
        value = amount.div(cycle.reverseAssetValue);
      }
    }

    return(amount, value);

  }

  /**
   * @dev Release payment for a given order.
   * @param orderIndex Index of the order of the payment to be sent.
   * @param recipient Address to receive to the payment.
   */
  function _releasePayment(uint256 orderIndex, address recipient) internal {
    Order storage order = _orders[orderIndex];
    Cycle storage cycle = _cycles[order.cycleIndex];

    if(cycle.paymentType == Payment.ETH) {
      address payable refundAddress = payable(recipient);
      refundAddress.transfer(order.value);
      _escrowedEth[cycle.assetAddress] -= order.value;
    } else if(cycle.paymentType == Payment.ERC20) {
      ERC20(cycle.paymentAddress).transfer(recipient, order.value);
      _escrowedErc20[cycle.assetAddress][cycle.paymentAddress] -= order.value;
    } else if(cycle.paymentType == Payment.ERC1400) {
      ERC1400(cycle.paymentAddress).transferByPartition(cycle.paymentPartition, recipient, order.value, abi.encodePacked(BYPASS_ACTION_FLAG));
      _escrowedErc1400[cycle.assetAddress][cycle.paymentAddress][cycle.paymentPartition] -= order.value;
    }
  }

  /**
   * @dev Settle a given order.
   * @param orderIndex Index of the order to settle.
   */
  function settleOrder(uint256 orderIndex) internal {
    Order storage order = _orders[orderIndex];
    Cycle storage cycle = _cycles[order.cycleIndex];

    require(_tokenController(msg.sender, cycle.assetAddress),
      "Sender is not a token controller."
    );

    _settleOrder(orderIndex);
  }

  /**
   * @dev Settle a batch of given orders.
   * @param orderIndexes Indexes of the orders to settle.
   */
  function batchSettleOrders(uint256[] calldata orderIndexes)
    external
  {
    for (uint i = 0; i<orderIndexes.length; i++){
      Order storage order = _orders[orderIndexes[i]];
      Cycle storage cycle = _cycles[order.cycleIndex];

      require(_tokenController(msg.sender, cycle.assetAddress),
        "Sender is not a token controller."
      );

      _settleOrder(orderIndexes[i]);
    }
  }

  /**
   * @dev Settle a given order.
   * @param orderIndex Index of the order to settle.
   */
  function _settleOrder(uint256 orderIndex) internal {
    Order storage order = _orders[orderIndex];

    require(order.state > OrderState.Undefined, "Order doesnt exist");

    CycleState currentState = _getCycleState(order.cycleIndex);

    Cycle storage cycle = _cycles[order.cycleIndex];

    if(cycle.assetValueType == AssetValue.Unknown) {
      require(currentState >= CycleState.Settlement, "Order settlement can only be performed during settlement period");
    } else {
      require(currentState >= CycleState.Valuation, "Order settlement can only be performed after the cut-off");
    }

    _releasePayment(orderIndex, cycle.fundAddress);

    if(order.state == OrderState.Paid) {
      ERC1400(cycle.assetAddress).issueByPartition(cycle.assetClass, order.investor, order.amount, "");
      order.state = OrderState.PaidSettled;
    } else if (order.state == OrderState.Subscribed) {
      ERC1400(cycle.assetAddress).issueByPartition(cycle.assetClass, address(this), order.amount, "");
      order.state = OrderState.UnpaidSettled;
    } else {
      revert("Impossible to settle an order that is neither in state Paid, nor Subscribed");
    }
  }

  /**
   * @dev Finalize a given cycle.
   * @param cycleIndex Index of the cycle to finalize.
   */
  function finalizeCycle(uint256 cycleIndex) external {
    Cycle storage cycle = _cycles[cycleIndex];

    require(_tokenController(msg.sender, cycle.assetAddress),
      "Sender is not a token controller."
    );

    require(!cycle.finalized, "Cycle is already finalized");

    (, uint256 totalUnpaidSettled, bool remainingOrdersToSettle) = _getTotalSettledForCycle(cycleIndex);

    if(!remainingOrdersToSettle) {
      cycle.finalized = true;
      if(totalUnpaidSettled != 0) {
        ERC1400(cycle.assetAddress).transferByPartition(cycle.assetClass, cycle.fundAddress, totalUnpaidSettled, "");
      }
    } else {
      revert("Remaining orders to settle");
    }
  }

  /**
   * @dev Retrieve sum of paid/unpaid settled orders for a given cycle.
   *
   * @param cycleIndex Index of the cycle.
   * @return Sum of paid settled orders.
   * @return Sum of unpaid settled orders.
   * @return 'True' if there are remaining orders to settle, 'false' if not.
   */
  function getTotalSettledForCycle(uint256 cycleIndex) external view returns(uint256, uint256, bool) {
    return _getTotalSettledForCycle(cycleIndex);
  }

  /**
   * @dev Retrieve sum of paid/unpaid settled orders for a given cycle.
   *
   * @param cycleIndex Index of the cycle.
   * @return Sum of paid settled orders.
   * @return Sum of unpaid settled orders.
   * @return 'True' if there are remaining orders to settle, 'false' if not.
   */
  function _getTotalSettledForCycle(uint256 cycleIndex) internal view returns(uint256, uint256, bool) {
    uint256 totalPaidSettled;
    uint256 totalUnpaidSettled;
    bool remainingOrdersToSettle;

    for (uint i = 0; i<_cycleOrders[cycleIndex].length; i++){
      Order storage order = _orders[_cycleOrders[cycleIndex][i]];

      if(order.state == OrderState.PaidSettled) {
        totalPaidSettled = totalPaidSettled.add(order.amount);
      } else if(order.state == OrderState.UnpaidSettled) {
        totalUnpaidSettled = totalUnpaidSettled.add(order.amount);
      } else if(
        order.state != OrderState.Cancelled &&
        order.state != OrderState.Rejected
      ) {
        remainingOrdersToSettle = true;
      }

    }

    return (totalPaidSettled, totalUnpaidSettled, remainingOrdersToSettle);
  }

  /**
   * @dev Retrieve the current state of the cycle.
   *
   * @param cycleIndex Index of the cycle.
   * @return Cycle state.
   */
  function getCycleState(uint256 cycleIndex) external view returns(CycleState) {
    return _getCycleState(cycleIndex);
  }

  /**
   * @dev Retrieve the current state of the cycle.
   *
   * @param cycleIndex Index of the cycle.
   * @return Cycle state.
   */
  function _getCycleState(uint256 cycleIndex) internal view returns(CycleState) {
    Cycle storage cycle = _cycles[cycleIndex];

    if(block.timestamp < cycle.startTime || cycle.startTime == 0) {
      return CycleState.Undefined;
    } else if(block.timestamp < cycle.startTime + cycle.subscriptionPeriodLength) {
      return CycleState.Subscription;
    } else if(block.timestamp < cycle.startTime + cycle.subscriptionPeriodLength + cycle.valuationPeriodLength) {
      return CycleState.Valuation;
    } else if(block.timestamp < cycle.startTime + cycle.subscriptionPeriodLength + cycle.valuationPeriodLength + cycle.paymentPeriodLength) {
      return CycleState.Payment;
    } else if(!cycle.finalized){
      return CycleState.Settlement; 
    } else {
      return CycleState.Finalized;
    }
  }

  /**
   * @dev Check if the sender is a token controller.
   *
   * @param sender Transaction sender.
   * @param assetAddress Address of the token representing the asset.
   * @return Returns 'true' if sender is a token controller.
   */
  function _tokenController(address sender, address assetAddress) internal view returns(bool) {
    if(sender == Ownable(assetAddress).owner() ||
      _isTokenController[assetAddress][sender]) {
      return true;
    } else {
      return false;
    }

  }

  /**
   * @dev Indicate whether or not the fund issuance contract can receive the tokens.
   *
   * By convention, the 32 first bytes of a token transfer to the fund issuance smart contract contain a flag.
   *
   *  - When tokens are transferred to fund issuance contract to create a new order, the 'data' field starts with the
   *  following flag: 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
   *  In this case the data structure is the the following:
   *  <transferFlag (32 bytes)><asset address (32 bytes)><asset class (32 bytes)><order data (3 * 32 bytes)>
   *
   *  - When tokens are transferred to fund issuance contract to pay for an existing order, the 'data' field starts with the
   *  following flag: 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
   *  In this case the data structure is the the following:
   *  <transferFlag (32 bytes)><order index (32 bytes)>
   *
   * If the 'data' doesn't start with one of those flags, the fund issuance contract won't accept the token transfer.
   *
   * @param data Information attached to the token transfer to fund issuance contract.
   * @param operatorData Information attached to the token transfer to fund issuance contract, by the operator.
   * @return 'true' if the fund issuance contract can receive the tokens, 'false' if not.
   */
  function _canReceive(bytes memory data, bytes memory operatorData) internal pure returns(bool) {
    if(operatorData.length == 0) { // The reason for this check is to avoid a certificate gets interpreted as a flag by mistake
      return false;
    }
    
    bytes32 flag = _getTransferFlag(data);
    if(data.length == 192 && flag == ORDER_SUBSCRIPTION_FLAG) {
      return true;
    } else if(data.length == 64 && flag == ORDER_PAYMENT_FLAG) {
      return true;
    } else if (data.length == 32 && flag == BYPASS_ACTION_FLAG) {
      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Retrieve the transfer flag from the 'data' field.
   *
   * By convention, the 32 first bytes of a token transfer to the fund issuance smart contract contain a flag.
   *  - When tokens are transferred to fund issuance contract to create a new order, the 'data' field starts with the
   *  following flag: 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
   *  - When tokens are transferred to fund issuance contract to pay for an existing order, the 'data' field starts with the
   *  following flag: 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
   *
   * @param data Concatenated information about the transfer.
   * @return flag Transfer flag.
   */
  function _getTransferFlag(bytes memory data) internal pure returns(bytes32 flag) {
    assembly {
      flag:= mload(add(data, 32))
    }
  }

  /**
   * By convention, when tokens are transferred to fund issuance contract to create a new order, the 'data' of a token transfer has the following structure:
   *  <transferFlag (32 bytes)><asset address (32 bytes)><asset class (32 bytes)><order data (3 * 32 bytes)>
   *
   * The first 32 bytes are the flag 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
   *
   * The next 32 bytes contain the order index.
   *
   * Example input for asset address '0xb5747835141b46f7C472393B31F8F5A57F74A44f',
   * asset class '37252', order type 'Value', and value 12000
   * 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc000000000000000000000000b5747835141b46f7C472393B31F8F5A57F74A44f
   * 000000000000000000000000000000000000000000000000000000000037252000000000000000000000000000000000000000000000000000000000000001
   * 000000000000000000000000000000000000000000000000000000000002ee0000000000000000000000000000000000000000000000000000000000000000
   *
   */
  function _getAssetAddress(bytes memory data) internal pure returns(address assetAddress) {
    assembly {
      assetAddress:= mload(add(data, 64))
    }
  }

  function _getAssetClass(bytes memory data) internal pure returns(bytes32 assetClass) {
    assembly {
      assetClass:= mload(add(data, 96))
    }
  }

  function _getOrderData(bytes memory data) internal pure returns(bytes memory orderData) {
    uint256 orderValue;
    uint256 orderAmount;
    OrderType orderType;
    assembly {
      orderValue:= mload(add(data, 128))
      orderAmount:= mload(add(data, 160))
      orderType:= mload(add(data, 192))
    }
    orderData = abi.encode(orderValue, orderAmount, orderType);
  }

  /**
   * By convention, when tokens are transferred to fund issuance contract to pay for an existing order, the 'data' of a token transfer has the following structure:
   *  <transferFlag (32 bytes)><order index (32 bytes)>
   *
   * The first 32 bytes are the flag 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
   *
   * The next 32 bytes contain the order index.
   *
   * Example input for order index 3:
   * 0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000000000000000000000000000000000003
   *
   */

  /**
   * @dev Retrieve the order index from the 'data' field.
   *
   * @param data Concatenated information about the order payment.
   * @return orderIndex Order index.
   */
  function _getOrderIndex(bytes memory data) internal pure returns(uint256 orderIndex) {
    assembly {
      orderIndex:= mload(add(data, 64))
    }
  }

  /************************** TOKEN CONTROLLERS *******************************/

  /**
   * @dev Get the list of token controllers for a given token.
   * @param tokenAddress Token address.
   * @return List of addresses of all the token controllers for a given token.
   */
  function tokenControllers(address tokenAddress) external view returns (address[] memory) {
    return _tokenControllers[tokenAddress];
  }

  /**
   * @dev Set list of token controllers for a given token.
   * @param tokenAddress Token address.
   * @param operators Operators addresses.
   */
  function setTokenControllers(address tokenAddress, address[] calldata operators) external onlyTokenController(tokenAddress) {
    _setTokenControllers(tokenAddress, operators);
  }

  /**
   * @dev Set list of token controllers for a given token.
   * @param tokenAddress Token address.
   * @param operators Operators addresses.
   */
  function _setTokenControllers(address tokenAddress, address[] memory operators) internal {
    for (uint i = 0; i<_tokenControllers[tokenAddress].length; i++){
      _isTokenController[tokenAddress][_tokenControllers[tokenAddress][i]] = false;
    }
    for (uint j = 0; j<operators.length; j++){
      _isTokenController[tokenAddress][operators[j]] = true;
    }
    _tokenControllers[tokenAddress] = operators;
  }

  /************************** TOKEN PRICE ORACLES *******************************/

  /**
   * @dev Get the list of price oracles for a given token.
   * @param tokenAddress Token address.
   * @return List of addresses of all the price oracles for a given token.
   */
  function priceOracles(address tokenAddress) external view returns (address[] memory) {
    return _priceOracles[tokenAddress];
  }

  /**
   * @dev Set list of price oracles for a given token.
   * @param tokenAddress Token address.
   * @param oracles Oracles addresses.
   */
  function setPriceOracles(address tokenAddress, address[] calldata oracles) external onlyPriceOracle(tokenAddress) {
    _setPriceOracles(tokenAddress, oracles);
  }

  /**
   * @dev Set list of price oracles for a given token.
   * @param tokenAddress Token address.
   * @param oracles Oracles addresses.
   */
  function _setPriceOracles(address tokenAddress, address[] memory oracles) internal {
    for (uint i = 0; i<_priceOracles[tokenAddress].length; i++){
      _isPriceOracle[tokenAddress][_priceOracles[tokenAddress][i]] = false;
    }
    for (uint j = 0; j<oracles.length; j++){
      _isPriceOracle[tokenAddress][oracles[j]] = true;
    }
    _priceOracles[tokenAddress] = oracles;
  }

  /**
   * @dev Check if address is oracle of a given token.
   * @param tokenAddress Token address.
   * @param oracle Oracle address.
   * @return 'true' if the address is oracle of the given token.
   */
  function _checkPriceOracle(address tokenAddress, address oracle) internal view returns(bool) {
    return(_isPriceOracle[tokenAddress][oracle] || oracle == Ownable(tokenAddress).owner());
  }

  /**************************** VIEW FUNCTIONS *******************************/

  /**
   * @dev Get asset rules.
   * @param assetAddress Address of the asset.
   * @param assetClass Class of the asset.
   * @return Asset rules.
   */
  function getAssetRules(address assetAddress, bytes32 assetClass)
    external
    view
    returns(uint256, uint256, uint256, uint256, Payment, address, bytes32, address, bool)
  {
    AssetRules storage rules = _assetRules[assetAddress][assetClass];
    return (
      rules.firstStartTime,
      rules.subscriptionPeriodLength,
      rules.valuationPeriodLength,
      rules.paymentPeriodLength,
      rules.paymentType,
      rules.paymentAddress,
      rules.paymentPartition,
      rules.fundAddress,
      rules.subscriptionsOpened
    );

  }

  /**
   * @dev Get the cycle asset value rules.
   * @param assetAddress Address of the asset.
   * @param assetClass Class of the asset.
   * @return Asset value rules.
   */
  function getAssetValueRules(address assetAddress, bytes32 assetClass) external view returns(AssetValue, uint256, uint256) {
    AssetRules storage rules = _assetRules[assetAddress][assetClass];
    return (
      rules.assetValueType,
      rules.assetValue,
      rules.reverseAssetValue
    );
  }

  /**
   * @dev Get total number of cycles in the contract.
   * @return Number of cycles.
   */
  function getNbCycles() external view returns(uint256) {
    return _cycleIndex;
  }

  /**
   * @dev Get the index of the last cycle created for a given asset class.
   * @param assetAddress Address of the token representing the asset.
   * @param assetClass Asset class.
   * @return Cycle index.
   */
  function getLastCycleIndex(address assetAddress, bytes32 assetClass) external view returns(uint256) {
    return _lastCycleIndex[assetAddress][assetClass];
  }

  /**
   * @dev Get the cycle.
   * @param index Index of the cycle.
   * @return Cycle.
   */
  function getCycle(uint256 index) external view returns(address, bytes32, uint256, uint256, uint256, uint256, Payment, address, bytes32, bool) {
    Cycle storage cycle = _cycles[index];
    return (
      cycle.assetAddress,
      cycle.assetClass,
      cycle.startTime,
      cycle.subscriptionPeriodLength,
      cycle.valuationPeriodLength,
      cycle.paymentPeriodLength,
      cycle.paymentType,
      cycle.paymentAddress,
      cycle.paymentPartition,
      cycle.finalized
    );
  }

  /**
   * @dev Get the cycle asset value.
   * @param index Index of the cycle.
   * @return Cycle.
   */
  function getCycleAssetValue(uint256 index) external view returns(AssetValue, uint256, uint256) {
    Cycle storage cycle = _cycles[index];
    return (
      cycle.assetValueType,
      cycle.assetValue,
      cycle.reverseAssetValue
    );
  }

  /**
   * @dev Get total number of orders in the contract.
   * @return Number of orders.
   */
  function getNbOrders() external view returns(uint256) {
    return _orderIndex;
  }

  /**
   * @dev Retrieve an order.
   * @param index Index of the order.
   * @return Order.
   */
  function getOrder(uint256 index) external view returns(uint256, address, uint256, uint256, OrderType, OrderState) {
    Order storage order = _orders[index];
    return (
      order.cycleIndex,
      order.investor,
      order.value,
      order.amount,
      order.orderType,
      order.state
    );
  }

  /**
   * @dev Retrieve order amount and order value calculated based on cycle valuation.
   * @param orderIndex Index of the order.
   * @return Order amount.
   * @return Order value.
   */
  function getOrderAmountAndValue(uint256 orderIndex) external view returns(uint256, uint256) {
    return _getOrderAmountAndValue(orderIndex);
  }

  /**
   * @dev Get list of cycle orders.
   * @param index Index of the cycle.
   * @return List of cycle orders.
   */
  function getCycleOrders(uint256 index) external view returns(uint256[] memory) {
    return _cycleOrders[index];
  }

  /**
   * @dev Get list of investor orders.
   * @return List of investor orders.
   */
  function getInvestorOrders(address investor) external view returns(uint256[] memory) {
    return _investorOrders[investor];
  }

 }
