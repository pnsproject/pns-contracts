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

    // controller
    for (const address of CONTROLLER_ADDRESS_LIST) {
        console.log(`remove ${address} from manager list`)
        const ctrl = Controller.attach(address)

        if (await pns.isManager(address)) {
            await (await pns.setManager(address, false)).wait()
        }
        console.log(`isManager ${await pns.isManager(address)}`)
    }

    console.log("now, set PNS.FLAGS to 0")

    await (await pns.setContractConfig(0)).wait()
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
