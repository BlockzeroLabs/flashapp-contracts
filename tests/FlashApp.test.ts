import { expect, use } from "chai";
import { deployContract, MockProvider, solidity, createFixtureLoader, loadFixture } from "ethereum-waffle";
import { PoolFactory } from "../typechain/PoolFactory"
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

    let id:string;

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
        FlashProtocol = await FlashProtocol.connect(wallet)
        expect(FlashProtocol.address.toString()).to.equal(FlashProtocolAddress)

        const fixtureThree = await loadFixture(deployAltToken)
        AltToken = fixtureThree.token
        expect(await AltToken.balanceOf(wallet.address).toString()).to.not.equal("0")

        FlashApp = await deployContract(wallet, FlashAppArtifact)

    })

    it('create pool -> fail', async () => {
        await expect(FlashApp.createPool(constants.AddressZero)).to.be.revertedWith("FlashApp:: INVALID_TOKEN_ADDRESS");
    })

    it('create pool', async () => {
        await FlashApp.createPool(AltToken.address);
        expect((await FlashApp.pools(AltToken.address)).toString()).to.not.equal(constants.AddressZero);
    })

    it('create pool -> fail', async () => {
        await expect(FlashApp.createPool(AltToken.address)).to.be.revertedWith("FlashApp:: POOL_ALREADY_EXISTS");
    })

    it('approve tokens', async () => {
        await FlashToken.approve(FlashApp.address, constants.MaxUint256);
        await FlashToken.approve(FlashProtocol.address, constants.MaxUint256);
        await AltToken.approve(FlashApp.address, constants.MaxUint256);

        expect((await FlashToken.allowance(wallet.address, FlashApp.address)).toString()).to.not.equal("0");
        expect((await FlashToken.allowance(wallet.address, FlashProtocol.address)).toString()).to.not.equal("0");
        expect((await AltToken.allowance(wallet.address, FlashApp.address)).toString()).to.not.equal("0");
    })

    it('add liquidity -> fail', async () => {
        await expect(FlashApp.addLiquidityInPool("100000000000000000000",
            "100000000000000000000",
            "0",
            "0",
            constants.AddressZero)).to.be.revertedWith("FlashApp:: POOL_DOESNT_EXIST");
    })

    it('add liquidity', async () => {
        await expect(FlashApp.addLiquidityInPool("1000000000000000000000",
            "1000000000000000000000",
            "0",
            "0",
            AltToken.address)).to.emit(FlashApp, "LiquidityAdded");
    })

    it('stake', async () => {
        let encode = ethers.utils.defaultAbiCoder.encode(['address', 'uint256'], [AltToken.address.toString(), '0'])
        let tx = await FlashProtocol.stake("100000000000000000000", "2", FlashApp.address, encode);
        let receipt = await provider.getTransaction(tx.hash)
        let block = await provider.getBlock(String(receipt.blockHash))
        id = await utils.solidityKeccak256(["uint256", "uint256", "address", "address", "uint256"],
            [
                "100000000000000000000",
                "2",
                FlashApp.address,
                wallet.address,
                block.timestamp
            ]
        )
        let stake = await FlashProtocol.stakes(id)

        expect(stake.amountIn.toString()).not.equal("0")
    })

    it('unstake', async () => {
        setTimeout(async () => {
          await expect(
            FlashApp.unstake([id])
          ).to.emit(FlashProtocol, "Unstaked");
        }, 3000)
      })

    it('swap', async () => {
        await expect(FlashApp.swap("100000000000000000", AltToken.address, "0")).to.emit(FlashApp, "Swapped")
    })

    it('remove liquidity', async () => {
        let poolAddress: string = await FlashApp.pools(AltToken.address);
        let PoolContract: Contract = await PoolFactory.connect(poolAddress, provider);
        let contract = await PoolContract.connect(wallet);
        await contract.approve(FlashApp.address, constants.MaxUint256);
        await expect(FlashApp.removeLiquidityInPool((await contract.balanceOf(wallet.address)).toString(), AltToken.address)).to.emit(FlashApp, "LiquidityRemoved");
    })

});
