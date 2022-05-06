module.exports = {
  configureYulOptimizer: true,
  testCommand:
    "node --max-old-space-size=4096 ../node_modules/.bin/truffle test --network coverage",
  compileCommand:
    "node --max-old-space-size=4096 ../node_modules/.bin/truffle compile --network coverage",
  skipFiles: [
    "extensions/allowblock/allow/IAllowlistedAdminRole.sol",
    "extensions/allowblock/allow/IAllowlistedRole.sol",
    "extensions/allowblock/block/IBlocklistedAdminRole.sol",
    "extensions/allowblock/block/IBlocklistedRole.sol",
    "tokens/storage/TokenEventManagerStorage.sol",
    "utils/erc1820/ERC1820Registry.sol",
    "utils/mocks/legacy/erc1400/ERC1400.sol",
    "utils/mocks/legacy/MinterRole.sol",
    "utils/mocks/FakeERC1400Mock.sol",
    "utils/mocks/MockAllowExtension.sol",
    "utils/mocks/MockBlockExtension.sol",
    "utils/mocks/legacy/erc20/ERC20Token.sol",
    "utils/mocks/legacy/erc721/ERC721Token.sol"],
  copyPackages: ["@openzeppelin/contracts"],
  mocha: {
    enableTimeouts: false,
    before_timeout: 0
  }
};
