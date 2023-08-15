import { ethers } from "hardhat";
import { ContractFactory, Contract, BigNumberish, Signer, BigNumber, EventFilter } from "ethers"
import { sha3, getNamehash, emptyAddress, weirdNode, emptyNode, baseNode, baseLabel } from "../lib/helper";

async function main() {
    let oneAddr: string, twoAddr: string, threeAddr: string, fourAddr: string, fiveAddr: string;
    let one: Signer, two: Signer, three: Signer, four: Signer, five: Signer;
    [one, two, three] = await ethers.getSigners();
    [oneAddr, twoAddr, threeAddr] = await Promise.all([one, two, three].map((s) => s.getAddress()));
    console.log('oneAddr', oneAddr)
    console.log(twoAddr)
    console.log(threeAddr)

    const PNS = await ethers.getContractFactory("PNS")
    const Controller = await ethers.getContractFactory("Controller")

    const pns: Contract = PNS.attach("0x7d5F0398549C9fDEa03BbDde388361827cb376D5")

    const controller0 = Controller.attach('0xcD0771139fEE77f6a13E87C245Bc1Df92eAca1b6')
    console.log(await controller0.root())
    console.log(await controller0.priceFeed())

    console.log('pns.isManager true', await pns.isManager(controller0.address))

    let basePrices = [
         "1000",
         "1000",
         "250",
         "40",
         "5"
      ]
    let rentPrices = [
         "500",
         "500",
         "100",
         "20",
         "3"
      ]

    await (await controller0.setPrices(basePrices, rentPrices)).wait();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
