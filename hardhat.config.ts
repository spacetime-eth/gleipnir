import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
	solidity: {
		version: "0.8.9",

		settings: {
				optimizer: {
					enabled: true,
					runs: 1000,
				}
    }
	},
	networks: {
		ganache: {
			url: "http://127.0.0.1:8545",
			chainId: 1337
		}
	},
	mocha: {
		inlineDiffs: true
	},
};

export default config;
