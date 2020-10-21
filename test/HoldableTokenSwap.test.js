const { assert } = require("chai");
const {
  nowSeconds,
  advanceTime,
  takeSnapshot,
  revertToSnapshot,
} = require("./utils/time");
const { newSecretHashPair } = require("./utils/crypto");
const { bytes32 } = require("./utils/regex");

const HoldableToken = artifacts.require("ERC20HoldableToken");
const SwapHoldableToken = artifacts.require("SwapHoldableToken");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ZERO_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

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
    swapDeployer,
    deployer,
    deployer2,
    holder1,
    holder2,
    recipient1,
    recipient2,
    random,
  ]) => {
    before(async () => {
      this.swap = await SwapHoldableToken.new({ from: swapDeployer });
    });
    describe("Holdable ERC20 Tokens", () => {
      const inOneHour = nowSeconds() + 60 * 60;
      const inOneDay = nowSeconds() + 60 * 60 * 24;
      let snapshotId;
      beforeEach(async () => {
        snapshot = await takeSnapshot();
        snapshotId = snapshot["result"];
      });
      afterEach(async () => {
        await revertToSnapshot(snapshotId);
      });
      describe("swap as notary, recipient set on hold, hash lock", () => {
        const hashLock = newSecretHashPair();
        let token1;
        let token2;
        let token1HoldId;
        let token2HoldId;
        beforeEach(async () => {
          token1 = await HoldableToken.new({ from: deployer });
          await token1.mint(holder1, 1000, { from: deployer });
          const token1Result = await token1.hold(
            recipient1,
            this.swap.address,
            600,
            inOneHour,
            hashLock.hash,
            { from: holder1 }
          );
          token1HoldId = token1Result.receipt.logs[0].args.holdId;

          token2 = await HoldableToken.new({ from: deployer2 });
          await token2.mint(holder2, 2000, { from: deployer2 });
          const token2Result = await token2.hold(
            recipient2,
            this.swap.address,
            1200,
            inOneDay,
            hashLock.hash,
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
            await this.swap.executeHolds(
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
            await this.swap.executeHolds(
              token1.address,
              token1HoldId,
              Standard.HoldableERC20,
              token2.address,
              token2HoldId,
              Standard.HoldableERC20,
              hashLock.secret,
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
            await this.swap.executeHolds(
              token1.address,
              token1HoldId,
              Standard.HoldableERC20,
              token2.address,
              token2HoldId,
              Standard.HoldableERC20,
              hashLock.secret,
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
          const result = await this.swap.executeHolds(
            token1.address,
            token1HoldId,
            Standard.HoldableERC20,
            token2.address,
            token2HoldId,
            Standard.HoldableERC20,
            hashLock.secret,
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
          const result = await this.swap.executeHolds(
            token1.address,
            token1HoldId,
            Standard.HoldableERC20,
            token2.address,
            token2HoldId,
            Standard.HoldableERC20,
            hashLock.secret,
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
          token1 = await HoldableToken.new({ from: deployer });
          await token1.mint(holder1, 1000, { from: deployer });
          const token1Result = await token1.hold(
            recipient1,
            this.swap.address,
            600,
            inOneHour,
            ZERO_ADDRESS,
            { from: holder1 }
          );
          token1HoldId = token1Result.receipt.logs[0].args.holdId;
          assert.equal(
            await token1.holdStatus(token1HoldId),
            HoldStatusCode.Held
          );

          token2 = await HoldableToken.new({ from: deployer2 });
          await token2.mint(holder2, 2000, { from: deployer2 });
          const token2Result = await token2.hold(
            recipient2,
            this.swap.address,
            1200,
            inOneDay,
            ZERO_ADDRESS,
            { from: holder2 }
          );
          token2HoldId = token2Result.receipt.logs[0].args.holdId;
        });
        it("Execute swap before expiration period with preimage", async () => {
          const result = await this.swap.executeHolds(
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
          const result = await this.swap.executeHolds(
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
          token1 = await HoldableToken.new({ from: deployer });
          await token1.mint(holder1, 1000, { from: deployer });
          const token1Result = await token1.hold(
            ZERO_ADDRESS,
            this.swap.address,
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

          token2 = await HoldableToken.new({ from: deployer2 });
          await token2.mint(holder2, 2000, { from: deployer2 });
          const token2Result = await token2.hold(
            ZERO_ADDRESS,
            this.swap.address,
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
          const result = await this.swap.methods[
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
          const result = await this.swap.methods[
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
    describe("Holdable ERC1400 Tokens", () => {});
    describe("Holdable ERC20 and ERC1400 Tokens", () => {});
  }
);
