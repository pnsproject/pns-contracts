import { ethers } from "hardhat"
import { ContractFactory, Contract, BigNumberish, BigNumber, EventFilter } from "ethers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { existsSync, rename, writeFileSync } from "fs"

import { PNS_ADDRESS, CONTROLLER_ADDRESS_LIST,
         PNS_BLOCK,
         ControllerRecord, PNSRecord,
         NewSubdomain, ControllerConfig,
         PNSInfo, ControllerInfo
       } from "./rc"

function toNum(a: BigNumberish): number {
    return BigNumber.from(a).toNumber()
}

function save_file(path: string, str: string) {
    if (existsSync(path)) {
        rename(path, path + ".old-" + Date.now().toString(), (e) => {
            if (e) throw(e)
        })
    }

    console.log("================= ", path)
    console.log(str)

    writeFileSync(path, str)
}

async function query_event(contract: Contract, filter: EventFilter, start: number): Promise<any[]> {
    var end = start - 1
    const STEP = 1000
    var res: any[] = []

    while (true) {
        const block = await ethers.provider.getBlockNumber()
        const begin = end + 1
        if (begin > block) break

        end = ((begin + STEP - 1) > block) ? block : (begin + STEP - 1)

        console.log(`query [${begin}, ${end}]: `)

        const res1 = await contract.queryFilter(filter, begin, end)

        console.log(`${res1.length} records`)

        res = res.concat(res1)
    }

    return res
}

async function main() {
    const PNS = await ethers.getContractFactory("PNS")
    const Controller = await ethers.getContractFactory("Controller")

    // get contract
    const pns: Contract = PNS.attach(PNS_ADDRESS)

    console.log("pns.FLAGS = ", await pns.FLAGS())

    // get all tokennn
    let token_list: string[] = []
    let ev_list = await query_event(pns, pns.filters.Transfer(ethers.constants.AddressZero), PNS_BLOCK)

    for (let ev of ev_list) {
        let tok = ev.args![2]
        if (await pns.exists(tok)) {
            token_list.push(ethers.utils.hexlify(tok))
        }
    }

    console.log("token_list", token_list)

    // get controller info
    let controller_info_list: ControllerInfo[] = []

    for (const address of CONTROLLER_ADDRESS_LIST) {
        const ctrl = Controller.attach(address)
        let records: Record<string, ControllerRecord> = {}

        console.log(`process controller ${address}`)
        console.log("isManager: ", await pns.isManager(address))
        console.log(`FLAGS: `, await ctrl.FLAGS())

        let prices: BigNumberish[][] = await ctrl.getPrices()

        let manager_set: Set<string> = new Set()
        let ev_list_mgr = await query_event(ctrl, ctrl.filters.ManagerChanged(), PNS_BLOCK)
        for (const ev of ev_list_mgr) {
            let m = ethers.utils.hexlify(ev.args![0])
            let r = ev.args![1]

            if (r) { manager_set.add(m) }
            else { manager_set.delete(m) }
        }

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
            managers: Array.from(manager_set)
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

            console.log(`records[${tok}]`, records[tok])
        }
    }

    // fill pns info
    let pns_info: PNSInfo = {
        token_list,
        new_subdomain: [],
    }

    let ev_list_nsd = await query_event(pns, pns.filters.NewSubdomain(), PNS_BLOCK)
    for (let ev of ev_list_nsd) {
        pns_info.new_subdomain.push({
            to: ev.args![0],
            tokenId: ethers.utils.hexlify(ev.args![1]),
            subtokenId: ethers.utils.hexlify(ev.args![2]),
            name: ev.args![3],
        })
    }

    save_file("pns_info.json", JSON.stringify(pns_info, null, 2))
    save_file("controller_info_list.json", JSON.stringify(controller_info_list, null, 2))
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
