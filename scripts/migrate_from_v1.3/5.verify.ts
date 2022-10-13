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

function toHexString(a: BigNumberish): string {
    return BigNumber.from(a).toHexString()
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

    // verify
    console.log("NOTE: only below data, and assume openzeppelin upgradeable contract will preserve all original state")
    console.log(" 1. token in pns_info.token_list exist")
    console.log(" 2. pns records")

    // verify existance
    var cnt = 0
    for (const tok of pns_info.token_list) {
        if (await pns.exists(tok) == false) {
            throw(`ERROR: token ${tok} not exist`)
        }
        cnt++
    }
    console.log(`PASS: all ${cnt} token still exist`)

    cnt = 0
    for (const [tok, rec] of Object.entries(pns_records)) {
        var origin: string = toHexString(await pns.origin(tok))
        var expire: number = toNum(await pns.expire(tok))
        var parent: string = toHexString(await pns.parent(tok))

        if (origin != toHexString(rec.origin)) {
            throw(`ERROR: token ${tok} origin mismatch, ${origin} != ${rec.origin}`)
        }

        if (expire != toNum(rec.expire)) {
            throw(`ERROR: token ${tok} expire mismatch, ${expire} != ${rec.expire}`)
        }

        if (parent != toHexString(rec.parent)) {
            throw(`ERROR: token ${tok} parent mismatch, ${parent} != ${rec.parent}`)
        }
        cnt++
    }
    console.log(`PASS: all ${cnt} records match`)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
