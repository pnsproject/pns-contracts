import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";

import { sha3, getNamehash, emptyAddress, weirdNode, emptyNode } from "../lib/helper";
import { isException, ensureException, expectFailure } from "../lib/test-helper";
import { deployPNS } from "./scripts";

let tld = "dot";
let basePrices: any = [2000, 2000, 2000, 200, 200, 20];
let rentPrices: any = [500, 500, 500, 50, 50, 5];

describe("PNS", function () {
  it("Should deploy PNS contract successfully", async function () {
    let deployer, other: string;
    let deployerSign, otherSign: Signer;

    [deployerSign, otherSign] = await ethers.getSigners();
    [deployer, other] = await Promise.all([deployerSign, otherSign].map((s) => s.getAddress()));

    let { pns, controller, resolver } = await deployPNS();

    console.log(
      JSON.stringify(
        {
          pns: pns.address,
          controller: controller.address,
          resolver: resolver.address,
        },
        null,
        2
      )
    );

    let getTokenPrice = await controller.getTokenPrice();
    let fee = (await controller.totalRegisterPrice("gavinwood100", 86400 * 365)).toString();
    console.log("totalRegisterPrice", fee);
    console.log("getTokenPrice", getTokenPrice.toString());
    console.log("getTokenPrice of fee", getTokenPrice.mul(fee).div("100000000000000000000000000").toString());

    await (
      await controller.nameRegister("gavinwood100", deployer, 86400 * 365, {
        value: fee,
      })
    ).wait();
    let tokenId = getNamehash("gavinwood100.dot");
    console.log("gavinwood100.dot owner:", await pns.ownerOf(tokenId));
    console.log("gavinwood100.dot nameExpires:", (await controller.nameExpires(getNamehash("gavinwood100.dot"))).toString());
    console.log("gavinwood100.dot available:", await controller.available(getNamehash("gavinwood100.dot")));

    await pns.setResolver(tokenId, resolver.address);
    console.log("pns setResolver:");
    console.log("pns resolver:", await pns.getResolver(tokenId));

    await resolver.set("ETH", deployer, tokenId);
    console.log("gavinwood100.dot set:");
    console.log("gavinwood100.dot get:", await resolver.get("ETH", tokenId));
  });
});
