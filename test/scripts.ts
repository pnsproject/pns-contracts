import { Signer } from "ethers";
import { ethers, upgrades } from "hardhat";

import { sha3, getNamehash, emptyAddress, weirdNode, emptyNode, baseNode, altBaseNode, baseLabel } from "../lib/helper";

let tld = "dot";
let altTld = "dot";
let basePrices: any = [2000, 2000, 2000, 200, 200, 20];
let rentPrices: any = [500, 500, 500, 50, 50, 5];

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

export async function deployPNSContract() {
    let PNS, pns: any;

    let forwarderAddr = await deployForwarder()

    PNS = await ethers.getContractFactory("PNS");
    pns = await upgrades.deployProxy(PNS, [], {constructorArgs: [forwarderAddr]});
    await pns.deployed();

    return {
        pns,
    };
}

export async function deployPNS() {
  let PNS, pns: any;
  let Controller, controller: any;

  let PriceOracleAddr = await deployPriceOracle();

  let forwarderAddr = await deployForwarder()

  PNS = await ethers.getContractFactory("PNS");
  pns = await upgrades.deployProxy(PNS, [], {constructorArgs: [forwarderAddr]});
  let tx = await pns.deployed();
  if (process.env.PRINT_START_BLOCK) {
    console.log("startblock", (await tx.deployTransaction.wait()).blockNumber);
  }

  Controller = await ethers.getContractFactory("Controller");
  controller = await Controller.deploy(pns.address, baseNode, basePrices, rentPrices, PriceOracleAddr, forwarderAddr);
  if (process.env.PRINT_START_BLOCK) {
    console.log("controller.deployed():");
  }
  await controller.deployed();

  if (process.env.PRINT_START_BLOCK) {
    console.log("controller deployed to:", controller.address);
  }

  await (await pns.mint(controller.address, getNamehash("dot"))).wait();

  if (process.env.PRINT_START_BLOCK) {
    console.log("pns setManager:");
  }
  await (await pns.setManager(controller.address, true)).wait();

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

  if (process.env.PRINT_START_BLOCK) {
    console.log("dot owner:", await pns.ownerOf(getNamehash("dot")));
  }

  return {
    pns,
    controller,
  };
}

export async function deployPNSMultipleController() {
  let PNS, pns: any;
  let Controller, controller, controller2: any;

  let forwarderAddr = await deployForwarder()
  let PriceOracleAddr = await deployPriceOracle();

  PNS = await ethers.getContractFactory("PNS");
  pns = await upgrades.deployProxy(PNS, [], {constructorArgs: [forwarderAddr]});
  await pns.deployed();
  console.log("pns deployed to:", pns.address);

  Controller = await ethers.getContractFactory("Controller");
  controller = await Controller.deploy(pns.address, baseNode, basePrices, rentPrices, PriceOracleAddr, forwarderAddr);
  await controller.deployed();

  controller2 = await Controller.deploy(pns.address, altBaseNode, basePrices, rentPrices, PriceOracleAddr, forwarderAddr);
  await controller2.deployed();

  console.log("controller deployed to:", controller.address);

  await (await pns.mint(controller.address, baseNode)).wait();
  await (await pns.mint(controller2.address, altBaseNode)).wait();

  console.log("transferRoot:");
  await (await pns.setManager(controller.address, true)).wait();
  await (await pns.setManager(controller2.address, true)).wait();

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
    "resolver",
  ];
  console.log("addKeys:");
  await pns.addKeys(keylist);

  console.log("dot owner:", await pns.ownerOf(getNamehash("dot")));

  return {
    pns,
    controller,
    controller2,
  };
}

export async function deployPNSExtraController() {
  let PNS, pns: any;
  let Controller, controller, controller2: any;

  let forwarderAddr = await deployForwarder()
  let PriceOracleAddr = await deployPriceOracle();

  PNS = await ethers.getContractFactory("PNS");
  pns = await upgrades.deployProxy(PNS, [], {constructorArgs: [forwarderAddr]});
  await pns.deployed();
  // console.log("pns deployed to:", pns.address);

  Controller = await ethers.getContractFactory("Controller");
  controller = await Controller.deploy(pns.address, baseNode, basePrices, rentPrices, PriceOracleAddr, forwarderAddr);
  await controller.deployed();

  controller2 = await Controller.deploy(pns.address, baseNode, basePrices, rentPrices, PriceOracleAddr, forwarderAddr);
  await controller2.deployed();

  // console.log("controller deployed to:", controller.address);

  // await (await pns.mint(controller.address, baseNode)).wait();
  // await (await pns.mint(controller2.address, altBaseNode)).wait();

  // console.log("transferRoot:");
  await (await pns.setManager(controller.address, true)).wait();
  // await (await pns.setManager(controller2.address, true)).wait();

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
    "resolver",
  ];
  // console.log("addKeys:");
  await pns.addKeys(keylist);

  // console.log("dot owner:", await pns.ownerOf(getNamehash("dot")));

  return {
    pns,
    controller,
    controller2,
  };
}
