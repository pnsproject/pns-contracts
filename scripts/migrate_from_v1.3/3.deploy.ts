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

function check_data(pns_info: PNSInfo, controller_info_list: ControllerInfo[]): Record<string, PNSRecord> {
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

    // check data
    const pns_records = check_data(pns_info, controller_info_list)

    // deploy forwarder
    const forwarder = await PNSForwarder.deploy()
    await forwarder.deployed()
    console.log(`forwarder address ${forwarder.address}`)

    // see https://github.com/OpenZeppelin/openzeppelin-upgrades/issues/241#issuecomment-1192657444
    // https://github.com/OpenZeppelin/openzeppelin-upgrades/pull/517
    console.log("NOTE: please copy .openzepplin/*.json file when report below error:")
    console.log(`"Deployment at address 0x... is not registered"`)

    // get contract
    const pns = await upgrades.upgradeProxy(PNS_ADDRESS, PNS,
                                            {constructorArgs: [forwarder.address]});
    await pns.deployed()

    let address_info: AddressInfo = {
        forwarder: forwarder.address,
        controller: {}
    }

    for (const cinfo of controller_info_list) {
        const config = cinfo.config
        const ctrl = await Controller.deploy(PNS_ADDRESS, config.BASE_NODE,
                                             config.basePrices,
                                             config.rentPrices,
                                             config.priceFeed,
                                             forwarder.address)
        await ctrl.deployed()

        address_info.controller[cinfo.address] = ctrl.address
    }


    save_file("address_info.json", JSON.stringify(address_info, null, 2))
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
