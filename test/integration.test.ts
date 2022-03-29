import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer, BigNumber } from "ethers";

import { sha3, getNamehash, emptyAddress, weirdNode, emptyNode, baseNode, baseLabel } from "../lib/helper";
import { isException, ensureException, expectFailure } from "../lib/test-helper";
import { deployPNS, deployPNSMultipleController, deployPNSContract } from "./scripts";

let tld = "dot";
let basePrices: any = [2000, 2000, 2000, 200, 200, 20];
let rentPrices: any = [500, 500, 500, 50, 50, 5];
let oneyear = 86400 * 365;
let tokenId = getNamehash("gavinwood100.dot");
let subTokenId = getNamehash("sub0.gavinwood100.dot");

export const revert = (messages: TemplateStringsArray) => `Error: VM Exception while processing transaction: reverted with reason string '${messages[0]}'`;

describe("PNS", async function () {
  it("Should deploy PNS contract successfully", async function () {
    let oneAddr: string, twoAddr: string, threeAddr: string, fourAddr: string, fiveAddr: string;
    let one: Signer, two: Signer, three: Signer, four: Signer, five: Signer;
    let pns: any, controller: any, controller2: any;

    [one, two, three, four, five] = await ethers.getSigners();
    [oneAddr, twoAddr, threeAddr, fourAddr, fiveAddr] = await Promise.all([one, two, three, four, five].map((s) => s.getAddress()));

    async function getFee(name: string) {
      return (await controller.totalRegisterPrice("gavinwood100", oneyear)).toString();
    }

    async function registerName(name: string, address: string) {
      let fee = getFee("gavinwood100");
      return controller.nameRegister("gavinwood100", address, oneyear, {
        value: fee,
      });
    }

    beforeEach(async () => {
      await ethers.provider.send("hardhat_reset", []);
      ({ pns, controller } = await deployPNS());
    });

    describe("nameRegister", async () => {
      let fee: string;
      let tx: any;

      it("mint subtoken and burn", async () => {
        await expect(pns.ownerOf(tokenId)).revertedWith(revert`ERC721: owner query for nonexistent token`);
        expect(await pns.exists(tokenId)).to.eq(false);

        fee = (await controller.totalRegisterPrice("gavinwood100", oneyear)).toString();
        tx = await controller.nameRegister("gavinwood100", twoAddr, oneyear, {
          value: fee,
        });

        expect(await pns.ownerOf(tokenId)).to.eq(twoAddr);
        expect(await pns.exists(tokenId)).to.eq(true);

        let subTokenId = getNamehash("sub0.gavinwood100.dot");
        let subSubTokenId = getNamehash("sub1.sub0.gavinwood100.dot");

        await controller.connect(two).mintSubdomain(threeAddr, tokenId, "sub0");
        await controller.connect(three).mintSubdomain(threeAddr, subTokenId, "sub1");

        expect(await pns.ownerOf(subTokenId)).to.eq(threeAddr);
        expect(await pns.ownerOf(subSubTokenId)).to.eq(threeAddr);

        let resp = await tx.wait();
        let blocktime = (await ethers.provider.getBlock(resp.blockNumber)).timestamp;
        let expiresAt = blocktime + 86400 * 365;

        expect(await controller.expires(tokenId)).to.eq(expiresAt);
        expect(await controller.capacity(tokenId)).to.eq(20);
        expect(await controller.children(tokenId)).to.eq(2);
        expect(await controller.origin(tokenId)).to.eq(tokenId);
        expect(await controller.available(tokenId)).to.eq(false);

        expect(await controller.nameExpires(subTokenId)).to.eq(expiresAt);
        expect(await controller.expires(subTokenId)).to.eq(0);
        expect(await controller.capacity(subTokenId)).to.eq(0);
        expect(await controller.children(subTokenId)).to.eq(0);
        expect(await controller.origin(subTokenId)).to.eq(tokenId);
        expect(await controller.available(subTokenId)).to.eq(false);
        expect(await pns.exists(subTokenId)).to.eq(true);

        // burn sub sub token

        await controller.connect(three).burn(subTokenId);
        await expect(controller.connect(two).burn(tokenId)).revertedWith(revert`subdomains should be cleared`);

        expect(await controller.nameExpires(tokenId)).to.eq(expiresAt);
        expect(await controller.expires(tokenId)).to.eq(expiresAt);
        expect(await controller.capacity(tokenId)).to.eq(20);
        expect(await controller.children(tokenId)).to.eq(1);
        expect(await controller.origin(tokenId)).to.eq(tokenId);
        expect(await controller.available(tokenId)).to.eq(false);

        expect(await controller.nameExpires(subTokenId)).to.eq(0);
        expect(await controller.expires(subTokenId)).to.eq(0);
        expect(await controller.capacity(subTokenId)).to.eq(0);
        expect(await controller.children(subTokenId)).to.eq(0);
        expect(await controller.origin(subTokenId)).to.eq(0);
        expect(await controller.available(subTokenId)).to.eq(true);

        expect(await controller.nameExpires(subSubTokenId)).to.eq(expiresAt);
        expect(await controller.expires(subSubTokenId)).to.eq(0);
        expect(await controller.capacity(subSubTokenId)).to.eq(0);
        expect(await controller.children(subSubTokenId)).to.eq(0);
        expect(await controller.origin(subSubTokenId)).to.eq(tokenId);
        expect(await controller.available(subSubTokenId)).to.eq(false);

        // burn sub token

        await controller.connect(three).burn(subSubTokenId);
        await controller.connect(two).burn(tokenId);
      });

      it("should expire after registration period", async () => {
        fee = (await controller.totalRegisterPrice("gavinwood100", oneyear)).toString();
        tx = await controller.nameRegister("gavinwood100", twoAddr, oneyear, {
          value: fee,
        });

        expect(await pns.ownerOf(tokenId)).to.eq(twoAddr);
        expect(await pns.exists(tokenId)).to.eq(true);

        let subTokenId = getNamehash("sub0.gavinwood100.dot");

        await controller.connect(two).mintSubdomain(twoAddr, tokenId, "sub0");

        expect(await pns.ownerOf(subTokenId)).to.eq(twoAddr);

        let resp = await tx.wait();
        let blocktime = (await ethers.provider.getBlock(resp.blockNumber)).timestamp;
        let expireAt = blocktime + 86400 * 365;
        let availableAt = expireAt + 86400 * 360;

        expect(await controller.expires(tokenId)).to.eq(expireAt);
        expect(await controller.capacity(tokenId)).to.eq(20);
        expect(await controller.children(tokenId)).to.eq(1);
        expect(await controller.origin(tokenId)).to.eq(tokenId);
        expect(await controller.available(tokenId)).to.eq(false);

        await ethers.provider.send("evm_setNextBlockTimestamp", [expireAt + 86400 * 360]);
        await ethers.provider.send("evm_mine", []);

        expect(await controller.available(tokenId)).to.eq(false);

        await ethers.provider.send("evm_setNextBlockTimestamp", [availableAt + 100]);
        await ethers.provider.send("evm_mine", []);

        expect(await controller.available(tokenId)).to.eq(true);

        await expect(controller.connect(three).burn(tokenId)).revertedWith(revert`subdomains should be cleared`);
        await controller.connect(three).burn(subTokenId);
        await controller.connect(three).burn(tokenId);

        tx = await controller.nameRegister("gavinwood100", twoAddr, oneyear, {
          value: fee,
        });

        expect(await pns.ownerOf(tokenId)).to.eq(twoAddr);
        expect(await pns.exists(tokenId)).to.eq(true);
        expect(await controller.available(tokenId)).to.eq(false);
      });

      it("should register a new domain name with config and renew it", async () => {
        fee = (await controller.totalRegisterPrice("gavinwood100", 86400 * 365)).toString();
        await controller.nameRegisterWithConfig("gavinwood100", twoAddr, 86400 * 365, [sha3("text.email")], ["user@example.com"], {
          value: fee,
        });

        expect(await pns.ownerOf(tokenId)).to.eq(twoAddr);
        expect(await pns.exists(tokenId)).to.eq(true);
        expect(await controller.capacity(tokenId)).to.eq(20);
        expect(await controller.children(tokenId)).to.eq(0);
        expect(await controller.origin(tokenId)).to.eq(tokenId);
        expect(await controller.available(tokenId)).to.eq(false);

        expect(await pns.get("text.email", tokenId)).to.eq("user@example.com");

        let expires: BigNumber;
        let newExpires: BigNumber;

        expires = await controller.expires(tokenId);

        fee = (await controller.totalRegisterPrice("gavinwood100", 86400 * 10)).toString();
        await controller.renew("gavinwood100", 86400 * 10, {
          value: fee,
        });

        newExpires = await controller.expires(tokenId);
        expect(newExpires.sub(expires)).to.eq(86400 * 10);
        expires = newExpires;

        await controller.renewByManager("gavinwood100", 86400 * 100);

        newExpires = await controller.expires(tokenId);
        expect(newExpires.sub(expires)).to.eq(86400 * 100);
      });

      it("should register a new domain name by manager", async () => {
        await expect(controller.connect(three).nameRegisterByManager("gavinwood100", twoAddr, 86400 * 365)).revertedWith(
          revert`caller is not the root or manager`
        );
        await controller.connect(one).nameRegisterByManager("gavinwood100", twoAddr, 86400 * 365);

        expect(await pns.ownerOf(tokenId)).to.eq(twoAddr);
        expect(await pns.exists(tokenId)).to.eq(true);
        expect(await controller.capacity(tokenId)).to.eq(20);
        expect(await controller.children(tokenId)).to.eq(0);
        expect(await controller.origin(tokenId)).to.eq(tokenId);
        expect(await controller.available(tokenId)).to.eq(false);

        let expires: BigNumber;
        let newExpires: BigNumber;

        expires = await controller.expires(tokenId);

        await expect(controller.connect(three).renewByManager("gavinwood100", 86400 * 100)).revertedWith(revert`caller is not the root or manager`);
        await controller.connect(one).renewByManager("gavinwood100", 86400 * 100);

        newExpires = await controller.expires(tokenId);
        expect(newExpires.sub(expires)).to.eq(86400 * 100);
      });
    });
  });
});
