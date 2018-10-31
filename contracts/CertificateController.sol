pragma solidity ^0.4.24;


contract CertificateController {
    
    // Address used by off-chain controller service to sign certificate
    mapping(address => bool) public certificateEmitters;

    // A nonce used to ensure a certificate can be used only once
    mapping(address => uint) public checkCount;
    
    event Checked(address sender);

    constructor(
        address _certificateEmitter
    )
        public
    {
        require(_certificateEmitter != address(0), "Valid address required");
        certificateEmitters[_certificateEmitter] = true;
    }

    /**
     * @dev Modifier to protect methods with certificate control
     */
    modifier isValidCertificate(bytes data) {
        require(checkCertificate(data), "Certificate is invalid");
        _;
    }

    /**
     * @dev Check if a certificate is correct
     * @param data Certificate to control
     */
    function checkCertificate(bytes data)
        public
        returns(bool)
    {   
        uint256 e;
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        // Certificate should be 97 bytes long
        if (data.length != 97) {
            return false;
        }

        // Extract certificate information and expiration time from payload
        assembly {
            // Retrieve expirationTime & ECDSA elements from certificate which is a 97 long bytes
            // Certificate encoding format is: <expirationTime (32 bytes)>@<r (32 bytes)>@<s (32 bytes)>@<v (1 byte)>
            e := mload(add(data, 0x20))
            r := mload(add(data, 0x40))
            s := mload(add(data, 0x60))
            v := byte(0, mload(add(data, 0x80)))
        }

        // Certificate should not be expired
        if (e < now) {
            return false;
        }
        
        if (v < 27) {
            v += 27;
        }

        // Perform ecrecover to ensure message information corresponds to certificate
        if (v == 27 || v == 28) {
            // Extract payload and remove data argument
            bytes memory payload;
            assembly {
                let payloadsize := sub(calldatasize, 160)
                payload := mload(0x40) // allocate new memory
                mstore(0x40, add(payload, and(add(add(payloadsize, 0x20), 0x1f), not(0x1f)))) // boolean trick for padding to 0x40
                mstore(payload, payloadsize) // set length
                calldatacopy(add(payload, 0x20), 0, payloadsize)
            }

            // Pack and hash
            bytes memory pack = abi.encodePacked(
                msg.sender,
                this,
                msg.value,
                payload,
                e,
                checkCount[msg.sender]
            );
            bytes32 hash = keccak256(pack);

            // Check if certificate match expected transactions parameters
            if (certificateEmitters[ecrecover(hash, v, r, s)]) {
                // Increment sender check count
                checkCount[msg.sender] += 1;

                emit Checked(msg.sender);

                return true;
            }
        }   
        return false;
    } 
}
