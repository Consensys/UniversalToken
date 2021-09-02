
pragma solidity ^0.8.0;

struct TokenExtensionData {
    mapping(bytes4 => bool) isImplemented;
}

struct TokenExtensionFacetData {
    address erc20Core;
    mapping(address => TokenExtensionData) extensions;
}

library LibTokenExtensionFacet {
    bytes32 constant TOKEN_EXTENSION_STORAGE_POSITION = keccak256("org.consensys.tokens.erc20.tokenextensionfacet");

    function tokenExtensionFacetStorage() internal pure returns (TokenExtensionFacetData storage ds) {
        bytes32 position = TOKEN_EXTENSION_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}