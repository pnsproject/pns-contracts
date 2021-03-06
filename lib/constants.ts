export const Chains: any = {
  43113: {
    name: "Avalanche Fuji Testnet",
    chain: "AVAX",
    network: "testnet",
    rpc: ["https://api.avax-test.network/ext/bc/C/rpc"],
    faucets: ["https://faucet.avax-test.network/"],
    nativeCurrency: {
      name: "Avalanche",
      symbol: "AVAX",
      decimals: 18,
    },
    infoURL: "https://cchain.explorer.avax-test.network",
    shortName: "Fuji",
    chainId: 43113,
    networkId: 1,
  },
};

export interface IContractAddrs {
  pns: string;
  controller: string;
  resolver: string;
}

export interface IContractAddrsMap {
  [index: number]: IContractAddrs;
}

export const ContractAddrMap: IContractAddrsMap = {
  43113: {
    pns: "0x03A06c4ee14b8E499aC9d1C369F1f92c8b032D00",
    controller: "0xeAb2a7a0F48BDA36dA1D3Bdfa1AB5922A3327AD7",
    resolver: "0x4897B2A10A66d444027F3B05b2c21f873ad61D8f",
  },
  31337: {
    pns: "0x3d4FC217B07Be922B584a5995D76b511736AcAF3",
    controller: "0x04bc6B8361965A9158C6210A2927C7C7EBb165F0",
    resolver: "0x7004B76d3E1b7b84E8f2f47e3387EabFD7bc9c9D",
  },
};

export const PaymentAddrs: any = {
  eth: "0x0b23E3588c906C3F723C58Ef4d6baEe7840A977c",
  avax: "0x0b23E3588c906C3F723C58Ef4d6baEe7840A977c",
  movr: "0x0b23E3588c906C3F723C58Ef4d6baEe7840A977c",
  bsc: "0x0b23E3588c906C3F723C58Ef4d6baEe7840A977c",
  dot: "",
  ksm: "",
};

export const RPC_URL = "https://api.avax-test.network/ext/bc/C/rpc";

// export const PriceOracleAddr = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419"; // ETH / USD on mainnet
// export const PriceOracleAddr = "0x5498BB86BC934c8D34FDA08E81D444153d0D06aD"; // AVAX / USD on fuji
// export const PriceOracleAddr = "0x3f8BFbDc1e79777511c00Ad8591cef888C2113C1"; // MOVR / USD on MOVR
export const PriceOracleAddr = "0xa242Cb23053b23198B5eC9a10Ff83742A30bb0D3"; // ETH / USD on hardhat
