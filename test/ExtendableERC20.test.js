const { assert } = require("chai");
const { expectRevert } = require("@openzeppelin/test-helpers");
const {
  nowSeconds,
  advanceTime,
  takeSnapshot,
  revertToSnapshot,
} = require("./utils/time");
const { newSecretHashPair } = require("./utils/crypto");
const { bytes32 } = require("./utils/regex");

const ERC20Extendable = artifacts.require("ERC20Extendable");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ZERO_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
contract(
  "ERC20Extendable",
  ([deployer, sender, holder, recipient, recipient2, notary]) => {
    describe("ERC20 (mint: on, burn: on, with owner) with no extensions", () => {
      const totalSupply = 1000;
      let snapshotId;
      beforeEach(async function () {
        //snapshot = await takeSnapshot();
        //snapshotId = snapshot["result"];
        this.token = await debug(ERC20Extendable.new(
          "ERC20Extendable",
          "DAU",
          true,
          true,
          deployer,
          totalSupply
        ));
      });
/*       after(async () => {
        await revertToSnapshot(snapshotId);
      }); */

      it("Mint 1000 tokens to holder", async () => {
        assert.equal(await this.token.totalSupply(), 0);
        assert.equal(await this.token.balanceOf(holder), 0);
        const result = await this.token.mint(holder, 1000, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.balanceOf(deployer), 0);
        assert.equal(await this.token.balanceOf(holder), 1000);
        assert.equal(await this.token.balanceOf(sender), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient2), 0);
        assert.equal(await this.token.balanceOf(notary), 0);
        assert.equal(await this.token.totalSupply(), 1000);
      });

      it("Burn 100 tokens", async () => {
        assert.equal(await this.token.totalSupply(), 0);
        assert.equal(await this.token.balanceOf(holder), 1000);
        const result = await this.token.burn(100, { from: holder });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.balanceOf(deployer), 0);
        assert.equal(await this.token.balanceOf(holder), 1000 - 100);
        assert.equal(await this.token.balanceOf(sender), 0);
        assert.equal(await this.token.balanceOf(recipient), 0);
        assert.equal(await this.token.balanceOf(recipient2), 0);
        assert.equal(await this.token.balanceOf(notary), 0);
        assert.equal(await this.token.totalSupply(), 1000);
      });

      it("Transfer 100 tokens from holder to recipient", async () => {
        assert.equal(await this.token.totalSupply(), 0);
        assert.equal(await this.token.balanceOf(holder), 900);
        const result = await this.token.transfer(recipient, 100, { from: holder });
        assert.equal(result.receipt.status, 1);
        assert.equal(await this.token.balanceOf(deployer), 0);
        assert.equal(await this.token.balanceOf(holder), 800);
        assert.equal(await this.token.balanceOf(sender), 0);
        assert.equal(await this.token.balanceOf(recipient), 100);
        assert.equal(await this.token.balanceOf(recipient2), 0);
        assert.equal(await this.token.balanceOf(notary), 0);
        assert.equal(await this.token.totalSupply(), 1000);
      });

      it("Recipient cant transfer 200 tokens to recipient2", async () => {
        await expectRevert.unspecified(
          this.token.transfer(recipient2, 200, { from: recipient })
        );
      });

      it("Recipient cant transferFrom 200 tokens from holder to recipient2", async () => {
        await expectRevert.unspecified(
          this.token.transfer(recipient2, 200, { from: recipient })
        );
      });

      it("When holder approves recipient to transfer 200", async () => {
        await expectRevert.unspecified(
          this.token.transfer(recipient2, 200, { from: recipient })
        );
      });
    });
})