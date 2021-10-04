## `ERC1400HoldableCertificateToken`



Holdable ERC1400 with nonce-based certificate controller logic


### `constructor(string name, string symbol, uint256 granularity, address[] controllers, bytes32[] defaultPartitions, address extension, address newOwner, address certificateSigner, enum IExtensionTypes.CertificateValidation certificateActivated)` (public)



Initialize ERC1400 + initialize certificate controller.


### `canTransferByPartition(bytes32 partition, address to, uint256 value, bytes data) → bytes1, bytes32, bytes32` (external)



Know the reason on success or failure based on the EIP-1066 application-specific status codes.


### `canOperatorTransferByPartition(bytes32 partition, address from, address to, uint256 value, bytes data, bytes operatorData) → bytes1, bytes32, bytes32` (external)



Know the reason on success or failure based on the EIP-1066 application-specific status codes.


### `_replaceFunctionSelector(bytes4 functionSig, bytes payload) → bytes` (internal)



Replace function selector





