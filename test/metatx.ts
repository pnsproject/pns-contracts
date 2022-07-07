import chai from "chai"

//import chaiAsPromised from 'chai-as-promised'
//chai.use(chaiAsPromised)

import { expect } from "chai"
import { ethers, upgrades } from "hardhat"
import { ContractFactory, Contract, BigNumberish, BigNumber } from "ethers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

import { TransactionReceipt } from "@ethersproject/providers"

import { deployPNS, deployForwarder, deployPriceOracle } from "./scripts"

import { getNamehash } from "../lib/helper";

// NOTE: only _msgSender() is used for all contracts, except in constructor,
// so only test any of function that need check sender should enough for
// metatx functionality.
describe("metatx", () => {
    let _forwarder: Contract
    let _priceFeed: Contract
    let _pns: Contract
    let _controller: Contract

    let _owner: SignerWithAddress
    let _other1: SignerWithAddress
    let _other2: SignerWithAddress

    async function forwardRequestDomain(): Promise<{
        name: string,
        version: string,
        chainId: number,
        verifyingContract: string
    }> {
        return {
            name              : "PNSForwarder",
            version           : "0.1.0",
            chainId           : await _owner.getChainId(),
            verifyingContract : _forwarder.address
        }
    }

    interface ForwardRequest {
        from: string,
        to: string,
        value: BigNumberish,
        gas: BigNumberish,
        nonce: BigNumberish,
        data: string
    }

    const ForwardRequestType = {
        ForwardRequest: [
            { name: 'from'  , type: 'address' },
            { name: 'to'    , type: 'address' },
            { name: 'value' , type: 'uint256' },
            { name: 'gas'   , type: 'uint256' },
            { name: 'nonce' , type: 'uint256' },
            { name: 'data'  , type: 'bytes' }
        ]
    }

    before(async () => {
        const signers = await ethers.getSigners()
        _owner = signers[0]
        _other1 = signers[1]
        _other2 = signers[2]

        _forwarder = await ethers.getContractAt("PNSForwarder", await deployForwarder())
        _priceFeed = await ethers.getContractAt("AggregatorV3Interface", await deployPriceOracle())

        let res = await deployPNS()

        _pns = res.pns
        _controller = res.controller
    })

    describe("PNS", () => {
        async function xMint(sender: SignerWithAddress, to: BigNumberish, domain: BigNumberish) {
            let xFrom = sender.address
            let xReq = {
                from: xFrom,
                to: _pns.address,
                value: 0,
                gas: 1000000,
                nonce: await _forwarder.getNonce(xFrom),
                data: _pns.interface.encodeFunctionData("mint", [to, domain])
            }

            let xSignature = await sender._signTypedData(
                await forwardRequestDomain(), ForwardRequestType, xReq
            )

            expect(await _forwarder.verify(xReq, xSignature)).to.be.true

            let tx = await _forwarder.execute(xReq, xSignature)
            await tx.wait()
        }

        it("mint from root should success", async () => {
            let domain = ethers.utils.id("a1")

            await xMint(_owner, _other1.address, domain)

            expect(await _pns.exists(domain)).to.be.true
            expect(await _pns.ownerOf(domain)).to.be.equal(_other1.address)
        })

        it("mint from non-root should fail", async () => {
            let domain = ethers.utils.id("a2")

            await xMint(_other1, _other1.address, domain)
            expect(await _pns.exists(domain)).to.be.false
        })
    })


    // Now, we try to send so ether
    describe("Controller", () => {
        // here, 'other2' entrust 'other1' to registry a top domain, via _forwarder
        // we check payable & eth return, NOTE, eth return will to 'other2', *NOT* 'other1'
        // NOTE: here not use 'owner', due price will send to owner
        it("nameRegister should work with metatx, test payable, and eth return", async () => {
            let name = "0123456789"
            let duration = 365 * 24 * 3600 // 1yr

            let price = await _controller.totalRegisterPrice(name, duration)
            // we add 0.1 ether, extra 0.1 ether will return to '
            let value = ethers.utils.parseEther("0.1").add(price)

            let xFrom = _other2.address
            let xReq = {
                from: xFrom,
                to: _controller.address,
                value,
                gas: 1000000,
                nonce: await _forwarder.connect(_other1).getNonce(xFrom), // NOTE: getNonce will cost gas
                data: _controller.interface.encodeFunctionData("nameRegister", [name, _other2.address, duration])
            }

            let xSignature = await _other2._signTypedData(
                await forwardRequestDomain(), ForwardRequestType, xReq
            )

            let other2Balance = await _other2.getBalance()
            let ownerBalance = await _owner.getBalance()

            // execute should call by _other
            let tx = await _forwarder.connect(_other1).execute(xReq, xSignature, { value })
            await tx.wait()

            // we will check,
            // 1. new name 'test-domain-name.dot' belong to 'owner'
            let tok = getNamehash(name + ".dot")
            expect(await _pns.ownerOf(tok)).to.be.equal(_other2.address)

            // 2. 'owner' has extra 0.1 ether return by _pns, which send by 'other' via _forwarder
            //     and price will send to _owner
            let ownerBalanceNew = await _owner.getBalance()
            let other2BalanceNew = await _other2.getBalance()

            //console.log({price, value, ownerBalance, ownerBalanceNew, other2Balance, other2BalanceNew))
            expect(other2BalanceNew).to.equal(other2Balance.add(ethers.utils.parseEther("0.1")))
            expect(ownerBalanceNew).to.equal(ownerBalance.add(price))
        })

        // call nameRegisterByManager, return domain, sender is _other2
        async function xNameRegisterByManager(
            signer: SignerWithAddress,
            name: string,
            to: BigNumberish,
            duration: BigNumberish // data = 0, keyHashes = [], values = []
        ): Promise<BigNumberish> {
            let xFrom = signer.address
            let xReq = {
                from: xFrom,
                to: _controller.address,
                value: 0,
                gas: 1000000,
                nonce: await _forwarder.connect(signer).getNonce(xFrom),
                data: _controller.interface.encodeFunctionData("nameRegisterByManager",
                                                               [name, to, duration, 0, [], []])
            }
            let xSignature = await signer._signTypedData(
                await forwardRequestDomain(), ForwardRequestType, xReq
            )

            let tx = await _forwarder.connect(_other2).execute(xReq, xSignature)
            await tx.wait()

            return getNamehash(name + ".dot")
        }

        it("nameRegisterByManager should fail before set as manager", async () => {
            let tok = await xNameRegisterByManager(_other1, "1234", _other2.address, 365 * 24 * 3600)
            expect(await _pns.exists(tok)).to.be.false
        })

        // NOTE: here, manager of controller is not manager of PNS
        it("nameRegisterByManager should success after set as manager", async () => {
            await _controller.setManager(_other1.address, true)

            let tok = await xNameRegisterByManager(_other1, "1234", _other2.address, 365 * 24 * 3600)
            expect(await _pns.ownerOf(tok)).to.be.equal(_other2.address)
        })
    })
})
