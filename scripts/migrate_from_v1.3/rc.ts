import { ContractFactory, Contract, BigNumberish, BigNumber } from "ethers"

export var PNS_ADDRESS: string
export var PNS_BLOCK: number
export var CONTROLLER_ADDRESS_LIST: string[]

if (process.env.HARDHAT_NETWORK == "localhost") {
    PNS_ADDRESS  = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"
    PNS_BLOCK = 1
    CONTROLLER_ADDRESS_LIST = [
        "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9"
    ]
}
else if (process.env.HARDHAT_NETWORK == "glmr") {
    PNS_ADDRESS = "0x7d5F0398549C9fDEa03BbDde388361827cb376D5"
    PNS_BLOCK = 1270370
    CONTROLLER_ADDRESS_LIST = [
        "0x2dF0fC48837e69D26eFA50fD3baE86977903B697"
    ]
}


export interface ControllerRecord {
    origin: BigNumberish
    expire: BigNumberish
    capacity: number
    children: number
}

export interface PNSRecord {
    origin: BigNumberish
    expire: BigNumberish
    parent: BigNumberish
}

export interface NewSubdomain {
    to: string
    tokenId: BigNumberish
    subtokenId: BigNumberish
    name: string
}

export interface ControllerConfig {
    BASE_NODE: BigNumberish
    MIN_REGISTRATION_DURATION: number
    MIN_REGISTRATION_LENGTH: number
    GRACE_PERIOD: number
    basePrices: number[]
    rentPrices: number[]
    priceFeed: string
    root: string
}
