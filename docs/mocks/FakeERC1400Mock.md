## `FakeERC1400Mock`






### `constructor(string name, string symbol, uint256 granularity, address[] controllers, bytes32[] defaultPartitions, address extension, address mockAddress)` (public)





### `_callRecipientExtension(bytes32 partition, address operator, address from, address to, uint256 value, bytes data, bytes operatorData)` (internal)

Override function to allow calling "tokensReceived" hook with wrong recipient ("to")



### `transferFromWithData(address from, address to, uint256 value, bytes)` (external)

Override function to allow redeeming tokens from address(0)



### `redeemFrom(address from, uint256 value, bytes data)` (external)

Override function to allow redeeming tokens from address(0)






