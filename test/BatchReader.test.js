const { ZERO_ADDRESS, ZERO_BYTES32 } = require("@openzeppelin/test-helpers/src/constants");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");

const { newSecretHashPair, newHoldId } = require("./utils/crypto");

const BatchReader = artifacts.require("BatchReader.sol");

const ERC1820Registry = artifacts.require("IERC1820Registry");

const ERC721Token = artifacts.require("ERC721Token");
const ERC1400HoldableCertificate = artifacts.require("ERC1400HoldableCertificateToken");
const ERC1400TokensValidator = artifacts.require("ERC1400TokensValidator");

const {
  CERTIFICATE_VALIDATION_NONE,
  CERTIFICATE_VALIDATION_SALT,
  setAllowListActivated,
  setBlockListActivated,
  setGranularityByPartitionActivated,
  setHoldsActivated,
  addTokenController
} = require("./common/extension");
const { assert } = require("chai");

const EMPTY_CERTIFICATE = "0x";

const partition1_short =
  "7265736572766564000000000000000000000000000000000000000000000000"; // reserved in hex
const partition2_short =
  "6973737565640000000000000000000000000000000000000000000000000000"; // issued in hex
const partition3_short =
  "6c6f636b65640000000000000000000000000000000000000000000000000000"; // locked in hex
const partition4_short =
  "636f6c6c61746572616c00000000000000000000000000000000000000000000"; // collateral in hex
const partition1 = "0x".concat(partition1_short);
const partition2 = "0x".concat(partition2_short);
const partition3 = "0x".concat(partition3_short);
const partition4 = "0x".concat(partition4_short);

const partitions = [partition1, partition2, partition3, partition4];

const issuanceAmount11 = 11;
const issuanceAmount12 = 12;
const issuanceAmount13 = 13;

const issuanceAmount21 = 21;
const issuanceAmount22 = 22;
const issuanceAmount23 = 23;

const issuanceAmount31 = 31;
const issuanceAmount32 = 32;
const issuanceAmount33 = 33;

const issuanceAmount41 = 41;
const issuanceAmount42 = 42;
const issuanceAmount43 = 43;

const token1DefaultPartitions = [partition1, partition2, partition3];
const token2DefaultPartitions = [partition1, partition2, partition3, partition4];
const token3DefaultPartitions = [];
const token4DefaultPartitions = [partition3, partition4];

const token1Partitions = [partition1, partition2, partition3];
const token2Partitions = [partition2, partition3, partition4];
const token3Partitions = [];
const token4Partitions = [partition1];

const SECONDS_IN_AN_HOUR = 3600;

const holdAmount = 6;

contract(
  "BatchReader",
  ([owner, controller1, controller2, controller3, deployer, tokenHolder1, tokenHolder2, tokenHolder3, unknown]) => {
    before(async function () {
      this.registry = await ERC1820Registry.at(
        "0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24"
      );
  
      this.extension = await ERC1400TokensValidator.new({
        from: deployer,
      });
      this.extension2 = await ERC1400TokensValidator.new({
        from: deployer,
      });

      this.balanceReader = await BatchReader.new();

      this.token1 = await ERC1400HoldableCertificate.new(
        "ERC1400Token",
        "DAU",
        1,
        [controller1],
        token1DefaultPartitions,
        this.extension.address,
        ZERO_ADDRESS, // owner
        ZERO_ADDRESS, // certitficate signer
        CERTIFICATE_VALIDATION_NONE,
        { from: controller1 }
      );
      this.token2 = await ERC1400HoldableCertificate.new(
        "ERC1400Token",
        "DAU",
        1,
        [controller1],
        token2DefaultPartitions,
        this.extension.address,
        ZERO_ADDRESS, // owner
        ZERO_ADDRESS, // certitficate signer
        CERTIFICATE_VALIDATION_NONE,
        { from: controller1 }
      );
      this.token3 = await ERC1400HoldableCertificate.new(
        "ERC1400Token",
        "DAU",
        1,
        [],
        token3DefaultPartitions,
        this.extension2.address,
        owner, // owner
        ZERO_ADDRESS, // certitficate signer
        CERTIFICATE_VALIDATION_SALT,
        { from: controller2 }
      );
      this.token4 = await ERC1400HoldableCertificate.new(
        "ERC1400Token",
        "DAU",
        1,
        [controller1, controller2, controller3],
        token4DefaultPartitions,
        ZERO_ADDRESS, // extension
        ZERO_ADDRESS, // owner
        ZERO_ADDRESS, // certitficate signer
        CERTIFICATE_VALIDATION_NONE,
        { from: controller3 }
      );

      this.token5 = await ERC721Token.new(
        "ERC721Token",
        "DAU",
        "",
        ""
      );

      this.token6 = await ERC721Token.new(
        "ERC721Token",
        "DAU",
        "",
        ""
      );

      // Add token extension controllers
      await addTokenController(
        this.extension2,
        this.token3,
        owner,
        controller1
      );
      await addTokenController(
        this.extension2,
        this.token3,
        owner,
        controller2
      );

      // Deactivate allowlist checks
      await setAllowListActivated(
        this.extension,
        this.token1,
        controller1,
        false
      );
      await setAllowListActivated(
        this.extension,
        this.token2,
        controller1,
        false
      );

      // Deactivate blocklist checks
      await setBlockListActivated(
        this.extension,
        this.token2,
        controller1,
        false
      );

      // Deactivate granularity by partition checks
      await setGranularityByPartitionActivated(
        this.extension,
        this.token1,
        controller1,
        false
      );

      // Deactivate holds
      await setHoldsActivated(
        this.extension2,
        this.token3,
        owner,
        false
      );

      // Token1
      await this.token1.issueByPartition(
        partition1,
        tokenHolder1,
        issuanceAmount11,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );
      await this.token1.issueByPartition(
        partition1,
        tokenHolder2,
        issuanceAmount12,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );
      await this.token1.issueByPartition(
        partition1,
        tokenHolder3,
        issuanceAmount13,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );

      await this.token1.issueByPartition(
        partition2,
        tokenHolder1,
        issuanceAmount21,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );
      await this.token1.issueByPartition(
        partition2,
        tokenHolder2,
        issuanceAmount22,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );
      await this.token1.issueByPartition(
        partition2,
        tokenHolder3,
        issuanceAmount23,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );

      await this.token1.issueByPartition(
        partition3,
        tokenHolder1,
        issuanceAmount31,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );
      await this.token1.issueByPartition(
        partition3,
        tokenHolder2,
        issuanceAmount32,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );
      await this.token1.issueByPartition(
        partition3,
        tokenHolder3,
        issuanceAmount33,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );

      // Token2
      await this.token2.issueByPartition(
        partition2,
        tokenHolder1,
        2 * issuanceAmount21,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );
      await this.token2.issueByPartition(
        partition2,
        tokenHolder2,
        2 * issuanceAmount22,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );
      await this.token2.issueByPartition(
        partition2,
        tokenHolder3,
        2 * issuanceAmount23,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );

      await this.token2.issueByPartition(
        partition3,
        tokenHolder1,
        2 * issuanceAmount31,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );
      await this.token2.issueByPartition(
        partition3,
        tokenHolder2,
        2 * issuanceAmount32,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );
      await this.token2.issueByPartition(
        partition3,
        tokenHolder3,
        2 * issuanceAmount33,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );

      await this.token2.issueByPartition(
        partition4,
        tokenHolder1,
        2 * issuanceAmount41,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );
      await this.token2.issueByPartition(
        partition4,
        tokenHolder2,
        2 * issuanceAmount42,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );
      await this.token2.issueByPartition(
        partition4,
        tokenHolder3,
        2 * issuanceAmount43,
        EMPTY_CERTIFICATE,
        { from: controller1 }
      );

      // Token4
      await this.token4.issueByPartition(
        partition1,
        tokenHolder1,
        4*issuanceAmount11,
        EMPTY_CERTIFICATE,
        { from: controller3 }
      );

      // Transfer some ETH to modify the balances
      await web3.eth.sendTransaction({from: tokenHolder1, to: tokenHolder2, value: web3.utils.toWei('5')});

      // Create token holds to modify the spendable balances by partition
      await this.extension.hold(
        this.token1.address,
        newHoldId(),
        tokenHolder2,
        unknown, // notary
        partition1,
        holdAmount,
        SECONDS_IN_AN_HOUR,
        newSecretHashPair().hash,
        ZERO_BYTES32, // certificate
        { from: tokenHolder1 }
      );
      await this.extension.hold(
        this.token2.address,
        newHoldId(),
        tokenHolder2,
        unknown, // notary
        partition2,
        2*holdAmount,
        SECONDS_IN_AN_HOUR,
        newSecretHashPair().hash,
        ZERO_BYTES32, // certificate
        { from: tokenHolder3 }
      );

      // Add allowlisted
      await this.extension.addAllowlisted(this.token1.address, tokenHolder1, { from: controller1 });
      await this.extension.addAllowlisted(this.token1.address, tokenHolder2, { from: controller1 });
      await this.extension.addAllowlisted(this.token2.address, tokenHolder3, { from: controller1 });

      // Add blocklisted
      await this.extension.addBlocklisted(this.token1.address, tokenHolder3, { from: controller1 });
      await this.extension.addBlocklisted(this.token2.address, tokenHolder2, { from: controller1 });
      await this.extension.addBlocklisted(this.token2.address, tokenHolder3, { from: controller1 });

      // Mint NFTs
      await this.token5.mint(tokenHolder1, 1);
      await this.token5.mint(tokenHolder1, 2);
      await this.token5.mint(tokenHolder1, 3);
      await this.token5.mint(tokenHolder1, 4);

      await this.token5.mint(tokenHolder2, 5);
      await this.token5.mint(tokenHolder2, 6);
      await this.token5.mint(tokenHolder2, 7);

      await this.token5.mint(tokenHolder3, 8);
      await this.token5.mint(tokenHolder3, 9);
      await this.token5.mint(tokenHolder3, 10);
      await this.token5.mint(tokenHolder3, 11);
      await this.token5.mint(tokenHolder3, 12);
      await this.token5.mint(tokenHolder3, 13);
      await this.token5.mint(tokenHolder3, 14);

      await this.token6.mint(tokenHolder1, 10);
      await this.token6.mint(tokenHolder1, 20);
      await this.token6.mint(tokenHolder1, 30);
      await this.token6.mint(tokenHolder1, 40);

      await this.token6.mint(tokenHolder2, 50);
      await this.token6.mint(tokenHolder2, 60);
      await this.token6.mint(tokenHolder2, 70);

      await this.token6.mint(tokenHolder3, 80);
      await this.token6.mint(tokenHolder3, 90);
      await this.token6.mint(tokenHolder3, 100);
      await this.token6.mint(tokenHolder3, 110);
      await this.token6.mint(tokenHolder3, 120);
      await this.token6.mint(tokenHolder3, 130);
      await this.token6.mint(tokenHolder3, 140);
    });

    describe("batchTokenSuppliesInfos", function () {
      it("returns the list of token supplies", async function () {
        const tokenAddresses = [this.token1.address, this.token2.address, this.token3.address, this.token4.address];

        const batchTokenSupplies = await this.balanceReader.batchTokenSuppliesInfos(
          tokenAddresses,
          { from: unknown }
        );

        const totalSupply1Partition1 = issuanceAmount11 + issuanceAmount12 + issuanceAmount13;
        const totalSupply1Partition2 = issuanceAmount21 + issuanceAmount22 + issuanceAmount23;
        const totalSupply1Partition3 = issuanceAmount31 + issuanceAmount32 + issuanceAmount33;
        const totalSupply1 = totalSupply1Partition1 + totalSupply1Partition2 + totalSupply1Partition3;

        const totalSupply2Partition1 = 2 * (issuanceAmount21 + issuanceAmount22 + issuanceAmount23);
        const totalSupply2Partition2 = 2 * (issuanceAmount31 + issuanceAmount32 + issuanceAmount33);
        const totalSupply2Partition3 = 2 * (issuanceAmount41 + issuanceAmount42 + issuanceAmount43);
        const totalSupply2 = totalSupply2Partition1 + totalSupply2Partition2 + totalSupply2Partition3;

        const totalSupply3 = 0;

        const totalSupply4Partition1 = 4 * issuanceAmount11;
        const totalSupply4 = totalSupply4Partition1;

        const batchTotalSupplies = batchTokenSupplies[0];
        const totalPartitionsLengths = batchTokenSupplies[1];
        const batchTotalPartitions = batchTokenSupplies[2];
        const batchPartitionSupplies = batchTokenSupplies[3];
        const defaultPartitionsLengths = batchTokenSupplies[4];
        const batchDefaultPartitions = batchTokenSupplies[5];

        // TOTAL SUPPLIES
        //
        assert.equal(batchTotalSupplies.length, tokenAddresses.length);
        //
        // Token1
        assert.equal(parseInt(batchTotalSupplies[0]), totalSupply1);
        // Token2
        assert.equal(parseInt(batchTotalSupplies[1]), totalSupply2);
        // Token3
        assert.equal(parseInt(batchTotalSupplies[2]), totalSupply3);
        // Token3
        assert.equal(parseInt(batchTotalSupplies[3]), totalSupply4);

        // TOTAL PARTITIONS LENGTH
        //
        assert.equal(totalPartitionsLengths.length, tokenAddresses.length);
        //
        // Token1
        assert.equal(totalPartitionsLengths[0], token1Partitions.length);
        // Token2
        assert.equal(totalPartitionsLengths[1], token2Partitions.length);
        // Token3
        assert.equal(totalPartitionsLengths[2], token3Partitions.length);
        // Token3
        assert.equal(totalPartitionsLengths[3], token4Partitions.length);

        // TOTAL PARTITIONS
        //
        assert.equal(batchTotalPartitions.length, token1Partitions.length + token2Partitions.length + token3Partitions.length + token4Partitions.length);
        //
        // Token1
        assert.equal(batchTotalPartitions[0], token1Partitions[0]);
        assert.equal(batchTotalPartitions[1], token1Partitions[1]);
        assert.equal(batchTotalPartitions[2], token1Partitions[2]);
        // Token2
        assert.equal(batchTotalPartitions[3], token2Partitions[0]);
        assert.equal(batchTotalPartitions[4], token2Partitions[1]);
        assert.equal(batchTotalPartitions[5], token2Partitions[2]);
        // Token3
        // NA
        // Token4
        assert.equal(batchTotalPartitions[6], token4Partitions[0]);

        // PARTITION SUPPLIES
        //
        assert.equal(batchPartitionSupplies.length, token1Partitions.length + token2Partitions.length + token3Partitions.length + token4Partitions.length);
        //
        // Token1
        assert.equal(parseInt(batchPartitionSupplies[0]), totalSupply1Partition1);
        assert.equal(parseInt(batchPartitionSupplies[1]), totalSupply1Partition2);
        assert.equal(parseInt(batchPartitionSupplies[2]), totalSupply1Partition3);
        // Token2
        assert.equal(parseInt(batchPartitionSupplies[3]), totalSupply2Partition1);
        assert.equal(parseInt(batchPartitionSupplies[4]), totalSupply2Partition2);
        assert.equal(parseInt(batchPartitionSupplies[5]), totalSupply2Partition3);
        // Token3
        // NA
        // Token4
        assert.equal(parseInt(batchPartitionSupplies[6]), totalSupply4Partition1);

        // DEFAULT PARTITIONS LENGTH
        //
        assert.equal(defaultPartitionsLengths.length, tokenAddresses.length);
        //
        // Token1
        assert.equal(defaultPartitionsLengths[0], token1DefaultPartitions.length);
        // Token2
        assert.equal(defaultPartitionsLengths[1], token2DefaultPartitions.length);
        // Token3
        assert.equal(defaultPartitionsLengths[2], token3DefaultPartitions.length);
        // Token4
        assert.equal(defaultPartitionsLengths[3], token4DefaultPartitions.length);

        // DEFAULT PARTITIONS
        //
        assert.equal(batchDefaultPartitions.length, token1DefaultPartitions.length + token2DefaultPartitions.length + token3DefaultPartitions.length + token4DefaultPartitions.length);
        //
        // Token1
        assert.equal(batchDefaultPartitions[0], token1DefaultPartitions[0]);
        assert.equal(batchDefaultPartitions[1], token1DefaultPartitions[1]);
        assert.equal(batchDefaultPartitions[2], token1DefaultPartitions[2]);
        // Token2
        assert.equal(batchDefaultPartitions[3], token2DefaultPartitions[0]);
        assert.equal(batchDefaultPartitions[4], token2DefaultPartitions[1]);
        assert.equal(batchDefaultPartitions[5], token2DefaultPartitions[2]);
        assert.equal(batchDefaultPartitions[6], token2DefaultPartitions[3]);
        // Token3
        // NA
        // Token4
        assert.equal(batchDefaultPartitions[7], token4DefaultPartitions[0]);
        assert.equal(batchDefaultPartitions[8], token4DefaultPartitions[1]);
      });
    });

    describe("batchTokenRolesInfos", function () {
      it("returns the list of token roles", async function () {
        const tokenAddresses = [this.token1.address, this.token2.address, this.token3.address, this.token4.address];

        const batchTokenRolesInfos = await this.balanceReader.batchTokenRolesInfos(
          tokenAddresses,
          { from: unknown }
        );

        const batchOwners = batchTokenRolesInfos[0];
        const batchControllersLength = batchTokenRolesInfos[1];
        const batchControllers = batchTokenRolesInfos[2];
        const batchExtensionControllersLength = batchTokenRolesInfos[3];
        const batchExtensionControllers = batchTokenRolesInfos[4];

        // OWNERS
        //
        assert.equal(batchOwners.length, tokenAddresses.length);
        //
        // Token1
        assert.equal(parseInt(batchOwners[0]), controller1);
        // Token2
        assert.equal(parseInt(batchOwners[1]), controller1);
        // Token3
        assert.equal(parseInt(batchOwners[2]), owner);
        // Token4
        assert.equal(parseInt(batchOwners[3]), controller3);

        // CONTROLLERS LENGTH
        //
        assert.equal(batchControllersLength.length, tokenAddresses.length);
        //
        // Token1
        assert.equal(parseInt(batchControllersLength[0]), 1);
        // Token2
        assert.equal(parseInt(batchControllersLength[1]), 1);
        // Token3
        assert.equal(parseInt(batchControllersLength[2]), 0);
        // Token4
        assert.equal(parseInt(batchControllersLength[3]), 3);

        // CONTROLLERS
        //
        assert.equal(batchControllers.length, 1+1+0+3);
        //
        // Token1
        assert.equal(batchControllers[0], controller1);
        // Token2
        assert.equal(batchControllers[1], controller1);
        // Token3
        //
        // Token4
        assert.equal(batchControllers[2], controller1);
        assert.equal(batchControllers[3], controller2);
        assert.equal(batchControllers[4], controller3);

        // EXTENSION CONTROLLERS LENGTH
        //
        assert.equal(batchExtensionControllersLength.length, tokenAddresses.length);
        //
        // Token1
        assert.equal(parseInt(batchExtensionControllersLength[0]), 1);
        // Token2
        assert.equal(parseInt(batchExtensionControllersLength[1]), 1);
        // Token3
        assert.equal(parseInt(batchExtensionControllersLength[2]), 2);
        // Token4
        assert.equal(parseInt(batchExtensionControllersLength[3]), 0);

        // EXTENSION CONTROLLERS
        //
        assert.equal(batchExtensionControllers.length, 1+1+2+0);
        //
        // Token1
        assert.equal(batchExtensionControllers[0], controller1);
        // Token2
        assert.equal(batchExtensionControllers[1], controller1);
        // Token3
        assert.equal(batchExtensionControllers[2], controller1);
        assert.equal(batchExtensionControllers[3], controller2);
        // Token4
        //

      });
    });

    describe("batchTokenExtensionSetup", function () {
      it("returns the list of token extensions setup", async function () {
        const tokenAddresses = [this.token1.address, this.token2.address, this.token3.address, this.token4.address];

        const batchTokenRolesInfos = await this.balanceReader.batchTokenExtensionSetup(
          tokenAddresses,
          { from: unknown }
        );

        const batchTokenExtension = batchTokenRolesInfos[0];
        const batchCertificateActivated = batchTokenRolesInfos[1];
        const batchAllowlistActivated = batchTokenRolesInfos[2];
        const batchBlocklistActivated = batchTokenRolesInfos[3];
        const batchGranularityByPartitionActivated = batchTokenRolesInfos[4];
        const batchHoldsActivated = batchTokenRolesInfos[5];

        // TOKEN EXTENSION ADDRESS
        //
        assert.equal(batchTokenExtension.length, tokenAddresses.length);
        //
        // Token1
        assert.equal(batchTokenExtension[0], this.extension.address);
        // Token2
        assert.equal(batchTokenExtension[1], this.extension.address);
        // Token3
        assert.equal(batchTokenExtension[2], this.extension2.address);
        // Token4
        assert.equal(batchTokenExtension[3], ZERO_ADDRESS);

        // CERTIFICATE VALIDATION
        //
        assert.equal(batchCertificateActivated.length, tokenAddresses.length);
        //
        // Token1
        assert.equal(batchCertificateActivated[0], CERTIFICATE_VALIDATION_NONE);
        // Token2
        assert.equal(batchCertificateActivated[1], CERTIFICATE_VALIDATION_NONE);
        // Token3
        assert.equal(batchCertificateActivated[2], CERTIFICATE_VALIDATION_SALT);
        // Token4
        assert.equal(batchCertificateActivated[3], CERTIFICATE_VALIDATION_NONE);

        // ALLOWLIST
        //
        assert.equal(batchAllowlistActivated.length, tokenAddresses.length);
        //
        // Token1
        assert.equal(batchAllowlistActivated[0], false);
        // Token2
        assert.equal(batchAllowlistActivated[1], false);
        // Token3
        assert.equal(batchAllowlistActivated[2], true);
        // Token4
        assert.equal(batchAllowlistActivated[3], false);

        // BLOCKLIST
        //
        assert.equal(batchBlocklistActivated.length, tokenAddresses.length);
        //
        // Token1
        assert.equal(batchBlocklistActivated[0], true);
        // Token2
        assert.equal(batchBlocklistActivated[1], false);
        // Token3
        assert.equal(batchBlocklistActivated[2], true);
        // Token4
        assert.equal(batchBlocklistActivated[3], false);

        // GRANULARITY BY PARTITION
        //
        assert.equal(batchGranularityByPartitionActivated.length, tokenAddresses.length);
        //
        // Token1
        assert.equal(batchGranularityByPartitionActivated[0], false);
        // Token2
        assert.equal(batchGranularityByPartitionActivated[1], true);
        // Token3
        assert.equal(batchGranularityByPartitionActivated[2], true);
        // Token4
        assert.equal(batchGranularityByPartitionActivated[3], false);

        // HOLDS
        //
        assert.equal(batchHoldsActivated.length, tokenAddresses.length);
        //
        // Token1
        assert.equal(batchHoldsActivated[0], true);
        // Token2
        assert.equal(batchHoldsActivated[1], true);
        // Token3
        assert.equal(batchHoldsActivated[2], false);
        // Token4
        assert.equal(batchHoldsActivated[3], false);

      });
    });

    describe("batchBalances", function () {
      it("returns the lists of ETH, ERC20 and ERC1400 balances (spendable or not)", async function () {
        const tokenHolders = [tokenHolder1, tokenHolder2, tokenHolder3];
        const tokenAddresses = [this.token1.address, this.token2.address, this.token3.address, this.token4.address];

        const batchERC1400Balances = await this.balanceReader.batchERC1400Balances(
          tokenAddresses,
          tokenHolders,
          { from: unknown }
        );

        const batchEthBalances = batchERC1400Balances[0];
        const batchBalancesOf = batchERC1400Balances[1];
        const totalPartitionsLengths = batchERC1400Balances[2];
        const batchTotalPartitions = batchERC1400Balances[3];
        const batchBalancesOfByPartition = batchERC1400Balances[4];
        const batchSpendableBalancesOfByPartition = batchERC1400Balances[5];

        // ETH BALANCES
        //
        assert.equal(batchEthBalances.length, tokenHolders.length);
        assert.equal(web3.utils.fromWei(batchEthBalances[0]), web3.utils.fromWei(await web3.eth.getBalance(tokenHolders[0])));
        assert.equal(web3.utils.fromWei(batchEthBalances[1]), web3.utils.fromWei(await web3.eth.getBalance(tokenHolders[1])));
        assert.equal(web3.utils.fromWei(batchEthBalances[2]), web3.utils.fromWei(await web3.eth.getBalance(tokenHolders[2])));

        // BALANCES
        //
        assert.equal(batchBalancesOf.length, tokenHolders.length*tokenAddresses.length);
        //
        // Tokenholder1
        assert.equal(parseInt(batchBalancesOf[0]), issuanceAmount11+issuanceAmount21+issuanceAmount31);
        assert.equal(parseInt(batchBalancesOf[1]), 2*(issuanceAmount21+issuanceAmount31+issuanceAmount41));
        assert.equal(parseInt(batchBalancesOf[2]), 0);
        assert.equal(parseInt(batchBalancesOf[3]), 4*issuanceAmount11);
        // Tokenholder2
        assert.equal(parseInt(batchBalancesOf[4]), issuanceAmount12+issuanceAmount22+issuanceAmount32);
        assert.equal(parseInt(batchBalancesOf[5]), 2*(issuanceAmount22+issuanceAmount32+issuanceAmount42));
        assert.equal(parseInt(batchBalancesOf[6]), 0);
        assert.equal(parseInt(batchBalancesOf[7]), 0);
        // Tokenholder3
        assert.equal(parseInt(batchBalancesOf[8]), issuanceAmount13+issuanceAmount23+issuanceAmount33);
        assert.equal(parseInt(batchBalancesOf[9]), 2*(issuanceAmount23+issuanceAmount33+issuanceAmount43));
        assert.equal(parseInt(batchBalancesOf[10]), 0);
        assert.equal(parseInt(batchBalancesOf[11]), 0);

        // TOTAL PARTITION LENGTHS
        //
        assert.equal(totalPartitionsLengths.length, tokenAddresses.length);
        //
        // Token1
        assert.equal(parseInt(totalPartitionsLengths[0]), token1Partitions.length);
        // Token2
        assert.equal(parseInt(totalPartitionsLengths[1]), token2Partitions.length);
        // Token3
        assert.equal(parseInt(totalPartitionsLengths[2]), token3Partitions.length);
        // Token4
        assert.equal(parseInt(totalPartitionsLengths[3]), token4Partitions.length);

        // TOTAL PARTITIONS
        //
        assert.equal(batchTotalPartitions.length, token1Partitions.length+token2Partitions.length + token3Partitions.length+token4Partitions.length);
        //
        // Token1
        assert.equal(batchTotalPartitions[0], token1Partitions[0]);
        assert.equal(batchTotalPartitions[1], token1Partitions[1]);
        assert.equal(batchTotalPartitions[2], token1Partitions[2]);
        // Token2
        assert.equal(batchTotalPartitions[3], token2Partitions[0]);
        assert.equal(batchTotalPartitions[4], token2Partitions[1]);
        assert.equal(batchTotalPartitions[5], token2Partitions[2]);
        // Token3
        // NA
        // Token4
        assert.equal(batchTotalPartitions[6], token4Partitions[0]);

        // PARTITION BALANCES
        //
        assert.equal(batchBalancesOfByPartition.length, tokenHolders.length*(token1Partitions.length+token2Partitions.length+token3Partitions.length+token4Partitions.length));
        //
        // Tokenholder1 - token1
        assert.equal(parseInt(batchBalancesOfByPartition[0]), issuanceAmount11);
        assert.equal(parseInt(batchBalancesOfByPartition[1]), issuanceAmount21);
        assert.equal(parseInt(batchBalancesOfByPartition[2]), issuanceAmount31);
        // Tokenholder1 - token2
        assert.equal(parseInt(batchBalancesOfByPartition[3]), 2*issuanceAmount21);
        assert.equal(parseInt(batchBalancesOfByPartition[4]), 2*issuanceAmount31);
        assert.equal(parseInt(batchBalancesOfByPartition[5]), 2*issuanceAmount41);
        // Tokenholder1 - token3
        // NA
        // Tokenholder1 - token4
        assert.equal(parseInt(batchBalancesOfByPartition[6]), 4*issuanceAmount11);
        //
        // Tokenholder2 - token1
        assert.equal(parseInt(batchBalancesOfByPartition[7]), issuanceAmount12);
        assert.equal(parseInt(batchBalancesOfByPartition[8]), issuanceAmount22);
        assert.equal(parseInt(batchBalancesOfByPartition[9]), issuanceAmount32);
        // Tokenholder2 - token2
        assert.equal(parseInt(batchBalancesOfByPartition[10]), 2*issuanceAmount22);
        assert.equal(parseInt(batchBalancesOfByPartition[11]), 2*issuanceAmount32);
        assert.equal(parseInt(batchBalancesOfByPartition[12]), 2*issuanceAmount42);
        // Tokenholder2 - token3
        // NA
        // Tokenholder2 - token4
        assert.equal(parseInt(batchBalancesOfByPartition[13]), 0);
        //
        // Tokenholder3 - token1
        assert.equal(parseInt(batchBalancesOfByPartition[14]), issuanceAmount13);
        assert.equal(parseInt(batchBalancesOfByPartition[15]), issuanceAmount23);
        assert.equal(parseInt(batchBalancesOfByPartition[16]), issuanceAmount33);
        // Tokenholder3 - token2
        assert.equal(parseInt(batchBalancesOfByPartition[17]), 2*issuanceAmount23);
        assert.equal(parseInt(batchBalancesOfByPartition[18]), 2*issuanceAmount33);
        assert.equal(parseInt(batchBalancesOfByPartition[19]), 2*issuanceAmount43);
        // Tokenholder3 - token3
        // NA
        // Tokenholder3 - token4
        assert.equal(parseInt(batchBalancesOfByPartition[20]), 0);

        // SPENDABLE PARTITION BALANCES
        //
        assert.equal(batchSpendableBalancesOfByPartition.length, tokenHolders.length*(token1Partitions.length+token2Partitions.length+token3Partitions.length+token4Partitions.length));
        //
        // Tokenholder1 - token1
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[0]), issuanceAmount11 - holdAmount);
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[1]), issuanceAmount21);
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[2]), issuanceAmount31);
        // Tokenholder1 - token2
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[3]), 2*issuanceAmount21);
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[4]), 2*issuanceAmount31);
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[5]), 2*issuanceAmount41);
        // Tokenholder1 - token3
        // NA
        // Tokenholder1 - token4
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[6]), 4*issuanceAmount11);
        //
        // Tokenholder2 - token1
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[7]), issuanceAmount12);
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[8]), issuanceAmount22);
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[9]), issuanceAmount32);
        // Tokenholder2 - token2
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[10]), 2*issuanceAmount22);
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[11]), 2*issuanceAmount32);
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[12]), 2*issuanceAmount42);
        // Tokenholder2 - token3
        // NA
        // Tokenholder2 - token4
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[13]), 0);
        //
        // Tokenholder3 - token1
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[14]), issuanceAmount13);
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[15]), issuanceAmount23);
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[16]), issuanceAmount33);
        // Tokenholder3 - token2
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[17]), 2*issuanceAmount23 - 2*holdAmount);
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[18]), 2*issuanceAmount33);
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[19]), 2*issuanceAmount43);
        // Tokenholder3 - token3
        // NA
        // Tokenholder3 - token4
        assert.equal(parseInt(batchSpendableBalancesOfByPartition[20]), 0);

        //
        //
        //
        //
        //

        const batchERC20Balances = await this.balanceReader.batchERC20Balances(
          tokenAddresses,
          tokenHolders,
          { from: unknown }
        );
        const batchEthBalances2 = batchERC20Balances[0];
        const batchBalancesOf2 = batchERC20Balances[1];

        // ETH BALANCES
        //
        assert.equal(batchEthBalances.length, tokenHolders.length);
        assert.equal(web3.utils.fromWei(batchEthBalances2[0]), web3.utils.fromWei(await web3.eth.getBalance(tokenHolders[0])));
        assert.equal(web3.utils.fromWei(batchEthBalances2[1]), web3.utils.fromWei(await web3.eth.getBalance(tokenHolders[1])));
        assert.equal(web3.utils.fromWei(batchEthBalances2[2]), web3.utils.fromWei(await web3.eth.getBalance(tokenHolders[2])));

        // BALANCES
        //
        assert.equal(batchBalancesOf2.length, tokenHolders.length*tokenAddresses.length);
        //
        // Tokenholder1
        assert.equal(parseInt(batchBalancesOf2[0]), issuanceAmount11+issuanceAmount21+issuanceAmount31);
        assert.equal(parseInt(batchBalancesOf2[1]), 2*(issuanceAmount21+issuanceAmount31+issuanceAmount41));
        assert.equal(parseInt(batchBalancesOf2[2]), 0);
        assert.equal(parseInt(batchBalancesOf2[3]), 4*issuanceAmount11);
        // Tokenholder2
        assert.equal(parseInt(batchBalancesOf2[4]), issuanceAmount12+issuanceAmount22+issuanceAmount32);
        assert.equal(parseInt(batchBalancesOf2[5]), 2*(issuanceAmount22+issuanceAmount32+issuanceAmount42));
        assert.equal(parseInt(batchBalancesOf2[6]), 0);
        assert.equal(parseInt(batchBalancesOf2[7]), 0);
        // Tokenholder3
        assert.equal(parseInt(batchBalancesOf2[8]), issuanceAmount13+issuanceAmount23+issuanceAmount33);
        assert.equal(parseInt(batchBalancesOf2[9]), 2*(issuanceAmount23+issuanceAmount33+issuanceAmount43));
        assert.equal(parseInt(batchBalancesOf2[10]), 0);
        assert.equal(parseInt(batchBalancesOf2[11]), 0);

      });
    });

    describe("batchERC721Balances", function() {
      it("returns the list of minted tokens", async function() {
        const tokenHolders = [tokenHolder1, tokenHolder2, tokenHolder3];
        const tokenAddresses = [this.token5.address, this.token6.address];

        const batchERC721Balances = await this.balanceReader.batchERC721Balances(
          tokenAddresses,
          tokenHolders,
          { from: unknown }
        );

        const batchEthBalances = batchERC721Balances[0];
        const batchBalancesOf = batchERC721Balances[1];

        assert.equal(batchBalancesOf.length, tokenAddresses.length);
        assert.equal(batchEthBalances.length, tokenHolders.length);

        const token5Balances = batchBalancesOf[0];
        const token6Balances = batchBalancesOf[1];

        assert.equal(token5Balances.length, tokenHolders.length);
        assert.equal(token6Balances.length, tokenHolders.length);

        const token5Holder1 = token5Balances[0];
        const token5Holder2 = token5Balances[1];
        const token5Holder3 = token5Balances[2];

        const token6Holder1 = token6Balances[0];
        const token6Holder2 = token6Balances[1];
        const token6Holder3 = token6Balances[2];

        assert.equal(token5Holder1.length, 4);
        assert.equal(token5Holder2.length, 3);
        assert.equal(token5Holder3.length, 7);

        assert.equal(token6Holder1.length, 4);
        assert.equal(token6Holder2.length, 3);
        assert.equal(token6Holder3.length, 7);

        assert.equal(token5Holder1[0], 1);
        assert.equal(token5Holder1[1], 2);
        assert.equal(token5Holder1[2], 3);
        assert.equal(token5Holder1[3], 4);

        assert.equal(token5Holder2[0], 5);
        assert.equal(token5Holder2[1], 6);
        assert.equal(token5Holder2[2], 7);

        assert.equal(token5Holder3[0], 8);
        assert.equal(token5Holder3[1], 9);
        assert.equal(token5Holder3[2], 10);
        assert.equal(token5Holder3[3], 11);
        assert.equal(token5Holder3[4], 12);
        assert.equal(token5Holder3[5], 13);
        assert.equal(token5Holder3[6], 14);

        
        assert.equal(token6Holder1[0], 10);
        assert.equal(token6Holder1[1], 20);
        assert.equal(token6Holder1[2], 30);
        assert.equal(token6Holder1[3], 40);

        assert.equal(token6Holder2[0], 50);
        assert.equal(token6Holder2[1], 60);
        assert.equal(token6Holder2[2], 70);

        assert.equal(token6Holder3[0], 80);
        assert.equal(token6Holder3[1], 90);
        assert.equal(token6Holder3[2], 100);
        assert.equal(token6Holder3[3], 110);
        assert.equal(token6Holder3[4], 120);
        assert.equal(token6Holder3[5], 130);
        assert.equal(token6Holder3[6], 140);
      })
    });

    describe("batchValidations", function () {
      it("returns the lists of allowlisted and blocklisted", async function () {
        const tokenHolders = [tokenHolder1, tokenHolder2, tokenHolder3];
        const tokenAddresses = [this.token1.address, this.token2.address, this.token3.address, this.token4.address];

        const batchValidations = await this.balanceReader.batchValidations(
          tokenAddresses,
          tokenHolders,
          { from: unknown }
        );

        const batchAllowlisted = batchValidations[0];
        const batchBlocklisted = batchValidations[1];

        // ALLOWLISTED
        //
        assert.equal(batchAllowlisted.length, tokenAddresses.length * tokenHolders.length);
        //
        // Tokenholder1
        assert.equal(batchAllowlisted[0], true);
        assert.equal(batchAllowlisted[1], false);
        assert.equal(batchAllowlisted[2], false);
        assert.equal(batchAllowlisted[3], false);
        // Tokenholder2
        assert.equal(batchAllowlisted[4], true);
        assert.equal(batchAllowlisted[5], false);
        assert.equal(batchAllowlisted[6], false);
        assert.equal(batchAllowlisted[7], false);
        // Tokenholder3
        assert.equal(batchAllowlisted[8], false);
        assert.equal(batchAllowlisted[9], true);
        assert.equal(batchAllowlisted[10], false);
        assert.equal(batchAllowlisted[11], false);

        // BLOCKLISTED
        //
        assert.equal(batchBlocklisted.length, tokenAddresses.length * tokenHolders.length);
        //
        // Tokenholder1
        assert.equal(batchBlocklisted[0], false);
        assert.equal(batchBlocklisted[1], false);
        assert.equal(batchBlocklisted[2], false);
        assert.equal(batchBlocklisted[3], false);
        // Tokenholder2
        assert.equal(batchBlocklisted[4], false);
        assert.equal(batchBlocklisted[5], true);
        assert.equal(batchBlocklisted[6], false);
        assert.equal(batchBlocklisted[7], false);
        // Tokenholder3
        assert.equal(batchBlocklisted[8], true);
        assert.equal(batchBlocklisted[9], true);
        assert.equal(batchBlocklisted[10], false);
        assert.equal(batchBlocklisted[11], false);
      });
    });
  }
);
