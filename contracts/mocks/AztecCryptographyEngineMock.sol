pragma solidity ^0.5.0;


contract AztecCryptographyEngineMock {

  uint24 _mockValue = 0;

  function validateProof(
    uint24 proofId,
    address /*zeroKnowledgeAsset*/,
    bytes calldata /*proofData*/
  ) external {
    if(proofId != _mockValue) {
      _mockValue = proofId;
    }
  }

}
