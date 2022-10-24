import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer, BigNumber } from "ethers";

import { sha3, getNamehash, emptyAddress, weirdNode, emptyNode, baseNode, baseLabel } from "../lib/helper";
import { isException, ensureException, expectFailure } from "../lib/test-helper";

let tld = "dot";
let basePrices: any = [2000, 2000, 2000, 200, 20, 20];
let rentPrices: any = [500, 500, 500, 50, 5, 5];
let oneyear = 86400 * 365;
let tokenId = getNamehash("gavinwood100.dot");
let subTokenId = getNamehash("sub0.gavinwood100.dot");

export const revert = (messages: TemplateStringsArray) => `Error: VM Exception while processing transaction: reverted with reason string '${messages[0]}'`;

describe("PNS", async function () {
  it("Should deploy PNS contract successfully", async function () {
    let oneAddr: string, twoAddr: string, threeAddr: string, fourAddr: string, fiveAddr: string;
    let one: Signer, two: Signer, three: Signer, four: Signer, five: Signer;
    let pns: any, controller: any, controller2: any;

    [one, two, three] = await ethers.getSigners();
    [oneAddr, twoAddr, threeAddr] = await Promise.all([one, two, three].map((s) => s.getAddress()));

    // async function getFee(name: string) {
    //   return (await controller.totalRegisterPrice("gavinwood100", oneyear)).toString();
    // }

    // async function registerName(name?: string, address?: string) {
    //   name = name || "gavinwood100";
    //   address = address || twoAddr;
    //   let fee = getFee(name);
    //   return controller.nameRegister(name, address, oneyear, {
    //     value: fee,
    //   });
    // }

    console.log("accounts", { oneAddr, twoAddr });

    describe("PNSController", async () => {
      let fee: string;
      let tx: any;

      it("should register a new domain name", async () => {
        let PNS = await ethers.getContractFactory("PNS");
        let Controller = await ethers.getContractFactory("Controller");
        pns = PNS.attach("0x7d5F0398549C9fDEa03BbDde388361827cb376D5")
        controller = Controller.attach("0x8113e4070297b22D943241054a9dbDC395Bc6eaa")

        let PriceOracleAddr = "0x4497B606be93e773bbA5eaCFCb2ac5E2214220Eb"
        let forwarderAddr = "0x46388408c8828085f70dF7f8c3e7520B16e33391"
        // let ctrl = await Controller.deploy(pns.address, baseNode, basePrices, rentPrices, PriceOracleAddr, forwarderAddr);
        let ctrl = await Controller.attach("0x4B332f38E0484078CD1368144A776482244663CE");
        console.log("ctrl.deployed():");
        // let tx = await ctrl.deployed();
        console.log("ctrl deployed to:", ctrl.address);
        // console.log(tx)


        await ctrl.setContractConfig(7,
                               7,
                               2419200,
                               PriceOracleAddr);

        // await (await pns.setManager(controller.address, false)).wait()
        // await (await pns.setManager(ctrl.address, true)).wait()
        // await (await ctrl.setManager(twoAddr, true)).wait()
        // await (await ctrl.setManager(threeAddr, true)).wait()


        // console.log("controller.setManager(twoAddr, true)");
        // await controller.setManager(twoAddr, true);
        // console.log("controller.setManager(threeAddr, true)");
        // await controller.setManager(threeAddr, true);

        // console.log(
        //   JSON.stringify(
        //     {
        //       pns: pns.address,
        //       controller: controller.address,
        //     },
        //     null,
        //     2
        //   )
        // );

        // console.log("controller.getPrices", await controller.getPrices());
        // console.log("controller.MIN_REGISTRATION_LENGTH", await controller.MIN_REGISTRATION_LENGTH());
        // console.log("controller.MIN_REGISTRATION_DURATION", await controller.MIN_REGISTRATION_DURATION());
        // console.log("controller.priceFeed", await controller.priceFeed());
        // console.log("controller.isTrustedForwarder", await controller.isTrustedForwarder("0x46388408c8828085f70dF7f8c3e7520B16e33391"));

        // console.log("ctrl.getPrices", await ctrl.getPrices());
        // console.log("ctrl.MIN_REGISTRATION_LENGTH", await ctrl.MIN_REGISTRATION_LENGTH());
        // console.log("ctrl.MIN_REGISTRATION_DURATION", await ctrl.MIN_REGISTRATION_DURATION());
        // console.log("ctrl.priceFeed", await ctrl.priceFeed());
        // console.log("ctrl.isTrustedForwarder", await ctrl.isTrustedForwarder("0x46388408c8828085f70dF7f8c3e7520B16e33391"));

        console.log("pns root", await pns.root());
        console.log("ctrl root", await ctrl.root());
        console.log("pns manager controller", await pns.isManager(controller.address));
        console.log("pns manager ctrl", await pns.isManager(ctrl.address));
        console.log("ctrl manager two", await ctrl.isManager(twoAddr));
        console.log("ctrl manager three", await ctrl.isManager(threeAddr));
      });
    });
  });
});
