module.exports = {
  configureYulOptimizer: true,
  testCommand:
    "node --max-old-space-size=4096 ../node_modules/.bin/truffle test test/TokenExtension.test.js --network coverage",
  compileCommand:
    "node --max-old-space-size=4096 ../node_modules/.bin/truffle compile --network coverage",
  skipFiles: ["tokens/ERC20Token", "tokens/ERC721Token", "tools/FundIssuer", 
    "extensions/allowblock/allow/IAllowlistedAdminRole.sol",
    "extensions/allowblock/allow/IAllowlistedRole.sol",
    "extensions/allowblock/block/IBlocklistedAdminRole.sol",
    "extensions/allowblock/block/IBlocklistedRole.sol"],
  copyPackages: ["@openzeppelin/contracts"],
  mocha: {
    enableTimeouts: false,
    before_timeout: 0
  }
};
