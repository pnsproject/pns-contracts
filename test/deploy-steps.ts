import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { Signer, BigNumber } from "ethers";

import { sha3, getNamehash, emptyAddress, weirdNode, emptyNode, baseNode, baseLabel } from "../lib/helper";
import { isException, ensureException, expectFailure } from "../lib/test-helper";

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

    let PNS: any;
    let Controller: any;

    [one, two] = await ethers.getSigners();
    [oneAddr, twoAddr] = await Promise.all([one, two].map((s) => s.getAddress()));

    console.log("accounts", { oneAddr, twoAddr });


    describe("PNSController#nameRegister", async () => {

      it("should register a new domain name", async () => {


        // if (process.env.PRICE_ORACLE) {
        //   return process.env.PRICE_ORACLE || "";
        // }

        let PriceOracle = await ethers.getContractFactory("PriceOracle");
        // let priceOracle = await PriceOracle.deploy(100000000000);
        // await priceOracle.deployed();
        // console.log("priceOracle deployed to:", priceOracle.address);

        // let PriceOracleAddr = priceOracle.address;
        let PriceOracleAddr = process.env.PRICE_ORACLE || "";
        // let priceOracle = await PriceOracle.attach(PriceOracleAddr);
        // console.log(await priceOracle.latestRoundData())

        PNS = await ethers.getContractFactory("PNS");
        // pns = await upgrades.deployProxy(PNS, []);
        // let tx = await pns.deployed();
        
        // console.log("startblock", (await tx.deployTransaction.wait()).blockNumber);

        let pnsAddr = "0xf24e64621c9df0b4b0f0bc03c74af93955f69825"
        let pns = PNS.attach(pnsAddr)

        Controller = await ethers.getContractFactory("Controller");
        // controller = await Controller.deploy(pnsAddr, baseNode, basePrices, rentPrices, PriceOracleAddr);
        
        // console.log("controller.deployed():");
        // await controller.deployed();

        // // console.log("controller deployed to:", controller.address);

        let controller = Controller.attach("0x31d6c3d957bf11c3b858cedcd325feb02b6e2801")

        // await (await pns.mint(controller.address, getNamehash("dot"))).wait();

        // console.log("pns setManager:");
        // await (await pns.setManager(controller.address, true)).wait();
        // console.log("pns setManager done");

        // let keylist = [
        //   "ETH",
        //   "BTC",
        //   "DOT",
        //   "KSM",
        //   "text.email",
        //   "text.url",
        //   "text.avatar",
        //   "text.description",
        //   "text.notice",
        //   "text.keywords",
        //   "text.com.twitter",
        //   "text.com.github",
        //   "contenthash",
        //   "cname",
        // ];
        
        // console.log("addKeys:");
        // await pns.addKeys(keylist);

        console.log("dot owner:", await pns.ownerOf(getNamehash("dot")));




        console.log("controller.setManager(twoAddr, true)");
        await controller.setManager(twoAddr, true);

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
