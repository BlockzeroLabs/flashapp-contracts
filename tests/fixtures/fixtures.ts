import { deployContract } from 'ethereum-waffle'
import { Contract, Wallet, ethers, ContractFactory } from 'ethers'
import FlashTokenArtifact from '../../artifacts/contracts/tests/flash-token/Flashtoken.sol/FlashToken.json'
import FlashProtocolArticact from '../../artifacts/contracts/tests/flash-protocol/FlashProtocol.sol/FlashProtocol.json'
import AltTokenArtifact from '../../artifacts/contracts/tests/alt-token/ALTToken.sol/ALTToken.json'

interface Token {
    token: Contract
}

let AMOUNT = "500000000000000000000000"

let FlashProtocol:string = "0x54421e7a0325cCbf6b8F3A28F9c176C77343b7db"


export async function deployFlashToken(
    address: Wallet[], provider: ethers.providers.Web3Provider
)
: Promise<Token>
 {
    let token = await deployContract(address[0],FlashTokenArtifact, [address[0].address,FlashProtocol])
    await token.mint(address[0].address,AMOUNT)
    return {token }
}

export async function deployFlashProtocol(
    address: Wallet[], provider: ethers.providers.Web3Provider
): Promise<Token> {
    let token = await deployContract(address[1], FlashProtocolArticact, [address[0].address])
    return { token }
}


export async function deployAltToken(address: Wallet[], provider: ethers.providers.Web3Provider): Promise<Token> {
    let token = await deployContract(address[0], AltTokenArtifact)
    return { token }
}

