import { ContractFactory, Contract, BigNumberish, BigNumber } from "ethers"

export const PNS_ADDRESS = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"
export const CONTROLLER_ADDRESS_LIST = [
    "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9"
]

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
