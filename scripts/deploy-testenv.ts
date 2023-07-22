import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { Signer, BigNumber } from "ethers";

import { sha3, getNamehash, emptyAddress, weirdNode, emptyNode, baseNode, baseLabel } from "../lib/helper";
import { isException, ensureException, expectFailure } from "../lib/test-helper";

let tld = "dot";
let basePrices: any = [2000, 2000, 2000, 200, 20, 20];
let rentPrices: any = [500, 500, 500, 50, 5, 5];
let oneyear = 86400 * 365;
let tokenId = getNamehash("gavinwood100.dot");
let subTokenId = getNamehash("sub0.gavinwood100.dot");


export async function deployForwarder() {
    if (process.env.FORWARDER) {
        return process.env.FORWARDER || ""
    }

    const PNSForwarder = await ethers.getContractFactory("PNSForwarder")
    let forwarder = await upgrades.deployProxy(PNSForwarder)
    await forwarder.deployed()

    if (process.env.PRINT_START_BLOCK) {
        console.log("forwarder deployed to:", forwarder.address)
    }

    // update env
    process.env.FORWARDER = forwarder.address

    return forwarder.address
}

export async function deployPriceOracle(): Promise<string> {
  if (process.env.PRICE_ORACLE) {
    return process.env.PRICE_ORACLE || "";
  }

  let forwarderAddr = await deployForwarder()

  let PriceOracle = await ethers.getContractFactory("PriceOracle");
  let priceOracle = await PriceOracle.deploy(326000000, forwarderAddr);
  await priceOracle.deployed();
  if (process.env.PRINT_START_BLOCK) {
    console.log("priceOracle deployed to:", priceOracle.address);
  }

  return priceOracle.address;
}

async function main() {
    let oneAddr: string, twoAddr: string, threeAddr: string, fourAddr: string, fiveAddr: string;
    let one: Signer, two: Signer, three: Signer, four: Signer, five: Signer;
    let PNS, pns: any;
    let Controller, controller: any;

    [one, two, three] = await ethers.getSigners();
    [oneAddr, twoAddr, threeAddr] = await Promise.all([one, two, three].map((s) => s.getAddress()));

    console.log("accounts", { oneAddr, twoAddr, threeAddr });
    // process.exit(0)

    process.env.PRINT_START_BLOCK = "1"

    let priceOracleAddr = await deployPriceOracle();

    let forwarderAddr = await deployForwarder()

    PNS = await ethers.getContractFactory("PNS");
    pns = await upgrades.deployProxy(PNS, [], {constructorArgs: [forwarderAddr]});
    let tx = await pns.deployed();
    if (process.env.PRINT_START_BLOCK) {
      console.log("startblock", (await tx.deployTransaction.wait()).blockNumber);
    }

    if (process.env.PRINT_START_BLOCK) {
      console.log("pns deployed to:", pns.address);
    }

    Controller = await ethers.getContractFactory("Controller");
    controller = await Controller.deploy(pns.address, baseNode, basePrices, rentPrices, priceOracleAddr, forwarderAddr);
    await controller.deployed();

    if (process.env.PRINT_START_BLOCK) {
      console.log("controller deployed to:", controller.address);
    }

    await (await pns.mint(controller.address, getNamehash("dot"))).wait();
    console.log("pns setManager:");

    await (await pns.setManager(controller.address, true)).wait();
    await (await controller.setManager(twoAddr, true)).wait();
    await (await controller.setManager(threeAddr, true)).wait();

    let keylist = [
      "ETH",
      "BTC",
      "DOT",
      "KSM",
      "text.email",
      "text.url",
      "text.avatar",
      "text.description",
      "text.notice",
      "text.keywords",
      "text.com.twitter",
      "text.com.github",
      "contenthash",
      "cname",
    ];
    if (process.env.PRINT_START_BLOCK) {
      console.log("addKeys:");
    }
    await pns.addKeys(keylist);

    await controller.setContractConfig(7, 7, 28*86400, priceOracleAddr);

    console.log("dot owner:", await pns.ownerOf(getNamehash("dot")));
    // console.log("controller.getPrices", await controller.getPrices());
    console.log("controller.MIN_REGISTRATION_LENGTH", await controller.MIN_REGISTRATION_LENGTH());
    console.log("controller.MIN_REGISTRATION_DURATION", await controller.MIN_REGISTRATION_DURATION());
    console.log("controller.priceFeed", await controller.priceFeed());

    console.log("pns.GRACE_PERIOD", await pns.GRACE_PERIOD());
    console.log("pns root", await pns.root());
    console.log("controller root", await controller.root());
    console.log("controller manager two", await controller.isManager(twoAddr));
    console.log("controller manager three", await controller.isManager(threeAddr));

    let fee = (await controller.totalRegisterPrice("gavinwood", oneyear)).toString();

    await controller.nameRegister("gavinwood", twoAddr, oneyear, {
      value: fee,
    });
    console.log("gavinwood.dot owner:", await pns.ownerOf(getNamehash("gavinwood.dot")));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
