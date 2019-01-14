/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/access/roles/MinterRole.sol";

import "./IERC1400.sol";
import "./token/ERC1410/ERC1410.sol";


/**
 * @title ERC1400
 * @dev ERC1400 logic
 */
contract ERC1400 is IERC1400, ERC1410, MinterRole {

  struct Doc {
    string docURI;
    bytes32 docHash;
  }

  // Mapping for token URIs.
  mapping(bytes32 => Doc) internal _documents;

  // Indicate whether the token can still be issued by the issuer or not anymore.
  bool internal _isIssuable;

  /**
   * @dev Modifier to verify if token is issuable.
   */
  modifier issuableToken() {
    require(_isIssuable, "A8, Transfer Blocked - Token restriction");
    _;
  }

  /**
   * [ERC1400 CONSTRUCTOR]
   * @dev Initialize ERC1400 + register
   * the contract implementation in ERC820Registry.
   * @param name Name of the token.
   * @param symbol Symbol of the token.
   * @param granularity Granularity of the token.
   * @param controllers Array of initial controllers.
   * @param certificateSigner Address of the off-chain service which signs the
   * conditional ownership certificates required for token transfers, issuance,
   * redemption (Cf. CertificateController.sol).
   */
  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] controllers,
    address certificateSigner,
    bytes32[] tokenDefaultPartitions
  )
    public
    ERC1410(name, symbol, granularity, controllers, certificateSigner, tokenDefaultPartitions)
  {
    setInterfaceImplementation("ERC1400Token", this);
    _isControllable = true;
    _isIssuable = true;
  }

  /********************** ERC1400 EXTERNAL FUNCTIONS **************************/

  /**
   * [ERC1400 INTERFACE (1/9)]
   * @dev Access a document associated with the token.
   * @param name Short name (represented as a bytes32) associated to the document.
   * @return Requested document + document hash.
   */
  function getDocument(bytes32 name) external view returns (string, bytes32) {
    require(bytes(_documents[name].docURI).length != 0, "Action Blocked - Empty document");
    return (
      _documents[name].docURI,
      _documents[name].docHash
    );
  }

  /**
   * [ERC1400 INTERFACE (2/9)]
   * @dev Associate a document with the token.
   * @param name Short name (represented as a bytes32) associated to the document.
   * @param uri Document content.
   * @param documentHash Hash of the document [optional parameter].
   */
  function setDocument(bytes32 name, string uri, bytes32 documentHash) external onlyOwner {
    _documents[name] = Doc({
      docURI: uri,
      docHash: documentHash
    });
    emit Document(name, uri, documentHash);
  }

  /**
   * [ERC1400 INTERFACE (3/9)]
   * @dev Know if the token can be controlled by operators.
   * If a token returns 'false' for 'isControllable()'' then it MUST always return 'false' in the future.
   * @return bool 'true' if the token can still be controlled by operators, 'false' if it can't anymore.
   */
  function isControllable() external view returns (bool) {
    return _isControllable;
  }

  /**
   * [ERC1400 INTERFACE (4/9)]
   * @dev Know if new tokens can be issued in the future.
   * @return bool 'true' if tokens can still be issued by the issuer, 'false' if they can't anymore.
   */
  function isIssuable() external view returns (bool) {
    return _isIssuable;
  }

  /**
   * [ERC1400 INTERFACE (5/9)]
   * @dev Issue tokens from a specific partition.
   * @param partition Name of the partition.
   * @param tokenHolder Address for which we want to issue tokens.
   * @param value Number of tokens issued.
   * @param data Information attached to the issuance, by the issuer. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function issueByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes data)
    external
    onlyMinter
    issuableToken
    isValidCertificate(data)
  {
    _issueByPartition(partition, msg.sender, tokenHolder, value, data, "");
  }

  /**
   * [ERC1400 INTERFACE (6/9)]
   * @dev Redeem tokens of a specific partition.
   * @param partition Name of the partition.
   * @param value Number of tokens redeemed.
   * @param data Information attached to the redemption, by the redeemer. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function redeemByPartition(bytes32 partition, uint256 value, bytes data)
    external
    isValidCertificate(data)
  {
    _redeemByPartition(partition, msg.sender, msg.sender, value, data, "");
  }

  /**
   * [ERC1400 INTERFACE (7/9)]
   * @dev Redeem tokens of a specific partition.
   * @param partition Name of the partition.
   * @param tokenHolder Address for which we want to redeem tokens.
   * @param value Number of tokens redeemed.
   * @param data Information attached to the redemption.
   * @param operatorData Information attached to the redemption, by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function operatorRedeemByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (tokenHolder == address(0)) ? msg.sender : tokenHolder;
    require(_isOperatorForPartition(partition, msg.sender, _from), "A7: Transfer Blocked - Identity restriction");

    _redeemByPartition(partition, msg.sender, _from, value, data, operatorData);
  }

  /**
   * [ERC1400 INTERFACE (8/9)]
   * @dev Know the reason on success or failure based on the EIP-1066 application-specific status codes.
   * @param partition Name of the partition.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   * @return ESC (Ethereum Status Code) following the EIP-1066 standard.
   * @return Additional bytes32 parameter that can be used to define
   * application specific reason codes with additional details (for example the
   * transfer restriction rule responsible for making the transfer operation invalid).
   * @return Destination partition.
   */
  function canTransferByPartition(bytes32 partition, address to, uint256 value, bytes data)
    external
    view
    returns (byte, bytes32, bytes32)
  {
    if(!_checkCertificate(data, 0, 0xf3d490db)) { // 4 first bytes of keccak256(transferByPartition(bytes32,address,uint256,bytes))
      return(hex"A3", "", partition); // Transfer Blocked - Sender lockup period not ended
    } else {
      return _canTransfer(partition, msg.sender, msg.sender, to, value, data, "");
    }
  }

  /**
   * [ERC1400 INTERFACE (9/9)]
   * @dev Know the reason on success or failure based on the EIP-1066 application-specific status codes.
   * @param partition Name of the partition.
   * @param from Token holder.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer. [CAN CONTAIN THE DESTINATION PARTITION]
   * @param operatorData Information attached to the transfer, by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   * @return ESC (Ethereum Status Code) following the EIP-1066 standard.
   * @return Additional bytes32 parameter that can be used to define
   * application specific reason codes with additional details (for example the
   * transfer restriction rule responsible for making the transfer operation invalid).
   * @return Destination partition.
   */
  function canOperatorTransferByPartition(bytes32 partition, address from, address to, uint256 value, bytes data, bytes operatorData)
    external
    view
    returns (byte, bytes32, bytes32)
  {
    if(!_checkCertificate(operatorData, 0, 0x8c0dee9c)) { // 4 first bytes of keccak256(operatorTransferByPartition(bytes32,address,address,uint256,bytes,bytes))
      return(hex"A3", "", partition); // Transfer Blocked - Sender lockup period not ended
    } else {
      address _from = (from == address(0)) ? msg.sender : from;
      return _canTransfer(partition, msg.sender, _from, to, value, data, operatorData);
    }
  }

  /********************** ERC1400 INTERNAL FUNCTIONS **************************/

  /**
   * [INTERNAL]
   * @dev Know the reason on success or failure based on the EIP-1066 application-specific status codes.
   * @param partition Name of the partition.
   * @param operator The address performing the transfer.
   * @param from Token holder.
   * @param to Token recipient.
   * @param value Number of tokens to transfer.
   * @param data Information attached to the transfer. [CAN CONTAIN THE DESTINATION PARTITION]
   * @param operatorData Information attached to the transfer, by the operator (if any).
   * @return ESC (Ethereum Status Code) following the EIP-1066 standard.
   * @return Additional bytes32 parameter that can be used to define
   * application specific reason codes with additional details (for example the
   * transfer restriction rule responsible for making the transfer operation invalid).
   * @return Destination partition.
   */
   function _canTransfer(bytes32 partition, address operator, address from, address to, uint256 value, bytes data, bytes operatorData)
     internal
     view
     returns (byte, bytes32, bytes32)
   {
     if(!_isOperatorForPartition(partition, operator, from))
       return(hex"A7", "", partition); // "Transfer Blocked - Identity restriction"

     if((_balances[from] < value) || (_balanceOfByPartition[from][partition] < value))
       return(hex"A4", "", partition); // Transfer Blocked - Sender balance insufficient

     if(to == address(0))
       return(hex"A6", "", partition); // Transfer Blocked - Receiver not eligible

     address senderImplementation;
     address recipientImplementation;
     senderImplementation = interfaceAddr(from, "ERC777TokensSender");
     recipientImplementation = interfaceAddr(to, "ERC777TokensRecipient");

     if((senderImplementation != address(0))
       && !IERC777TokensSender(senderImplementation).canTransfer(partition, from, to, value, data, operatorData))
       return(hex"A5", "", partition); // Transfer Blocked - Sender not eligible

     if((recipientImplementation != address(0))
       && !IERC777TokensRecipient(recipientImplementation).canReceive(partition, from, to, value, data, operatorData))
       return(hex"A6", "", partition); // Transfer Blocked - Receiver not eligible

     if(!_isMultiple(value))
       return(hex"A9", "", partition); // Transfer Blocked - Token granularity

     return(hex"A2", "", partition);  // Transfer Verified - Off-Chain approval for restricted token
   }

  /**
   * [INTERNAL]
   * @dev Issue tokens from a specific partition.
   * @param toPartition Name of the partition.
   * @param operator The address performing the issuance.
   * @param to Token recipient.
   * @param value Number of tokens to issue.
   * @param data Information attached to the issuance.
   * @param operatorData Information attached to the issuance, by the operator (if any).
   */
  function _issueByPartition(
    bytes32 toPartition,
    address operator,
    address to,
    uint256 value,
    bytes data,
    bytes operatorData
  )
    internal
  {
    _issue(toPartition, operator, to, value, data, operatorData);
    _addTokenToPartition(to, toPartition, value);

    emit IssuedByPartition(toPartition, operator, to, value, data, operatorData);
  }

  /**
   * [INTERNAL]
   * @dev Redeem tokens of a specific partition.
   * @param fromPartition Name of the partition.
   * @param operator The address performing the redemption.
   * @param from Token holder whose tokens will be redeemed.
   * @param value Number of tokens to redeem.
   * @param data Information attached to the redemption.
   * @param operatorData Information attached to the redemption, by the operator (if any).
   */
  function _redeemByPartition(
    bytes32 fromPartition,
    address operator,
    address from,
    uint256 value,
    bytes data,
    bytes operatorData
  )
    internal
  {
    require(_balanceOfByPartition[from][fromPartition] >= value, "A4: Transfer Blocked - Sender balance insufficient");

    _removeTokenFromPartition(from, fromPartition, value);
    _redeem(fromPartition, operator, from, value, data, operatorData);

    emit RedeemedByPartition(fromPartition, operator, from, value, data, operatorData);
  }

  /********************** ERC1400 OPTIONAL FUNCTIONS **************************/

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Definitely renounce the possibility to control tokens on behalf of tokenHolders.
   * Once set to false, '_isControllable' can never be set to 'true' again.
   */
  function renounceControl() external onlyOwner {
    _isControllable = false;
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Definitely renounce the possibility to issue new tokens.
   * Once set to false, '_isIssuable' can never be set to 'true' again.
   */
  function renounceIssuance() external onlyOwner {
    _isIssuable = false;
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Set list of token controllers.
   * @param operators Controller addresses.
   */
  function setControllers(address[] operators) external onlyOwner {
    _setControllers(operators);
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Set list of token partition controllers.
   * @param partition Name of the partition.
   * @param operators Controller addresses.
   */
   function setPartitionControllers(bytes32 partition, address[] operators) external onlyOwner {
     _setPartitionControllers(partition, operators);
   }

   /**
   * @dev Add a certificate signer for the token.
   * @param operator Address to set as a certificate signer.
   * @param authorized 'true' if operator shall be accepted as certificate signer, 'false' if not.
   */
  function setCertificateSigner(address operator, bool authorized) external onlyOwner {
    _setCertificateSigner(operator, authorized);
  }

  /************* ERC1410/ERC777 BACKWARDS RETROCOMPATIBILITY ******************/

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Get token default partitions to send from.
   * Function used for ERC777 and ERC20 backwards compatibility.
   * For example, a security token may return the bytes32("unrestricted").
   * @return Default partitions.
   */
  function getTokenDefaultPartitions() external view returns (bytes32[]) {
    return _tokenDefaultPartitions;
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD]
   * @dev Set token default partitions to send from.
   * Function used for ERC777 and ERC20 backwards compatibility.
   * @param defaultPartitions Partitions to use by default when not specified.
   */
  function setTokenDefaultPartitions(bytes32[] defaultPartitions) external onlyOwner {
    _tokenDefaultPartitions = defaultPartitions;
  }


  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD][OVERRIDES ERC1410 METHOD]
   * @dev Redeem the value of tokens from the address 'msg.sender'.
   * @param value Number of tokens to redeem.
   * @param data Information attached to the redemption, by the token holder. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function redeem(uint256 value, bytes data)
    external
    isValidCertificate(data)
  {
    _redeemByDefaultPartitions(msg.sender, msg.sender, value, data, "");
  }

  /**
   * [NOT MANDATORY FOR ERC1400 STANDARD][OVERRIDES ERC1410 METHOD]
   * @dev Redeem the value of tokens on behalf of the address 'from'.
   * @param from Token holder whose tokens will be redeemed (or 'address(0)' to set from to 'msg.sender').
   * @param value Number of tokens to redeem.
   * @param data Information attached to the redemption.
   * @param operatorData Information attached to the redemption, by the operator. [CONTAINS THE CONDITIONAL OWNERSHIP CERTIFICATE]
   */
  function redeemFrom(address from, uint256 value, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (from == address(0)) ? msg.sender : from;

    require(_isOperatorFor(msg.sender, _from), "A7: Transfer Blocked - Identity restriction");

    _redeemByDefaultPartitions(msg.sender, _from, value, data, operatorData);
  }

  /**
  * [NOT MANDATORY FOR ERC1410 STANDARD]
   * @dev Redeem tokens from a default partitions.
   * @param operator The address performing the redeem.
   * @param from Token holder.
   * @param value Number of tokens to redeem.
   * @param data Information attached to the redemption.
   * @param operatorData Information attached to the redemption, by the operator (if any).
   */
  function _redeemByDefaultPartitions(
    address operator,
    address from,
    uint256 value,
    bytes data,
    bytes operatorData
  )
    internal
  {
    bytes32[] memory _partitions = _getDefaultPartitions(from);
    require(_partitions.length != 0, "A8: Transfer Blocked - Token restriction");

    uint256 _remainingValue = value;
    uint256 _localBalance;

    for (uint i = 0; i < _partitions.length; i++) {
      _localBalance = _balanceOfByPartition[from][_partitions[i]];
      if(_remainingValue <= _localBalance) {
        _redeemByPartition(_partitions[i], operator, from, _remainingValue, data, operatorData);
        _remainingValue = 0;
        break;
      } else {
        _redeemByPartition(_partitions[i], operator, from, _localBalance, data, operatorData);
        _remainingValue = _remainingValue - _localBalance;
      }
    }

    require(_remainingValue == 0, "A8: Transfer Blocked - Token restriction");
  }

}
