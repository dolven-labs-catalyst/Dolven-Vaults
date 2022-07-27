import { expect } from "chai";
import { assert } from "console";
import { starknet } from "hardhat";
import { ethers } from "ethers";
import {
  StarknetContract,
  StarknetContractFactory,
} from "hardhat/types/runtime";

function returnToHex(intValue: string) {
  return "0x0" + BigInt(intValue).toString(16);
}

function returnToInt(hexValue: string) {
  return BigInt(hexValue);
}

describe("Starknet", function () {
  let dolvenVault_factory: StarknetContractFactory;
  let contractFactory_token: StarknetContractFactory;
  let contractFactory_unstaker: StarknetContractFactory;
  let dolvenVault: StarknetContract;
  let staking_token: StarknetContract;
  let pool_token: StarknetContract;
  let dolvenUnstaker: StarknetContract;
  let account: any;
  let test_account: any;

  it("deploy accounts", async function () {
    account = await starknet.deployAccount("OpenZeppelin");
    test_account = await starknet.deployAccount("OpenZeppelin");

    console.log(account.starknetContract._address, "account 1 address");
    console.log(account.privateKey, "account 1 privkey");

    console.log(test_account.starknetContract._address, "account 2 address");
    console.log(test_account.privateKey, "account 2 privkey");
  });

  it("deploy tokens", async function () {
    dolvenVault_factory = await starknet.getContractFactory("DolvenVault");
    contractFactory_unstaker = await starknet.getContractFactory("Unstaker");
    contractFactory_token = await starknet.getContractFactory("Dolven-token");

    console.log(account.starknetContract._address, "contract address");
    staking_token = await contractFactory_token.deploy({
      recipient: account.starknetContract._address,
    });
    pool_token = await contractFactory_token.deploy({
      recipient: account.starknetContract._address,
    });

    console.log("Staking Token Contract Deployed at", staking_token.address);
    console.log("Pool Token Contract Deployed at", pool_token.address);
  });

  //Constructor

  it("Interact with constructor and insert values", async function () {
    // account infos
    const time_now = Math.floor(Date.now() / 1000);
    const time_end = time_now + 500000;
    const pool_token_amount = BigInt(123456000000000000000000);
    const limit_for_ticket = BigInt(1000000000000000000000);
    const constructorElement = {
      _stakingToken: returnToInt(staking_token.address),
      _poolToken: returnToInt(pool_token.address),
      _startTimestamp: BigInt(time_now),
      _finishTimestamp: BigInt(time_end),
      _poolTokenAmount: pool_token_amount,
      _limitForTicket: limit_for_ticket,
      _isFarming: 1,
      _admin: returnToInt(account.starknetContract._address),
    };

    dolvenVault = await dolvenVault_factory.deploy({
      ...constructorElement,
    });

    console.log("DolvenVault Contract Deployed at", dolvenVault.address);

    const properties = await dolvenVault.call("get_properties");
    console.log(properties, "prop");
    expect(returnToHex(properties._stakingToken)).to.deep.equal(
      staking_token.address
    );
  });

  it("deploy unstaker contract", async function () {
    dolvenUnstaker = await contractFactory_unstaker.deploy({
      token_address_: staking_token.address,
      staking_contract_address_: dolvenVault.address,
      _admin: account.starknetContract._address,
    });
    console.log("DolvenUnstaker Contract Deployed at", dolvenUnstaker.address);
  });
});
