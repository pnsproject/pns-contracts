import { ethers } from "hardhat";
import { ContractFactory, Contract, BigNumberish, Signer, BigNumber, EventFilter } from "ethers"

async function main() {
    let oneAddr: string, twoAddr: string, threeAddr: string, fourAddr: string, fiveAddr: string;
    let one: Signer, two: Signer, three: Signer, four: Signer, five: Signer;
    [one, two, three] = await ethers.getSigners();
    [oneAddr, twoAddr, threeAddr] = await Promise.all([one, two, three].map((s) => s.getAddress()));
    console.log(oneAddr)
    console.log(twoAddr)
    console.log(threeAddr)

    // console.log('balance')
    // console.log(await ethers.provider.getBalance(oneAddr))
    // console.log(await ethers.provider.getBalance(twoAddr))
    // console.log(await ethers.provider.getBalance(threeAddr))
    const PNS = await ethers.getContractFactory("PNS")
    const Controller = await ethers.getContractFactory("Controller")

    const pns: Contract = PNS.attach("0x7d5F0398549C9fDEa03BbDde388361827cb376D5")

    // disable discount controller
    const controller0 = Controller.attach('0x4EA48B8045889A7426CcD00b3968686010B4cc62')
    // console.log('pns.setManager false', await pns.setManager(controller0.address, false))
    console.log('pns.isManager false', await pns.isManager(controller0.address))

    const controller = Controller.attach('0x4B332f38E0484078CD1368144A776482244663CE')
    console.log(await controller.root())
    console.log(await pns.root())
    console.log(await controller.getPrices())

    // set min length
    // set new prices

    // await controller.setContractConfig(7, 2, 2419200, "0x4497B606be93e773bbA5eaCFCb2ac5E2214220Eb")
    // await controller.setPrices(
    //   [
    //      "2000",
    //      "2000",
    //      "500",
    //      "100",
    //      "20"
    //   ],
    //   [
    //      "500",
    //      "500",
    //      "100",
    //      "20",
    //      "5"
    //   ])

    console.log('pns.isManager', await pns.isManager(controller.address))
    // console.log('owner', await controller.FLAGS())
    console.log('MIN_REGISTRATION_LENGTH', await controller.MIN_REGISTRATION_LENGTH())
    // console.log('owner', await controller.MIN_REGISTRATION_DURATION())
    // console.log('owner', await controller.priceFeed())
    // console.log('owner', await controller.getPrices())
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
