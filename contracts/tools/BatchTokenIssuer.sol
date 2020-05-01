pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "../IERC1400.sol";

import "../token/ERC1820/ERC1820Implementer.sol";

/**
 * @title BatchTokenIssuer
 * @dev Proxy contract to issue multiple ERC1400/ERC20 tokens in a single transaction.
 */
contract BatchTokenIssuer is ERC1820Implementer {

  string constant internal BATCH_ISSUER = "BatchTokenIssuer";

  // Mapping from token to token minters.
  mapping(address => address[]) internal _tokenMinters;

  // Mapping from (token, operator) to token minter status.
  mapping(address => mapping(address => bool)) internal _isTokenMinter;

  /**
   * @dev Modifier to verify if sender is a token minter.
   */
  modifier onlyTokenMinter(address tokenAddress) {
    require(_tokenMinter(msg.sender, tokenAddress),
      "Sender is not a token minter."
    );
    _;
  }

  constructor() public {
    ERC1820Implementer._setInterface(BATCH_ISSUER);
  }

  /**
   * @dev Issue tokens for multiple addresses.
   * @param tokenAddress Address of token where the tokens need to be issued.
   * @param partitions Name of the partitions.
   * @param tokenHolders Addresses for which we want to issue tokens.
   * @param values Number of tokens issued.
   */
  function batchIssueByPartition(
    address tokenAddress,
    bytes32[] calldata partitions,
    address[] calldata tokenHolders,
    uint256[] calldata values
  )
    external
    onlyTokenMinter(tokenAddress)
    returns (uint256[] memory)
  {
    require(partitions.length == tokenHolders.length, 'partitions and tokenHolders arrays have different lengths');
    require(partitions.length == values.length, 'partitions and values arrays have different lengths');
    
    for (uint i = 0; i < partitions.length; i++) {
        IERC1400(tokenAddress).issueByPartition(partitions[i], tokenHolders[i], values[i], '');
    }
  }

  /************************** TOKEN MINTERS *******************************/

  /**
   * @dev Get the list of token minters for a given token.
   * @param tokenAddress Token address.
   * @return List of addresses of all the token minters for a given token.
   */
  function tokenMinters(address tokenAddress) external view returns (address[] memory) {
    return _tokenMinters[tokenAddress];
  }

  /**
   * @dev Set list of token minters for a given token.
   * @param tokenAddress Token address.
   * @param operators Operators addresses.
   */
  function setTokenMinters(address tokenAddress, address[] calldata operators) external onlyTokenMinter(tokenAddress) {
    _setTokenMinters(tokenAddress, operators);
  }

  /**
   * @dev Set list of token minters for a given token.
   * @param tokenAddress Token address.
   * @param operators Operators addresses.
   */
  function _setTokenMinters(address tokenAddress, address[] memory operators) internal {
    for (uint i = 0; i<_tokenMinters[tokenAddress].length; i++){
      _isTokenMinter[tokenAddress][_tokenMinters[tokenAddress][i]] = false;
    }
    for (uint j = 0; j<operators.length; j++){
      _isTokenMinter[tokenAddress][operators[j]] = true;
    }
    _tokenMinters[tokenAddress] = operators;
  }

  /**
   * @dev Check if the sender is a token minter.
   *
   * @param sender Transaction sender.
   * @param tokenAddress Token address.
   * @return Returns 'true' if sender is a token minter.
   */
  function _tokenMinter(address sender, address tokenAddress) internal view returns(bool) {
    if(sender == Ownable(tokenAddress).owner() ||
      _isTokenMinter[tokenAddress][sender]) {
      return true;
    } else {
      return false;
    }

  }

}
