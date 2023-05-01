import {BigNumber} from "ethers"
import { ethers } from "hardhat";

async function main() {
	const BoardManager = await ethers.getContractFactory("BoardManager")

	console.log("Deploying... ")
	const contract = await BoardManager.deploy(BigNumber.from(255n))
	await contract.deployed()
	console.log(`Deployed to ${contract.address}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
