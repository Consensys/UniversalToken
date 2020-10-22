exports.bytes = /^0x([A-Fa-f0-9]{1,})$/

exports.bytes32 = /^0x([A-Fa-f0-9]{64})$/
exports.ethereumAddress = /^0x([A-Fa-f0-9]{40})$/
exports.transactionHash = /^0x([A-Fa-f0-9]{64})$/

exports.uuid4 = /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
