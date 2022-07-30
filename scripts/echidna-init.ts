import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ContractFactory, Contract, BigNumberish, BigNumber } from "ethers";
import { writeFileSync, promises as fsPromises } from 'fs';

import { getNamehash } from "../lib/helper"

const SENDER_POOL: string[] = [
    "0x5409ED021D9299bf6814279A6A1411A7e866A631",
    "0x6Ecbe1DB9EF729CBe972C83Fb886247691Fb6beb",
    "0xE36Ea790bc9d7AB70C55260C66D52b1eca985f84",
]

const SENDER_PK: Record<string, string> = {
    "0x5409ED021D9299bf6814279A6A1411A7e866A631": "0xf2f48ee19680706196e2e339e5da3491186e0c4c5030670656b0e0164837257d",
    "0x6Ecbe1DB9EF729CBe972C83Fb886247691Fb6beb": "0x5d862464fe9303452126c8bc94274b8c5f9874cbd219789b3eb2128075a76f72",
    "0xE36Ea790bc9d7AB70C55260C66D52b1eca985f84": "0xdf02719c4df8b9b8ac7f551fcb5d9ef48fa27eef7a66453879f4d8fdc6e78fb1",
}

const WORD_SET: string[] = [
    "dot", "com", "net", "org", "hello", "world"
]

let P: Contract
let GRACE_PERIOD: number = 360 * 86400
let _pns_root: string
let _pns_manager_set: string[] = []
let _pns_owner_tbl: Record<string, string> = {}
let _pns_token_set: string[] = []

let C: Contract[] = []
let C_BASE_NODE: string[] = []
let _c_root: string[] = []
let _c_manager_set: string[][] = [[],[]]
let _c_price_feed: string[] = []
let _c_base_prices: number[][] = [ [2000, 2000, 2000, 200, 200, 20] , [5000, 2500, 1250, 10, 5]]
let _c_rent_prices: number[][] = [[500, 400, 300, 100, 5], [300, 200, 100, 50, 30, 20]]

let NFT: Contract[] = []
let PRICE: Contract[] = []

const TEST_CONTRACT_ADDR = "0x00a329c0648769A73afAc7F9381E08FB43dBEA72"

let _signers: SignerWithAddress[]
let _deployer: SignerWithAddress

async function signer_init() {
    _signers = await ethers.getSigners()

    _deployer = _signers[0]

    expect(_signers[0].address).to.equal(SENDER_POOL[0])
    expect(_signers[1].address).to.equal(SENDER_POOL[1])
    expect(_signers[2].address).to.equal(SENDER_POOL[2])
}

async function nft_init() {
    const MacroNFT = await ethers.getContractFactory("MacroNFT")
    NFT[0] = await MacroNFT.deploy()
    NFT[1] = await MacroNFT.deploy()

    await NFT[0].deployed()
    await NFT[1].deployed()

    for (var i = 0; i < 10; i++) {
        await (await NFT[0].mint(SENDER_POOL[i % 3])).wait()
        await (await NFT[1].mint(SENDER_POOL[(i + 1) % 3])).wait()
    }

    await (await NFT[0].transferOwnership(SENDER_POOL[1])).wait()
    await (await NFT[1].transferOwnership(SENDER_POOL[2])).wait()
}

async function price_init() {
    const PriceOracle = await ethers.getContractFactory("PriceOracle")
    PRICE[0] = await PriceOracle.deploy(Math.floor(79.2222 * 100000000))
    PRICE[1] = await PriceOracle.deploy(Math.floor(47.1234 * 100000000))

    await PRICE[0].deployed()
    await PRICE[1].deployed()
}

async function pns_and_controller_init() {
    // pns
    const PNS = await ethers.getContractFactory("PNS")
    P = await upgrades.deployProxy(PNS, [], { constructorArgs: [TEST_CONTRACT_ADDR] })

    await P.deployed()

    // NOTE, ManagerOwnableUpgradeable will add deployer to manager set
    _pns_manager_set.push(_deployer.address)

    // controller
    const Controller = await ethers.getContractFactory("Controller")
    for (var i = 0; i < 2; i++) {
        C_BASE_NODE[i] = getNamehash(WORD_SET[i])
        _c_price_feed[i] = PRICE[i].address

        C[i] = await Controller.deploy(P.address, C_BASE_NODE[i], _c_base_prices[i],
                                       _c_rent_prices[i], _c_price_feed[i], TEST_CONTRACT_ADDR);
        await C[i].deployed()
    }
}

async function pns_and_controller_setup() {
    // setup pns
    for (var i = 0; i < 2; i++) {
        // set manager
        await (await P.setManager(C[i].address, true)).wait()
        _pns_manager_set.push(C[i].address)

        // mint base node
        await (await P.mint(C[i].address, C_BASE_NODE[i])).wait()
        _pns_owner_tbl[C_BASE_NODE[i]] = C[i].address
        _pns_token_set.push(C_BASE_NODE[i])
    }

    // setup controller
    for (var i = 0; i < 2; i++) {
        await (await C[i].setManager(SENDER_POOL[i+1], true)).wait()
        _c_manager_set[i].push( SENDER_POOL[i+1])
    }

    // finally, transfer ownership
    await (await P.transferRootOwnership(SENDER_POOL[0])).wait()
    _pns_root = SENDER_POOL[0]

    for (var i = 0; i < 2; i++) {
        await (await C[i].transferRootOwnership(SENDER_POOL[i+1])).wait()
        _c_root[i] = SENDER_POOL[i+1]
    }
}

async function echidna_init() {
    await signer_init()
    await nft_init()
    await price_init()

    await pns_and_controller_init()
    await pns_and_controller_setup()
}

async function echidna_gen(fn: string) {
    let data: string = ""

    data += `// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../pns/PNS.sol";
import "../pns/PNSController.sol";
import "../MacroNFT.sol";

contract EchidnaInit {
using EnumerableSet for EnumerableSet.AddressSet;
using EnumerableSet for EnumerableSet.UintSet;
using EnumerableMap for EnumerableMap.UintToAddressMap;

// const
EnumerableSet.AddressSet    SENDER_POOL;
mapping(address => uint256) SENDER_PK;

uint256 GRACE_PERIOD = ${GRACE_PERIOD};

PNS P                          = PNS(${P.address});
Controller[2] C                = [Controller(${C[0].address}), Controller(${C[1].address})];
MacroNFT[2] NFT                = [MacroNFT(${NFT[0].address}), MacroNFT(${NFT[1].address})];
AggregatorV3Interface[2] PRICE = [AggregatorV3Interface(${PRICE[0].address}), AggregatorV3Interface(${PRICE[1].address})];

uint256[2] C_BASE_NODE = [${C_BASE_NODE[0]}, ${C_BASE_NODE[1]}];

// pns var
address _pns_root;
EnumerableSet.AddressSet       _pns_manager_set;
EnumerableMap.UintToAddressMap _pns_owner_tbl;
EnumerableSet.UintSet          _pns_token_set;

// controller val
address[2] _c_root;
EnumerableSet.AddressSet[2] _c_manager_set;
AggregatorV3Interface[2] _c_price_feed;
uint256[][2] _c_base_prices;
uint256[][2] _c_rent_prices;

constructor() {
`
    // SENDER_POOL
    for (const a of SENDER_POOL) {
        data += `SENDER_POOL.add(${a});\n`
    }
    data += "\n"

    // SENDER_PK
    for (const [a,pk] of Object.entries(SENDER_PK)) {
        data += `SENDER_PK[${a}] = ${pk};\n`
    }
    data += "\n"

    // _pns_root
    data += `_pns_root = ${_pns_root};\n`
    data += "\n"

    // _pns_manager_set
    for (const a of _pns_manager_set) {
        data += `_pns_manager_set.add(${a});\n`
    }

    data += "\n"

    // _pns_owner_tbl
    for (const [t, o] of Object.entries(_pns_owner_tbl)) {
        data += `_pns_owner_tbl.set(${t}, ${o});\n`
    }

    data += "\n"

    // _pns_token_set
    for (const t of _pns_token_set) {
        data += `_pns_token_set.add(${t});\n`
    }

    data += "\n"

    // controller
    for (var i = 0; i < 2; i++) {
        data += `// Controller ${i}\n`
        data += `_c_root[${i}] = ${_c_root[i]};\n`
        for (const m of _c_manager_set[i]) {
            data += `_c_manager_set[${i}].add(${m});\n`
        }
        data += `_c_price_feed[${i}] = AggregatorV3Interface(${_c_price_feed[i]});\n`
        data += "\n"
        data += `_c_base_prices[${i}] = new uint256[](${_c_base_prices[i].length});\n`
        for (var j = 0; j < _c_base_prices[i].length; j++) {
            data += `_c_base_prices[${i}][${j}] = ${_c_base_prices[i][j]};\n`
        }
        data += "\n"
        data += `_c_rent_prices[${i}] = new uint256[](${_c_rent_prices[i].length});\n`
        for (var j = 0; j < _c_rent_prices[i].length; j++) {
            data += `_c_rent_prices[${i}][${j}] = ${_c_rent_prices[i][j]};\n`
        }
        data += "\n"
    }

    data += "\n}\n}"

    writeFileSync(fn, data, {
        flag: 'w',
    })
}

async function main() {
    await echidna_init()
    await echidna_gen("./contracts/fuzzing/EchidnaInit.sol")
}

main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error(e)
        process.exit(1)
    })
