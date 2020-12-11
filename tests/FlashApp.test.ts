import { expect, use } from "chai";
import { deployContract, MockProvider, solidity, createFixtureLoader, loadFixture } from "ethereum-waffle";
import FlashAppArtifact from "../artifacts/contracts/FlashApp.sol/FlashApp.json"
import { constants, ContractFactory, ethers, utils, Contract } from "ethers";
import { predictFlashTokenAddress, predictFlashProtocolAddress } from './utils/utils'
import { deployFlashToken, deployFlashProtocol, deployAltToken } from './fixtures/fixtures'

use(solidity);

describe("Flash App", async () => {

    const provider = new MockProvider({
        ganacheOptions: {
            "hardfork": 'istanbul',
            "mnemonic": 'horn horn horn horn horn horn horn horn horn horn horn horn',
            "gasLimit": 9999999
        }
    })

    const [wallet, walletTo, walletThree] = provider.getWallets()


    let FlashToken: Contract;

    let FlashProtocol: Contract;

    let FlashApp: Contract;

    let AltToken: Contract;

    it('setup contracts', async () => {

        let FlashTokenAddress: string = await predictFlashTokenAddress(wallet);

        let FlashProtocolAddress: string = await predictFlashProtocolAddress(walletTo);

        const loadFixture = createFixtureLoader([wallet, walletTo], provider)

        const fixtureOne =
            await loadFixture(deployFlashToken)
        FlashToken = fixtureOne.token
        expect(FlashToken.address.toString()).to.equal(FlashTokenAddress)

        const fixtureTwo = await loadFixture(deployFlashProtocol)
        FlashProtocol = fixtureTwo.token
        expect(FlashProtocol.address.toString()).to.equal(FlashProtocolAddress)

        const fixtureThree = await loadFixture(deployAltToken)
        AltToken = fixtureThree.token
        expect(await AltToken.balanceOf(wallet.address).toString()).to.not.equal("0")

        FlashApp = await deployContract(wallet, FlashAppArtifact)

    })

});
