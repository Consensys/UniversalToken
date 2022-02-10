/*
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
pragma solidity ^0.8.0;

abstract contract DomainAware {

    bytes32 constant DOMAIN_AWARE_SLOT = keccak256("domainaware.data");

    struct DomainData {
        bytes32 domainSeparator;
        bytes32 version; 
    }

    struct DomainAwareData {
        // Mapping of ChainID to domain separators. This is a very gas efficient way
        // to not recalculate the domain separator on every call, while still
        // automatically detecting ChainID changes.
        mapping(uint256 => DomainData) chainToDomainData;
    }

    constructor() {
        if (domainName().length > 0) {
            _updateDomainSeparator();
        }
    }

    function domainAwareData() private pure returns (DomainAwareData storage ds) {
        bytes32 position = DOMAIN_AWARE_SLOT;
        assembly {
            ds.slot := position
        }
    }

    function domainName() public virtual view returns (bytes memory);

    function domainVersion() public virtual view returns (bytes32);

    function generateDomainSeparator() public view returns (bytes32) {
        uint256 chainID = _chainID();
        bytes memory dn = domainName();
        bytes memory dv = abi.encodePacked(domainVersion());

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

    function domainSeparator() public returns (bytes32) {
        return _domainSeparator();
    }

    function _updateDomainSeparator() internal returns (bytes32) {
        uint256 chainID = _chainID();

        bytes32 newDomainSeparator = generateDomainSeparator();

        require(newDomainSeparator != bytes32(0), "Invalid domain seperator");

        domainAwareData().chainToDomainData[chainID] = DomainData(
            newDomainSeparator,
            domainVersion()
        );

        return newDomainSeparator;
    }

    // Returns the domain separator, updating it if chainID changes
    function _domainSeparator() private returns (bytes32) {
        uint256 chainID = _chainID();
        bytes32 reportedVersion = domainVersion();

        DomainData memory currentDomainData = domainAwareData().chainToDomainData[chainID];

        if (currentDomainData.domainSeparator != 0x00 && currentDomainData.version == reportedVersion) {
            return currentDomainData.domainSeparator;
        }

        return _updateDomainSeparator();
    }

    function _chainID() internal view returns (uint256) {
        uint256 chainID;
        assembly {
            chainID := chainid()
        }

        return chainID;
    }
}