const { assert } = require("chai");
const {
  nowSeconds,
  advanceTime,
  takeSnapshot,
  revertToSnapshot,
} = require("./utils/time");
const { newSecretHashPair, newHoldId } = require("./utils/crypto");

const HoldableToken = artifacts.require("ERC20HoldableToken");
const DVPHoldableLockable = artifacts.require("DVPHoldableLockable");
const ERC1820Registry = artifacts.require("IERC1820Registry");
const ERC1400HoldableCertificate = artifacts.require("ERC1400HoldableCertificateToken");
const ERC1400TokensValidator = artifacts.require("ERC1400TokensValidator");

const ERC1400_TOKENS_VALIDATOR = "ERC1400TokensValidator";

const partition1_short =
  "5265736572766564000000000000000000000000000000000000000000000000"; // Reserved in hex
const partition2_short =
  "4973737565640000000000000000000000000000000000000000000000000000"; // Issued in hex
const partition3_short =
  "4c6f636b65640000000000000000000000000000000000000000000000000000"; // Locked in hex

const partition1 = "0x".concat(partition1_short);
const partition2 = "0x".concat(partition2_short);
const partition3 = "0x".concat(partition3_short);

const partitions = [partition1, partition2, partition3];

const EMPTY_CERTIFICATE = "0x";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ZERO_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

const CERTIFICATE_SIGNER = "0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630";

const SECONDS_IN_AN_HOUR = 3600;
const SECONDS_IN_A_DAY = 24*SECONDS_IN_AN_HOUR;

const HOLD_STATUS_NON_EXISTENT = 0;
const HOLD_STATUS_ORDERED = 1;
const HOLD_STATUS_EXECUTED = 2;
const HOLD_STATUS_EXECUTED_AND_KEPT_OPEN = 3;
const HOLD_STATUS_RELEASED_BY_NOTARY = 4;
const HOLD_STATUS_RELEASED_BY_PAYEE = 5;
const HOLD_STATUS_RELEASED_ON_EXPIRATION = 6;

const CERTIFICATE_VALIDATION_NONE = 0;
const CERTIFICATE_VALIDATION_NONCE = 1;
const CERTIFICATE_VALIDATION_SALT = 2;
const CERTIFICATE_VALIDATION_DEFAULT = CERTIFICATE_VALIDATION_SALT;

const Standard = Object.freeze({
  Undefined: 0,
  HoldableERC20: 1,
  HoldableERC1400: 2,
});
const HoldStatusCode = Object.freeze({
  Nonexistent: 0,
  Held: 1,
  Executed: 2,
  Released: 3,
});

contract(
  "Holdable Token",
  ([
    dvpDeployer,
    owner1,
    owner2,
    holder1,
    holder2,
    recipient1,
    recipient2,
    random,
    controller1,
    controller2,
  ]) => {
    const secretHashPair = newSecretHashPair();

    before(async () => {
      this.dvp = await DVPHoldableLockable.new({ from: dvpDeployer });
      this.registry = await ERC1820Registry.at(
        "0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24"
      );
      this.extension = await ERC1400TokensValidator.new({
        from: dvpDeployer,
      });
    });
    describe("Holdable ERC20 Tokens", () => {
      const inOneHour = nowSeconds() + SECONDS_IN_AN_HOUR;
      const inOneDay = nowSeconds() + SECONDS_IN_A_DAY;
      let snapshotId;
      beforeEach(async () => {
        snapshot = await takeSnapshot();
        snapshotId = snapshot["result"];
      });
      afterEach(async () => {
        await revertToSnapshot(snapshotId);
      });
      describe("swap as notary, recipient set on hold, hash lock", () => {
        let token1;
        let token2;
        let token1HoldId;
        let token2HoldId;
        beforeEach(async () => {
          token1 = await HoldableToken.new("ERC20Token", "DAU20", 18, { from: owner1 });
          await token1.mint(holder1, 1000, { from: owner1 });
          const token1Result = await token1.hold(
            recipient1,
            this.dvp.address,
            600,
            inOneHour,
            secretHashPair.hash,
            { from: holder1 }
          );
          token1HoldId = token1Result.receipt.logs[0].args.holdId;

          token2 = await HoldableToken.new("ERC20Token", "DAU20", 18, { from: owner2 });
          await token2.mint(holder2, 2000, { from: owner2 });
          const token2Result = await token2.hold(
            recipient2,
            this.dvp.address,
            1200,
            inOneDay,
            secretHashPair.hash,
            { from: holder2 }
          );
          token2HoldId = token2Result.receipt.logs[0].args.holdId;
        });
        it("Check initial states", async () => {
          assert.equal(
            await token1.holdStatus(token1HoldId),
            HoldStatusCode.Held
          );
          assert.equal(await token1.balanceOf(holder1), 400);
          assert.equal(await token1.holdBalanceOf(holder1), 600);
          assert.equal(await token1.grossBalanceOf(holder1), 1000);
          assert.equal(await token1.totalSupply(), 1000);

          assert.equal(
            await token2.holdStatus(token2HoldId),
            HoldStatusCode.Held
          );
          assert.equal(await token2.balanceOf(holder2), 800);
          assert.equal(await token2.holdBalanceOf(holder2), 1200);
          assert.equal(await token2.grossBalanceOf(holder2), 2000);
          assert.equal(await token2.totalSupply(), 2000);
        });
        it("fail to execute swap with incorrect preimage", async () => {
          const incorrectHashLock = newSecretHashPair();
          try {
            await this.dvp.executeHolds(
              token1.address,
              token1HoldId,
              Standard.HoldableERC20,
              token2.address,
              token2HoldId,
              Standard.HoldableERC20,
              incorrectHashLock.secret,
              { from: holder1 }
            );
            assert(false, "transaction should have failed");
          } catch (err) {
            assert.instanceOf(err, Error);
            assert.match(err.message, /preimage hash does not match lock hash/);
            assert.equal(await token1.balanceOf(holder1), 400);
            assert.equal(await token2.balanceOf(holder2), 800);
          }
        });
        it("fail to execute swap after token 1 has been released by holder", async () => {
          await advanceTime(inOneHour + 1);
          const result = await token1.releaseHold(token1HoldId, {
            from: holder1,
          });
          assert.equal(await token1.balanceOf(holder1), 1000);
          assert.equal(await token2.balanceOf(holder2), 800);
          assert.equal(result.receipt.status, 1);
          try {
            await this.dvp.executeHolds(
              token1.address,
              token1HoldId,
              Standard.HoldableERC20,
              token2.address,
              token2HoldId,
              Standard.HoldableERC20,
              secretHashPair.secret,
              { from: holder1 }
            );
            assert(false, "transaction should have failed");
          } catch (err) {
            assert.instanceOf(err, Error);
            assert.match(err.message, /Hold is not in Held status/);
            assert.equal(await token1.balanceOf(holder1), 1000);
            assert.equal(await token2.balanceOf(holder2), 800);
          }
        });
        it("fail to execute swap after token 2 has been released by holder", async () => {
          await advanceTime(inOneDay + 1);
          const result = await token2.releaseHold(token2HoldId, {
            from: holder2,
          });
          assert.equal(await token1.balanceOf(holder1), 400);
          assert.equal(await token2.balanceOf(holder2), 2000);
          assert.equal(result.receipt.status, 1);
          try {
            await this.dvp.executeHolds(
              token1.address,
              token1HoldId,
              Standard.HoldableERC20,
              token2.address,
              token2HoldId,
              Standard.HoldableERC20,
              secretHashPair.secret,
              { from: holder1 }
            );
            assert(false, "transaction should have failed");
          } catch (err) {
            assert.instanceOf(err, Error);
            assert.match(err.message, /Hold is not in Held status/);
            assert.equal(await token1.balanceOf(holder1), 400);
            assert.equal(await token2.balanceOf(holder2), 2000);
          }
        });
        it("Execute swap before expiration period with preimage", async () => {
          const result = await this.dvp.executeHolds(
            token1.address,
            token1HoldId,
            Standard.HoldableERC20,
            token2.address,
            token2HoldId,
            Standard.HoldableERC20,
            secretHashPair.secret,
            { from: holder1 }
          );
          assert.equal(result.receipt.status, 1);
          assert.equal(
            await token1.holdStatus(token1HoldId),
            HoldStatusCode.Executed
          );
          assert.equal(await token1.balanceOf(holder1), 400);
          assert.equal(await token1.holdBalanceOf(holder1), 0);
          assert.equal(await token1.grossBalanceOf(holder1), 400);
          assert.equal(await token1.balanceOf(recipient1), 600);
          assert.equal(await token1.holdBalanceOf(recipient1), 0);
          assert.equal(await token1.grossBalanceOf(recipient1), 600);
          assert.equal(await token1.totalSupply(), 1000);

          assert.equal(
            await token2.holdStatus(token2HoldId),
            HoldStatusCode.Executed
          );
          assert.equal(await token2.balanceOf(holder2), 800);
          assert.equal(await token2.holdBalanceOf(holder2), 0);
          assert.equal(await token2.grossBalanceOf(holder2), 800);
          assert.equal(await token2.balanceOf(recipient2), 1200);
          assert.equal(await token2.holdBalanceOf(recipient2), 0);
          assert.equal(await token2.grossBalanceOf(recipient2), 1200);
          assert.equal(await token2.totalSupply(), 2000);
        });
        it("Execute swap after expiration period with preimage", async () => {
          await advanceTime(inOneDay + 1);
          const result = await this.dvp.executeHolds(
            token1.address,
            token1HoldId,
            Standard.HoldableERC20,
            token2.address,
            token2HoldId,
            Standard.HoldableERC20,
            secretHashPair.secret,
            { from: holder1 }
          );
          assert.equal(result.receipt.status, 1);
          assert.equal(
            await token1.holdStatus(token1HoldId),
            HoldStatusCode.Executed
          );
          assert.equal(await token1.balanceOf(holder1), 400);
          assert.equal(await token1.holdBalanceOf(holder1), 0);
          assert.equal(await token1.grossBalanceOf(holder1), 400);
          assert.equal(await token1.balanceOf(recipient1), 600);
          assert.equal(await token1.holdBalanceOf(recipient1), 0);
          assert.equal(await token1.grossBalanceOf(recipient1), 600);
          assert.equal(await token1.totalSupply(), 1000);

          assert.equal(
            await token2.holdStatus(token2HoldId),
            HoldStatusCode.Executed
          );
          assert.equal(await token2.balanceOf(holder2), 800);
          assert.equal(await token2.holdBalanceOf(holder2), 0);
          assert.equal(await token2.grossBalanceOf(holder2), 800);
          assert.equal(await token2.balanceOf(recipient2), 1200);
          assert.equal(await token2.holdBalanceOf(recipient2), 0);
          assert.equal(await token2.grossBalanceOf(recipient2), 1200);
          assert.equal(await token2.totalSupply(), 2000);
        });
      });
      describe("swap as notary, recipient set on hold, no hash lock", () => {
        let token1;
        let token2;
        let token1HoldId;
        let token2HoldId;
        beforeEach(async () => {
          token1 = await HoldableToken.new("ERC20Token", "DAU20", 18, { from: owner1 });
          await token1.mint(holder1, 1000, { from: owner1 });
          const token1Result = await token1.hold(
            recipient1,
            this.dvp.address,
            600,
            inOneHour,
            ZERO_BYTES32,
            { from: holder1 }
          );
          token1HoldId = token1Result.receipt.logs[0].args.holdId;
          assert.equal(
            await token1.holdStatus(token1HoldId),
            HoldStatusCode.Held
          );

          token2 = await HoldableToken.new("ERC20Token", "DAU20", 18, { from: owner2 });
          await token2.mint(holder2, 2000, { from: owner2 });
          const token2Result = await token2.hold(
            recipient2,
            this.dvp.address,
            1200,
            inOneDay,
            ZERO_BYTES32,
            { from: holder2 }
          );
          token2HoldId = token2Result.receipt.logs[0].args.holdId;
        });
        it("Execute swap before expiration period with preimage", async () => {
          const result = await this.dvp.executeHolds(
            token1.address,
            token1HoldId,
            Standard.HoldableERC20,
            token2.address,
            token2HoldId,
            Standard.HoldableERC20,
            ZERO_BYTES32,
            { from: holder1 }
          );
          assert.equal(result.receipt.status, 1);
          assert.equal(
            await token1.holdStatus(token1HoldId),
            HoldStatusCode.Executed
          );
          assert.equal(await token1.balanceOf(holder1), 400);
          assert.equal(await token1.holdBalanceOf(holder1), 0);
          assert.equal(await token1.grossBalanceOf(holder1), 400);
          assert.equal(await token1.balanceOf(recipient1), 600);
          assert.equal(await token1.holdBalanceOf(recipient1), 0);
          assert.equal(await token1.grossBalanceOf(recipient1), 600);
          assert.equal(await token1.totalSupply(), 1000);

          assert.equal(
            await token2.holdStatus(token2HoldId),
            HoldStatusCode.Executed
          );
          assert.equal(await token2.balanceOf(holder2), 800);
          assert.equal(await token2.holdBalanceOf(holder2), 0);
          assert.equal(await token2.grossBalanceOf(holder2), 800);
          assert.equal(await token2.balanceOf(recipient2), 1200);
          assert.equal(await token2.holdBalanceOf(recipient2), 0);
          assert.equal(await token2.grossBalanceOf(recipient2), 1200);
          assert.equal(await token2.totalSupply(), 2000);
        });
        it("Execute swap after expiration period with preimage", async () => {
          await advanceTime(inOneDay + 1);
          const result = await this.dvp.executeHolds(
            token1.address,
            token1HoldId,
            Standard.HoldableERC20,
            token2.address,
            token2HoldId,
            Standard.HoldableERC20,
            ZERO_BYTES32,
            { from: holder1 }
          );
          assert.equal(result.receipt.status, 1);
          assert.equal(
            await token1.holdStatus(token1HoldId),
            HoldStatusCode.Executed
          );
          assert.equal(await token1.balanceOf(holder1), 400);
          assert.equal(await token1.holdBalanceOf(holder1), 0);
          assert.equal(await token1.grossBalanceOf(holder1), 400);
          assert.equal(await token1.balanceOf(recipient1), 600);
          assert.equal(await token1.holdBalanceOf(recipient1), 0);
          assert.equal(await token1.grossBalanceOf(recipient1), 600);
          assert.equal(await token1.totalSupply(), 1000);

          assert.equal(
            await token2.holdStatus(token2HoldId),
            HoldStatusCode.Executed
          );
          assert.equal(await token2.balanceOf(holder2), 800);
          assert.equal(await token2.holdBalanceOf(holder2), 0);
          assert.equal(await token2.grossBalanceOf(holder2), 800);
          assert.equal(await token2.balanceOf(recipient2), 1200);
          assert.equal(await token2.holdBalanceOf(recipient2), 0);
          assert.equal(await token2.grossBalanceOf(recipient2), 1200);
          assert.equal(await token2.totalSupply(), 2000);
        });
      });
      describe("swap as notary, no recipient set on hold, no hash lock and swap failed to executed after expiration and release ", () => {
        let token1;
        let token2;
        let token1HoldId;
        let token2HoldId;
        beforeEach(async () => {
          token1 = await HoldableToken.new("ERC20Token", "DAU20", 18, { from: owner1 });
          await token1.mint(holder1, 1000, { from: owner1 });
          const token1Result = await token1.hold(
            ZERO_ADDRESS,
            this.dvp.address,
            600,
            inOneHour,
            ZERO_BYTES32,
            { from: holder1 }
          );
          token1HoldId = token1Result.receipt.logs[0].args.holdId;
          assert.equal(
            await token1.holdStatus(token1HoldId),
            HoldStatusCode.Held
          );

          token2 = await HoldableToken.new("ERC20Token", "DAU20", 18, { from: owner2 });
          await token2.mint(holder2, 2000, { from: owner2 });
          const token2Result = await token2.hold(
            ZERO_ADDRESS,
            this.dvp.address,
            1200,
            inOneDay,
            ZERO_BYTES32,
            { from: holder2 }
          );
          token2HoldId = token2Result.receipt.logs[0].args.holdId;
          assert.equal(
            await token2.holdStatus(token2HoldId),
            HoldStatusCode.Held
          );
        });
        it("Execute swap before expiration period with preimage", async () => {
          const result = await this.dvp.methods[
            "executeHolds(address,bytes32,uint8,address,bytes32,uint8,bytes32,address,address)"
          ](
            token1.address,
            token1HoldId,
            Standard.HoldableERC20,
            token2.address,
            token2HoldId,
            Standard.HoldableERC20,
            ZERO_BYTES32,
            recipient1,
            recipient2,
            { from: random }
          );
          assert.equal(result.receipt.status, 1);
          assert.equal(
            await token1.holdStatus(token1HoldId),
            HoldStatusCode.Executed
          );
          assert.equal(await token1.balanceOf(holder1), 400);
          assert.equal(await token1.holdBalanceOf(holder1), 0);
          assert.equal(await token1.grossBalanceOf(holder1), 400);
          assert.equal(await token1.balanceOf(recipient1), 600);
          assert.equal(await token1.holdBalanceOf(recipient1), 0);
          assert.equal(await token1.grossBalanceOf(recipient1), 600);
          assert.equal(await token1.totalSupply(), 1000);

          assert.equal(
            await token2.holdStatus(token2HoldId),
            HoldStatusCode.Executed
          );
          assert.equal(await token2.balanceOf(holder2), 800);
          assert.equal(await token2.holdBalanceOf(holder2), 0);
          assert.equal(await token2.grossBalanceOf(holder2), 800);
          assert.equal(await token2.balanceOf(recipient2), 1200);
          assert.equal(await token2.holdBalanceOf(recipient2), 0);
          assert.equal(await token2.grossBalanceOf(recipient2), 1200);
          assert.equal(await token2.totalSupply(), 2000);
        });
        it("Execute swap after expiration period with preimage", async () => {
          await advanceTime(inOneDay + 1);
          const result = await this.dvp.methods[
            "executeHolds(address,bytes32,uint8,address,bytes32,uint8,bytes32,address,address)"
          ](
            token1.address,
            token1HoldId,
            Standard.HoldableERC20,
            token2.address,
            token2HoldId,
            Standard.HoldableERC20,
            ZERO_BYTES32,
            recipient1,
            recipient2,
            { from: random }
          );
          assert.equal(result.receipt.status, 1);
          assert.equal(
            await token1.holdStatus(token1HoldId),
            HoldStatusCode.Executed
          );
          assert.equal(await token1.balanceOf(holder1), 400);
          assert.equal(await token1.holdBalanceOf(holder1), 0);
          assert.equal(await token1.grossBalanceOf(holder1), 400);
          assert.equal(await token1.balanceOf(recipient1), 600);
          assert.equal(await token1.holdBalanceOf(recipient1), 0);
          assert.equal(await token1.grossBalanceOf(recipient1), 600);
          assert.equal(await token1.totalSupply(), 1000);

          assert.equal(
            await token2.holdStatus(token2HoldId),
            HoldStatusCode.Executed
          );
          assert.equal(await token2.balanceOf(holder2), 800);
          assert.equal(await token2.holdBalanceOf(holder2), 0);
          assert.equal(await token2.grossBalanceOf(holder2), 800);
          assert.equal(await token2.balanceOf(recipient2), 1200);
          assert.equal(await token2.holdBalanceOf(recipient2), 0);
          assert.equal(await token2.grossBalanceOf(recipient2), 1200);
          assert.equal(await token2.totalSupply(), 2000);
        });
      });
    });
    
    describe("Holdable ERC1400 Tokens", () => {
      const inOneHour = nowSeconds() + SECONDS_IN_AN_HOUR;

      describe("swap as secret holder, recipient set on hold, hash lock", () => {
        beforeEach(async () => {
          this.token1 = await ERC1400HoldableCertificate.new(
            "ERC1400Token",
            "DAU",
            1,
            [controller1],
            partitions,
            this.extension.address,
            owner1,
            CERTIFICATE_SIGNER,
            CERTIFICATE_VALIDATION_NONE,
            { from: controller1 }
          );
          await this.extension.addAllowlisted(this.token1.address, holder1, { from: controller1 });
          await this.extension.addAllowlisted(this.token1.address, recipient1, { from: controller1 });
          await this.token1.issueByPartition(
            partition1,
            holder1,
            1000,
            EMPTY_CERTIFICATE,
            { from: controller1 }
          );
          this.token1HoldId = newHoldId();
          await this.extension.holdFrom(
            this.token1.address,
            this.token1HoldId,
            holder1,
            recipient1,
             /*this.dvp.address*/ owner1,
             partition1, 600,
             SECONDS_IN_AN_HOUR,
             secretHashPair.hash,
             EMPTY_CERTIFICATE,
             { from: controller1 }
          )
  
          this.token2 = await ERC1400HoldableCertificate.new(
            "ERC1400Token",
            "DAU",
            1,
            [controller2],
            partitions,
            this.extension.address,
            owner2,
            CERTIFICATE_SIGNER,
            CERTIFICATE_VALIDATION_NONE,
            { from: controller2 }
          );
          await this.extension.addAllowlisted(this.token2.address, holder2, { from: controller2 });
          await this.extension.addAllowlisted(this.token2.address, recipient2, { from: controller2 });

          await this.token2.issueByPartition(
            partition2,
            holder2,
            2000,
            EMPTY_CERTIFICATE,
            { from: controller2 }
          );
          this.token2HoldId = newHoldId();
          await this.extension.holdFrom(
            this.token2.address,
            this.token2HoldId,
            holder2,
            recipient2,
            /*this.dvp.address*/ owner2,
            partition2,
            1200,
            SECONDS_IN_AN_HOUR,
            secretHashPair.hash,
            EMPTY_CERTIFICATE,
            { from: controller2 }
          )
        });
  
        it("Check initial states", async () => {
          assert.equal(await this.token1.balanceOfByPartition(partition1, holder1), 1000)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token1.address, partition1, holder1), 600)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token1.address, partition1, holder1), 400)
  
          this.holdData1 = await this.extension.retrieveHoldData(this.token1.address, this.token1HoldId);
          assert.equal(parseInt(this.holdData1[8]), HOLD_STATUS_ORDERED);
  
          assert.equal(await this.token2.balanceOfByPartition(partition2, holder2), 2000)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token2.address, partition2, holder2), 1200)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token2.address, partition2, holder2), 800)
  
          this.holdData2 = await this.extension.retrieveHoldData(this.token2.address, this.token2HoldId);
          assert.equal(parseInt(this.holdData2[8]), HOLD_STATUS_ORDERED);
        });
  
        it("fail to execute swap with incorrect preimage", async () => {
          const incorrectHashLock = newSecretHashPair();
          try {
            await this.dvp.executeHolds(
              this.token1.address,
              this.token1HoldId,
              Standard.HoldableERC1400,
              this.token2.address,
              this.token2HoldId,
              Standard.HoldableERC1400,
              incorrectHashLock.secret,
              { from: holder1 }
            );
            assert(false, "transaction should have failed");
          } catch (err) {
            assert.instanceOf(err, Error);
            assert.match(err.message, /hold can not be executed/);
  
            assert.equal(await this.token1.balanceOfByPartition(partition1, holder1), 1000)
            this.holdData1 = await this.extension.retrieveHoldData(this.token1.address, this.token1HoldId);
            assert.equal(parseInt(this.holdData1[8]), HOLD_STATUS_ORDERED);
  
            assert.equal(await this.token2.balanceOfByPartition(partition2, holder2), 2000)
            this.holdData2 = await this.extension.retrieveHoldData(this.token2.address, this.token2HoldId);
            assert.equal(parseInt(this.holdData2[8]), HOLD_STATUS_ORDERED);
          }
        });
  
        it("fail to execute swap after token 1 has been released by holder", async () => {
          await advanceTime(inOneHour + 1);
          const result = await this.extension.releaseHold(this.token1.address, this.token1HoldId, {
            from: holder1,
          });
          assert.equal(await this.token1.balanceOfByPartition(partition1, holder1), 1000)
          this.holdData1 = await this.extension.retrieveHoldData(this.token1.address, this.token1HoldId);
          assert.equal(parseInt(this.holdData1[8]), HOLD_STATUS_RELEASED_ON_EXPIRATION);
  
          assert.equal(await this.token2.balanceOfByPartition(partition2, holder2), 2000)
          this.holdData2 = await this.extension.retrieveHoldData(this.token2.address, this.token2HoldId);
          assert.equal(parseInt(this.holdData2[8]), HOLD_STATUS_ORDERED);
  
          assert.equal(result.receipt.status, 1);
          try {
            await this.dvp.executeHolds(
              this.token1.address,
              this.token1HoldId,
              Standard.HoldableERC1400,
              this.token2.address,
              this.token2HoldId,
              Standard.HoldableERC1400,
              secretHashPair.secret,
              { from: holder1 }
            );
            assert(false, "transaction should have failed");
          } catch (err) {
            assert.instanceOf(err, Error);
            assert.match(err.message, /hold can not be executed/);
  
            assert.equal(await this.token1.balanceOfByPartition(partition1, holder1), 1000)
            this.holdData1 = await this.extension.retrieveHoldData(this.token1.address, this.token1HoldId);
            assert.equal(parseInt(this.holdData1[8]), HOLD_STATUS_RELEASED_ON_EXPIRATION);
    
            assert.equal(await this.token2.balanceOfByPartition(partition2, holder2), 2000)
            this.holdData2 = await this.extension.retrieveHoldData(this.token2.address, this.token2HoldId);
            assert.equal(parseInt(this.holdData2[8]), HOLD_STATUS_ORDERED);
          }
        });
  
        it("Execute swap before expiration period with preimage", async () => {
          const result = await this.dvp.executeHolds(
            this.token1.address,
            this.token1HoldId,
            Standard.HoldableERC1400,
            this.token2.address,
            this.token2HoldId,
            Standard.HoldableERC1400,
            secretHashPair.secret,
            { from: holder1 }
          );
          assert.equal(result.receipt.status, 1);
          
          assert.equal(await this.token1.balanceOfByPartition(partition1, holder1), 400)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token1.address, partition1, holder1), 0)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token1.address, partition1, holder1), 400)
          assert.equal(await this.token1.balanceOfByPartition(partition1, recipient1), 600)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token1.address, partition1, recipient1), 0)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token1.address, partition1, recipient1), 600)
  
          this.holdData1 = await this.extension.retrieveHoldData(this.token1.address, this.token1HoldId);
          assert.equal(parseInt(this.holdData1[8]), HOLD_STATUS_EXECUTED);
  
          assert.equal(await this.token2.balanceOfByPartition(partition2, holder2), 800)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token2.address, partition2, holder2), 0)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token2.address, partition2, holder2), 800)
          assert.equal(await this.token2.balanceOfByPartition(partition2, recipient2), 1200)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token2.address, partition2, recipient2), 0)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token2.address, partition2, recipient2), 1200)
  
          this.holdData2 = await this.extension.retrieveHoldData(this.token2.address, this.token2HoldId);
          assert.equal(parseInt(this.holdData2[8]), HOLD_STATUS_EXECUTED);
        });

      });
      
      describe("swap as notary, recipient set on hold, hash lock", () => {
        beforeEach(async () => {
          this.token1 = await ERC1400HoldableCertificate.new(
            "ERC1400Token",
            "DAU",
            1,
            [controller1],
            partitions,
            this.extension.address,
            owner1,
            CERTIFICATE_SIGNER,
            CERTIFICATE_VALIDATION_NONE,
            { from: controller1 }
          );
          await this.extension.addAllowlisted(this.token1.address, holder1, { from: controller1 });
          await this.extension.addAllowlisted(this.token1.address, recipient1, { from: controller1 });

          await this.token1.issueByPartition(
            partition1,
            holder1,
            1000,
            EMPTY_CERTIFICATE,
            { from: controller1 }
          );
          this.token1HoldId = newHoldId();
          await this.extension.holdFrom(
            this.token1.address,
            this.token1HoldId,
            holder1,
            recipient1,
            this.dvp.address,
            partition1,
            600,
            SECONDS_IN_AN_HOUR,
            ZERO_BYTES32,
            EMPTY_CERTIFICATE,
            { from: controller1 }
          )
  
          this.token2 = await ERC1400HoldableCertificate.new(
            "ERC1400Token",
            "DAU",
            1,
            [controller2],
            partitions,
            this.extension.address,
            owner2,
            CERTIFICATE_SIGNER,
            CERTIFICATE_VALIDATION_NONE,
            { from: controller2 }
          );
          await this.extension.addAllowlisted(this.token2.address, holder2, { from: controller2 });
          await this.extension.addAllowlisted(this.token2.address, recipient2, { from: controller2 });

          await this.token2.issueByPartition(
            partition2,
            holder2,
            2000,
            EMPTY_CERTIFICATE,
            { from: controller2 }
          );
          this.token2HoldId = newHoldId();
          await this.extension.holdFrom(
            this.token2.address,
            this.token2HoldId,
            holder2,
            recipient2,
            this.dvp.address,
            partition2,
            1200,
            SECONDS_IN_AN_HOUR,
            ZERO_BYTES32,
            EMPTY_CERTIFICATE,
            { from: controller2 }
          )
        });
  
        it("Check initial states", async () => {
          assert.equal(await this.token1.balanceOfByPartition(partition1, holder1), 1000)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token1.address, partition1, holder1), 600)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token1.address, partition1, holder1), 400)
  
          this.holdData1 = await this.extension.retrieveHoldData(this.token1.address, this.token1HoldId);
          assert.equal(parseInt(this.holdData1[8]), HOLD_STATUS_ORDERED);
  
          assert.equal(await this.token2.balanceOfByPartition(partition2, holder2), 2000)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token2.address, partition2, holder2), 1200)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token2.address, partition2, holder2), 800)
  
          this.holdData2 = await this.extension.retrieveHoldData(this.token2.address, this.token2HoldId);
          assert.equal(parseInt(this.holdData2[8]), HOLD_STATUS_ORDERED);
        });

        it("Execute swap before expiration period without preimage", async () => {
          const result = await this.dvp.executeHolds(
            this.token1.address,
            this.token1HoldId,
            Standard.HoldableERC1400,
            this.token2.address,
            this.token2HoldId,
            Standard.HoldableERC1400,
            ZERO_BYTES32,
            { from: holder1 }
          );
          assert.equal(result.receipt.status, 1);
          
          assert.equal(await this.token1.balanceOfByPartition(partition1, holder1), 400)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token1.address, partition1, holder1), 0)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token1.address, partition1, holder1), 400)
          assert.equal(await this.token1.balanceOfByPartition(partition1, recipient1), 600)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token1.address, partition1, recipient1), 0)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token1.address, partition1, recipient1), 600)
  
          this.holdData1 = await this.extension.retrieveHoldData(this.token1.address, this.token1HoldId);
          assert.equal(parseInt(this.holdData1[8]), HOLD_STATUS_EXECUTED);
  
          assert.equal(await this.token2.balanceOfByPartition(partition2, holder2), 800)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token2.address, partition2, holder2), 0)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token2.address, partition2, holder2), 800)
          assert.equal(await this.token2.balanceOfByPartition(partition2, recipient2), 1200)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token2.address, partition2, recipient2), 0)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token2.address, partition2, recipient2), 1200)
  
          this.holdData2 = await this.extension.retrieveHoldData(this.token2.address, this.token2HoldId);
          assert.equal(parseInt(this.holdData2[8]), HOLD_STATUS_EXECUTED);
        });
      });

    });
  
    describe("Holdable ERC20 and ERC1400 Tokens", () => {
      const inOneDay = nowSeconds() + SECONDS_IN_A_DAY;
      beforeEach(async () => {
        this.token1 = await ERC1400HoldableCertificate.new(
          "ERC1400Token",
          "DAU",
          1,
          [controller1],
          partitions,
          this.extension.address,
          owner1,
          CERTIFICATE_SIGNER,
          CERTIFICATE_VALIDATION_NONE,
          { from: controller1 }
        );
        await this.extension.addAllowlisted(this.token1.address, holder1, { from: controller1 });
        await this.extension.addAllowlisted(this.token1.address, recipient1, { from: controller1 });

        await this.token1.issueByPartition(
          partition1,
          holder1,
          1000,
          EMPTY_CERTIFICATE,
          { from: controller1 }
        );
        this.token1HoldId = newHoldId();
        await this.extension.holdFrom(
          this.token1.address,
          this.token1HoldId,
          holder1,
          recipient1,
          /*this.dvp.address*/ owner1,
          partition1,
          600,
          SECONDS_IN_AN_HOUR,
          secretHashPair.hash,
          EMPTY_CERTIFICATE,
          { from: controller1 }
        )

        this.token2 = await HoldableToken.new("ERC20Token", "DAU20", 18, { from: owner2 });
          await this.token2.mint(holder2, 2000, { from: owner2 });
          const token2Result = await this.token2.hold(
            recipient2,
            this.dvp.address,
            1200,
            inOneDay,
            secretHashPair.hash,
            { from: holder2 }
          );
          this.token2HoldId = token2Result.receipt.logs[0].args.holdId;
      });

      it("Check initial states", async () => {
        assert.equal(await this.token1.balanceOfByPartition(partition1, holder1), 1000)
        assert.equal(await this.extension.balanceOnHoldByPartition(this.token1.address, partition1, holder1), 600)
        assert.equal(await this.extension.spendableBalanceOfByPartition(this.token1.address, partition1, holder1), 400)

        this.holdData1 = await this.extension.retrieveHoldData(this.token1.address, this.token1HoldId);
        assert.equal(parseInt(this.holdData1[8]), HOLD_STATUS_ORDERED);

        assert.equal(
          await this.token2.holdStatus(this.token2HoldId),
          HoldStatusCode.Held
        );
        assert.equal(await this.token2.balanceOf(holder2), 800);
        assert.equal(await this.token2.holdBalanceOf(holder2), 1200);
        assert.equal(await this.token2.grossBalanceOf(holder2), 2000);
        assert.equal(await this.token2.totalSupply(), 2000);
      });

      it("Execute swap before expiration period with preimage", async () => {
        const result = await this.dvp.executeHolds(
          this.token1.address,
          this.token1HoldId,
          Standard.HoldableERC1400,
          this.token2.address,
          this.token2HoldId,
          Standard.HoldableERC20,
          secretHashPair.secret,
          { from: holder1 }
        );
        assert.equal(result.receipt.status, 1);
        
        assert.equal(await this.token1.balanceOfByPartition(partition1, holder1), 400)
        assert.equal(await this.extension.balanceOnHoldByPartition(this.token1.address, partition1, holder1), 0)
        assert.equal(await this.extension.spendableBalanceOfByPartition(this.token1.address, partition1, holder1), 400)
        assert.equal(await this.token1.balanceOfByPartition(partition1, recipient1), 600)
        assert.equal(await this.extension.balanceOnHoldByPartition(this.token1.address, partition1, recipient1), 0)
        assert.equal(await this.extension.spendableBalanceOfByPartition(this.token1.address, partition1, recipient1), 600)

        this.holdData1 = await this.extension.retrieveHoldData(this.token1.address, this.token1HoldId);
        assert.equal(parseInt(this.holdData1[8]), HOLD_STATUS_EXECUTED);

        assert.equal(
          await this.token2.holdStatus(this.token2HoldId),
          HoldStatusCode.Executed
        );
        assert.equal(await this.token2.balanceOf(holder2), 800);
        assert.equal(await this.token2.holdBalanceOf(holder2), 0);
        assert.equal(await this.token2.grossBalanceOf(holder2), 800);
        assert.equal(await this.token2.balanceOf(recipient2), 1200);
        assert.equal(await this.token2.holdBalanceOf(recipient2), 0);
        assert.equal(await this.token2.grossBalanceOf(recipient2), 1200);
        assert.equal(await this.token2.totalSupply(), 2000);
      });

      it("fail to execute swap with incorrect token standard for the first token", async () => {
        try {
          await this.dvp.executeHolds(
            this.token1.address,
            this.token1HoldId,
            Standard.Undefined,
            this.token2.address,
            this.token2HoldId,
            Standard.HoldableERC20,
            secretHashPair.secret,
            { from: holder1 }
          );
          assert(false, "transaction should have failed");
        } catch (err) {
          assert.instanceOf(err, Error);
          assert.match(err.message, /invalid token standard/);
          assert.equal(await this.token1.balanceOfByPartition(partition1, holder1), 1000)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token1.address, partition1, holder1), 600)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token1.address, partition1, holder1), 400)
          assert.equal(await this.token2.balanceOf(holder2), 800)
          assert.equal(await this.token2.holdBalanceOf(holder2), 1200)
          assert.equal(await this.token2.grossBalanceOf(holder2), 2000)
        }
      });

      it("fail to execute swap with incorrect token standard for the second token", async () => {
        try {
          await this.dvp.executeHolds(
            this.token1.address,
            this.token1HoldId,
            Standard.HoldableERC1400,
            this.token2.address,
            this.token2HoldId,
            Standard.Undefined,
            secretHashPair.secret,
            { from: holder1 }
          );
          assert(false, "transaction should have failed");
        } catch (err) {
          assert.instanceOf(err, Error);
          assert.match(err.message, /invalid token standard/);
          assert.equal(await this.token1.balanceOfByPartition(partition1, holder1), 1000)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token1.address, partition1, holder1), 600)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token1.address, partition1, holder1), 400)
          assert.equal(await this.token2.balanceOf(holder2), 800)
          assert.equal(await this.token2.holdBalanceOf(holder2), 1200)
          assert.equal(await this.token2.grossBalanceOf(holder2), 2000)
        }
      });

      it("fail to execute swap with incorrect token address for the first token", async () => {
        try {
          await this.dvp.executeHolds(
            ZERO_ADDRESS,
            this.token1HoldId,
            Standard.HoldableERC1400,
            this.token2.address,
            this.token2HoldId,
            Standard.HoldableERC20,
            secretHashPair.secret,
            { from: holder1 }
          );
          assert(false, "transaction should have failed");
        } catch (err) {
          assert.instanceOf(err, Error);
          assert.match(err.message, /token can not be a zero address/);
          assert.equal(await this.token1.balanceOfByPartition(partition1, holder1), 1000)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token1.address, partition1, holder1), 600)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token1.address, partition1, holder1), 400)
          assert.equal(await this.token2.balanceOf(holder2), 800)
          assert.equal(await this.token2.holdBalanceOf(holder2), 1200)
          assert.equal(await this.token2.grossBalanceOf(holder2), 2000)
        }
      });

      it("fail to execute swap with incorrect token address for the second token", async () => {
        try {
          await this.dvp.executeHolds(
            this.token1.address,
            this.token1HoldId,
            Standard.HoldableERC1400,
            ZERO_ADDRESS,
            this.token2HoldId,
            Standard.HoldableERC20,
            secretHashPair.secret,
            { from: holder1 }
          );
          assert(false, "transaction should have failed");
        } catch (err) {
          assert.instanceOf(err, Error);
          assert.match(err.message, /token can not be a zero address/);
          assert.equal(await this.token1.balanceOfByPartition(partition1, holder1), 1000)
          assert.equal(await this.extension.balanceOnHoldByPartition(this.token1.address, partition1, holder1), 600)
          assert.equal(await this.extension.spendableBalanceOfByPartition(this.token1.address, partition1, holder1), 400)
          assert.equal(await this.token2.balanceOf(holder2), 800)
          assert.equal(await this.token2.holdBalanceOf(holder2), 1200)
          assert.equal(await this.token2.grossBalanceOf(holder2), 2000)
        }
      });

      it("fail to execute swap with non-holdable token address for the first token", async () => {
        try {
          this.token1withoutHold = await ERC1400HoldableCertificate.new(
            "ERC1400Token",
            "DAU",
            1,
            [controller1],
            partitions,
            ZERO_ADDRESS,
            owner1,
            CERTIFICATE_SIGNER,
            CERTIFICATE_VALIDATION_NONE,
            { from: controller1 }
          );

          await this.token1withoutHold.issueByPartition(
            partition1,
            holder1,
            1000,
            EMPTY_CERTIFICATE,
            { from: controller1 }
          );
          this.token1HoldId = newHoldId();
          await this.dvp.executeHolds(
            this.token1withoutHold.address,
            this.token1HoldId,
            Standard.HoldableERC1400,
            this.token2.address,
            this.token2HoldId,
            Standard.HoldableERC20,
            secretHashPair.secret,
            { from: holder1 }
          );
          assert(false, "transaction should have failed");
        } catch (err) {
          assert.instanceOf(err, Error);
          assert.match(err.message, /token has no holdable token extension/);
          assert.equal(await this.token1withoutHold.balanceOfByPartition(partition1, holder1), 1000)
          assert.equal(await this.token2.balanceOf(holder2), 800)
          assert.equal(await this.token2.holdBalanceOf(holder2), 1200)
          assert.equal(await this.token2.grossBalanceOf(holder2), 2000)
        }
      });

    });
  }
);
