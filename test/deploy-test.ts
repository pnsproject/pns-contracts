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

    [one, two, three] = await ethers.getSigners();
    [oneAddr, twoAddr, threeAddr] = await Promise.all([one, two, three].map((s) => s.getAddress()));

    async function getFee(name: string) {
      return (await controller.totalRegisterPrice("gavinwood100", oneyear)).toString();
    }

    async function registerName(name?: string, address?: string) {
      name = name || "gavinwood100";
      address = address || twoAddr;
      let fee = getFee(name);
      return controller.nameRegister(name, address, oneyear, {
        value: fee,
      });
    }

    console.log("accounts", { oneAddr, twoAddr });

    beforeEach(async () => {
      ({ pns, controller } = await deployPNS());
    });

    describe("PNSController#nameRegister", async () => {
      let fee: string;
      let tx: any;

      it("should register a new domain name", async () => {
        console.log("controller.setManager(twoAddr, true)");
        await controller.setManager(twoAddr, true);
        console.log("controller.setManager(threeAddr, true)");
        await controller.setManager(threeAddr, true);

          await registerName();
          for (var i = 0; i < 500; ++i) {
              let tx = await registerName("test-domain-123456-" + i.toString(), oneAddr);
              let rc = await tx.wait()
              let tok = rc.events.filter((x: any) =>
                  { return x.event == "NameRegistered" })[0].args[1]

              for (var j = 0; j < 10; ++j) {
                  await controller.mintSubdomain(threeAddr, tok, "domain-another-" + j.toString() + "-" + i.toString());
              }
          }

        console.log(
          JSON.stringify(
            {
              pns: pns.address,
              controller: controller.address,
            },
            null,
            2
          )
        );

        console.log("pns root", await pns.root());
        console.log("controller root", await controller.root());
        console.log("controller manager", twoAddr);
      });
    });
  });
});
