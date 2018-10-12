pragma solidity ^0.4.24;

import "./Controller.sol";

contract CertificateController is Controller {
    
    // Address used by off-chain controller service to sign certificate
    mapping(address => bool) public certificateEmitters;

    // A nonce used to ensure a certificate can be used only once
    mapping(address => uint) checkCount;
    
    event NounceUpdate(address sender, uint256 newNounce);

    constructor(
        address _certificateEmitter
    )
        public
    {
        require(_certificateEmitter != address(0), "Must provide valid address");
        certificateEmitters[_certificateEmitter] = true;
    }

    /**
     * @dev Modifier to protect methods with certificate control
     */
    modifier isValidCertificate() {
        require(checkCertificate(), "Certificate is invalid");
        _;
    }

    /**
     * @dev Modifier to protect methods with certificate control
     */
    function isValid() 
        public
        returns(bool)
    {
        return checkCertificate();
    }

    event Debug2(uint256 expTime, bytes32 hash, bytes data, bytes data2);
    event BadCertificate(uint256 expTime, bytes32 hash, bytes data, bytes data2);

    /**
     * @dev Check if a provided certificate is correct
     * 
     * This method extracts certificate and expiration time arguments from method call payload
     * so you don't to pass them as arguments of the method
     * 
     * Warning:
     * - certificate should be a 65 long bytes (encoded on 160 byte) and provided as last argument of method call
     * - expirationTime should be a uint256 provided as argument previous to certificate
     */
    function () isValidCertificate payable public {
    }
    function checkCertificate()
        public
        returns(bool)
    {   
        bytes memory data;
        bytes32 r;
        bytes32 s;
        uint8 v;
        uint256 expirationTime;
        
        // Extract certificate information and expiration time from payload
        assembly {
            // Get data payload size
            let size := calldatasize

            // Retrieve ECDSA elements from certificate which is a 65 long bytes (encoded on 160 bytes)
            // Certificate encoding format is: <Head prefix (32 + 32 bytes)>@<r (32 bytes)>@<s (32 bytes)>@<v (1 bytes)>@<zero padding (31 bytes)> 
            r := calldataload(sub(size, 65))
            s := calldataload(sub(size, 33))
            v := byte(0, calldataload(sub(size, 1)))

            // TODO: we could retrieve certificate length from certificate prefix and test if certificate lenght is 65 bytes

            // Retrieve expiration date which come just before certificate in data payload
            expirationTime := calldataload(sub(size, 97))

            // Store non hidden data payload in memory
            if gt(size, 97)
            {
                let payloadsize := sub(size, 97)
                data := mload(0x40) // allocate new memory
                mstore(0x40, add(data, and(add(add(payloadsize, 0x20), 0x1f), not(0x1f)))) // boolean trick for padding to 0x40
                mstore(data, payloadsize) // set length
                calldatacopy(add(data, 0x20), 0, payloadsize)
            }
        }

        // Certificate should not have expired
        if (now > expirationTime) {
            return false;
        }
        
        if (v < 27) {
            v += 27;
        }

        // Perform ecrecover to ensure message information corresponds to certificate
        if (v == 27 || v == 28) {
            // Compute expected certificate content
            bytes32 hash = keccak256(
                abi.encodePacked(
                    msg.sender,
                    msg.value, // TODO: check if payable is required even with no transfer of ETH
                    data,
                    this,
                    expirationTime,
                    checkCount[msg.sender]
                )
            );
            emit Debug2(expirationTime, hash, data, T);
            // Check if the certificate match expected content
            if (certificateEmitters[ecrecover(hash, v, r, s)]) {
                checkCount[msg.sender] += 1; //TODO check that too
                emit NounceUpdate(msg.sender, checkCount[msg.sender]);
                return true;
            }
            bytes memory T = abi.encodePacked(
                    msg.sender,
                    msg.value, // TODO: check if payable is required even with no transfer of ETH
                    data,
                    this,
                    expirationTime,
                    checkCount[msg.sender]
                );
            emit BadCertificate(expirationTime, hash, data, T);
        }

        return false;
    } 
}
