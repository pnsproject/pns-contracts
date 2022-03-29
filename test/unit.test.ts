import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer, BigNumber } from "ethers";

import { sha3, getNamehash, emptyAddress, weirdNode, emptyNode, baseNode, baseLabel } from "../lib/helper";
import { isException, ensureException, expectFailure } from "../lib/test-helper";
import { deployPNS, deployPNSMultipleController, deployPNSExtraController, deployPNSContract } from "./scripts";
import { generateRedeemCode } from "../lib/sdk";

let tld = "dot";
let basePrices: any = [2000, 2000, 2000, 200, 200, 20];
let rentPrices: any = [500, 500, 500, 50, 50, 5];
let oneyear = 86400 * 365;
let tokenId = getNamehash("gavinwood100.dot");
let subTokenId = getNamehash("sub0.gavinwood100.dot");
let altTokenId = getNamehash("gavinwood100.com");

export const revert = (messages: TemplateStringsArray) => `Error: VM Exception while processing transaction: reverted with reason string '${messages[0]}'`;

describe("PNS", async function () {
  it("Should init the test", async function () {
    let oneAddr: string, twoAddr: string, threeAddr: string, fourAddr: string, fiveAddr: string;
    let one: Signer, two: Signer, three: Signer, four: Signer, five: Signer;
    let pns: any, controller: any, controller2: any;
    let nameRecord: any, expiresAt: any, expire: any, newExpire: BigNumber, origin: any, children: any, capacity: any;
    let tx: any, fee: string;

    [one, two, three, four, five] = await ethers.getSigners();
    [oneAddr, twoAddr, threeAddr, fourAddr, fiveAddr] = await Promise.all([one, two, three, four, five].map((s) => s.getAddress()));

    function getFee(name: string) {
      return controller.totalRegisterPrice(name, oneyear);
    }

    async function registerName(name?: string, address?: string) {
      name = name || "gavinwood100";
      address = address || twoAddr;
      fee = await getFee(name);
      return controller.nameRegister(name, address, oneyear, {
        value: fee,
      });
    }

    async function getExpire(tokenId: any) {
      return (await controller.nameRecord(tokenId)).expire;
    }

    async function checkNameData(tokenId: string, origin: any, expire: Number, capacity: Number, children: Number) {
      let nameRecord = await controller.nameRecord(tokenId);
      expect(nameRecord.origin).to.eq(origin);
      expect(nameRecord.expire).to.eq(expire);
      expect(nameRecord.capacity).to.eq(capacity);
      expect(nameRecord.children).to.eq(children);
    }

    beforeEach(async () => {
      await ethers.provider.send("hardhat_reset", []);
      ({ pns, controller } = await deployPNS());
    });

    describe("PNS#root", async () => {
      it("should be equal to controller address", async () => {
        expect(await pns.root()).to.eq(oneAddr);
        expect(await controller.root()).to.eq(oneAddr);
        expect(await pns.isManager(controller.address)).to.eq(true);
      });
    });

    describe("PNS#transferRootOwnership", async () => {
      it("should be transferable by root", async () => {
        await pns.connect(one).transferRootOwnership(twoAddr);
        expect(await pns.root()).to.eq(twoAddr);
      });

      it("should not be transferable by non root", async () => {
        await expect(pns.connect(three).transferRootOwnership(twoAddr)).revertedWith(revert`caller is not root`);
      });
    });

    describe("PNS#approve", async () => {
      it("should revert for nonexistent token", async () => {
        await expect(pns.isApprovedOrOwner(oneAddr, tokenId)).revertedWith(revert`ERC721: operator query for nonexistent token`);
      });

      it("should not be approvable by non-owner", async () => {
        await registerName("gavinwood100", oneAddr);

        expect(await pns.isApprovedOrOwner(oneAddr, tokenId)).to.eq(true);
        expect(await pns.isApprovedOrOwner(twoAddr, tokenId)).to.eq(false);

        await expect(pns.connect(three).approve(twoAddr, tokenId)).revertedWith(revert`ERC721: approve caller is not owner nor approved for all`);
        expect(await pns.isApprovedOrOwner(threeAddr, tokenId)).to.eq(false);
      });

      it("should be approvable by owner", async () => {
        await registerName("gavinwood100", oneAddr);

        await pns.connect(one).approve(twoAddr, tokenId);

        expect(await pns.isApprovedOrOwner(oneAddr, tokenId)).to.eq(true);
        expect(await pns.isApprovedOrOwner(twoAddr, tokenId)).to.eq(true);
        expect(await pns.isApprovedOrOwner(threeAddr, tokenId)).to.eq(false);
      });
    });

    describe("PNS#ownerOf", async () => {
      it("should revert for nonexistent token", async () => {
        await expect(pns.ownerOf(tokenId)).revertedWith(revert`ERC721: owner query for nonexistent token`);
        await expect(pns.ownerOf(emptyNode)).revertedWith(revert`ERC721: owner query for nonexistent token`);
        await expect(pns.ownerOf(weirdNode)).revertedWith(revert`ERC721: owner query for nonexistent token`);
      });

      it("should return current owner of tokenId", async () => {
        await registerName("gavinwood100", oneAddr);
        expect(await pns.ownerOf(tokenId)).to.eq(oneAddr);
      });
    });

    describe("PNS#exists", async () => {
      it("should return if tokenId exists", async () => {
        expect(await pns.exists(tokenId)).to.eq(false);
        expect(await pns.exists(emptyNode)).to.eq(false);
        expect(await pns.exists(baseNode)).to.eq(true);
        expect(await pns.exists(weirdNode)).to.eq(false);

        await registerName("gavinwood100", oneAddr);

        expect(await pns.exists(tokenId)).to.eq(true);
      });
    });

    describe("PNS#mint", async () => {
      it("should be able to mint new token by root", async () => {
        let newBaseNode = getNamehash("test");
        expect(await pns.root()).to.eq(oneAddr);

        await pns.connect(one).mint(twoAddr, newBaseNode);
        expect(await pns.ownerOf(newBaseNode)).to.eq(twoAddr);

        await pns.connect(one).mint(twoAddr, tokenId);
        expect(await pns.ownerOf(tokenId)).to.eq(twoAddr);
      });

      it("should revert for duplicated tokenId", async () => {
        await pns.connect(one).mint(twoAddr, tokenId);
        await expect(pns.connect(one).mint(threeAddr, tokenId)).revertedWith(revert`ERC721: token already minted`);
      });

      it("should be able to mint subtoken", async () => {
        await pns.connect(one).mint(twoAddr, tokenId);
        await pns.connect(one).mintSubdomain(threeAddr, tokenId, "sub0");
        expect(await pns.ownerOf(subTokenId)).to.eq(threeAddr);
      });

      it("should be able to burn token", async () => {
        await pns.connect(one).mint(twoAddr, tokenId);
        await pns.connect(one).mintSubdomain(threeAddr, tokenId, "sub0");
        await pns.connect(one).burn(tokenId);

        expect(await pns.exists(tokenId)).to.eq(false);
        expect(await pns.exists(subTokenId)).to.eq(true);

        await expect(pns.connect(one).burn(tokenId)).revertedWith(revert`ERC721: owner query for nonexistent token`);
      });

      it("should be able to burn subtoken", async () => {
        await pns.connect(one).mint(twoAddr, tokenId);
        await pns.connect(one).mintSubdomain(threeAddr, tokenId, "sub0");
        await pns.connect(one).burn(subTokenId);
        expect(await pns.exists(subTokenId)).to.eq(false);
      });

      it("should not be able to mint or burn by non-root", async () => {
        await expect(pns.connect(two).mint(twoAddr, tokenId)).revertedWith(revert`caller is not root`);

        await pns.connect(one).mint(twoAddr, tokenId);
        await expect(pns.connect(two).mintSubdomain(threeAddr, tokenId, "sub0")).revertedWith(revert`caller is not root or manager`);

        await expect(pns.connect(two).burn(tokenId)).revertedWith(revert`caller is not root or manager`);
      });
    });

    describe("PNSController#transferRootOwnership", async () => {
      it("should set root correctly", async () => {
        expect(await controller.root()).to.eq(oneAddr);
        expect(await controller.isManager(oneAddr)).to.eq(true);
        await controller.connect(one).transferRootOwnership(twoAddr);
        expect(await controller.root()).to.eq(twoAddr);
      });
    });

    describe("PNSController#setManager", async () => {
      it("should set new manager correctly", async () => {
        expect(await controller.root()).to.eq(oneAddr);
        await expect(controller.connect(two).setManager(threeAddr, true)).revertedWith(revert`caller is not root`);

        await controller.connect(one).setManager(twoAddr, true);
        expect(await controller.isManager(twoAddr)).to.eq(true);
      });
    });

    describe("PNSController#nameRegister", async () => {
      it("should register a new domain name", async () => {
        fee = (await controller.totalRegisterPrice("gavinwood100", 86400 * 365)).toString();
        tx = await controller.nameRegister("gavinwood100", twoAddr, 86400 * 365, {
          value: fee,
        });
        expect(await pns.ownerOf(tokenId)).to.eq(twoAddr);
        expect(await pns.exists(tokenId)).to.eq(true);
      });

      it("should register a new domain name for 100 years", async () => {
        fee = (await controller.totalRegisterPrice("gavinwood100", 86400 * 365 * 2)).toString();
        await controller.nameRegister("gavinwood100", twoAddr, 86400 * 365, {
          value: fee,
        });
      });

      it("should register a new domain name for 100 days", async () => {
        fee = (await controller.totalRegisterPrice("gavinwood100", 86400 * 100)).toString();
        await controller.nameRegister("gavinwood100", twoAddr, 86400 * 100, {
          value: fee,
        });
      });

      it("should not register a domain name for 1 days", async () => {
        fee = (await controller.totalRegisterPrice("gavinwood104", 86400 * 1)).toString();
        await expect(
          controller.nameRegister("gavinwood104", twoAddr, 86400 * 1, {
            value: fee,
          })
        ).revertedWith(revert`duration too small`);
      });

      it("should not register a short domain name", async () => {
        fee = (await controller.totalRegisterPrice("gavinwood", 86400 * 365)).toString();
        await expect(controller.nameRegister("gavinwood", twoAddr, 86400 * 365, { value: fee })).revertedWith(revert`name too short`);
      });

      it("should not register the same domain name twice", async () => {
        fee = (await controller.totalRegisterPrice("gavinwood100", 86400 * 365)).toString();
        await controller.nameRegister("gavinwood100", twoAddr, 86400 * 365, {
          value: fee,
        });

        await expect(controller.nameRegister("gavinwood100", twoAddr, 86400 * 365, { value: fee })).revertedWith(revert`ERC721: token already minted`);
      });

      it("should not register with an empty address", async () => {
        fee = (await controller.totalRegisterPrice("gavinwood100", 86400 * 365)).toString();
        await expect(controller.nameRegister("gavinwood100", emptyAddress, 86400 * 365, { value: fee })).revertedWith(revert`ERC721: mint to the zero address`);
      });

      it("should register a new unicode domain name", async () => {
        await controller.nameRegister("这是一个中文的PNS域名", twoAddr, 86400 * 365, {
          value: fee,
        });
        expect(await pns.ownerOf(getNamehash("这是一个中文的PNS域名.dot"))).to.eq(twoAddr);
      });

      it("should be able to register a strange domain name, but not resolvable", async () => {
        await controller.nameRegister("abc.def.ghi", twoAddr, 86400 * 365, {
          value: fee,
        });
        expect(await pns.exists(getNamehash("abc.def.ghi.dot"))).to.eq(false);
      });

      it("should cost expected fee", async () => {
        expect(await controller.root()).to.eq(oneAddr);

        let beforeRootBalance = await ethers.provider.getBalance(oneAddr);
        let beforeUserBalance = await ethers.provider.getBalance(twoAddr);

        fee = (await controller.totalRegisterPrice("gavinwood100", 86400 * 365)).toString();
        tx = await controller.connect(two).nameRegister("gavinwood100", twoAddr, 86400 * 365, {
          value: fee,
        });

        let afterRootBalance = await ethers.provider.getBalance(oneAddr);
        let afterUserBalance = await ethers.provider.getBalance(twoAddr);

        let result = await tx.wait();
        let gas = result.cumulativeGasUsed.mul(result.effectiveGasPrice);

        let rootBalanceDelta = afterRootBalance.sub(beforeRootBalance);
        let userBalanceDelta = beforeUserBalance.sub(afterUserBalance);

        expect(userBalanceDelta.sub(rootBalanceDelta)).to.eq(gas);
        expect(rootBalanceDelta).to.eq(fee);
      });

      it("should refund extra value", async () => {
        expect(await controller.root()).to.eq(oneAddr);

        let beforeRootBalance = await ethers.provider.getBalance(oneAddr);
        let beforeUserBalance = await ethers.provider.getBalance(twoAddr);

        fee = await controller.totalRegisterPrice("gavinwood100", 86400 * 365);
        let highfee = await controller.totalRegisterPrice("gavinwood100", 86400 * 365 * 2);
        tx = await controller.connect(two).nameRegister("gavinwood100", twoAddr, 86400 * 365, {
          value: highfee,
        });

        let afterRootBalance = await ethers.provider.getBalance(oneAddr);
        let afterUserBalance = await ethers.provider.getBalance(twoAddr);

        let result = await tx.wait();
        let gas = result.cumulativeGasUsed.mul(result.effectiveGasPrice);

        let rootBalanceDelta = afterRootBalance.sub(beforeRootBalance);
        let userBalanceDelta = beforeUserBalance.sub(afterUserBalance);

        expect(userBalanceDelta.sub(rootBalanceDelta)).to.eq(gas);
        expect(rootBalanceDelta).to.eq(fee);
      });

      it("should fail with insufficient value", async () => {
        expect(await controller.root()).to.eq(oneAddr);

        fee = await controller.totalRegisterPrice("gavinwood100", 86400 * 365);
        let lowfee = await controller.totalRegisterPrice("gavinwood100", (86400 * 365) / 2);
        tx = await expect(
          controller.connect(two).nameRegister("gavinwood100", twoAddr, 86400 * 365, {
            value: lowfee,
          })
        ).revertedWith(revert`insufficient fee`);
      });
    });

    describe("PNSController#nameRegister", async () => {
      it("should register a new domain name with config", async () => {
        fee = (await controller.totalRegisterPrice("gavinwood100", 86400 * 365)).toString();
        await controller.nameRegisterWithConfig("gavinwood100", twoAddr, 86400 * 365, [sha3("text.email")], ["user@example.com"], {
          value: fee,
        });
      });

      it("should register a new domain name with empty config", async () => {
        fee = (await controller.totalRegisterPrice("gavinwood100", 86400 * 365)).toString();
        await controller.nameRegisterWithConfig("gavinwood100", twoAddr, 86400 * 365, [], [], {
          value: fee,
        });
      });
    });

    describe("PNSController#nameRedeem", async () => {
      it("should redeem a new domain name", async () => {
        let sig = await generateRedeemCode(sha3("gavinwood100"), twoAddr, 86400 * 365, one);
        await controller.nameRedeem("gavinwood100", twoAddr, 86400 * 365, sig);
        expect(await pns.exists(tokenId)).to.eq(true);
      });

      it("should not redeem with invalid name", async () => {
        let sig = await generateRedeemCode(sha3("gavinwood101"), twoAddr, 86400 * 365, one);
        await expect(controller.nameRedeem("gavinwood100", twoAddr, 86400 * 365, sig)).revertedWith(`code invalid`);
      });

      it("should not redeem with invalid address", async () => {
        let sig = await generateRedeemCode(sha3("gavinwood101"), threeAddr, 86400 * 365, one);
        await expect(controller.nameRedeem("gavinwood100", twoAddr, 86400 * 365, sig)).revertedWith(`code invalid`);
      });

      it("should not redeem with invalid signer", async () => {
        let sig = await generateRedeemCode(sha3("gavinwood101"), threeAddr, 86400 * 365, three);
        await expect(controller.nameRedeem("gavinwood100", twoAddr, 86400 * 365, sig)).revertedWith(`code invalid`);
      });
    });

    describe("PNSController#renew", async () => {
      beforeEach(async () => {
        await registerName("gavinwood100", twoAddr);
      });

      it("should renew an existing domain name", async () => {
        expire = await getExpire(tokenId);

        fee = (await controller.renewPrice("gavinwood100", 86400)).toString();
        await controller.renew("gavinwood100", 86400, {
          value: fee,
        });

        newExpire = await getExpire(tokenId);
        expect(newExpire.sub(expire)).to.eq(86400);

        fee = (await controller.renewPrice("gavinwood100", 86400 * 100)).toString();
        await controller.renew("gavinwood100", 86400 * 100, {
          value: fee,
        });

        expire = newExpire;
        newExpire = await getExpire(tokenId);
        expect(newExpire.sub(expire)).to.eq(86400 * 100);
      });

      it("should renew a domain name with expected fee", async () => {
        expect(await controller.root()).to.eq(oneAddr);

        let beforeRootBalance = await ethers.provider.getBalance(oneAddr);
        let beforeUserBalance = await ethers.provider.getBalance(twoAddr);

        expire = (await controller.nameRecord(tokenId)).expire;

        fee = (await controller.renewPrice("gavinwood100", 86400)).toString();
        tx = await controller.connect(two).renew("gavinwood100", 86400, {
          value: fee,
        });

        let afterRootBalance = await ethers.provider.getBalance(oneAddr);
        let afterUserBalance = await ethers.provider.getBalance(twoAddr);

        let rootBalanceDelta = afterRootBalance.sub(beforeRootBalance);
        let userBalanceDelta = beforeUserBalance.sub(afterUserBalance);

        let result = await tx.wait();
        let gas = result.cumulativeGasUsed.mul(result.effectiveGasPrice);

        expect(userBalanceDelta.sub(rootBalanceDelta)).to.eq(gas);
        expect(rootBalanceDelta).to.eq(fee);

        newExpire = await getExpire(tokenId);
        expect(newExpire.sub(expire)).to.eq(86400);

        fee = (await controller.renewPrice("gavinwood100", 86400 * 100)).toString();
        await controller.renew("gavinwood100", 86400 * 100, {
          value: fee,
        });
        expire = newExpire;
        newExpire = await getExpire(tokenId);
        expect(newExpire.sub(expire)).to.eq(86400 * 100);
      });
    });

    describe("PNSController#renewByManager", async () => {
      it("should renew an existing domain name by manager", async () => {
        await registerName("gavinwood100", twoAddr);

        expire = (await controller.nameRecord(tokenId)).expire;

        await controller.renewByManager("gavinwood100", 86400 * 100);

        newExpire = (await controller.nameRecord(tokenId)).expire;
        expect(newExpire.sub(expire)).to.eq(86400 * 100);
      });
    });

    describe("PNSController#mintSubdomain", async () => {
      it("should be able to mint subdomains", async () => {
        await registerName("gavinwood100", twoAddr);

        await expect(controller.connect(three).mintSubdomain(threeAddr, tokenId, "sub0")).revertedWith(revert`not owner nor approved`);

        await controller.connect(two).mintSubdomain(threeAddr, tokenId, "sub0");
        expect(await pns.ownerOf(getNamehash("sub0.gavinwood100.dot"))).to.eq(threeAddr);
      });

      it("should not mint subdomains for an empty domain", async () => {
        await registerName("gavinwood100", twoAddr);

        await expect(controller.connect(two).mintSubdomain(emptyAddress, tokenId, "sub0")).revertedWith(revert`ERC721: mint to the zero address`);
      });

      it("should not mint subdomains to empty address", async () => {
        await registerName("gavinwood100", twoAddr);

        await expect(controller.connect(two).mintSubdomain(threeAddr, weirdNode, "sub0")).revertedWith(revert`ERC721: operator query for nonexistent token`);
      });

      it("should not mint subdomains twice", async () => {
        await registerName("gavinwood100", twoAddr);

        await controller.connect(two).mintSubdomain(threeAddr, tokenId, "sub0");
        await expect(controller.connect(two).mintSubdomain(threeAddr, tokenId, "sub0")).revertedWith(revert`ERC721: token already minted`);
      });
    });

    describe("PNSController#nameRecord", async () => {
      it("should register a new domain name with metadata", async () => {
        await registerName("gavinwood100", twoAddr);

        nameRecord = await controller.nameRecord(tokenId);
        expect(nameRecord.capacity).to.eq(20);
        expect(nameRecord.children).to.eq(0);
        expect(nameRecord.origin).to.eq(tokenId);
        expect(await controller.available(tokenId)).to.eq(false);
      });

      it("should register a domain name and burn with expected metadata", async () => {
        let subSubTokenId = getNamehash("sub1.sub0.gavinwood100.dot");
        tx = await registerName("gavinwood100", twoAddr);
        let resp = await tx.wait();
        let ts = (await ethers.provider.getBlock(resp.blockNumber)).timestamp + 86400 * 365;

        await controller.connect(two).mintSubdomain(threeAddr, tokenId, "sub0");
        await controller.connect(three).mintSubdomain(threeAddr, subTokenId, "sub1");

        expect(await pns.ownerOf(tokenId)).to.eq(twoAddr);
        expect(await pns.ownerOf(subTokenId)).to.eq(threeAddr);
        expect(await pns.ownerOf(subSubTokenId)).to.eq(threeAddr);

        nameRecord = await controller.nameRecord(tokenId);

        expire = nameRecord.expire;

        await checkNameData(tokenId, tokenId, ts, 20, 2);
        expect(await controller.available(tokenId)).to.eq(false);

        await checkNameData(subTokenId, tokenId, 0, 0, 0);
        expect(await controller.nameExpired(subTokenId)).to.eq(false);
        expect(await pns.exists(subTokenId)).to.eq(true);

        // after subTokenId burn
        await controller.connect(three).burn(subTokenId);
        await expect(controller.connect(two).burn(tokenId)).revertedWith(revert`subdomains not cleared`);
        await checkNameData(tokenId, tokenId, ts, 20, 1);
        await checkNameData(subTokenId, 0, 0, 0, 0);

        expect(await controller.nameExpired(subTokenId)).to.eq(true);
        expect(await controller.available(subTokenId)).to.eq(true);

        await checkNameData(subSubTokenId, tokenId, 0, 0, 0);
        expect(await controller.available(subSubTokenId)).to.eq(false);

        await controller.connect(three).burn(subSubTokenId);
        await controller.connect(two).burn(tokenId);

        await checkNameData(subSubTokenId, 0, 0, 0, 0);
      });
    });

    describe("PNSController#nameExpired", async () => {
      it("should expire after registration period", async () => {
        await registerName();

        expiresAt = (await controller.nameRecord(tokenId)).expire;

        await ethers.provider.send("evm_setNextBlockTimestamp", [expiresAt.toNumber() + 86400 * 360]);
        await ethers.provider.send("evm_mine", []);

        expect(await controller.nameExpired(tokenId)).to.eq(false);

        await ethers.provider.send("evm_setNextBlockTimestamp", [expiresAt.toNumber() + 86400 * 365 + 100]);
        await ethers.provider.send("evm_mine", []);

        expect(await controller.nameExpired(tokenId)).to.eq(true);
      });
    });

    describe("PNSController#setCapacity", async () => {
      async function getCapacity(tokenId: string) {
        return (await controller.nameRecord(tokenId)).capacity;
      }
      async function getChildren(tokenId: string) {
        return (await controller.nameRecord(tokenId)).children;
      }

      beforeEach(async () => {
        await registerName("gavinwood100", twoAddr);
      });

      it("should be able to set capacity by manager", async () => {
        expect(await getCapacity(tokenId)).to.eq(20);
        await controller.connect(one).setCapacityByManager(tokenId, 40);
        expect(await getCapacity(tokenId)).to.eq(40);
        await controller.connect(one).setCapacityByManager(tokenId, 10);
        expect(await getCapacity(tokenId)).to.eq(10);
      });

      it("should be able to set capacity with fee", async () => {
        expect(await getCapacity(tokenId)).to.eq(20);
        await expect(controller.connect(one).setCapacity(tokenId, 40)).revertedWith(`insufficient fee`);
        let capfee = await controller.getCapacityPrice(20);
        await controller.connect(one).setCapacity(tokenId, 40, { value: capfee });
        expect(await getCapacity(tokenId)).to.eq(40);
      });

      it("should not mint subdomains excceed capacity", async () => {
        await controller.connect(one).setCapacityByManager(tokenId, 3);
        expect(await getCapacity(tokenId)).to.eq(3);
        await controller.connect(two).mintSubdomain(threeAddr, tokenId, "sub0");
        await controller.connect(two).mintSubdomain(threeAddr, tokenId, "sub1");
        await controller.connect(two).mintSubdomain(threeAddr, tokenId, "sub2");
        await expect(controller.connect(two).mintSubdomain(threeAddr, tokenId, "sub3")).revertedWith(revert`reach subdomain capacity`);
      });
    });

    describe("PNSController#burn", async () => {
      beforeEach(async () => {
        await registerName("gavinwood100", twoAddr);
      });

      it("should be able to burn domains", async () => {
        await controller.connect(two).burn(tokenId);

        expect(await pns.exists(tokenId)).to.eq(false);
      });

      it("should be able to burn subdomains", async () => {
        await controller.connect(two).mintSubdomain(threeAddr, tokenId, "sub0");

        expect(await pns.exists(subTokenId)).to.eq(true);

        await controller.connect(three).burn(subTokenId);

        expect(await pns.exists(subTokenId)).to.eq(false);
      });

      it("should be able to burnBatch token", async () => {
        await controller.connect(two).mintSubdomain(threeAddr, tokenId, "sub0");

        expect(await pns.exists(subTokenId)).to.eq(true);

        await controller.connect(one).burnBatch([subTokenId, tokenId]);

        expect(await pns.exists(subTokenId)).to.eq(false);
      });

      it("should not be able to burnBatch token by non-root", async () => {
        await controller.connect(two).mintSubdomain(threeAddr, tokenId, "sub0");

        expect(await pns.exists(subTokenId)).to.eq(true);

        await expect(controller.connect(two).burnBatch([subTokenId, tokenId])).revertedWith(revert`caller is not root or manager`);
      });

      it("should be able to burn subdomains by parent owner", async () => {
        await controller.connect(two).mintSubdomain(threeAddr, tokenId, "sub0");

        expect(await pns.exists(subTokenId)).to.eq(true);

        await controller.connect(two).burn(subTokenId);

        expect(await pns.exists(subTokenId)).to.eq(false);
      });

      it("should not be able to burn by non-owner", async () => {
        await expect(controller.connect(three).burn(tokenId)).revertedWith(revert`not owner nor approved`);

        expect(await pns.exists(tokenId)).to.eq(true);
      });

      it("should be able to burn by root", async () => {
        await controller.connect(one).burn(tokenId);

        expect(await pns.exists(tokenId)).to.eq(false);
      });
    });

    describe("PNSController#nameRegister with update min_registration_length", async () => {
      it("should register a new domain name", async () => {
        let pricefeed = await controller.priceFeed();

        await registerName("gavinwood100", twoAddr);
        await registerName("gavinwood0", twoAddr);
        await expect(registerName("gavinwood", twoAddr)).revertedWith(revert`name too short`);
        await expect(registerName("gavinwoo", twoAddr)).revertedWith(revert`name too short`);
        await expect(registerName("gavin", twoAddr)).revertedWith(revert`name too short`);
        await expect(registerName("gav", twoAddr)).revertedWith(revert`name too short`);
        await expect(registerName("g", twoAddr)).revertedWith(revert`name too short`);

        await controller.connect(one).setContractConfig(7, 8, 28 * 86400, 360 * 86400, 20, 100, pricefeed);
        await expect(await controller.MIN_REGISTRATION_LENGTH()).to.eq(8);

        await registerName("gavinwood101", twoAddr);
        await registerName("gavinwood1", twoAddr);
        await registerName("gavinwood", twoAddr);
        await registerName("gavinwoo", twoAddr);

        await expect(registerName("gavin", twoAddr)).revertedWith(revert`name too short`);
        await expect(registerName("gav", twoAddr)).revertedWith(revert`name too short`);
        await expect(registerName("g", twoAddr)).revertedWith(revert`name too short`);

        await controller.connect(one).setContractConfig(7, 5, 28 * 86400, 360 * 86400, 20, 100, pricefeed);
        await expect(await controller.MIN_REGISTRATION_LENGTH()).to.eq(5);

        await registerName("gavinwo", twoAddr);
        await registerName("gavin", twoAddr);
        await expect(registerName("gav2", twoAddr)).revertedWith(revert`name too short`);
        await expect(registerName("g2", twoAddr)).revertedWith(revert`name too short`);

        await controller.connect(one).setContractConfig(7, 3, 28 * 86400, 360 * 86400, 20, 100, pricefeed);
        await expect(await controller.MIN_REGISTRATION_LENGTH()).to.eq(3);
        await registerName("gav", twoAddr);
        await expect(registerName("g", twoAddr)).revertedWith(revert`name too short`);
      });
    });

    describe("PNSController#setPrices", async () => {
      it("should be able to set the price", async () => {
        expect(await controller.getTokenPrice()).to.eq(10000000000);
        let prices = await controller.getPrices();
        prices = [prices[0].map((x: BigNumber) => x.toNumber()), prices[1].map((x: BigNumber) => x.toNumber())];

        expect(prices).to.deep.equal([
          [2000, 2000, 2000, 200, 200, 20],
          [500, 500, 500, 50, 50, 5],
        ]);

        basePrices = [200, 200, 20];
        rentPrices = [50, 50, 5];
        await controller.setPrices(basePrices, rentPrices);

        prices = await controller.getPrices();
        prices = [prices[0].map((x: BigNumber) => x.toNumber()), prices[1].map((x: BigNumber) => x.toNumber())];
        expect(prices).to.deep.equal([
          [200, 200, 20],
          [50, 50, 5],
        ]);
      });

      it("should be able to get the base and rent price", async () => {
        basePrices = [200, 200, 20];
        rentPrices = [50, 50, 5];
        await controller.setPrices(basePrices, rentPrices);

        expect(await controller.basePrice("a")).to.eq(200);
        expect(await controller.basePrice("aa")).to.eq(200);
        expect(await controller.basePrice("aaa")).to.eq(20);
        expect(await controller.basePrice("aaaa")).to.eq(20);
        expect(await controller.basePrice("aaaaa")).to.eq(20);
        expect(await controller.basePrice("aaaaaa")).to.eq(20);
        expect(await controller.basePrice("aaaaaaa")).to.eq(20);

        expect(await controller.rentPrice("a", 0)).to.eq(0);
        expect(await controller.rentPrice("a", 1)).to.eq(50);
        expect(await controller.rentPrice("a", 86400)).to.eq(4320000);
        expect(await controller.rentPrice("a", 86400 * 365)).to.eq(1576800000);
        expect(await controller.rentPrice("aa", 86400)).to.eq(4320000);
        expect(await controller.rentPrice("aaa", 86400)).to.eq(432000);
        expect(await controller.rentPrice("aaaa", 86400)).to.eq(432000);
        expect(await controller.rentPrice("aaaaa", 86400)).to.eq(432000);
        expect(await controller.rentPrice("aaaaaa", 86400)).to.eq(432000);
      });
    });

    describe("PNSController#setNameBatch", async () => {
      it("should register a new domain name", async () => {
        await pns.mintSubdomainBatch([twoAddr], [baseNode], ["gavinwood100"]);
        await controller.setMetadataBatch([tokenId, tokenId, 1677200000, 20, 0]);

        expect(await pns.ownerOf(tokenId)).to.eq(twoAddr);
        expect(await pns.exists(tokenId)).to.eq(true);

        checkNameData(tokenId, tokenId, 1677200000, 20, 0);
        await controller.connect(one).burn(tokenId);
      });
    });

    describe("Multiple controller", async () => {
      it("should register a new domain name", async () => {
        ({ pns, controller, controller2 } = await deployPNSMultipleController());

        await registerName("gavinwood100", twoAddr);

        fee = (await controller2.totalRegisterPrice("gavinwood100", 86400 * 365)).toString();
        await controller2.nameRegister("gavinwood100", twoAddr, 86400 * 365, {
          value: fee,
        });

        expect(await pns.ownerOf(tokenId)).to.eq(twoAddr);
        expect(await pns.ownerOf(altTokenId)).to.eq(twoAddr);

        await expect(controller.connect(one).burn(altTokenId)).revertedWith(revert`missing metadata`);
        await expect(controller2.connect(one).burn(tokenId)).revertedWith(revert`missing metadata`);

        await controller.connect(one).burn(tokenId);
        await controller2.connect(one).burn(altTokenId);
      });
    });

    describe("swap controller", async () => {
      let altTokenId = getNamehash("gavinwood101.dot");

      beforeEach(async () => {
        ({ pns, controller, controller2 } = await deployPNSExtraController());
        fee = (await controller.totalRegisterPrice("gavinwood100", 86400 * 365)).toString();
      });

      it("should register a new domain name", async () => {
        tx = await controller.nameRegister("gavinwood100", twoAddr, 86400 * 365, {
          value: fee,
        });

        await pns.setManager(controller2.address, true);
        await pns.setManager(controller.address, false);

        tx = await controller2.nameRegister("gavinwood101", twoAddr, 86400 * 365, {
          value: fee,
        });

        fee = (await controller2.totalRegisterPrice("gavinwood100", 86400 * 365)).toString();
        await expect(
          controller2.nameRegister("gavinwood100", twoAddr, 86400 * 365, {
            value: fee,
          })
        ).revertedWith(revert`ERC721: token already minted`);

        expect(await pns.ownerOf(tokenId)).to.eq(twoAddr);
        expect(await pns.ownerOf(altTokenId)).to.eq(twoAddr);

        await expect(controller.connect(one).burn(altTokenId)).revertedWith(revert`missing metadata`);
        await expect(controller.connect(one).burn(tokenId)).revertedWith(revert`caller is not root or manager`);

        // controller2 cannot burn tokenId without migrating metadata
        await expect(controller2.connect(one).burn(tokenId)).revertedWith(revert`missing metadata`);
        await controller2.connect(one).burn(altTokenId);

        nameRecord = await controller.nameRecord(tokenId);
        await controller2.setMetadataBatch([tokenId, nameRecord.origin, nameRecord.expire, nameRecord.capacity, nameRecord.children]);
        await controller2.connect(one).burn(tokenId);
      });

      it("should be able to migrate existing metadata", async () => {
        await controller.nameRegister("gavinwood100", twoAddr, 86400 * 365, {
          value: fee,
        });

        await controller.connect(two).mintSubdomain(twoAddr, tokenId, "sub0");

        await pns.setManager(controller2.address, true);
        await pns.setManager(controller.address, false);

        await controller2.nameRegister("gavinwood101", twoAddr, 86400 * 365, {
          value: fee,
        });

        expect(await pns.ownerOf(tokenId)).to.eq(twoAddr);
        expect(await pns.ownerOf(altTokenId)).to.eq(twoAddr);

        // migrate token metadata
        let nameRecord = await controller.nameRecord(tokenId);
        await controller2.setMetadataBatch([tokenId, nameRecord.origin, nameRecord.expire, nameRecord.capacity, nameRecord.children]);

        let nameData2 = await controller2.nameRecord(tokenId);
        expect(nameRecord.origin).to.eq(nameData2.origin);
        expect(nameRecord.expire).to.eq(nameData2.expire);
        expect(nameRecord.capacity).to.eq(nameData2.capacity);
        expect(nameRecord.children).to.eq(nameData2.children);

        // migrate subtoken metadata

        let subNameData = await controller.nameRecord(subTokenId);
        await controller2.setMetadataBatch([subTokenId, subNameData.origin, subNameData.expire, subNameData.capacity, subNameData.children]);

        let subNameData2 = await controller2.nameRecord(subTokenId);
        expect(subNameData.origin).to.eq(subNameData2.origin);
        expect(subNameData.expire).to.eq(subNameData2.expire);
        expect(subNameData.capacity).to.eq(subNameData2.capacity);
        expect(subNameData.children).to.eq(subNameData2.children);

        // controller2 can burn tokenId with metadata migrated
        await controller2.connect(one).burn(subTokenId);
        await controller2.connect(one).burn(tokenId);
        await controller2.connect(one).burn(altTokenId);
      });
    });

    describe("PriceOracle#updateAnswer", async () => {
      it("should be able to update PriceOracle value", async () => {
        let PriceOracle = await ethers.getContractFactory("PriceOracle");
        let priceFeedAddr = await controller.priceFeed();
        let priceOracle = PriceOracle.attach(priceFeedAddr);

        expect(await controller.root()).to.eq(oneAddr);
        expect(await priceOracle.root()).to.eq(oneAddr);

        let tokenPrice = await controller.getTokenPrice();
        fee = await controller.totalRegisterPrice("gavinwood100", 86400 * 365);

        await priceOracle.updateAnswer(5000000000);

        tokenPrice = await controller.getTokenPrice();
        fee = await controller.totalRegisterPrice("gavinwood100", 86400 * 365);

        await expect(priceOracle.connect(two).transferRootOwnership(twoAddr)).revertedWith(revert`caller is not root`);
        await expect(priceOracle.connect(two).updateAnswer(2500000000)).revertedWith(revert`caller is not root`);
      });
    });

    describe("PNS#set", async () => {
      it("should be able to set and get record", async () => {
        await registerName("gavinwood100", twoAddr);
        await pns.connect(two).set("ETH", twoAddr, tokenId);
        await pns.connect(two).set("text.email", "user@example.com", tokenId);

        expect(await pns.get("ETH", tokenId)).to.eq(twoAddr);
        expect(await pns.get("text.email", tokenId)).to.eq("user@example.com");

        expect(await pns.getMany(["ETH", "text.email"], tokenId)).to.deep.equal([twoAddr, "user@example.com"]);
        expect(await pns.getByHash(sha3("ETH"), tokenId)).to.deep.equal(twoAddr);
        expect(await pns.getManyByHash([sha3("ETH"), sha3("text.email")], tokenId)).to.deep.equal([twoAddr, "user@example.com"]);
      });

      it("should be able to setByHash and get record", async () => {
        await registerName("gavinwood100", twoAddr);
        await pns.connect(two).setByHash(sha3("ETH"), twoAddr, tokenId);
        await pns.connect(two).setByHash(sha3("text.email"), "user@example.com", tokenId);

        expect(await pns.getMany(["ETH", "text.email"], tokenId)).to.deep.equal([twoAddr, "user@example.com"]);
      });

      it("should be able to setMany and get record", async () => {
        await registerName("gavinwood100", twoAddr);
        await pns.connect(two).setMany(["ETH", "text.email"], [twoAddr, "user@example.com"], tokenId);

        expect(await pns.getMany(["ETH", "text.email"], tokenId)).to.deep.equal([twoAddr, "user@example.com"]);
      });

      it("should be able to setManyByHash and get record", async () => {
        await registerName("gavinwood100", twoAddr);
        await pns.connect(two).setManyByHash([sha3("ETH"), sha3("text.email")], [twoAddr, "user@example.com"], tokenId);

        expect(await pns.getMany(["ETH", "text.email"], tokenId)).to.deep.equal([twoAddr, "user@example.com"]);
      });

      it("should not be able to set by non-owner", async () => {
        await registerName("gavinwood100", twoAddr);
        await expect(pns.connect(three).set("ETH", twoAddr, tokenId)).revertedWith(revert`not owner nor approved`);
        await expect(pns.connect(three).setByHash(sha3("ETH"), twoAddr, tokenId)).revertedWith(revert`not owner nor approved`);
        await expect(pns.connect(three).setMany(["ETH", "text.email"], [twoAddr, "user@example.com"], tokenId)).revertedWith(revert`not owner nor approved`);
        await expect(pns.connect(three).setManyByHash([sha3("ETH"), sha3("text.email")], [twoAddr, "user@example.com"], tokenId)).revertedWith(
          revert`not owner nor approved`
        );
      });

      it("should be able to set by approved user", async () => {
        await registerName("gavinwood100", twoAddr);
        await pns.connect(two).approve(threeAddr, tokenId);
        await pns.connect(three).set("ETH", twoAddr, tokenId);
        await pns.connect(three).setByHash(sha3("ETH"), twoAddr, tokenId);
        await pns.connect(three).setMany(["ETH", "text.email"], [twoAddr, "user@example.com"], tokenId);
        await pns.connect(three).setManyByHash([sha3("ETH"), sha3("text.email")], [twoAddr, "user@example.com"], tokenId);
      });

      it("should be able to set by root", async () => {
        await registerName("gavinwood100", twoAddr);
        await pns.connect(one).set("ETH", twoAddr, tokenId);
        await pns.connect(one).setByHash(sha3("ETH"), twoAddr, tokenId);
        await pns.connect(one).setMany(["ETH", "text.email"], [twoAddr, "user@example.com"], tokenId);
        await pns.connect(one).setManyByHash([sha3("ETH"), sha3("text.email")], [twoAddr, "user@example.com"], tokenId);
      });

      it("should be able to set only when writable", async () => {
        await registerName("gavinwood100", twoAddr);

        await pns.connect(one).setContractConfig(0);
        await expect(pns.connect(three).set("ETH", twoAddr, tokenId)).revertedWith(revert`invalid op`);
        await expect(pns.connect(three).setByHash(sha3("ETH"), twoAddr, tokenId)).revertedWith(revert`invalid op`);
        await expect(pns.connect(three).setMany(["ETH", "text.email"], [twoAddr, "user@example.com"], tokenId)).revertedWith(revert`invalid op`);
        await expect(pns.connect(three).setManyByHash([sha3("ETH"), sha3("text.email")], [twoAddr, "user@example.com"], tokenId)).revertedWith(
          revert`invalid op`
        );

        await pns.connect(one).setContractConfig(1);
        await pns.connect(one).set("ETH", twoAddr, tokenId);
        await pns.connect(one).setByHash(sha3("ETH"), twoAddr, tokenId);
        await pns.connect(one).setMany(["ETH", "text.email"], [twoAddr, "user@example.com"], tokenId);
        await pns.connect(one).setManyByHash([sha3("ETH"), sha3("text.email")], [twoAddr, "user@example.com"], tokenId);
      });
    });
  });
});
