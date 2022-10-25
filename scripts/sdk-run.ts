import { ethers } from "hardhat";
import { Signer, BigNumber } from "ethers";
import { SDK, sha3, getNamehash } from "./sdk";


async function main() {

  let oneAddr: string, twoAddr: string, threeAddr: string, fourAddr: string, fiveAddr: string;
  let one: Signer, two: Signer, three: Signer, four: Signer, five: Signer;

  [one, two, three] = await ethers.getSigners();
  [oneAddr, twoAddr, threeAddr] = await Promise.all([one, two, three].map((s) => s.getAddress()));

  let contracts = {
    "pns": "0x",
    "controller": "0x",
    "forwarder": "0x",
  }
  let sdk = new SDK(contracts["pns"], contracts["controller"], two)
  console.log(await sdk.namehash("gavinwood.dot"))
  console.log(await sdk.ownerOfId(getNamehash("gavinwood.dot")))
  console.log(await sdk.ownerOfName("gavinwood.dot"))
  console.log(await sdk.exists("gavinwood.dot"))
  console.log(await sdk.getOwner("gavinwood.dot"))
  console.log(await sdk.totalRegisterPrice("gavinwood.dot", 86400*365))
  console.log(await sdk.renewPrice("gavinwood.dot", 86400*365))

  console.log(await sdk.getPnsRoot())
  console.log(await sdk.getControllerRoot())

  console.log(await sdk.basePrice("gavinwood.dot"))
  console.log(await sdk.rentPrice("gavinwood.dot", 86400*365))
  console.log(await sdk.getPrices())
  console.log(await sdk.getTokenPrice())

  console.log(await sdk.nameExpires("gavinwood.dot"))
  console.log(await sdk.available("gavinwood.dot"))
  // console.log(await sdk.register("gavinwood001", twoAddr, 365*86400))
  // console.log(await sdk.registerWithConfig("gavin000", twoAddr, 365*86400, 1, [], []))
  // console.log(await sdk.mintSubdomain(twoAddr, "gavin000.dot", "sub0"))
  // console.log(await sdk.approve("sub0.gavin000.dot", threeAddr))
  console.log(await sdk.getApproved("sub0.gavin000.dot"))

  // console.log(await sdk.setName(twoAddr, "gavin000.dot"))
  console.log(await sdk.getName(twoAddr))

  // console.log(await sdk.setNftName(sdk.pns.address, getNamehash("sub0.gavin000.dot"), getNamehash("gavin000.dot")))
  // console.log(await sdk.getNftName(sdk.pns.address, getNamehash("sub0.gavin000.dot")))

  // console.log(await sdk.setKeysByHash("gavin000.dot", [sha3("ETH")], [twoAddr]))
  console.log(await sdk.getKey("gavin000.dot", "ETH"))
  console.log(await sdk.getKeys("gavin000.dot", ["ETH"]))
  console.log(await sdk.getKeysByHash("gavin000.dot", [sha3("ETH")]))
  console.log(await sdk.getDomainDetails("gavin000.dot"))

  // console.log(await sdk.registerByManager("gavin002", twoAddr, 365*86400, 1, [], []))
  // console.log(await sdk.renew("gavin000", 86400*365))
  // console.log(await sdk.renewByManager("gavin000", 86400*365))

  // console.log(await sdk.transferName("sub0.gavin000.dot", threeAddr))
  console.log(await sdk.mintSubdomain(twoAddr, "gavin000.dot", "sub1"))
  console.log(await sdk.burn("sub1.gavin000.dot"))
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
