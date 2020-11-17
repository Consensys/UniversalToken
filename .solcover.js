module.exports = {
  testCommand:
    "node --max-old-space-size=4096 ../node_modules/.bin/truffle test --network coverage",
  compileCommand:
    "node --max-old-space-size=4096 ../node_modules/.bin/truffle compile --network coverage",
  skipFiles: ["tokens/ERC20Token", "tokens/ERC721Token", "tools/FundIssuer"],
  copyPackages: ["openzeppelin-solidity"],
};
