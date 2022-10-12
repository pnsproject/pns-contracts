import { ethers, upgrades } from "hardhat"
import { ContractFactory, Contract, BigNumberish, BigNumber, EventFilter } from "ethers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { existsSync, rename, writeFileSync, readFileSync } from "fs"

import { PNS_ADDRESS, CONTROLLER_ADDRESS_LIST,
         PNS_BLOCK,
         ControllerRecord, PNSRecord,
         NewSubdomain, ControllerConfig,
         PNSInfo, ControllerInfo, AddressInfo
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

function check_data(pns_info: PNSInfo, controller_info_list: ControllerInfo[],
                    address_info: AddressInfo): Record<string, PNSRecord>
{
    // check grace_period
    const grace_period = controller_info_list[0].config.GRACE_PERIOD

    for (const cinfo of controller_info_list) {
        if (cinfo.config.GRACE_PERIOD != grace_period) {
            throw(`GRACE_PERIOD not same`)
        }
    }

    var parent_map: Record<string, string> = {}
    for (const ev of pns_info.new_subdomain) {
        parent_map[ethers.utils.hexlify(ev.subtokenId)] = ethers.utils.hexlify(ev.tokenId)
    }

    var records: Record<string, PNSRecord> = {}

    for (const cinfo of controller_info_list) {
        for (const [tok, rec] of Object.entries(cinfo.records)) {
            if (records[tok] !== undefined) {
                throw(`duplicate token ${tok}`)
            }

            if (parent_map[tok] === undefined) {
                throw(`unknow parent for ${tok}`)
            }

            records[tok] = {
                origin: rec.origin,
                expire: rec.expire,
                parent: parent_map[tok]
            }
        }

        if (address_info.controller[cinfo.address] === undefined) {
            throw(`new address for ${cinfo.address} undefined`)
        }
    }

    return records
}

async function set_metadata(pns: Contract, pns_records: Record<string, PNSRecord>) {
    var pns_records_list: Record<string, PNSRecord>[] = []

    console.log(`total ${Object.keys(pns_records).length} records`)
    var map: Record<string, PNSRecord> = {}
    for (const [tok, rec] of Object.entries(pns_records)) {
        map[tok] = rec
        if (Object.keys(map).length > 500) {
            pns_records_list.push(map)
            map = {}
        }
    }
    pns_records_list.push(map)

    for (const records of pns_records_list) {
        var ids: string[] = []
        var data: BigNumberish[][] = []
        for (const [tok, rec] of Object.entries(records)) {
            ids.push(tok)
            data.push([rec.origin, rec.parent, rec.expire])
        }

        await (await pns.setMetadataBatch(ids, data)).wait()

        console.log(`import ${ids.length} records`)
    }
}

async function main() {
    const PNS = await ethers.getContractFactory("PNS")
    const Controller = await ethers.getContractFactory("Controller")
    const PNSForwarder = await ethers.getContractFactory("PNSForwarder")

    // load info
    const pns_info: PNSInfo = JSON.parse(readFileSync("pns_info.json", 'utf8'))
    const controller_info_list: ControllerInfo[] = JSON.parse(readFileSync("controller_info_list.json", 'utf8'))
    const address_info: AddressInfo = JSON.parse(readFileSync("address_info.json", 'utf8'))

    console.log("load info done")

    // check data
    const pns_records = check_data(pns_info, controller_info_list, address_info)

    // get contract
    const pns = await PNS.attach(PNS_ADDRESS)

    // update controller
    for (const cinfo of controller_info_list) {
        const config = cinfo.config
        const old_addr = cinfo.address
        const new_addr = address_info.controller[old_addr]

        const ctrl = Controller.attach(new_addr)

        // set manager
        for (const m of cinfo.managers) {
            await (await ctrl.setManager(m, true)).wait()
        }

        console.log(`ctrl ${new_addr} set manager done`)

        // set config
        ctrl.setContractConfig(7,
                               config.MIN_REGISTRATION_LENGTH,
                               config.MIN_REGISTRATION_DURATION,
                               config.priceFeed);

        console.log(`ctrl ${new_addr} set config done`)
    }

    // update pns metadata
    await set_metadata(pns, pns_records)

    // add manager
    for (const cinfo of controller_info_list) {
        const old_addr = cinfo.address
        const new_addr = address_info.controller[old_addr]

        await (await pns.setManager(new_addr, true)).wait()
        console.log(`pns manager ${new_addr}: ${await pns.isManager(new_addr)}`)
    }

    // restore flag
    console.log(`pns flags: ${await pns.FLAGS()}`)
    await (await pns.setContractConfig(1)).wait()
    console.log(`pns flags: ${await pns.FLAGS()}`)

    // restore root
    for (const cinfo of controller_info_list) {
        const config = cinfo.config
        const old_addr = cinfo.address
        const new_addr = address_info.controller[old_addr]

        const ctrl = Controller.attach(new_addr)

        await (await ctrl.transferRootOwnership(config.root)).wait()
        console.log(`ctrl ${new_addr} root xfer to: ${await ctrl.root()}`)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
