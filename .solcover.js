module.exports = {
  configureYulOptimizer: true,
  testCommand:
    "node --max-old-space-size=4096 ../node_modules/.bin/truffle test test/TokenExtension.test.js --network coverage",
  compileCommand:
    "node --max-old-space-size=4096 ../node_modules/.bin/truffle compile --network coverage",
  skipFiles: ["tokens/ERC20Token", "tokens/ERC721Token", "tools/FundIssuer"],
  copyPackages: ["@openzeppelin/contracts"],
  mocha: {
    enableTimeouts: false,
    before_timeout: 0
  }
};
