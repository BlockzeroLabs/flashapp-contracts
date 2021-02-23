import { ethers } from "hardhat";
import { ContractFactory} from 'ethers'
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import FlashAppArtifact from "../artifacts/contracts/FlashApp.sol/FlashApp.json";
import PoolErc20Artifact from "../artifacts/contracts/pool/contracts/PoolERC20.sol/PoolERC20.json";
const FLASH_ADDRESS = "0xB4467E8D621105312a914F1D42f10770C0Ffe3c8";
const XIO_ADDRESS = "0x0f7F961648aE6Db43C75663aC7E5414Eb79b5704";
const DAI_ADDRESS = "0x6b175474e89094c44da98b954eedeac495271d0f";
const WETH_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";
const FLASH_APP_ADDRESS = "0xa91902085405ce0f648a7eb82045aefc1b7bac01";

// FLASH/XIO PAIR RATIO
const flash_xio = {
  flash: "10000000000000000000",
  xio: "27234100000000000000",
};
// FLASH/DAI PAIR RATIO
const flash_dai = {
  flash: "10000000000000000000",
  dai: "6815740000000000000",
};
// FLASH/WETH PAIR RATIO
const flash_weth = {
  flash: "10000000000000000000",
  weth: "9231330000000000",
};


async function getAddres() {
  const [liquidityProvider] = await ethers.getSigners()
  console.log(liquidityProvider.address)
}
//address -> 0xBe83486c05f74172a49994003F0a0d667388dbD7
async function main(): Promise<void> {
  const [liquidityProvider] = await ethers.getSigners();

  await liquidityProvider.sendTransaction({from:liquidityProvider.address, to:"0x6eEa54E4A0061305Fe753eD9Be8dA14db76EeDdf",value:"0x13B4DA79FD0E0000"})

  // await approveAll(FLASH_APP_ADDRESS, liquidityProvider);

  const FlashAppFactory = new ContractFactory(
    FlashAppArtifact.abi,
    FlashAppArtifact.bytecode,
    liquidityProvider
  );

  // // FLASH APP
  const flashAppInstance = FlashAppFactory.attach(FLASH_APP_ADDRESS)
  // // XIO POOL
  // let txPool1 = await flashAppInstance.createPool(XIO_ADDRESS, { gasPrice: "0x156BA09800" });
  // await txPool1.wait(1);
  // const xioPoolAddress = await flashAppInstance.pools(XIO_ADDRESS);
  // console.log("XIO POOL ADDRESS: ", xioPoolAddress);
  // let txAdd1 = await flashAppInstance.addLiquidityInPool(
  //   flash_xio.flash,
  //   flash_xio.xio,
  //   "0",
  //   "0",
  //   XIO_ADDRESS, { gasPrice: "0x156BA09800" }
  // );
  // await txAdd1.wait(1);
  // console.log(txAdd1, "Add 1")
  // // DAI POOL
  // let txPool2 = await flashAppInstance.createPool(DAI_ADDRESS,{ gasPrice: "0x156BA09800"});
  // await txPool2.wait(1);
  // // const daiPoolAddress = await flashAppInstance.pools(DAI_ADDRESS);
  // // console.log("DAI POOL ADDRESS: ", daiPoolAddress);
  // let txAdd2 = await flashAppInstance.addLiquidityInPool(
  //   flash_dai.flash,
  //   flash_dai.dai,
  //   "0",
  //   "0",
  //   DAI_ADDRESS,{ gasPrice: "0x156BA09800" }
  // );
  // await txAdd2.wait(1);
  // console.log(txAdd2, "Add 2")
  // // // // WETH POOL
  // let txPool3 = await flashAppInstance.createPool(WETH_ADDRESS, { gasPrice: "0x156BA09800"});
  // await txPool3.wait(1)
  // const wethPoolAddress = await flashAppInstance.pools(DAI_ADDRESS);
  // console.log("WETH POOL ADDRESS: ", wethPoolAddress);
  // let txAdd3 = await flashAppInstance.addLiquidityInPool(
  //   flash_weth.flash,
  //   flash_weth.weth,
  //   "0",
  //   "0",
  //   WETH_ADDRESS,
  //   { gasPrice: "0x156BA09800" });
  // await txAdd3.wait(1);
  // console.log(txAdd3, "Add 3");
}


const approveAll = async (flashAppAddress: string, signer: SignerWithAddress) => {
  // APPROVE FLASH
  // const PoolERC20Factory = new ContractFactory(
  //   PoolErc20Artifact.abi,
  //   PoolErc20Artifact.bytecode,
  //   signer
  // );

  // const flashToken = PoolERC20Factory.attach(FLASH_ADDRESS)
  // let tx0 = await flashToken.approve(flashAppAddress, ethers.constants.MaxUint256, { gasPrice: "0x156BA09800" });
  // await tx0.wait(1)
  // console.log(tx0, "app 0")

  // // APPROVE XIO
  // const xioToken = PoolERC20Factory.attach(XIO_ADDRESS)
  // let tx1 = await xioToken.approve(flashAppAddress, ethers.constants.MaxUint256,{ gasPrice: "0x156BA09800" });
  // await tx1.wait(1);
  // console.log(tx1, "app 1")
  // // APPROVE DAI
  // const daiToken = PoolERC20Factory.attach(DAI_ADDRESS)
  // let tx2 = await daiToken.approve(flashAppAddress, ethers.constants.MaxUint256,{ gasPrice: "0x156BA09800" });
  // console.log(tx2, "app 2")
  // // APPROVE WETH
  // const wethToken = PoolERC20Factory.attach(WETH_ADDRESS)
  // let tx3 = await wethToken.approve(flashAppAddress, ethers.constants.MaxUint256, { gasPrice: "0x156BA09800" });
  // await tx3.wait(1)
  // console.log(tx3, "app 3")
};
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });