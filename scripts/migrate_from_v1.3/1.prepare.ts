import { ethers } from "hardhat"
import { ContractFactory, Contract, BigNumberish, BigNumber, EventFilter } from "ethers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { existsSync, rename, writeFileSync } from "fs"

import { PNS_ADDRESS, CONTROLLER_ADDRESS_LIST,
         PNS_BLOCK,
         ControllerRecord, PNSRecord,
         NewSubdomain, ControllerConfig
       } from "./rc"


function toNum(a: BigNumberish): number {
    return BigNumber.from(a).toNumber()
}


async function main() {
    const PNS = await ethers.getContractFactory("PNS")
    const Controller = await ethers.getContractFactory("Controller")

    // pns
    const pns: Contract = PNS.attach(PNS_ADDRESS)

    console.log("pns.FLAGS = ", await pns.FLAGS())

    for (const address of CONTROLLER_ADDRESS_LIST) {
        const ctrl = Controller.attach(address)
        console.log(`controller ${address} FLAGS: `, await ctrl.FLAGS())
    }


    console.log("now, set PNS.FLAGS & Controller.FLAGS to 0")

    await (await pns.setContractConfig(0)).wait()

    // controller
    for (const address of CONTROLLER_ADDRESS_LIST) {
        const ctrl = Controller.attach(address)

        let min_length = toNum(await ctrl.MIN_REGISTRATION_LENGTH())
        let min_duration = toNum(await ctrl.MIN_REGISTRATION_DURATION())
        let grace_period = toNum(await ctrl.GRACE_PERIOD())
        let default_capacity = toNum(await ctrl.DEFAULT_DOMAIN_CAPACITY())
        let capacity_price = toNum(await ctrl.capacityPrice())
        let price_feed = ethers.utils.hexlify(await ctrl.priceFeed())

        console.log({
            address,
            min_length,
            min_duration,
            grace_period,
            default_capacity,
            capacity_price,
            price_feed
        })

        await (await ctrl.setContractConfig(
            0, min_length, min_duration, grace_period,
            default_capacity, capacity_price, price_feed)).wait()
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
