import { HardhatUserConfig } from "hardhat/types";
import "@shardlabs/starknet-hardhat-plugin";
import "@nomiclabs/hardhat-ethers";
require("@openzeppelin/hardhat-upgrades");
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  solidity: "0.6.12",
  starknet: {
    //dockerizedVersion: "0.8.2", // alternatively choose one of the two venv options below
    // uses (my-venv) defined by `python -m venv path/to/my-venv`
    venv: "./env",

    // uses the currently active Python environment (hopefully with available Starknet commands!)
    // venv: "active",
    network: "devnet", //alpha
    wallets: {
      MyWallet: {
        accountName: "OpenZeppelin",
        modulePath:
          "starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount",
        accountPath: "~/.starknet_accounts",
      },
      MyWallet_two: {
        accountName: "OpenZeppelin",
        modulePath:
          "starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount",
        accountPath: "~/.starknet_accounts",
      },
    },
  },
  networks: {
    devnet: {
      url: "http://127.0.0.1:5050",
    },
    integratedDevnet: {
      url: "http://127.0.0.1:5050",
      venv: "active",
      // dockerizedVersion: "0.2.2",
    },
    hardhat: {},
  },
};

export default config;
