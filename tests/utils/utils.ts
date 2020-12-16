import { Contract, ContractFactory, ethers } from 'ethers'
import FlashTokenArtifact from '../../artifacts/contracts/tests/flash-token/Flashtoken.sol/FlashToken.json'
import FlashProtocolArtifact  from '../../artifacts/contracts/tests/flash-protocol/FlashProtocol.sol/FlashProtocol.json'



export async function predictFlashTokenAddress(owner:ethers.Wallet) : Promise<string> {
    const factory = new ContractFactory(
        FlashTokenArtifact.abi,
        FlashTokenArtifact.bytecode,
        owner
    );
    let nonce = await owner.getTransactionCount();
    let address = await ethers.utils.getContractAddress({from:owner.address, nonce})
    return address;
}

export async function predictFlashProtocolAddress(owner:ethers.Wallet) : Promise<string> {
    const factory = new ContractFactory(
        FlashProtocolArtifact.abi,
        FlashProtocolArtifact.bytecode,
        owner
    );
    let nonce = await owner.getTransactionCount();
    let address = await ethers.utils.getContractAddress({from:owner.address, nonce})
    return address;
}
