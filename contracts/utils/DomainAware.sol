/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

/**
* @title Domain-Aware contract interface
* @notice This can be used to interact with a DomainAware contract of any type.
* @dev An interface that represents a DomainAware contract. This interface provides
* all public/external facing functions that the DomainAware contract implements.
*/
interface IDomainAware {
    /**
    * @dev Uses _domainName()
    * @notice The domain name for this contract used in the domain seperator. 
    * This value will not change and will have a length greater than 0.
    * @return bytes The domain name represented as bytes
    */
    function domainName() external view returns (bytes memory);

    /**
    * @dev The current version for this contract. Changing this value will
    * cause the domain separator to update and trigger a cache update.
    */
    function domainVersion() external view returns (bytes32);

    /**
    * @notice Generate the domain seperator hash for this contract using the contract's
    * domain name, current domain version and the current chain-id. This call bypasses the stored cache and
    * will always represent the current domain seperator for this Contract's name + version + chain id. 
    * @return bytes32 The domain seperator hash.
    */
    function generateDomainSeparator() external view returns (bytes32);

    /**
    * @notice Get the current domain seperator hash for this contract using the contract's
    * domain name, current domain version and the current chain-id. 
    * @dev This call is cached by the chain-id and contract version. If these two values do not 
    * change then the cached domain seperator hash is returned. If these two values do change,
    * then a new hash is generated and the cache is updated
    * @return bytes32 The current domain seperator hash
    */
    function domainSeparator() external returns (bytes32);
}

/**
* @title Domain-Aware contract
* @notice This should be inherited by any contract that plans on using the EIP712 
* typed structured data signing 
* @dev A generic contract to be used by contract plans on using the EIP712 typed structure
* data signing. This contract offers a way to generate the EIP712Domain seperator for the
* contract that extends from this. 
*
* The EIP712 domain seperator generated depends on the domain name and domain version of the child
* contract. Therefore, a child contract must implement the _domainName() and _domainVersion() functions in order
* to complete the implementation. 
* The child contract may return whatever it likes for the _domainName(), however this value should not change
* after deployment. Changing the result of the _domainName() function between calls may result in undefined behavior.
* The _domainVersion() must be a bytes32 and that _domainName() must have a length greater than 0.
*
* If a child contract changes the domain version after deployment, then the domain seperator will 
* update to reflect the new version.
*
* This contract stores the domain seperator for each chain-id detected after deployment. This
* means if the contract were to fork to a new blockchain with a new chain-id, then the domain-seperator
* of this contract would update to reflect the new domain context. 
*
*/
abstract contract DomainAware is IDomainAware {

    /**
    * @dev The storage slot the DomainData is stored in this contract
    */
    bytes32 constant internal DOMAIN_AWARE_SLOT = keccak256("domainaware.data");

    /**
    * @dev The cached DomainData for this chain & contract version.
    * @param domainSeparator The cached domainSeperator for this chain + contract version
    * @param version The contract version this DomainData is for
    */
    struct DomainData {
        bytes32 domainSeparator;
        bytes32 version; 
    }

    /**
    * @dev The struct storing all the DomainData cached for each chain-id.
    * This is a very gas efficient way to not recalculate the domain separator 
    * on every call, while still automatically detecting ChainID changes.
    * @param chainToDomainData Mapping of ChainID to domain separators. 
    */
    struct DomainAwareData {
        mapping(uint256 => DomainData) chainToDomainData;
    }

    /**
    * @dev If in the constructor we have a non-zero domain name, then update the domain seperator now.
    * Otherwise, the child contract will need to do this themselves
    */
    constructor() {
        if (_domainName().length > 0) {
            _updateDomainSeparator();
        }
    }

    /**
    * @dev The domain name for this contract. This value should not change at all and should have a length
    * greater than 0.
    * Changing this value changes the domain separator but does not trigger a cache update so may
    * result in undefined behavior
    * TODO Fix cache issue? Gas inefficient since we don't know if the data has updated?
    * We can't make this pure because ERC20 requires name() to be view.
    * @return bytes The domain name represented as a bytes
    */
    function _domainName() internal virtual view returns (bytes memory);

    /**
    * @dev The current version for this contract. Changing this value will
    * cause the domain separator to update and trigger a cache update.
    */
    function _domainVersion() internal virtual view returns (bytes32);

    /**
    * @dev Uses _domainName()
    * @notice The domain name for this contract used in the domain seperator. 
    * This value will not change and will have a length greater than 0.
    * @return bytes The domain name represented as bytes
    */
    function domainName() external override view returns (bytes memory) {
        return _domainName();
    }

    /**
    * @dev Uses _domainName()
    * @notice The current version for this contract. This is the domain version
    * used in the domain seperator
    */
    function domainVersion() external override view returns (bytes32) {
        return _domainVersion();
    }

    /**
    * @dev Get the DomainAwareData struct stored in this contract.
    */
    function domainAwareData() private pure returns (DomainAwareData storage ds) {
        bytes32 position = DOMAIN_AWARE_SLOT;
        assembly {
            ds.slot := position
        }
    }

    /**
    * @notice Generate the domain seperator hash for this contract using the contract's
    * domain name, current domain version and the current chain-id. This call bypasses the stored cache and
    * will always represent the current domain seperator for this Contract's name + version + chain id. 
    * @return bytes32 The domain seperator hash.
    */
    function generateDomainSeparator() public override view returns (bytes32) {
        uint256 chainID = _chainID();
        bytes memory dn = _domainName();
        bytes memory dv = abi.encodePacked(_domainVersion());
        require(dn.length > 0, "Domain name is empty");
        require(dv.length > 0, "Domain version is empty");

        // no need for assembly, running very rarely
        bytes32 domainSeparatorHash = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(dn), // ERC-20 Name
                keccak256(dv), // Version
                chainID,
                address(this)
            )
        );

        return domainSeparatorHash;
    }

    /**
    * @notice Get the current domain seperator hash for this contract using the contract's
    * domain name, current domain version and the current chain-id. 
    * @dev This call is cached by the chain-id and contract version. If these two values do not 
    * change then the cached domain seperator hash is returned. If these two values do change,
    * then a new hash is generated and the cache is updated
    * @return bytes32 The current domain seperator hash
    */
    function domainSeparator() public override returns (bytes32) {
        return _domainSeparator();
    }

    /**
    * @dev Generate and update the cached domain seperator hash for this contract 
    * using the contract's domain name, current domain version and the current chain-id. 
    * This call will always overwrite the cache even if the cached data of the same.
    * @return bytes32 The current domain seperator hash that was stored in cache
    */
    function _updateDomainSeparator() internal returns (bytes32) {
        uint256 chainID = _chainID();

        bytes32 newDomainSeparator = generateDomainSeparator();

        require(newDomainSeparator != bytes32(0), "Invalid domain seperator");

        domainAwareData().chainToDomainData[chainID] = DomainData(
            newDomainSeparator,
            _domainVersion()
        );

        return newDomainSeparator;
    }

    /**
    * @dev Get the current domain seperator hash for this contract using the contract's
    * domain name, current domain version and the current chain-id. 
    * This call is cached by the chain-id and contract version. If these two values do not 
    * change then the cached domain seperator hash is returned. If these two values do change,
    * then a new hash is generated and the cache is updated
    * @return bytes32 The current domain seperator hash
    */
    function _domainSeparator() private returns (bytes32) {
        uint256 chainID = _chainID();
        bytes32 reportedVersion = _domainVersion();

        DomainData memory currentDomainData = domainAwareData().chainToDomainData[chainID];

        if (currentDomainData.domainSeparator != 0x00 && currentDomainData.version == reportedVersion) {
            return currentDomainData.domainSeparator;
        }

        return _updateDomainSeparator();
    }

    /**
    * @dev Get the current chain-id. This is done using the chainid opcode.
    * @return uint256 The current chain-id as a number.
    */
    function _chainID() internal view returns (uint256) {
        uint256 chainID;
        assembly {
            chainID := chainid()
        }

        return chainID;
    }
}