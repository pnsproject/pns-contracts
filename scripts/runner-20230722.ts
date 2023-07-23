import { ethers } from "hardhat";
import { ContractFactory, Contract, BigNumberish, Signer, BigNumber, EventFilter } from "ethers"
import { sha3, getNamehash, emptyAddress, weirdNode, emptyNode, baseNode, baseLabel } from "../lib/helper";

async function main() {
    let oneAddr: string, twoAddr: string, threeAddr: string, fourAddr: string, fiveAddr: string;
    let one: Signer, two: Signer, three: Signer, four: Signer, five: Signer;
    [one, two, three] = await ethers.getSigners();
    [oneAddr, twoAddr, threeAddr] = await Promise.all([one, two, three].map((s) => s.getAddress()));
    console.log(oneAddr)
    console.log(twoAddr)
    console.log(threeAddr)

    const PNS = await ethers.getContractFactory("PNS")
    const Controller = await ethers.getContractFactory("Controller")

    const pns: Contract = PNS.attach("0x7d5F0398549C9fDEa03BbDde388361827cb376D5")

    const controller0 = Controller.attach('0x4B332f38E0484078CD1368144A776482244663CE')
    console.log(await controller0.root())
    console.log(await controller0.priceFeed())

    console.log(await pns.root())
    console.log(baseNode)
    let priceOracleAddr = "0x4497B606be93e773bbA5eaCFCb2ac5E2214220Eb"
    let forwarderAddr = "0x46388408c8828085f70dF7f8c3e7520B16e33391"

    let basePrices = [
         "1000",
         "1000",
         "250",
         "50",
         "20"
      ]
    let rentPrices = [
         "500",
         "500",
         "100",
         "20",
         "5"
      ]
    // task : deploy new controller
    let controller = await Controller.deploy(pns.address, baseNode, basePrices, rentPrices, priceOracleAddr, forwarderAddr);
    await controller.deployed();
    console.log("controller deployed to:", controller.address);
    // controller deployed to: 0xcD0771139fEE77f6a13E87C245Bc1Df92eAca1b6
    // tx : https://moonscan.io/tx/0x1be6ec2ab251bdfc3d83ddbc50e807f6807fd59d69aee5e6e902fbef685fc12c

    await (await pns.setManager(controller.address, true)).wait();
    await (await controller.setManager(twoAddr, true)).wait();
    await (await controller.setManager(threeAddr, true)).wait();
    console.log('getPrices', await controller.getPrices())

    await (await controller.setContractConfig(7, 2, 86400*28, priceOracleAddr)).wait();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
