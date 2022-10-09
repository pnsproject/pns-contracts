import { ethers } from "hardhat"
import { ContractFactory, Contract, BigNumberish, BigNumber } from "ethers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

import { PNS_ADDRESS, CONTROLLER_ADDRESS_LIST,
         ControllerRecord, PNSRecord,
         NewSubdomain, ControllerConfig
       } from "./rc"

interface PNSInfo {
    token_list: BigNumberish[]
    new_subdomain: NewSubdomain[]
    records: Record<string, PNSRecord>
}

interface ControllerInfo {
    address: string
    config: ControllerConfig
    records: Record<string, ControllerRecord>
}

function toNum(a: BigNumberish): number {
    return BigNumber.from(a).toNumber()
}

async function main() {
    const PNS = await ethers.getContractFactory("PNS")
    const Controller = await ethers.getContractFactory("Controller")

    // get contract
    const pns: Contract = PNS.attach(PNS_ADDRESS)

    // get all tokennn
    let token_list: string[] = []
    let ev_list = await pns.queryFilter(pns.filters.Transfer(ethers.constants.AddressZero))
    for (let ev of ev_list) {
        let tok = ev.args![2]
        if (await pns.exists(tok)) {
            token_list.push(ethers.utils.hexlify(tok))
        }
    }

    // get controller info
    let controller_info_list: ControllerInfo[] = []

    for (const address of CONTROLLER_ADDRESS_LIST) {
        const ctrl = Controller.attach(address)
        let records: Record<string, ControllerRecord> = {}

        let prices: BigNumberish[][] = await ctrl.getPrices()

        controller_info_list.push({
            address,
            config: {
                BASE_NODE: ethers.utils.hexlify(await ctrl.BASE_NODE()),
                MIN_REGISTRATION_DURATION: toNum(await ctrl.MIN_REGISTRATION_DURATION()),
                MIN_REGISTRATION_LENGTH: toNum(await ctrl.MIN_REGISTRATION_LENGTH()),
                GRACE_PERIOD: toNum(await ctrl.GRACE_PERIOD()),
                basePrices: prices![0].map((x) => { return toNum(x) }),
                rentPrices: prices![1].map((x) => { return toNum(x) }),
                priceFeed: await ctrl.priceFeed(),
                root: await ctrl.root(),
            },
            records,
        })

        for (const tok of token_list) {
            let origin = ethers.utils.hexlify(await ctrl.origin(tok))
            if (BigNumber.from(origin).eq(0)) continue

            records[tok] = {
                origin,
                expire: toNum(await ctrl.expire(tok)),
                capacity: toNum(await ctrl.capacity(tok)),
                children: toNum(await ctrl.children(tok)),
            }
        }
    }

    // fill pns info
    let pns_info: PNSInfo = {
        token_list,
        new_subdomain: [],
        records: {} // TODO
    }

    let ev_list_nsd = await pns.queryFilter(pns.filters.NewSubdomain())
    for (let ev of ev_list_nsd) {
        pns_info.new_subdomain.push({
            to: ev.args![0],
            tokenId: ethers.utils.hexlify(ev.args![1]),
            subtokenId: ethers.utils.hexlify(ev.args![2]),
            name: ev.args![3],
        })
    }

    console.log("pns_info")
    console.log(JSON.stringify(pns_info, null, 2))
    console.log("controller_info_list")
    console.log(JSON.stringify(controller_info_list, null, 2))
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
