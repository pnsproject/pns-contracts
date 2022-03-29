import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer, BigNumber } from "ethers";

import { sha3, getNamehash, emptyAddress, weirdNode, emptyNode, baseNode, baseLabel } from "../lib/helper";
import { isException, ensureException, expectFailure } from "../lib/test-helper";
import { deployPNS, deployPNSMultipleController, deployPNSContract } from "./scripts";

import {
  setSigner,
  setup,
  getProvider,
  getSigner,
  getAccount,
  getOwner,
  getOwnerOf,
  ownerOfName,
  ownerOfId,
  exists,
  totalRegisterPrice,
  basePrice,
  rentPrice,
  getPrices,
  getControllerRoot,
  transferController,
  nameExpires,
  available,
  register,
  registerWithConfig,
  mintSubdomain,
  approve,
  getApproved,
  suffixTld,
  removeTld,
  setName,
  getName,
  setNftName,
  getNftName,
  setKey,
  getKey,
  setKeys,
  setKeysByHash,
  getKeys,
  getKeysByHash,
  getDomainDetails,
  renew,
  transferName,
} from "../lib/sdk";

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

      let provider = ethers.provider;
      let signer = await provider.getSigner();
      let address = await signer.getAddress();
      console.log("address", address);

      setSigner(signer);

      ({ pns, controller } = await setup(provider as any, pns.address, controller.address));
    });

    describe("nameRegister", async () => {
      let fee: string;
      let tx: any;

      it("mint subtoken and burn", async () => {
        registerName("gavinwood100", oneAddr);
        let account = getAccount();
        console.log("account", account);

        console.log(await getOwner("gavinwood100.dot"));
        console.log(await getOwnerOf(getNamehash("gavinwood100.dot")));
        console.log(await ownerOfName("gavinwood100.dot"));
        console.log(await ownerOfId(getNamehash("gavinwood100.dot")));
        console.log(await exists("gavinwood100.dot"));

        console.log(await totalRegisterPrice("gavinwood111", 86400 * 365));
        console.log(await basePrice("gavinwood111"));
        console.log(await rentPrice("gavinwood111", 1));
        console.log(await getControllerRoot());

        console.log(await nameExpires("gavinwood100"));
        console.log(await nameExpires("gavinwood111"));

        console.log(await available("gavinwood100"));
        console.log(await available("gavinwood111"));

        console.log(await register("gavinwood111", account, 86400 * 365));
        console.log(await registerWithConfig("gavinwood112", account, 86400 * 365, [], []));
        console.log(await mintSubdomain(account, "gavinwood111.dot", "sub"));

        console.log(await getControllerRoot());
        console.log(await getPrices());

        console.log(await approve("gavinwood100.dot", twoAddr));
        console.log(await getApproved("gavinwood100.dot"));

        console.log((await getName(account)).toHexString());
        console.log(await setName("gavinwood100.dot"));
        console.log((await getName(account)).toHexString());

        console.log("setKey", await setKey("gavinwood100.dot", "ETH", account));
        console.log("getKey", await getKey("gavinwood100.dot", "ETH"));

        console.log("setKeys", await setKeys("gavinwood100.dot", ["BTC"], [account]));
        console.log("getKeys", await getKeys("gavinwood100.dot", ["BTC"]));

        console.log("setKeysByHash", await setKeysByHash("gavinwood100.dot", [sha3("DOT")], [account]));
        console.log("getKeysByHash", await getKeysByHash("gavinwood100.dot", [sha3("DOT")]));

        console.log(await getDomainDetails("gavinwood100.dot"));

        console.log(await renew("gavinwood100", 86400 * 365));

        console.log(await transferName("gavinwood100.dot", twoAddr));

        console.log(await transferController(twoAddr));
      });
    });
  });
});
