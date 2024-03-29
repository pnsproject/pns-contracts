import { ethers, Signer, BigNumber } from "ethers";
import { keccak_256 } from "js-sha3";

import { Provider as AbstractWeb3Provider } from "@ethersproject/abstract-provider";
import { Signer as Web3Signer } from "@ethersproject/abstract-signer";

import { RPC_URL, Chains, ContractAddrMap, PaymentAddrs } from "./constants";
import { IPNS, IController, IResolver, IOwnable, IPNS__factory, IController__factory, IResolver__factory, IOwnable__factory } from "./contracts";

export const formatEther = ethers.utils.formatEther;
export const abiCoder = ethers.utils.defaultAbiCoder;

export type HexAddress = string;

export type TokenId = string;

export type DomainString = string;

export type LabelString = string;

declare abstract class Web3Provider extends AbstractWeb3Provider {
  abstract getSigner(): Promise<Web3Signer>;
}

export type DomainDetails = {
  name: string;
  label: string;
  labelhash: string;
  owner: string;

  content: string;
  contentType?: string;

  addrs: {
    key: string;
    value: string;
  }[];
  textRecords: {
    key: string;
    value: string;
  }[];
};

let provider: Web3Provider;
let signer: Web3Signer;
let account: string;
let networkId: number;

let pns: IPNS;
let controller: IController;
let resolver: IResolver;

let pnsAddr: string;
let controllerAddr: string;
let resolverAddr: string;

export function sha3(data: string) {
  return "0x" + keccak_256(data);
}

export function getNamehash(name: string) {
  let node = "0000000000000000000000000000000000000000000000000000000000000000";

  if (name) {
    let labels = name.split(".");

    for (let i = labels.length - 1; i >= 0; i--) {
      let labelSha = keccak_256(labels[i]);
      node = keccak_256(Buffer.from(node + labelSha, "hex"));
    }
  }

  return "0x" + node;
}

export const emptyAddress = "0x0000000000000000000000000000000000000000";
export const weirdNode = "0x0000000000000000000000000000000000000000000000000000000000000001";
export const emptyNode = "0x0000000000000000000000000000000000000000000000000000000000000000";
export const baseLabel = sha3("dot");
export const baseNode = getNamehash("dot");
export const nonode = "0x0000000000000000000000000000000000000000000000000000000000001234";

export const TEXT_RECORD_KEYS = ["email", "url", "avatar", "description", "notice", "keywords", "com.twitter", "com.github"];

const tld = "dot";

export function getProvider(): Web3Provider {
  return provider;
}

export function getSigner(): Web3Signer {
  return signer;
}

export function getAccount(): string {
  return account;
}

export async function setSigner(_signer?: Web3Signer) {
  if (!_signer) throw "provider is empty";
  signer = _signer;
  account = await signer.getAddress();
}

export async function setProvider(_provider?: Web3Provider) {
  // if (!!_provider) {
  //   provider = _provider;
  // } else if (!!window && typeof (window as any).ethereum !== "undefined") {
  //   provider = new ethers.providers.Web3Provider((window as any).ethereum) as any;
  // } else {
  //   console.log("cannot find a global `ethereum` object");
  //   provider = new ethers.providers.JsonRpcProvider(RPC_URL) as any;
  //   account = "0x0";
  // }
  if (!_provider) throw "provider is empty";
  provider = _provider;

  networkId = (await provider.getNetwork()).chainId;
  console.log("network", networkId);
  return;
}

export async function setup(providerOpt?: Web3Provider, pnsAddress?: string, controllerAddress?: string) {
  await setProvider(providerOpt);

  let addrMap = ContractAddrMap[networkId];
  console.log("addrs", addrMap);

  pnsAddress = pnsAddress || addrMap.pns;
  controllerAddress = controllerAddress || addrMap.controller;

  if (signer) {
    pns = IPNS__factory.connect(pnsAddress, signer);
    controller = IController__factory.connect(controllerAddress, signer);
    resolver = IResolver__factory.connect(pnsAddress, signer);
  } else {
    pns = IPNS__factory.connect(pnsAddress, provider);
    controller = IController__factory.connect(controllerAddress, provider);
    resolver = IResolver__factory.connect(pnsAddress, provider);
  }

  pnsAddr = pnsAddress;

  return {
    provider,
    pns,
    controller,
    resolver,
  };
}

export async function setupWithContract(providerOpt: Web3Provider, pnsContract: IPNS, registrarContract: IController, resolverContract: IResolver) {
  await setProvider(providerOpt);

  pns = pnsContract;
  controller = registrarContract;
  resolver = resolverContract;

  pnsAddr = pns.address;
  controllerAddr = controller.address;
  resolverAddr = resolver.address;

  return {
    provider,
    pns,
    controller,
    resolver,
  };
}

export async function getOwner(name: DomainString): Promise<HexAddress> {
  let tokenId = getNamehash(name);
  if (await pns.exists(tokenId)) {
    console.log("tokenId", tokenId);
    return pns.ownerOf(tokenId);
  } else {
    return emptyAddress;
  }
}

export async function getOwnerOf(tokenId: TokenId): Promise<HexAddress> {
  if (await pns.exists(tokenId)) {
    return pns.ownerOf(tokenId);
  } else {
    return emptyAddress;
  }
}

export async function ownerOfName(name: DomainString): Promise<HexAddress> {
  let tokenId = getNamehash(name);
  return pns.ownerOf(tokenId);
}

export async function ownerOfId(tokenId: TokenId): Promise<HexAddress> {
  return pns.ownerOf(tokenId);
}

export async function exists(name: DomainString): Promise<boolean> {
  let tokenId = getNamehash(name);
  return pns.exists(tokenId);
}

export async function totalRegisterPrice(name: LabelString, duration: number): Promise<BigNumber> {
  return controller.totalRegisterPrice(name, duration);
}

export async function renewPrice(name: LabelString, duration: number): Promise<BigNumber> {
  return controller.renewPrice(name, duration);
}

export async function getControllerRoot(): Promise<HexAddress> {
  let ownable = IOwnable__factory.connect(controller.address, provider);
  return ownable.root();
}

export async function transferController(newRoot: HexAddress) {
  let ownable = IOwnable__factory.connect(controller.address, signer);
  return ownable.transferRootOwnership(newRoot);
}

export async function basePrice(name: LabelString): Promise<BigNumber> {
  return controller.basePrice(name);
}

export async function rentPrice(name: LabelString, duration: number): Promise<BigNumber> {
  return controller.rentPrice(name, duration);
}

export async function getPrices() {
  return controller.getPrices();
}

export async function getTokenPrice() {
  return controller.getTokenPrice();
}

export async function nameExpires(label: DomainString): Promise<BigNumber> {
  label = suffixTld(label);
  return controller.expire(getNamehash(label));
}

export async function available(label: DomainString): Promise<boolean> {
  label = suffixTld(label);
  return controller.available(getNamehash(label));
}

export async function register(label: DomainString, account: string, duration: number) {
  const price = await totalRegisterPrice(label, duration);
  return controller.nameRegister(label, account, duration, { value: price });
}

export async function registerWithConfig(label: DomainString, account: string, duration: number, keys: string[], values: string[]) {
  const price = await totalRegisterPrice(label, duration);
  return controller.nameRegisterWithConfig(label, account, duration, [], [], { value: price });
}

export function mintSubdomain(newOwner: HexAddress, name: DomainString, label: LabelString) {
  let tokenId = getNamehash(name);
  return controller.mintSubdomain(newOwner, tokenId, label);
}

export async function approve(name: DomainString, approved: HexAddress) {
  name = suffixTld(name);
  let tokenId = getNamehash(name);
  return pns.approve(approved, tokenId);
}

export async function getApproved(name: DomainString): Promise<HexAddress> {
  name = suffixTld(name);
  let tokenId = getNamehash(name);
  return await pns.getApproved(tokenId);
}

export function suffixTld(label: DomainString): DomainString {
  return label.replace(".dot", "") + ".dot";
}

export function removeTld(label: DomainString): DomainString {
  return label.replace(".dot", "");
}

export async function setName(addr: HexAddress, name: DomainString, resv?: IResolver) {
  const tokenId = getNamehash(name);
  return resolver.setName(addr, tokenId);
}

export async function getName(addr: HexAddress, resv?: IResolver): Promise<BigNumber> {
  return resolver.getName(addr);
}

export async function setNftName(nftAddr: HexAddress, nftTokenId: string, nameTokenId: TokenId) {
  return resolver.setNftName(nftAddr, nftTokenId, nameTokenId);
}

export async function getNftName(nftAddr: HexAddress, nftTokenId: string) {
  return resolver.getNftName(nftAddr, nftTokenId);
}

export async function getKey(name: DomainString, key: string, resv?: IResolver): Promise<string> {
  const tokenId = getNamehash(name);
  return resolver.get(key, tokenId);
}

export async function setKeysByHash(name: DomainString, keys: string[], values: string[], resv?: IResolver) {
  const tokenId = getNamehash(name);
  return resolver.setManyByHash(keys, values, tokenId);
}

export async function getKeys(name: DomainString, key: string[], resv?: IResolver): Promise<string[]> {
  const tokenId = getNamehash(name);
  return resolver.getMany(key, tokenId);
}

export async function getKeysByHash(name: DomainString, key: string[], resv?: IResolver) {
  const tokenId: TokenId = getNamehash(name);
  return resolver.getManyByHash(key as any, tokenId);
}
// return await resv.getMany(key, tokenId);

function buildKeyValueObjects(keys: any, values: any) {
  return values.map((record: any, i: any) => ({
    key: keys[i],
    value: record,
  }));
}

export function getLabelhash(rawlabel: string): HexAddress {
  if (rawlabel === "[root]") {
    return "";
  }

  return rawlabel.startsWith("[") && rawlabel.endsWith("]") && rawlabel.length === 66 ? "0x" + rawlabel.slice(1, -1) : "0x" + keccak_256(rawlabel);
}

function decodeLabelhash(hash: string): string {
  if (!(hash.startsWith("[") && hash.endsWith("]") && hash.length === 66)) {
    throw Error("Expected encoded labelhash in [hash] form");
  }
  return `${hash.slice(1, -1)}`;
}

export async function getDomainDetails(name: DomainString): Promise<DomainDetails> {
  const nameArray = name.split(".");
  const label = nameArray[0];
  const labelhash = getLabelhash(label);
  const owner = await getOwner(name);

  const promises = TEXT_RECORD_KEYS.map((key) => getKey(name, "text." + key));
  const records = await Promise.all(promises);
  let textRecords = buildKeyValueObjects(TEXT_RECORD_KEYS, records);

  const node = {
    name,
    label,
    labelhash,
    owner,
    textRecords: textRecords,
  };

  const content = await getKey(name, "contenthash");
  return {
    ...node,
    addrs: [
      { key: "BTC", value: await getKey(name, "BTC") },
      { key: "ETH", value: await getKey(name, "ETH") },
      { key: "DOT", value: await getKey(name, "DOT") },
      { key: "KSM", value: await getKey(name, "KSM") },
    ],
    content: content,
    contentType: "ipfs",
  };
}

export async function nameRedeem(label: DomainString, account: string, duration: number, deadline: number, code: string) {
  return controller.nameRedeem(label, account, duration, deadline, code);
}

export async function registerByManager(label: DomainString, account: string, duration: number) {
  return controller.nameRegisterByManager(label, account, duration, [], []);
}

export async function renew(label: LabelString, duration: number) {
  const price = await renewPrice(label, duration);
  return controller.renew(label, duration, { value: price });
}

export async function renewByManager(label: LabelString, duration: number) {
  return controller.renewByManager(label, duration);
}

export async function transferName(name: DomainString, newOwner: HexAddress) {
  let namehash = getNamehash(name);
  let oldOwner = await getOwner(name);
  return pns.transferFrom(oldOwner, newOwner, namehash);
}

export async function registerPayWithOtherCurrency(chain: string, label: DomainString, duration: number): Promise<any> {
  // todo : if user close before tx success, need recovering
  let price = await totalRegisterPrice(label, duration);
  let tx = await signer.sendTransaction({
    to: PaymentAddrs[chain] as string,
    value: price,
  });
  return {
    data: {
      chain: chain,
      label: label,
      duration: duration,
      txhash: tx.hash,
      value: tx.value.toString(),
      from: tx.from,
      to: tx.to,
      managed: true,
    },
    tx: tx,
  };
}

// sign message and generate redeem code

export function abiDataEncode(data: any, datatype: string): Buffer {
  let encoded = abiCoder.encode([datatype], [data]).slice(2);
  return Buffer.from(encoded, "hex");
}

export function encodeMsg(nameTokenId: string, address: string, duration: number, deadline: number, chainId: number, contractAddr: string): Uint8Array {
  let nameTokenIdBuffer = abiDataEncode(nameTokenId, "string");
  let addressBuffer = abiDataEncode(address, "uint160").slice(12);
  let durationBuffer = abiDataEncode(duration, "uint64").slice(24);
  let deadlineBuffer = abiDataEncode(deadline, "uint");
  let chainIdBuffer = abiDataEncode(chainId, "uint");
  let contractAddrBuffer = abiDataEncode(contractAddr, "uint");
  // console.log('data', Buffer.concat([nameTokenIdBuffer, addressBuffer, durationBuffer]).toString('hex'))
  // address type has strange padding, which doesn't work
  // console.log(ethers.utils.defaultAbiCoder.encode(['uint256', 'address', 'uint256'], [nameTokenId, address, duration]))
  return Buffer.concat([nameTokenIdBuffer, addressBuffer, durationBuffer, deadlineBuffer, chainIdBuffer, contractAddrBuffer]);
}

export function hashMsg(data: Uint8Array): Uint8Array {
  let hashed = "0x" + keccak_256(data);
  return ethers.utils.arrayify(hashed);
}

export async function generateRedeemCode(nameTokenId: string, address: string, duration: number, deadline: number, chainId: number, contractAddr: string, signer: any): Promise<string> {
  console.log('input', nameTokenId, address, duration, deadline, chainId, contractAddr)
  let msg = encodeMsg(nameTokenId, address, duration, deadline, chainId, contractAddr);
  let hashedMsg = hashMsg(msg);
  return signer.signMessage(hashedMsg);
}
