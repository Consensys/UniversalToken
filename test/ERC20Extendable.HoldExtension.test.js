const { assert } = require("chai");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const {
  nowSeconds,
  advanceTime,
  takeSnapshot,
  revertToSnapshot,
} = require("./utils/time");
const { newSecretHashPair } = require("./utils/crypto");
const { bytes32 } = require("./utils/regex");
const { expectRevert } = require("@openzeppelin/test-helpers");

const HoldExtension = artifacts.require("HoldExtension");
const ERC20Extendable = artifacts.require("ERC20Extendable");
const ERC20Logic = artifacts.require("ERC20Logic");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ZERO_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const HoldStatusCode = Object.freeze({
  Nonexistent: 0,
  Held: 1,
  Executed: 2,
  ExecutedAndKeptOpen: 3,
  Released: 4,
  ReleasedByPayee: 5,
  ReleasedOnExpiration: 6
});

const initialSupply = 0;
const maxSupply = web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1));

contract(
  "Holdable Token",
  ([deployer, sender, holder, recipient, recipient2, notary]) => {
    describe("Hold and execute by notary before expiration", () => {
      const hashLock = newSecretHashPair();
      const inOneHour = nowSeconds() + 60 * 60;
      let holdId;
      let snapshotId;
      before(async () => {
        snapshot = await takeSnapshot();
        snapshotId = snapshot["result"];
        this.logic = await ERC20Logic.new();
        this.token = await ERC20Extendable.new(
          "ERC20Extendable",
          "DAU20",
          true,
          true,
          deployer,
          initialSupply,
          maxSupply,
          this.logic.address,
          { from: deployer }
        );
        this.holdExtensionContract = await HoldExtension.new();
        this.holdExtension = this.holdExtensionContract.address;
        
        assert.equal((await this.token.allExtensionsRegistered()).length, 0);

        const result = await this.token.registerExtension(this.holdExtension, { from: deployer });
        assert.equal(result.receipt.status, 1);
 
        assert.equal((await this.token.allExtensionsRegistered()).length, 1);

        this.holdExtensionBind = await HoldExtension.at(this.token.address);
        
        //combine both objects 
        this.token = Object.assign(this.token, this.holdExtensionBind);
      });
      after(async () => {
        await revertToSnapshot(snapshotId);
      });
      it("Mint 1000 tokens to holder", async () => {
        assert.equal(await this.token.totalSupply(), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 0);
        const result = await this.token.mint(holder, 1000, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(deployer), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 1000);
        assert.equal(await this.token.spendableBalanceOf(sender), 0);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.spendableBalanceOf(recipient2), 0);
        assert.equal(await this.token.spendableBalanceOf(notary), 0);
        assert.equal(await this.token.totalSupply(), 1000);
      });
      it("Failed hold from notary with zero address", async () => {
        await expectRevert.unspecified(
          this.token.hold(
            web3.utils.randomHex(32),
            recipient2,
            ZERO_ADDRESS,
            900,
            inOneHour,
            hashLock.hash,
            { from: holder }
          ),
        );
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
      });
      it("Failed hold from a zero amount", async () => {
        await expectRevert.unspecified(
          this.token.hold(
            web3.utils.randomHex(32),
            recipient2,
            notary,
            0,
            inOneHour,
            hashLock.hash,
            { from: holder }
          )
        );
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
      });
      it("Recipient can not hold as they have no tokens", async () => {
        await expectRevert.unspecified(
          this.token.hold(
            web3.utils.randomHex(32),
            recipient2,
            notary,
            900,
            inOneHour,
            hashLock.hash,
            { from: recipient }
          )
        );
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
      });
      it("Holder can not hold more than what they own", async () => {
        await expectRevert.unspecified(
          this.token.hold(
            web3.utils.randomHex(32),
            recipient,
            notary,
            1001,
            inOneHour,
            hashLock.hash,
            { from: holder }
          )
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 1000);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 1000);
      });
      it("Holder holds 900 tokens for the recipient with a lock hash", async () => {
        holdId = web3.utils.randomHex(32);
        const result = await this.token.hold(
          holdId,
          recipient,
          notary,
          900,
          inOneHour,
          hashLock.hash,
          { from: holder }
        );
        assert.equal(result.receipt.status, 1);
        assert.lengthOf(result.receipt.logs, 1);
        assert.match(holdId, bytes32);
        assert.equal(await this.token.holdStatus(holdId), HoldStatusCode.Held);
        assert.equal(await this.token.spendableBalanceOf(deployer), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 100);
        assert.equal(await this.token.spendableBalanceOf(sender), 0);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.spendableBalanceOf(recipient2), 0);
        assert.equal(await this.token.spendableBalanceOf(notary), 0);

        assert.equal(await this.token.balanceOnHold(deployer), 0);
        assert.equal(await this.token.balanceOnHold(holder), 900);
        assert.equal(await this.token.balanceOnHold(sender), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient2), 0);
        assert.equal(await this.token.balanceOnHold(notary), 0);

        assert.equal(await this.token.balanceOf(holder), 1000);

        assert.equal(await this.token.totalSupply(), 1000);
      });
      it("Holder can not release the hold before expiration time", async () => {
        await expectRevert.unspecified(
          this.token.releaseHold(holdId, { from: holder })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 100);
        assert.equal(await this.token.balanceOnHold(holder), 900);
        assert.equal(await this.token.balanceOf(holder), 1000);
      });
      it("Recipient can not execute the hold", async () => {
        await expectRevert.unspecified(
          this.token.executeHold(holdId, hashLock.secret, {
            from: recipient,
          })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 100);
        assert.equal(await this.token.balanceOnHold(holder), 900);
        assert.equal(await this.token.balanceOf(holder), 1000);
      });
      it("Notary can not execute hold with the wrong lock hash", async () => {
        const incorrectHashLock = newSecretHashPair();
        await expectRevert.unspecified(
          this.token.executeHold(holdId, incorrectHashLock.secret, {
            from: notary,
          })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 100);
        assert.equal(await this.token.balanceOnHold(holder), 900);
        assert.equal(await this.token.balanceOf(holder), 1000);
      });
      it("Notary can not execute hold with the wrong execute function", async () => {
        await expectRevert.unspecified(
          this.token.methods["executeHold(bytes32,bytes32,address)"](holdId, hashLock.secret, recipient2, {
            from: notary,
          })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 100);
        assert.equal(await this.token.balanceOnHold(holder), 900);
        assert.equal(await this.token.balanceOf(holder), 1000);
      });
      it("Recipient can not release the hold", async () => {
        await expectRevert.unspecified(
          this.token.releaseHold(holdId, { from: recipient })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 100);
        assert.equal(await this.token.balanceOnHold(holder), 900);
        assert.equal(await this.token.balanceOf(holder), 1000);
      });
      it("Holder can not transfer 200 tokens with only 100 available and 900 on hold", async () => {
        await expectRevert.unspecified(
          this.token.hold(
            web3.utils.randomHex(32),
            recipient,
            notary,
            900,
            inOneHour,
            hashLock.hash,
            { from: holder }
          )
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 100);
        assert.equal(await this.token.balanceOnHold(holder), 900);
        assert.equal(await this.token.balanceOf(holder), 1000);
      });
      it("Holder can not approve 200 tokens for recipient2 to spend with only 100 available and 900 on hold", async () => {
        assert.equal(await this.token.allowance(holder, recipient2), 0);
        await expectRevert.unspecified(
          this.token.approve(recipient2, 200, { from: holder })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 100);
        assert.equal(await this.token.balanceOnHold(holder), 900);
        assert.equal(await this.token.balanceOf(holder), 1000);
        assert.equal(await this.token.allowance(holder, recipient2), 0);
      });
      it("Holder can approve 30 tokens for recipient2 to spend", async () => {
        assert.equal(await this.token.allowance(holder, recipient2), 0);
        const result = await this.token.approve(recipient2, 30, {
          from: holder,
        });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.allowance(holder, recipient2), 30);
        assert.equal(await this.token.spendableBalanceOf(holder), 100);
        assert.equal(await this.token.balanceOnHold(holder), 900);
        assert.equal(await this.token.balanceOf(holder), 1000);
      });
      it("Holder can transfer 80 tokens with 100 available and 30 approved for spending", async () => {
        const result = await this.token.transfer(recipient2, 80, {
          from: holder,
        });
        assert.equal(result.receipt.status, 1);

        assert.equal(await this.token.spendableBalanceOf(deployer), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 20);
        assert.equal(await this.token.spendableBalanceOf(sender), 0);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.spendableBalanceOf(recipient2), 80);
        assert.equal(await this.token.spendableBalanceOf(notary), 0);

        assert.equal(await this.token.balanceOnHold(deployer), 0);
        assert.equal(await this.token.balanceOnHold(holder), 900);
        assert.equal(await this.token.balanceOnHold(sender), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient2), 0);
        assert.equal(await this.token.balanceOnHold(notary), 0);

        assert.equal(await this.token.balanceOf(holder), 920);
        assert.equal(await this.token.balanceOf(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient2), 80);

        assert.equal(await this.token.totalSupply(), 1000);
      });
      it("Holder can not transfer 21 tokens with 20 available", async () => {
        await expectRevert.unspecified(
          this.token.transfer(recipient2, 101, {
            from: holder,
          })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 20);
        assert.equal(await this.token.balanceOnHold(holder), 900);
        assert.equal(await this.token.balanceOf(holder), 920);
      });
      it("Recipient 2 can not transfer 30 approved tokens from holder as only 20 are available", async () => {
        assert.equal(await this.token.allowance(holder, recipient2), 30);
        await expectRevert.unspecified(
          this.token.transferFrom(holder, recipient2, 30, {
            from: recipient2,
          })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 20);
        assert.equal(await this.token.balanceOnHold(holder), 900);
        assert.equal(await this.token.balanceOf(holder), 920);
        assert.equal(await this.token.allowance(holder, recipient2), 30);
      });
      it("Notary can not execute the hold without the lock hash", async () => {
        await expectRevert.unspecified(
          this.token.methods[
            "executeHold(bytes32)"
          ](holdId, { from: notary })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 20);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.spendableBalanceOf(notary), 0);
      });
      it("Notary can not execute hold with the wrong lock hash", async () => {
        const incorrectHashLock = newSecretHashPair();
        await expectRevert.unspecified(
          this.token.executeHold(holdId, incorrectHashLock.secret, {
            from: notary,
          })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 20);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.spendableBalanceOf(notary), 0);
      });
      it("Notary can execute the hold", async () => {
        const result = await this.token.executeHold(holdId, hashLock.secret, {
          from: notary,
        });
        assert.equal(result.receipt.status, 1);
        assert.equal(
          await this.token.holdStatus(holdId),
          HoldStatusCode.Executed
        );

        assert.equal(await this.token.spendableBalanceOf(deployer), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 20);
        assert.equal(await this.token.spendableBalanceOf(sender), 0);
        assert.equal(await this.token.spendableBalanceOf(recipient), 900);
        assert.equal(await this.token.spendableBalanceOf(recipient2), 80);
        assert.equal(await this.token.spendableBalanceOf(notary), 0);
        assert.equal(await this.token.totalSupply(), 1000);

        assert.equal(await this.token.balanceOnHold(deployer), 0);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOnHold(sender), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient2), 0);
        assert.equal(await this.token.balanceOnHold(notary), 0);

        assert.equal(await this.token.balanceOf(holder), 20);
        assert.equal(await this.token.balanceOf(recipient), 900);
        assert.equal(await this.token.balanceOf(recipient2), 80);

        assert.equal(await this.token.totalSupply(), 1000);
      });
      it("Notary can not execute a hold a second time", async () => {
        await expectRevert.unspecified(
          this.token.executeHold(holdId, hashLock.secret, {
            from: notary,
          })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 20);
        assert.equal(await this.token.spendableBalanceOf(recipient), 900);
      });
      it("The holder can not release a hold after execution", async () => {
        await expectRevert.unspecified(
          this.token.releaseHold(holdId, { from: holder })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 20);
        assert.equal(await this.token.spendableBalanceOf(recipient), 900);
      });
      it("The holder can not release a hold after expiration time and execution", async () => {
        await advanceTime(inOneHour + 1);
        await expectRevert.unspecified(
          this.token.releaseHold(holdId, { from: holder })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 20);
        assert.equal(await this.token.spendableBalanceOf(recipient), 900);
      });
    });
    describe("Hold and release by notary before expiration", () => {
      const hashLock = newSecretHashPair();
      const inOneHour = nowSeconds() + 60 * 60;
      let holdId;
      let snapshotId;
      before(async () => {
        const snapshot = await takeSnapshot();
        snapshotId = snapshot["result"];
        this.logic = await ERC20Logic.new();
        this.token = await ERC20Extendable.new(
          "ERC20Extendable",
          "DAU20",
          true,
          true,
          deployer,
          initialSupply,
          maxSupply,
          this.logic.address,
          { from: deployer }
        );
        this.holdExtensionContract = await HoldExtension.new();
        this.holdExtension = this.holdExtensionContract.address;
        
        assert.equal((await this.token.allExtensionsRegistered()).length, 0);

        const result = await this.token.registerExtension(this.holdExtension, { from: deployer });
        assert.equal(result.receipt.status, 1);
 
        assert.equal((await this.token.allExtensionsRegistered()).length, 1);

        this.holdExtensionBind = await HoldExtension.at(this.token.address);
        
        //combine both objects 
        this.token = Object.assign(this.token, this.holdExtensionBind);
      });
      after(async () => {
        await revertToSnapshot(snapshotId);
      });
      it("Mint 200 tokens to holder", async () => {
        assert.equal(await this.token.totalSupply(), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 0);
        const result = await this.token.mint(holder, 200, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(deployer), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 200);
        assert.equal(await this.token.spendableBalanceOf(sender), 0);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.spendableBalanceOf(recipient2), 0);
        assert.equal(await this.token.spendableBalanceOf(notary), 0);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 200);
        assert.equal(await this.token.totalSupply(), 200);
      });
      it("Holder holds 30 tokens for the recipient", async () => {
        holdId = web3.utils.randomHex(32);
        const result = await this.token.hold(
          holdId,
          recipient,
          notary,
          30,
          inOneHour,
          hashLock.hash,
          { from: holder }
        );
        assert.equal(result.receipt.status, 1);
        assert.lengthOf(result.receipt.logs, 1);
        assert.match(holdId, bytes32);
        assert.equal(await this.token.spendableBalanceOf(deployer), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 170);
        assert.equal(await this.token.spendableBalanceOf(sender), 0);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.spendableBalanceOf(recipient2), 0);
        assert.equal(await this.token.spendableBalanceOf(notary), 0);

        assert.equal(await this.token.balanceOnHold(deployer), 0);
        assert.equal(await this.token.balanceOnHold(holder), 30);
        assert.equal(await this.token.balanceOnHold(sender), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient2), 0);
        assert.equal(await this.token.balanceOnHold(notary), 0);

        assert.equal(await this.token.balanceOf(holder), 200);

        assert.equal(await this.token.totalSupply(), 200);
      });
      it("Holder can not hold with the same parameters again", async () => {
        await expectRevert.unspecified(
          this.token.hold(
            holdId,
            recipient,
            notary,
            30,
            inOneHour,
            hashLock.hash,
            { from: holder }
          )
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 170);
      });
      it("Notary releases 30 tokens back to holder", async () => {
        const result = await this.token.releaseHold(holdId, { from: notary });
        assert.equal(
          await this.token.holdStatus(holdId),
          HoldStatusCode.Released
        );
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 200);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 200);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
        assert.equal(await this.token.spendableBalanceOf(notary), 0);
        assert.equal(await this.token.balanceOnHold(notary), 0);
        assert.equal(await this.token.balanceOf(notary), 0);

        assert.equal(await this.token.totalSupply(), 200);
      });
      it("Notary can not release a hold twice", async () => {
        await expectRevert.unspecified(
          this.token.releaseHold(holdId, { from: notary })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 200);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 200);
        assert.equal(await this.token.totalSupply(), 200);
      });
      it("Notary can not execute a hold after release", async () => {
        await expectRevert.unspecified(
          this.token.executeHold(holdId, hashLock.secret, {
            from: notary,
          })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 200);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 200);
        assert.equal(await this.token.totalSupply(), 200);
      });
      it("Holder can not release a hold after release", async () => {
        await expectRevert.unspecified(
          this.token.releaseHold(holdId, { from: notary })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 200);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 200);
        assert.equal(await this.token.totalSupply(), 200);
      });
    });
    describe("Hold and release by notary after expiration", () => {
      const hashLock = newSecretHashPair();
      const inOneHour = nowSeconds() + 60 * 60;
      let holdId;
      let snapshotId;
      before(async () => {
        snapshot = await takeSnapshot();
        snapshotId = snapshot["result"];
        this.logic = await ERC20Logic.new();
        this.token = await ERC20Extendable.new(
          "ERC20Extendable",
          "DAU20",
          true,
          true,
          deployer,
          initialSupply,
          maxSupply,
          this.logic.address,
          { from: deployer }
        );
        this.holdExtensionContract = await HoldExtension.new();
        this.holdExtension = this.holdExtensionContract.address;
        
        assert.equal((await this.token.allExtensionsRegistered()).length, 0);

        const result = await this.token.registerExtension(this.holdExtension, { from: deployer });
        assert.equal(result.receipt.status, 1);
 
        assert.equal((await this.token.allExtensionsRegistered()).length, 1);

        this.holdExtensionBind = await HoldExtension.at(this.token.address);
        
        //combine both objects 
        this.token = Object.assign(this.token, this.holdExtensionBind);
      });
      after(async () => {
        await revertToSnapshot(snapshotId);
      });
      it("Mint 3 tokens to holder", async () => {
        assert.equal(await this.token.totalSupply(), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 0);
        const result = await this.token.mint(holder, 3, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 3);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 3);
        assert.equal(await this.token.totalSupply(), 3);
      });
      it("Holder holds 2 tokens for the recipient", async () => {
        holdId = web3.utils.randomHex(32);
        const result = await this.token.hold(
          holdId,
          recipient,
          notary,
          2,
          inOneHour,
          hashLock.hash,
          { from: holder }
        );
        assert.equal(result.receipt.status, 1);
        assert.lengthOf(result.receipt.logs, 1);
        assert.match(holdId, bytes32);
        assert.equal(await this.token.spendableBalanceOf(holder), 1);
        assert.equal(await this.token.balanceOnHold(holder), 2);
        assert.equal(await this.token.balanceOf(holder), 3);
        assert.equal(await this.token.totalSupply(), 3);
      });
      it("Holder can not release the hold before expiration", async () => {
        await expectRevert.unspecified(
          this.token.releaseHold(holdId, { from: holder })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 1);
        assert.equal(await this.token.balanceOnHold(holder), 2);
        assert.equal(await this.token.balanceOf(holder), 3);
      });
      it("Advance time to after expiration", async () => {
        await advanceTime(inOneHour + 1);
      });
      it("After expiration, notary releases 3 tokens back to holder", async () => {
        const result = await this.token.releaseHold(holdId, { from: notary });
        assert.equal(
          await this.token.holdStatus(holdId),
          HoldStatusCode.Released
        );
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 3);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 3);
        assert.equal(await this.token.totalSupply(), 3);
      });
      it("Notary can not release the hold twice", async () => {
        await expectRevert.unspecified(
          this.token.releaseHold(holdId, { from: notary })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 3);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 3);
      });
      it("Holder can not release the hold after release", async () => {
        await expectRevert.unspecified(
          this.token.releaseHold(holdId, { from: holder })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 3);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 3);
      });
    });
    describe("Hold and release by holder after expiration", () => {
      const hashLock = newSecretHashPair();
      const inOneHour = nowSeconds() + 60 * 60;
      let holdId;
      let snapshotId;
      before(async () => {
        snapshot = await takeSnapshot();
        snapshotId = snapshot["result"];
        this.logic = await ERC20Logic.new();
        this.token = await ERC20Extendable.new(
          "ERC20Extendable",
          "DAU20",
          true,
          true,
          deployer,
          initialSupply,
          maxSupply,
          this.logic.address,
          { from: deployer }
        );
        this.holdExtensionContract = await HoldExtension.new();
        this.holdExtension = this.holdExtensionContract.address;
        
        assert.equal((await this.token.allExtensionsRegistered()).length, 0);

        const result = await this.token.registerExtension(this.holdExtension, { from: deployer });
        assert.equal(result.receipt.status, 1);
 
        assert.equal((await this.token.allExtensionsRegistered()).length, 1);

        this.holdExtensionBind = await HoldExtension.at(this.token.address);
        
        //combine both objects 
        this.token = Object.assign(this.token, this.holdExtensionBind);
      });
      after(async () => {
        await revertToSnapshot(snapshotId);
      });
      it("Mint 3 tokens to holder", async () => {
        assert.equal(await this.token.totalSupply(), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 0);
        const result = await this.token.mint(holder, 3, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 3);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 3);
        assert.equal(await this.token.totalSupply(), 3);
      });
      it("Holder holds 2 tokens for the recipient", async () => {
        holdId = web3.utils.randomHex(32);
        const result = await this.token.hold(
          holdId,
          recipient,
          notary,
          2,
          inOneHour,
          hashLock.hash,
          { from: holder }
        );
        assert.equal(result.receipt.status, 1);
        assert.lengthOf(result.receipt.logs, 1);
        assert.match(holdId, bytes32);
        assert.equal(await this.token.spendableBalanceOf(holder), 1);
        assert.equal(await this.token.balanceOnHold(holder), 2);
        assert.equal(await this.token.balanceOf(holder), 3);
        assert.equal(await this.token.totalSupply(), 3);
      });
      it("Holder can not release the hold before expiration", async () => {
        await expectRevert.unspecified(
          this.token.releaseHold(holdId, { from: holder })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 1);
        assert.equal(await this.token.balanceOnHold(holder), 2);
        assert.equal(await this.token.balanceOf(holder), 3);
      });
      it("After expiration, holder releases 3 tokens back to holder", async () => {
        await advanceTime(inOneHour + 1);
        const result = await this.token.releaseHold(holdId, { from: holder });
        assert.equal(
          await this.token.holdStatus(holdId),
          HoldStatusCode.ReleasedOnExpiration
        );
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 3);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 3);
        assert.equal(await this.token.totalSupply(), 3);
      });
      it("Holder can not release the hold twice", async () => {
        await expectRevert.unspecified(
          this.token.releaseHold(holdId, { from: holder })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 3);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 3);
      });
      it("Notary can not release the hold after release", async () => {
        await expectRevert.unspecified(
          this.token.releaseHold(holdId, { from: notary })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 3);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 3);
      });
    });
    describe("Hold and execute by notary after expiration", () => {
      const hashLock = newSecretHashPair();
      const inOneHour = nowSeconds() + 60 * 60;
      let holdId;
      let snapshotId;
      before(async () => {
        snapshot = await takeSnapshot();
        snapshotId = snapshot["result"];
        this.logic = await ERC20Logic.new();
        this.token = await ERC20Extendable.new(
          "ERC20Extendable",
          "DAU20",
          true,
          true,
          deployer,
          initialSupply,
          maxSupply,
          this.logic.address,
          { from: deployer }
        );
        this.holdExtensionContract = await HoldExtension.new();
        this.holdExtension = this.holdExtensionContract.address;
        
        assert.equal((await this.token.allExtensionsRegistered()).length, 0);

        const result = await this.token.registerExtension(this.holdExtension, { from: deployer });
        assert.equal(result.receipt.status, 1);
 
        assert.equal((await this.token.allExtensionsRegistered()).length, 1);

        this.holdExtensionBind = await HoldExtension.at(this.token.address);
        
        //combine both objects 
        this.token = Object.assign(this.token, this.holdExtensionBind);
      });
      after(async () => {
        await revertToSnapshot(snapshotId);
      });
      it("Mint 3 tokens to holder", async () => {
        assert.equal(await this.token.totalSupply(), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 0);
        const result = await this.token.mint(holder, 3, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 3);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 3);
        assert.equal(await this.token.totalSupply(), 3);
      });
      it("Holder holds 2 tokens for the recipient", async () => {
        holdId = web3.utils.randomHex(32);
        const result = await this.token.hold(
          holdId,
          recipient,
          notary,
          2,
          inOneHour,
          hashLock.hash,
          { from: holder }
        );
        assert.equal(result.receipt.status, 1);
        assert.lengthOf(result.receipt.logs, 1);
        assert.match(holdId, bytes32);
        assert.equal(await this.token.spendableBalanceOf(holder), 1);
        assert.equal(await this.token.balanceOnHold(holder), 2);
        assert.equal(await this.token.balanceOf(holder), 3);
        assert.equal(await this.token.totalSupply(), 3);
      });
      it("Advance time to after expiration", async () => {
        await advanceTime(inOneHour + 1);
      });
      it("After expiration, notary execute hold to recipient", async () => {
        const result = await this.token.executeHold(holdId, hashLock.secret, {
          from: notary,
        });
        assert.equal(
          await this.token.holdStatus(holdId),
          HoldStatusCode.Executed
        );
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 1);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 1);
        assert.equal(await this.token.spendableBalanceOf(recipient), 2);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 2);
        assert.equal(await this.token.totalSupply(), 3);
      });
    });
    describe("Hold with no recipient, notary can execute before expiration with recipient", () => {
      const hashLock = newSecretHashPair();
      const inOneDay = nowSeconds() + 60 * 60 * 24;
      let holdId;
      let snapshotId;
      before(async () => {
        snapshot = await takeSnapshot();
        snapshotId = snapshot["result"];
        this.logic = await ERC20Logic.new();
        this.token = await ERC20Extendable.new(
          "ERC20Extendable",
          "DAU20",
          true,
          true,
          deployer,
          initialSupply,
          maxSupply,
          this.logic.address,
          { from: deployer }
        );
        this.holdExtensionContract = await HoldExtension.new();
        this.holdExtension = this.holdExtensionContract.address;
        
        assert.equal((await this.token.allExtensionsRegistered()).length, 0);

        const result = await this.token.registerExtension(this.holdExtension, { from: deployer });
        assert.equal(result.receipt.status, 1);
 
        assert.equal((await this.token.allExtensionsRegistered()).length, 1);

        this.holdExtensionBind = await HoldExtension.at(this.token.address);
        
        //combine both objects 
        this.token = Object.assign(this.token, this.holdExtensionBind)
      });
      after(async () => {
        await revertToSnapshot(snapshotId);
      });
      it("Mint 9876543210 tokens to holder", async () => {
        assert.equal(await this.token.totalSupply(), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 0);
        const result = await this.token.mint(holder, 9876543210, {
          from: deployer,
        });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 9876543210);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 9876543210);
        assert.equal(await this.token.totalSupply(), 9876543210);
      });
      it("Holder holds 9000000000 tokens with no recipient", async () => {
        holdId = web3.utils.randomHex(32);
        const result = await this.token.hold(
          holdId,
          ZERO_ADDRESS,
          notary,
          9000000000,
          inOneDay,
          hashLock.hash,
          { from: holder }
        );
        assert.equal(result.receipt.status, 1);
        assert.lengthOf(result.receipt.logs, 1);
        assert.match(holdId, bytes32);
        assert.equal(await this.token.spendableBalanceOf(holder), 876543210);
        assert.equal(await this.token.balanceOnHold(holder), 9000000000);
        assert.equal(await this.token.balanceOf(holder), 9876543210);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
        assert.equal(await this.token.totalSupply(), 9876543210);
      });
      it("Recipient can not execute a hold", async () => {
        await expectRevert.unspecified(
          this.token.methods[
            "executeHold(bytes32,bytes32,address)"
          ](holdId, hashLock.secret, recipient, { from: recipient })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 876543210);
        assert.equal(await this.token.balanceOnHold(holder), 9000000000);
        assert.equal(await this.token.balanceOf(holder), 9876543210);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
        assert.equal(await this.token.totalSupply(), 9876543210);
      });
      it("Recipient can not execute a hold without specifying a recipient", async () => {
        await expectRevert.unspecified(
          this.token.executeHold(holdId, hashLock.secret, {
            from: notary,
          })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 876543210);
        assert.equal(await this.token.balanceOnHold(holder), 9000000000);
        assert.equal(await this.token.balanceOf(holder), 9876543210);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
        assert.equal(await this.token.totalSupply(), 9876543210);
      });
      it("Recipient can not execute a hold with zero address as the recipient", async () => {
        await expectRevert.unspecified(
          this.token.methods[
            "executeHold(bytes32,bytes32,address)"
          ](holdId, hashLock.secret, ZERO_ADDRESS, { from: notary })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 876543210);
        assert.equal(await this.token.balanceOnHold(holder), 9000000000);
        assert.equal(await this.token.balanceOf(holder), 9876543210);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
        assert.equal(await this.token.totalSupply(), 9876543210);
      });
      it("Notary can not execute the hold without the lock hash", async () => {
        await expectRevert.unspecified(
          this.token.methods[
            "executeHold(bytes32)"
          ](holdId, { from: notary })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 876543210);
        assert.equal(await this.token.balanceOnHold(holder), 9000000000);
        assert.equal(await this.token.balanceOf(holder), 9876543210);
      });
      it("Notary can not execute hold with the wrong lock hash", async () => {
        const incorrectHashLock = newSecretHashPair();
        await expectRevert.unspecified(
          this.token.methods[
            "executeHold(bytes32,bytes32,address)"
          ](holdId, incorrectHashLock.secret, recipient, { from: notary })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 876543210);
        assert.equal(await this.token.balanceOnHold(holder), 9000000000);
        assert.equal(await this.token.balanceOf(holder), 9876543210);
      });
      it("Notary can execute the hold specifying the recipient", async () => {
        const result = await this.token.methods[
          "executeHold(bytes32,bytes32,address)"
        ](holdId, hashLock.secret, recipient, { from: notary });
        assert.equal(
          await this.token.holdStatus(holdId),
          HoldStatusCode.Executed
        );
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 876543210);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 876543210);
        assert.equal(await this.token.spendableBalanceOf(recipient), 9000000000);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 9000000000);
        assert.equal(await this.token.totalSupply(), 9876543210);
      });
    });
    describe("Hold with no hash lock, notary can execute without lock secret before expiration", () => {
      const inOneWeek = nowSeconds() + 60 * 60 * 24 * 7;
      let holdId;
      let snapshotId;
      before(async () => {
        snapshot = await takeSnapshot();
        snapshotId = snapshot["result"];
        this.logic = await ERC20Logic.new();
        this.token = await ERC20Extendable.new(
          "ERC20Extendable",
          "DAU20",
          true,
          true,
          deployer,
          initialSupply,
          maxSupply,
          this.logic.address,
          { from: deployer }
        );
        this.holdExtensionContract = await HoldExtension.new();
        this.holdExtension = this.holdExtensionContract.address;
        
        assert.equal((await this.token.allExtensionsRegistered()).length, 0);

        const result = await this.token.registerExtension(this.holdExtension, { from: deployer });
        assert.equal(result.receipt.status, 1);
 
        assert.equal((await this.token.allExtensionsRegistered()).length, 1);

        this.holdExtensionBind = await HoldExtension.at(this.token.address);
        
        //combine both objects 
        this.token = Object.assign(this.token, this.holdExtensionBind);
      });
      after(async () => {
        await revertToSnapshot(snapshotId);
      });
      it("Mint 123 tokens to holder", async () => {
        assert.equal(await this.token.totalSupply(), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 0);
        const result = await this.token.mint(holder, 123, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 123);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 123);
        assert.equal(await this.token.totalSupply(), 123);
      });
      it("Holder holds 100 tokens with no hash lock", async () => {
        holdId = web3.utils.randomHex(32);
        const result = await this.token.hold(
          holdId,
          recipient,
          notary,
          100,
          inOneWeek,
          ZERO_BYTES32,
          { from: holder }
        );
        assert.equal(result.receipt.status, 1);
        assert.lengthOf(result.receipt.logs, 1);
        assert.match(holdId, bytes32);
        assert.equal(await this.token.spendableBalanceOf(holder), 23);
        assert.equal(await this.token.balanceOnHold(holder), 100);
        assert.equal(await this.token.balanceOf(holder), 123);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
        assert.equal(await this.token.totalSupply(), 123);
      });
      it("Notary can execute the hold without a lock preimage", async () => {
        const result = await this.token.methods["executeHold(bytes32)"](
          holdId,
          { from: notary }
        );
        assert.equal(
          await this.token.holdStatus(holdId),
          HoldStatusCode.Executed
        );
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 23);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 23);
        assert.equal(await this.token.spendableBalanceOf(recipient), 100);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 100);
        assert.equal(await this.token.totalSupply(), 123);
      });
    });
    describe("Hold with no recipient or hash lock, notary can execute before expiration", () => {
      const inOneWeek = nowSeconds() + 60 * 60 * 24 * 7;
      let holdId;
      let snapshotId;
      before(async () => {
        snapshot = await takeSnapshot();
        snapshotId = snapshot["result"];
        this.logic = await ERC20Logic.new();
        this.token = await ERC20Extendable.new(
          "ERC20Extendable",
          "DAU20",
          true,
          true,
          deployer,
          initialSupply,
          maxSupply,
          this.logic.address,
          { from: deployer }
        );
        this.holdExtensionContract = await HoldExtension.new();
        this.holdExtension = this.holdExtensionContract.address;
        
        assert.equal((await this.token.allExtensionsRegistered()).length, 0);

        const result = await this.token.registerExtension(this.holdExtension, { from: deployer });
        assert.equal(result.receipt.status, 1);
 
        assert.equal((await this.token.allExtensionsRegistered()).length, 1);

        this.holdExtensionBind = await HoldExtension.at(this.token.address);
        
        //combine both objects 
        this.token = Object.assign(this.token, this.holdExtensionBind);
      });
      after(async () => {
        await revertToSnapshot(snapshotId);
      });
      it("Mint 123 tokens to holder", async () => {
        assert.equal(await this.token.totalSupply(), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 0);
        const result = await this.token.mint(holder, 123, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 123);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 123);
        assert.equal(await this.token.totalSupply(), 123);
      });
      it("Holder holds 100 tokens with no hash lock", async () => {
        holdId = web3.utils.randomHex(32);
        const result = await this.token.hold(
          holdId,
          ZERO_ADDRESS,
          notary,
          100,
          inOneWeek,
          ZERO_BYTES32,
          { from: holder }
        );
        assert.equal(result.receipt.status, 1);
        assert.lengthOf(result.receipt.logs, 1);
        assert.match(holdId, bytes32);
        assert.equal(await this.token.spendableBalanceOf(holder), 23);
        assert.equal(await this.token.balanceOnHold(holder), 100);
        assert.equal(await this.token.balanceOf(holder), 123);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
        assert.equal(await this.token.totalSupply(), 123);
      });
      it("Notary can execute the hold specifying a recipient without a lock preimage", async () => {
        const result = await this.token.methods[
          "executeHold(bytes32,bytes32,address)"
        ](holdId, ZERO_BYTES32, recipient2, { from: notary });
        assert.equal(
          await this.token.holdStatus(holdId),
          HoldStatusCode.Executed
        );
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 23);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 23);
        assert.equal(await this.token.spendableBalanceOf(recipient2), 100);
        assert.equal(await this.token.balanceOnHold(recipient2), 0);
        assert.equal(await this.token.balanceOf(recipient2), 100);
        assert.equal(await this.token.totalSupply(), 123);
      });
    });
    describe("Hold with no expiration time, holder releases straight away", () => {
      const inOneWeek = nowSeconds() + 60 * 60 * 24 * 7;
      let holdId;
      let snapshotId;
      before(async () => {
        snapshot = await takeSnapshot();
        snapshotId = snapshot["result"];
        this.logic = await ERC20Logic.new();
        this.token = await ERC20Extendable.new(
          "ERC20Extendable",
          "DAU20",
          true,
          true,
          deployer,
          initialSupply,
          maxSupply,
          this.logic.address,
          { from: deployer }
        );
        this.holdExtensionContract = await HoldExtension.new();
        this.holdExtension = this.holdExtensionContract.address;
        
        assert.equal((await this.token.allExtensionsRegistered()).length, 0);

        const result = await this.token.registerExtension(this.holdExtension, { from: deployer });
        assert.equal(result.receipt.status, 1);
 
        assert.equal((await this.token.allExtensionsRegistered()).length, 1);

        this.holdExtensionBind = await HoldExtension.at(this.token.address);
        
        //combine both objects 
        this.token = Object.assign(this.token, this.holdExtensionBind);
      });
      after(async () => {
        await revertToSnapshot(snapshotId);
      });
      it("Mint 123 tokens to holder", async () => {
        assert.equal(await this.token.totalSupply(), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 0);
        const result = await this.token.mint(holder, 123, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 123);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 123);
        assert.equal(await this.token.totalSupply(), 123);
      });
      it("Holder holds 100 tokens with no hash lock", async () => {
        holdId = web3.utils.randomHex(32);
        const result = await this.token.hold(
          holdId,
          ZERO_ADDRESS,
          notary,
          100,
          0,
          ZERO_BYTES32,
          { from: holder }
        );
        assert.equal(result.receipt.status, 1);
        assert.lengthOf(result.receipt.logs, 1);
        assert.match(holdId, bytes32);
        assert.equal(await this.token.spendableBalanceOf(holder), 23);
        assert.equal(await this.token.balanceOnHold(holder), 100);
        assert.equal(await this.token.balanceOf(holder), 123);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
        assert.equal(await this.token.totalSupply(), 123);
      });
      it("Holder releases tokens back to holder straight away", async () => {
        const result = await this.token.releaseHold(holdId, { from: holder });
        assert.equal(
          await this.token.holdStatus(holdId),
          HoldStatusCode.ReleasedOnExpiration
        );
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 123);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 123);
        assert.equal(await this.token.totalSupply(), 123);
      });
    });
    describe("Can not burn notes on hold", () => {
      const inOneWeek = nowSeconds() + 60 * 60 * 24 * 7;
      let holdId;
      let snapshotId;
      before(async () => {
        snapshot = await takeSnapshot();
        snapshotId = snapshot["result"];
        this.logic = await ERC20Logic.new();
        this.token = await ERC20Extendable.new(
          "ERC20Extendable",
          "DAU20",
          true,
          true,
          deployer,
          initialSupply,
          maxSupply,
          this.logic.address,
          { from: deployer }
        );
        this.holdExtensionContract = await HoldExtension.new();
        this.holdExtension = this.holdExtensionContract.address;
        
        assert.equal((await this.token.allExtensionsRegistered()).length, 0);

        const result = await this.token.registerExtension(this.holdExtension, { from: deployer });
        assert.equal(result.receipt.status, 1);
 
        assert.equal((await this.token.allExtensionsRegistered()).length, 1);

        this.holdExtensionBind = await HoldExtension.at(this.token.address);
        
        //combine both objects 
        this.token = Object.assign(this.token, this.holdExtensionBind);
      });
      after(async () => {
        //await revertToSnapshot(snapshotId);
      });
      it("Mint 123 tokens to holder", async () => {
        assert.equal(await this.token.totalSupply(), 0);
        assert.equal(await this.token.spendableBalanceOf(holder), 0);
        const result = await this.token.mint(holder, 123, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.spendableBalanceOf(holder), 123);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 123);
        assert.equal(await this.token.totalSupply(), 123);
      });
      it("Holder holds 100 tokens with no hash lock", async () => {
        holdId = web3.utils.randomHex(32);
        const result = await this.token.hold(
          holdId,
          ZERO_ADDRESS,
          notary,
          100,
          0,
          ZERO_BYTES32,
          { from: holder }
        );
        assert.equal(result.receipt.status, 1);
        assert.lengthOf(result.receipt.logs, 1);
        assert.equal(await this.token.holdStatus(holdId), HoldStatusCode.Held);
        assert.match(holdId, bytes32);
        assert.equal(await this.token.spendableBalanceOf(holder), 23);
        assert.equal(await this.token.balanceOnHold(holder), 100);
        assert.equal(await this.token.balanceOf(holder), 123);
        assert.equal(await this.token.spendableBalanceOf(recipient), 0);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
        assert.equal(await this.token.totalSupply(), 123);
      });
      it("Holder can not burn on hold tokens", async () => {
        await expectRevert.unspecified(
          this.token.burn(24, { from: holder })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 23);
        assert.equal(await this.token.balanceOnHold(holder), 100);
        assert.equal(await this.token.balanceOf(holder), 123);
      });
      it("Holder approves a recipient to spend 10 tokens", async () => {
        assert.equal(await this.token.allowance(holder, recipient), 0);

        const result = await this.token.approve(recipient, 10, {
          from: holder,
        });
        assert.equal(result.receipt.status, 1);

        assert.equal(await this.token.allowance(holder, recipient), 10);
        assert.equal(await this.token.spendableBalanceOf(holder), 23);
        assert.equal(await this.token.balanceOnHold(holder), 100);
        assert.equal(await this.token.balanceOf(holder), 123);
        assert.equal(await this.token.totalSupply(), 123);
      });
      it("Recipient transfers 4 tokens from the holder to themselves", async () => {
        const result = await this.token.transferFrom(holder, recipient, 4, {
          from: recipient,
        });
        assert.equal(result.receipt.status, 1);

        assert.equal(await this.token.allowance(holder, recipient), 6);
        assert.equal(await this.token.spendableBalanceOf(holder), 19);
        assert.equal(await this.token.balanceOnHold(holder), 100);
        assert.equal(await this.token.balanceOf(holder), 119);

        assert.equal(await this.token.spendableBalanceOf(recipient), 4);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 4);

        assert.equal(await this.token.totalSupply(), 123);
      });
      it("Recipient burns one token held by the Holder", async () => {
        const result = await this.token.burnFrom(holder, 1, {
          from: recipient,
        });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.allowance(holder, recipient), 5);
        assert.equal(await this.token.spendableBalanceOf(holder), 18);
        assert.equal(await this.token.balanceOnHold(holder), 100);
        assert.equal(await this.token.balanceOf(holder), 118);

        assert.equal(await this.token.spendableBalanceOf(recipient), 4);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 4);

        assert.equal(await this.token.totalSupply(), 122);
      });
      it("Recipient can not burn more tokens than total held by the Holder", async () => {
        await expectRevert.unspecified(
          this.token.burnFrom(holder, 19, {
            from: recipient,
          })
        );
        assert.equal(await this.token.spendableBalanceOf(holder), 18);
        assert.equal(await this.token.balanceOnHold(holder), 100);
        assert.equal(await this.token.balanceOf(holder), 118);
      });
      it("Holder can burn tokens not on hold", async () => {
        const result = await this.token.burn(18, { from: holder });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.allowance(holder, recipient), 5);
        assert.equal(await this.token.spendableBalanceOf(holder), 0);
        assert.equal(await this.token.balanceOnHold(holder), 100);
        assert.equal(await this.token.balanceOf(holder), 100);

        assert.equal(await this.token.spendableBalanceOf(recipient), 4);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 4);

        assert.equal(await this.token.totalSupply(), 104);
      });
      it("Holder can not burn on hold tokens", async () => {
        await expectRevert.unspecified(
          this.token.burn(1, { from: holder })
        );
      });
      it("Notary executes hold to the recipient", async () => {
        const result = await this.token.methods[
          "executeHold(bytes32,bytes32,address)"
        ](holdId, ZERO_ADDRESS, recipient, { from: notary });
        assert.equal(
          await this.token.holdStatus(holdId),
          HoldStatusCode.Executed
        );
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.allowance(holder, recipient), 5);
        assert.equal(await this.token.spendableBalanceOf(holder), 0);
        assert.equal(await this.token.balanceOnHold(holder), 0);
        assert.equal(await this.token.balanceOf(holder), 0);

        assert.equal(await this.token.spendableBalanceOf(recipient), 104);
        assert.equal(await this.token.balanceOnHold(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient), 104);

        assert.equal(await this.token.totalSupply(), 104);
      });
    });
  }
);
