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

const AllowExtension = artifacts.require("AllowExtension");
const ERC20Extendable = artifacts.require("ERC20Extendable");
const ERC20Logic = artifacts.require("ERC20Logic");
const ERC20LogicMock = artifacts.require("ERC20LogicMock");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ZERO_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
contract(
  "ERC20Extendable",
  function ([deployer, sender, holder, recipient, recipient2, notary]) {
    describe("ERC20Extendable with Allowlist Extension", function () {
      const initialSupply = 1000;
      const maxSupply = 5000;
      let token;
      let allowExt;
      let allowExtContract;
      before(async function () {
        //snapshot = await takeSnapshot();
        //snapshotId = snapshot["result"];
        this.logic = await ERC20Logic.new();
        token = await ERC20Extendable.new(
          "ERC20Extendable",
          "DAU",
          true,
          true,
          deployer,
          initialSupply,
          maxSupply,
          this.logic.address
        );

        allowExtContract = await AllowExtension.new();
        allowExt = allowExtContract.address;
        assert.equal(await token.isMinter(deployer), true);
        assert.equal(await token.name(), "ERC20Extendable");
        assert.equal(await token.symbol(), "DAU");
        assert.equal(await token.totalSupply(), initialSupply);
        assert.equal(await token.balanceOf(deployer), initialSupply);
      });

      it("Deployer can registers extension", async () => {
        assert.equal((await token.allExtensionsRegistered()).length, 0);

        const result = await token.registerExtension(allowExt, { from: deployer });
        assert.equal(result.receipt.status, 1);

        assert.equal((await token.allExtensionsRegistered()).length, 1);
      });

      it("Transfers fail if address is not on allow list", async () => {
        assert.equal(await token.balanceOf(deployer), initialSupply);
        await expectRevert.unspecified(
          token.transfer(recipient, 200, { from: deployer })
        );
      });

      it("Allow list admins can add their own address to allow list", async () => {
        const allowlistToken = await AllowExtension.at(token.address);

        assert.equal(await allowlistToken.isAllowlisted(deployer), false);

        const result = await allowlistToken.addAllowlisted(deployer, { from: deployer });
        assert.equal(result.receipt.status, 1);

        assert.equal(await allowlistToken.isAllowlisted(deployer), true);
      });

      it("Holder can't add addresses to allow list", async () => {
        const allowlistToken = await AllowExtension.at(token.address);

        assert.equal(await allowlistToken.isAllowlisted(holder), false);

        await expectRevert.unspecified(
          allowlistToken.addAllowlisted(holder, { from: holder })
        );
        
        assert.equal(await allowlistToken.isAllowlisted(holder), false);
      });

      it("Allow list admins can make other addresses allow list admins", async () => {
        const allowlistToken = await AllowExtension.at(token.address);

        assert.equal(await allowlistToken.isAllowlistedAdmin(holder), false);

        const result = await allowlistToken.addAllowlistedAdmin(holder, { from: deployer });
        assert.equal(result.receipt.status, 1);

        assert.equal(await allowlistToken.isAllowlistedAdmin(holder), true);
      });

      it("Holder can now add addresses to allow list", async () => {
        const allowlistToken = await AllowExtension.at(token.address);

        assert.equal(await allowlistToken.isAllowlisted(recipient), false);

        const result = await allowlistToken.addAllowlisted(recipient, { from: holder });
        assert.equal(result.receipt.status, 1);

        assert.equal(await allowlistToken.isAllowlisted(recipient), true);
      });

      it("Transfer 100 tokens from deployer to recipient", async () => {
        assert.equal(await token.totalSupply(), initialSupply);
        assert.equal(await token.balanceOf(deployer), initialSupply);
        const result = await token.transfer(recipient, 100, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await token.balanceOf(deployer), initialSupply - 100);
        assert.equal(await token.balanceOf(holder), 0);
        assert.equal(await token.balanceOf(sender), 0);
        assert.equal(await token.balanceOf(recipient), 100);
        assert.equal(await token.balanceOf(recipient2), 0);
        assert.equal(await token.balanceOf(notary), 0);
        assert.equal(await token.totalSupply(), initialSupply);
      });

      it("Transfer 100 tokens from recipient to deployer", async () => {
        assert.equal(await token.totalSupply(), initialSupply);
        assert.equal(await token.balanceOf(deployer), initialSupply - 100);
        assert.equal(await token.balanceOf(recipient), 100);
        const result = await token.transfer(deployer, 100, { from: recipient });
        assert.equal(result.receipt.status, 1);
        assert.equal(await token.balanceOf(deployer), initialSupply);
        assert.equal(await token.balanceOf(holder), 0);
        assert.equal(await token.balanceOf(sender), 0);
        assert.equal(await token.balanceOf(recipient), 0);
        assert.equal(await token.balanceOf(recipient2), 0);
        assert.equal(await token.balanceOf(notary), 0);
        assert.equal(await token.totalSupply(), initialSupply);
      });

      it("Allow list admins can remove allow listed addresses", async () => {
        const allowlistToken = await AllowExtension.at(token.address);

        assert.equal(await allowlistToken.isAllowlisted(recipient), true);

        const result = await allowlistToken.removeAllowlisted(recipient, { from: holder });
        assert.equal(result.receipt.status, 1);

        assert.equal(await allowlistToken.isAllowlisted(recipient), false);
      });


      it("Allow list admins can remove allow list admins", async () => {
        const allowlistToken = await AllowExtension.at(token.address);

        assert.equal(await allowlistToken.isAllowlistedAdmin(holder), true);

        const result = await allowlistToken.removeAllowlistedAdmin(holder, { from: deployer });
        assert.equal(result.receipt.status, 1);

        assert.equal(await allowlistToken.isAllowlistedAdmin(holder), false);
      });

      it("Holder can't add addresses to allow list", async () => {
        const allowlistToken = await AllowExtension.at(token.address);

        assert.equal(await allowlistToken.isAllowlisted(holder), false);

        await expectRevert.unspecified(
          allowlistToken.addAllowlisted(holder, { from: holder })
        );
        
        assert.equal(await allowlistToken.isAllowlisted(holder), false);
      });

      it("Deployer can disable extensions", async () => {
        const result2 = await token.disableExtension(allowExt, { from: deployer });

        assert.equal(result2.receipt.status, 1);
      });

      it("Transfer 100 tokens from deployer to recipient", async () => {
        assert.equal(await token.totalSupply(), initialSupply);
        assert.equal(await token.balanceOf(deployer), initialSupply);
        const result = await token.transfer(recipient, 100, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await token.balanceOf(deployer), initialSupply - 100);
        assert.equal(await token.balanceOf(holder), 0);
        assert.equal(await token.balanceOf(sender), 0);
        assert.equal(await token.balanceOf(recipient), 100);
        assert.equal(await token.balanceOf(recipient2), 0);
        assert.equal(await token.balanceOf(notary), 0);
        assert.equal(await token.totalSupply(), initialSupply);
      });

      it("Transfer 100 tokens from recipient to deployer", async () => {
        assert.equal(await token.totalSupply(), initialSupply);
        assert.equal(await token.balanceOf(deployer), initialSupply - 100);
        assert.equal(await token.balanceOf(recipient), 100);
        const result = await token.transfer(deployer, 100, { from: recipient });
        assert.equal(result.receipt.status, 1);
        assert.equal(await token.balanceOf(deployer), initialSupply);
        assert.equal(await token.balanceOf(holder), 0);
        assert.equal(await token.balanceOf(sender), 0);
        assert.equal(await token.balanceOf(recipient), 0);
        assert.equal(await token.balanceOf(recipient2), 0);
        assert.equal(await token.balanceOf(notary), 0);
        assert.equal(await token.totalSupply(), initialSupply);
      });

      it("addAllowlisted fails when extension is disabled", async () => {
        const allowlistToken = await AllowExtension.at(token.address);
        await expectRevert.unspecified(
          allowlistToken.addAllowlistedAdmin(holder, { from: deployer })
        );
      });

      it("isAllowlistedAdmin fails when extension is disabled", async () => {
        const allowlistToken = await AllowExtension.at(token.address);
        await expectRevert.unspecified(
          allowlistToken.isAllowlistedAdmin(holder)
        );
      });

      it("No one else can enable extensions", async () => {
        await expectRevert.unspecified(
          token.enableExtension(allowExt, { from: holder })
        );
      });

      it("No one else can register extensions", async () => {
        await expectRevert.unspecified(
          token.registerExtension(allowExt, { from: holder })
        );
      });

      it("Only deployer can enable extensions", async () => {
        const result2 = await token.enableExtension(allowExt, { from: deployer });

        assert.equal(result2.receipt.status, 1);
      });

      it("No one else can disable extensions", async () => {
        await expectRevert.unspecified(
          token.registerExtension(allowExt, { from: holder })
        );
      });

      it("Allow list admin can allow list several addresses", async () => {
        const allowlistToken = await AllowExtension.at(token.address);

        const addresses = [sender, holder, recipient, recipient2, notary]

        for (let i = 0; i < addresses.length; i++) {
          const adr = addresses[i];
          
          assert.equal(await allowlistToken.isAllowlisted(adr), false);

          const result = await allowlistToken.addAllowlisted(adr, { from: deployer });
          assert.equal(result.receipt.status, 1);
  
          assert.equal(await allowlistToken.isAllowlisted(adr), true);
        }
      });

      it("Mint 1000 tokens to holder", async () => {
        assert.equal(await token.totalSupply(), initialSupply);
        assert.equal(await token.balanceOf(holder), 0);
        const result = await token.mint(holder, 1000, { from: deployer });
        assert.equal(result.receipt.status, 1);
        assert.equal(await token.balanceOf(deployer), initialSupply);
        assert.equal(await token.balanceOf(holder), 1000);
        assert.equal(await token.balanceOf(sender), 0);
        assert.equal(await token.balanceOf(recipient), 0);
        assert.equal(await token.balanceOf(recipient2), 0);
        assert.equal(await token.balanceOf(notary), 0);
        assert.equal(await token.totalSupply(), initialSupply + 1000);
      });

      it("Holder Burns 100 tokens", async () => {
        assert.equal(await token.totalSupply(), initialSupply + 1000);
        assert.equal(await token.balanceOf(holder), 1000);
        const result = await token.burn(100, { from: holder });
        assert.equal(result.receipt.status, 1);
        assert.equal(await token.balanceOf(deployer), initialSupply);
        assert.equal(await token.balanceOf(holder), 1000 - 100);
        assert.equal(await token.balanceOf(sender), 0);
        assert.equal(await token.balanceOf(recipient), 0);
        assert.equal(await token.balanceOf(recipient2), 0);
        assert.equal(await token.balanceOf(notary), 0);
        assert.equal(await token.totalSupply(),  initialSupply + 1000 - 100);
      });

      it("Transfer 100 tokens from holder to recipient", async () => {
        assert.equal(await token.totalSupply(), initialSupply + 1000 - 100);
        assert.equal(await token.balanceOf(holder), 900);
        const result = await token.transfer(recipient, 100, { from: holder });
        assert.equal(result.receipt.status, 1);
        assert.equal(await token.balanceOf(deployer), initialSupply);
        assert.equal(await token.balanceOf(holder), 800);
        assert.equal(await token.balanceOf(sender), 0);
        assert.equal(await token.balanceOf(recipient), 100);
        assert.equal(await token.balanceOf(recipient2), 0);
        assert.equal(await token.balanceOf(notary), 0);
        assert.equal(await token.totalSupply(), initialSupply + 1000 - 100);
      });

      it("only minters can mint", async () => {
        assert.equal(await token.isMinter(recipient), false);
        await expectRevert.unspecified(
          token.mint(recipient2, 200, { from: recipient })
        );
      });

      it("recipient cant transfer 200 tokens to recipient2 with no balance", async () => {
        await expectRevert.unspecified(
          token.transfer(recipient2, 200, { from: recipient })
        );
      });

      it("recipient cant transferFrom 200 tokens from holder to recipient2 no balance", async () => {
        await expectRevert.unspecified(
          token.transfer(recipient2, 200, { from: recipient })
        );
      });

      it("notary can transferFrom(holder, recipient2, 200) when holder uses approve", async () => {
        await expectRevert.unspecified(
          token.transfer(recipient2, 200, { from: notary })
        );
        
        assert.equal(await token.totalSupply(), initialSupply + 1000 - 100);
        assert.equal(await token.balanceOf(holder), 800);
        assert.equal(await token.allowance(holder, notary), 0);

        const result = await token.approve(notary, 200, { from: holder });
        assert.equal(await token.allowance(holder, notary), 200);
        const result2 = await token.transferFrom(holder, recipient2, 200, { from: notary });

        assert.equal(result.receipt.status, 1);
        assert.equal(result2.receipt.status, 1);

        assert.equal(await token.balanceOf(deployer), initialSupply);
        assert.equal(await token.balanceOf(holder), 600);
        assert.equal(await token.balanceOf(sender), 0);
        assert.equal(await token.balanceOf(recipient2), 200);
        assert.equal(await token.allowance(holder, notary), 0);
        assert.equal(await token.balanceOf(notary), 0);
        assert.equal(await token.totalSupply(), initialSupply + 1000 - 100);
      });

      it("notary can transferFrom(holder, recipient2, 200) when holder uses increaseAllowance and decreaseAllowance", async () => {
        await expectRevert.unspecified(
          token.transfer(recipient2, 200, { from: notary })
        );
        
        assert.equal(await token.totalSupply(), initialSupply + 1000 - 100);
        assert.equal(await token.balanceOf(holder), 600);
        assert.equal(await token.allowance(holder, notary), 0);
  
        const result = await token.increaseAllowance(notary, 300, { from: holder });
        const result2 = await token.decreaseAllowance(notary, 100, { from: holder });

        assert.equal(await token.allowance(holder, notary), 200);
        const result3 = await token.transferFrom(holder, recipient2, 200, { from: notary });
  
        assert.equal(result.receipt.status, 1);
        assert.equal(result2.receipt.status, 1);
        assert.equal(result3.receipt.status, 1);
  
        assert.equal(await token.balanceOf(deployer), initialSupply);
        assert.equal(await token.balanceOf(holder), 400);
        assert.equal(await token.balanceOf(sender), 0);
        assert.equal(await token.balanceOf(recipient), 100);
        assert.equal(await token.balanceOf(recipient2), 400);
        assert.equal(await token.allowance(holder, recipient), 0);
        assert.equal(await token.balanceOf(notary), 0);
        assert.equal(await token.totalSupply(), initialSupply + 1000 - 100);
      });

      it("notary can burnFrom(holder, 200) when holder uses increaseAllowance and decreaseAllowance", async () => {
        await expectRevert.unspecified(
          token.transfer(recipient2, 200, { from: notary })
        );
        
        assert.equal(await token.totalSupply(), initialSupply + 1000 - 100);
        assert.equal(await token.balanceOf(holder), 400);
        assert.equal(await token.allowance(holder, notary), 0);
  
        const result = await token.increaseAllowance(notary, 300, { from: holder });
        const result2 = await token.decreaseAllowance(notary, 100, { from: holder });

        assert.equal(await token.allowance(holder, notary), 200);
        const result3 = await token.burnFrom(holder, 200, { from: notary });
  
        assert.equal(result.receipt.status, 1);
        assert.equal(result2.receipt.status, 1);
        assert.equal(result3.receipt.status, 1);
  
        assert.equal(await token.balanceOf(deployer), initialSupply);
        assert.equal(await token.balanceOf(holder), 200);
        assert.equal(await token.balanceOf(sender), 0);
        assert.equal(await token.balanceOf(recipient), 100);
        assert.equal(await token.balanceOf(recipient2), 400);
        assert.equal(await token.allowance(holder, notary), 0);
        assert.equal(await token.balanceOf(notary), 0);
        assert.equal(await token.totalSupply(), initialSupply + 1000 - 300);
      });

      it("notary can burnFrom(holder, 200) when holder uses approve", async () => {
        await expectRevert.unspecified(
          token.transfer(recipient2, 200, { from: notary })
        );
        
        assert.equal(await token.totalSupply(), initialSupply + 1000 - 300);
        assert.equal(await token.balanceOf(holder), 200);
        assert.equal(await token.allowance(holder, notary), 0);
  
        const result = await token.approve(notary, 200, { from: holder });

        assert.equal(await token.allowance(holder, notary), 200);
        const result3 = await token.burnFrom(holder, 200, { from: notary });
  
        assert.equal(result.receipt.status, 1);
        assert.equal(result3.receipt.status, 1);
  
        assert.equal(await token.balanceOf(deployer), initialSupply);
        assert.equal(await token.balanceOf(holder), 0);
        assert.equal(await token.balanceOf(sender), 0);
        assert.equal(await token.balanceOf(recipient), 100);
        assert.equal(await token.balanceOf(recipient2), 400);
        assert.equal(await token.allowance(holder, notary), 0);
        assert.equal(await token.balanceOf(notary), 0);
        assert.equal(await token.totalSupply(), initialSupply + 1000 - 500);
      });

      it("upgradeTo reverts if non-owner executes it", async () => {
        let newLogic = await ERC20LogicMock.new();

        await expectRevert.unspecified(
          token.upgradeTo(newLogic.address, "0x", { from: notary })
        );
      });

      it("when the owner upgrades, it's successful", async () => {
        let newLogic = await ERC20LogicMock.new();

        await token.upgradeTo(newLogic.address, "0x", { from: deployer });

        //Bind the token address to the mock ABI
        //so we can invoke new functions
        const upgradedTokenApi = await ERC20LogicMock.at(token.address);

        //Only mock contract has the isMock function
        assert.equal(await upgradedTokenApi.isMock(), "This is a mock!");
      });

    });
})