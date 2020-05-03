/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.5.0;

import "../ERC1400.sol";
import "./certificateControllers/CertificateControllerNonce.sol";

/**
 * @title ERC1400
 * @dev ERC1400 logic
 */
contract ERC1400CertificateNonce is ERC1400, CertificateController {

  /**
   * @dev Initialize ERC1400 + initialize certificate controller.
   * @param name Name of the token.
   * @param symbol Symbol of the token.
   * @param granularity Granularity of the token.
   * @param controllers Array of initial controllers.
   * @param certificateSigner Address of the off-chain service which signs the
   * conditional ownership certificates required for token transfers, issuance,
   * redemption (Cf. CertificateController.sol).
   * @param certificateActivated If set to 'true', the certificate controller
   * is activated at contract creation.
   * @param defaultPartitions Partitions chosen by default, when partition is
   * not specified, like the case ERC20 tranfers.
   */
  constructor(
    string memory name,
    string memory symbol,
    uint256 granularity,
    address[] memory controllers,
    address certificateSigner,
    bool certificateActivated,
    bytes32[] memory defaultPartitions
  )
    public
    ERC1400(name, symbol, granularity, controllers, defaultPartitions)
    CertificateController(certificateSigner, certificateActivated)
  {}


  /************************************ Certificate control ***************************************/
  /**
   * @dev Add a certificate signer for the token.
   * @param operator Address to set as a certificate signer.
   * @param authorized 'true' if operator shall be accepted as certificate signer, 'false' if not.
   */
  function setCertificateSigner(address operator, bool authorized) external onlyOwner {
    _setCertificateSigner(operator, authorized);
  }
  /**
   * @dev Activate/disactivate certificate controller.
   * @param activated 'true', if the certificate control shall be activated, 'false' if not.
   */
  function setCertificateControllerActivated(bool activated) external onlyOwner {
   _setCertificateControllerActivated(activated);
  }
  /************************************************************************************************/


  /********************** ERC1400 functions to control with certificate ***************************/
  function transferWithData(address to, uint256 value, bytes calldata data)
    external
    isValidCertificate(data)
  {
    _transferByDefaultPartitions(msg.sender, msg.sender, to, value, data);
  }

  function transferFromWithData(address from, address to, uint256 value, bytes calldata data)
    external
    isValidCertificate(data)
  {
    require(_isOperator(msg.sender, from), "58"); // 0x58	invalid operator (transfer agent)

    _transferByDefaultPartitions(msg.sender, from, to, value, data);
  }

  function transferByPartition(bytes32 partition, address to, uint256 value, bytes calldata data)
    external
    isValidCertificate(data)
    returns (bytes32)
  {
    return _transferByPartition(partition, msg.sender, msg.sender, to, value, data, "");
  }

  function operatorTransferByPartition(bytes32 partition, address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData)
    external
    isValidCertificate(operatorData)
    returns (bytes32)
  {
    require(_isOperatorForPartition(partition, msg.sender, from)
      || (value <= _allowedByPartition[partition][from][msg.sender]), "53"); // 0x53	insufficient allowance

    if(_allowedByPartition[partition][from][msg.sender] >= value) {
      _allowedByPartition[partition][from][msg.sender] = _allowedByPartition[partition][from][msg.sender].sub(value);
    } else {
      _allowedByPartition[partition][from][msg.sender] = 0;
    }

    return _transferByPartition(partition, msg.sender, from, to, value, data, operatorData);
  }

  function issue(address tokenHolder, uint256 value, bytes calldata data)
    external
    onlyMinter
    isIssuableToken
    isValidCertificate(data)
  {
    require(_defaultPartitions.length != 0, "55"); // 0x55	funds locked (lockup period)

    _issueByPartition(_defaultPartitions[0], msg.sender, tokenHolder, value, data);
  }

  function issueByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata data)
    external
    onlyMinter
    isIssuableToken
    isValidCertificate(data)
  {
    _issueByPartition(partition, msg.sender, tokenHolder, value, data);
  }

  function redeem(uint256 value, bytes calldata data)
    external
    isValidCertificate(data)
  {
    _redeemByDefaultPartitions(msg.sender, msg.sender, value, data);
  }

  function redeemFrom(address from, uint256 value, bytes calldata data)
    external
    isValidCertificate(data)
  {
    require(_isOperator(msg.sender, from), "58"); // 0x58	invalid operator (transfer agent)

    _redeemByDefaultPartitions(msg.sender, from, value, data);
  }

  function redeemByPartition(bytes32 partition, uint256 value, bytes calldata data)
    external
    isValidCertificate(data)
  {
    _redeemByPartition(partition, msg.sender, msg.sender, value, data, "");
  }

  function operatorRedeemByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata operatorData)
    external
    isValidCertificate(operatorData)
  {
    require(_isOperatorForPartition(partition, msg.sender, tokenHolder), "58"); // 0x58	invalid operator (transfer agent)

    _redeemByPartition(partition, msg.sender, tokenHolder, value, "", operatorData);
  }
  /************************************************************************************************/


  /************************************** Transfer Validity ***************************************/
  /**
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
  function canTransferByPartition(bytes32 partition, address to, uint256 value, bytes calldata data)
    external
    view
    returns (byte, bytes32, bytes32)
  {
    bytes4 functionSig = this.transferByPartition.selector; // 0xf3d490db: 4 first bytes of keccak256(transferByPartition(bytes32,address,uint256,bytes))
    if(!_checkCertificate(data, 0, functionSig)) {
      return(hex"54", "", partition); // 0x54	transfers halted (contract paused)
    } else {
      return ERC1400._canTransfer(functionSig, partition, msg.sender, msg.sender, to, value, data, "");
    }
  }
  /**
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
  function canOperatorTransferByPartition(bytes32 partition, address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData)
    external
    view
    returns (byte, bytes32, bytes32)
  {
    bytes4 functionSig = this.operatorTransferByPartition.selector; // 0x8c0dee9c: 4 first bytes of keccak256(operatorTransferByPartition(bytes32,address,address,uint256,bytes,bytes))
    if(!_checkCertificate(operatorData, 0, functionSig)) {
      return(hex"54", "", partition); // 0x54	transfers halted (contract paused)
    } else {
      return ERC1400._canTransfer(functionSig, partition, msg.sender, from, to, value, data, operatorData);
    }
  }
  /************************************************************************************************/

}