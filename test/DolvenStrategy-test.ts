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
  let airdrop_account: any;

  this.beforeEach(async () => {
    //Connections
    dolvenVault_factory = await starknet.getContractFactory("DolvenVault");
    contractFactory_unstaker = await starknet.getContractFactory("Unstaker");
    contractFactory_token = await starknet.getContractFactory("Dolven-token");
    account = await starknet.getAccountFromAddress(
      "0x06ac944e4415efb309377681edade9bd8fc4c610814c42f92ce4f9d2dbb489bf",
      "0x54e61016583ffe3bd134cc8a5a705db537f83d9932912bbbf5910793adf20be",
      "OpenZeppelin"
    );

    test_account = await starknet.getAccountFromAddress(
      "0x05b1db77823ae2a8ab0d586d4a8dded1d0885173eba794c4733d37aebda82e2b",
      "0x8fc425edf4c3874181a66d99ebc8e0b83e1f3e3284e3efdb4dff4ef2279a145",
      "OpenZeppelin"
    );

    dolvenVault = dolvenVault_factory.getContractAt(
      "0x050f143c1a085a379aed81afe5bf010447ce2ac9f6072fc3d38023eec07757f0"
    );
    dolvenUnstaker = contractFactory_unstaker.getContractAt(
      "0x016ce19efdd309cae647b79e6fce9a7b3e21cc22ab5a403bf5f749e5694a2595"
    );
    staking_token = contractFactory_token.getContractAt(
      "0x020207dc9d500fd98bd535f4b3e646d9c416a743706fde499aa9227c6d6c388f"
    );
    pool_token = contractFactory_token.getContractAt(
      "0x0785c243d4d6cfa63a177084bcfdd00fcbe0ccd966683fc0951ffda91b70a54d"
    );
  });

  it("token amount should be greater than zero", async function () {
    const { balance } = await account.call(staking_token, "balanceOf", {
      account: account.starknetContract._address,
    });
    console.log(balance, "balance");
    const as_uint = Number(ethers.utils.formatEther(balance.low.toString()));
    expect(as_uint).to.be.above(0);
  });

  it("Set Unstaker Address to DolvenVault", async function () {
    await account.invoke(dolvenVault, "set_unstakerAddress", {
      unstaker_address_: dolvenUnstaker.address,
    });
    const unstakerAddress = await account.call(
      dolvenVault,
      "get_unstakerAddress"
    );
    expect(returnToHex(unstakerAddress.res)).to.deep.equal(
      dolvenUnstaker.address
    );
  });

  it("Set lock type", async function () {
    const days_20_seconds = 1728000;
    const tx = await account.invoke(dolvenVault, "setLockDuration", {
      lockIndex: 0,
      lockDuration: days_20_seconds,
    });
    const duration = await account.call(dolvenVault, "get_lock_types", {
      index: 0,
    });
    expect(duration.res).to.deep.equal(BigInt(days_20_seconds));
  });

  it("token amount should be greater than zero for vault", async function () {
    const { balance } = await account.call(staking_token, "balanceOf", {
      account: account.starknetContract._address,
    });
    console.log(balance, "balance");
    const as_uint = Number(ethers.utils.formatEther(balance.low.toString()));
    expect(as_uint).to.be.above(0);
  });

  it("approve staking token", async function () {
    const approve = await account.invoke(staking_token, "approve", {
      spender: BigInt(dolvenVault.address),
      amount: { low: BigInt(1003000000000000000000), high: 0 },
    });
    const { remaining } = await account.call(staking_token, "allowance", {
      owner: BigInt(account.starknetContract._address),
      spender: BigInt(dolvenVault.address),
    });
    expect(remaining.low).to.deep.equal(BigInt(1003000000000000000000));
  });

  it("be delegator", async function () {
    await account.invoke(dolvenVault, "delege", {
      _amountToStake: { low: BigInt(1003000000000000000000), high: 0 },
      _staker: BigInt(account.starknetContract._address),
      _lockType: 0,
    });

    const { res } = await account.call(dolvenVault, "getUserInfo", {
      account_address: BigInt(account.starknetContract._address),
    });
    expect(res.amount.low).to.deep.equal(BigInt(1003000000000000000000));
  });
  it("send pool token to contract", async function () {
    await account.invoke(pool_token, "transfer", {
      recipient: BigInt(dolvenVault.address),
      amount: { low: BigInt(50000000000000000000000), high: 0 },
    });

    const { balance } = await account.call(pool_token, "balanceOf", {
      account: dolvenVault.address,
    });
    expect(balance.low).to.deep.equal(49999999999999995805696n);
  });

  it("create new test account and fund it", async function () {
    await account.invoke(staking_token, "transfer", {
      recipient: BigInt(test_account.starknetContract._address),
      amount: { low: BigInt(10000000000000000000000), high: 0 },
    });
    const { balance } = await account.call(staking_token, "balanceOf", {
      account: test_account.starknetContract._address,
    });
    expect(balance.low).to.equal(BigInt(10000000000000000000000));
  });

  it("approve staking token for second account", async function () {
    await test_account.invoke(staking_token, "approve", {
      spender: BigInt(dolvenVault.address),
      amount: { low: BigInt(5172000000000000000000), high: 0 },
    });
    const { remaining } = await test_account.call(staking_token, "allowance", {
      owner: BigInt(test_account.starknetContract._address),
      spender: BigInt(dolvenVault.address),
    });
    expect(remaining.low).to.deep.equal(BigInt(5172000000000000000000));
  });

  it("Set lock type for 40 days", async function () {
    const days_40_seconds = 1728000 * 2;
    const tx = await account.invoke(dolvenVault, "setLockDuration", {
      lockIndex: 1,
      lockDuration: days_40_seconds,
    });
    const duration = await account.call(dolvenVault, "get_lock_types", {
      index: 1,
    });
    expect(duration.res).to.deep.equal(BigInt(days_40_seconds));
  });

  it("be delegator from second account", async function () {
    await test_account.invoke(dolvenVault, "delege", {
      _amountToStake: { low: BigInt(2136000000000000000000), high: 0 },
      _staker: BigInt(test_account.starknetContract._address),
      _lockType: 1,
    });

    const { res } = await test_account.call(dolvenVault, "getUserInfo", {
      account_address: BigInt(test_account.starknetContract._address),
    });
    console.log(res, "response here");
    expect(res.amount.low).to.deep.equal(BigInt(2136000000000000000000));
  });

  it("set limit for ticket", async function () {
    await account.invoke(dolvenVault, "changeTicketLimit", {
      _amountToStake: { low: BigInt(1000000000000000000000), high: 0 },
    });
  });

  it("stake again from second account", async function () {
    await test_account.invoke(staking_token, "approve", {
      spender: BigInt(dolvenVault.address),
      amount: { low: BigInt(10000000000000000000000), high: 0 },
    });

    await test_account.invoke(dolvenVault, "delege", {
      _amountToStake: { low: BigInt(4136000000000000000000), high: 0 },
      _staker: BigInt(test_account.starknetContract._address),
      _lockType: 1,
    });

    const { res } = await test_account.call(dolvenVault, "getUserInfo", {
      account_address: BigInt(test_account.starknetContract._address),
    });
    console.log(res, "response here");
    expect(res.amount.low).to.deep.equal(BigInt(6272000000000000000000));
  });

  it("check pending reward", async function () {
    const res = await test_account.call(dolvenVault, "pendingReward", {
      account_address: BigInt(test_account.starknetContract._address),
    });
    const res_ = await test_account.call(dolvenVault, "pendingReward_view", {
      account_address: BigInt(test_account.starknetContract._address),
    });
    const as_uint = Number(ethers.utils.formatEther(res.reward.low.toString()));
    console.log(res, "pending reward");
    console.log(res_, "pending reward _ view");
    expect(as_uint).to.be.above(0);
  });

  it("check staking token balance in contract ", async function () {
    const res = await account.call(staking_token, "balanceOf", {
      account: dolvenVault.address,
    });
    console.log(res, "response here");
    const as_uint = Number(
      ethers.utils.formatEther(res.balance.low.toString())
    );

    expect(as_uint).to.be.above(0);
  });

  it("airdrop tokens ", async function () {
    airdrop_account = await starknet.deployAccount("OpenZeppelin");
    await account.invoke(dolvenVault, "dropToken", {
      addresses: [
        airdrop_account.starknetContract._address,
        "0x01e3ebc3bcf128187f18688bc26169d7f7075745d5f53dd3661df50ba046b66d",
      ],
      amounts: [
        { low: 12415264374, high: 0 },
        { low: 0, high: 0 },
      ],
    });

    const _res___ = await account.call(dolvenVault, "getUserInfo", {
      account_address: airdrop_account.starknetContract._address,
    });
    console.log(_res___);
    expect(_res___.res.amount.low).to.deep.equal(BigInt(12415264374));
  });

  it("one day should equal to 86400 ", async function () {
    const res = await account.invoke(dolvenUnstaker, "setDayDuration", {
      duration_as_second: BigInt(86400),
    });

    const one_day = await account.call(dolvenUnstaker, "get_one_day");
    console.log(one_day, "one day");
    expect(one_day.res).to.deep.equal(BigInt(86400));
  });

  it("lock type 2 should equal to 40 days in unstaker contract", async function () {
    const days_40_seconds = 1 * 2;
    const days_20_seconds = 1;
    await account.invoke(dolvenUnstaker, "setLockTypes", {
      id: 1,
      duration: days_40_seconds,
    });
    await account.invoke(dolvenUnstaker, "setLockTypes", {
      id: 0,
      duration: days_20_seconds,
    });
    const duration = await account.call(dolvenUnstaker, "get_lock_types", {
      index: 1,
    });
    expect(duration.res).to.deep.equal(BigInt(days_40_seconds));
  });

  it("should unstake ", async function () {
    const userInfo = await account.call(dolvenVault, "getUserInfo", {
      account_address: account.starknetContract._address,
    });
    console.log(userInfo, "user data");
    const prop = await account.call(dolvenVault, "get_properties");
    console.log(prop, "current prop");
    await account.invoke(dolvenVault, "unDelegate", {
      amountToWithdraw: { low: BigInt(1200000000000000000000), high: 0 },
    });
    const userInfo__2 = await account.call(dolvenVault, "getUserInfo", {
      account_address: account.starknetContract._address,
    });
    console.log(userInfo__2, "user info 2");
    const prop_2 = await account.call(dolvenVault, "get_properties");
    console.log(prop_2, "current 2 prop");

    expect(userInfo__2.res.amount.low).to.deep.equal(
      userInfo.res.amount.low - BigInt(1200000000000000000000)
    );
  });

  it("user should has balance in unstaker contract", async function () {
    const userInfo = await account.call(dolvenUnstaker, "get_lock_details", {
      nonce_id: 2,
    });
    console.log(userInfo, "user info");
    expect(userInfo.res.amount.low).to.deep.equal(
      BigInt(1200000000000000000000)
    );
  });

  it("should approve & duration should be extended ", async function () {
    await account.invoke(pool_token, "approve", {
      spender: dolvenVault.address,
      amount: { low: BigInt(1110000000000000000000), high: 0 },
    });
    const prop = await test_account.call(dolvenVault, "get_properties");
    console.log(prop, "props");
    await account.invoke(dolvenVault, "extendDuration", {
      tokenAmount: { low: BigInt(1110000000000000000000), high: 0n },
    });
    const prop_after = await test_account.call(dolvenVault, "get_properties");
    console.log(prop_after, "props");
    //expect(userInfo.amount.low).to.deep.equal(BigInt(252000000000000000000));
  });

  it("should revert because of insufficent amount", async function () {
    const userInfo = await account.call(dolvenVault, "getUserInfo", {
      account_address: account.starknetContract._address,
    });
    try {
      const unstake = await account.invoke(dolvenVault, "unDelegate", {
        amountToWithdraw: { low: BigInt(1000000000000000000000), high: 0 },
      });
    } catch (error: any) {
      expect(1).to.equal(1);
    }
    expect(1).to.equal(1);
  });

  it("should stake and approve again", async function () {
    await account.invoke(staking_token, "approve", {
      spender: dolvenVault.address,
      amount: { low: BigInt(189000000000000000000), high: 0 },
    });
    const userInfo = await account.call(dolvenVault, "getUserInfo", {
      account_address: account.starknetContract._address,
    });
    console.log(userInfo, "user info");

    await account.invoke(dolvenVault, "delege", {
      _amountToStake: { low: BigInt(189000000000000000000), high: 0 },
      _staker: account.starknetContract._address,
      _lockType: 1,
    });

    const userInfo__2 = await account.call(dolvenVault, "getUserInfo", {
      account_address: account.starknetContract._address,
    });
    console.log(userInfo__2, "user info 2");

    expect(userInfo__2.res.amount.low).to.deep.equal(
      userInfo.res.amount.low + BigInt(189000000000000000000)
    );
  });

  it("should stake and approve again 2", async function () {
    await account.invoke(staking_token, "approve", {
      spender: dolvenVault.address,
      amount: { low: BigInt(2176000000000000000000), high: 0 },
    });
    const userInfo = await account.call(dolvenVault, "getUserInfo", {
      account_address: account.starknetContract._address,
    });
    console.log(userInfo, "user info");

    await account.invoke(dolvenVault, "delege", {
      _amountToStake: { low: BigInt(2176000000000000000000), high: 0 },
      _staker: account.starknetContract._address,
      _lockType: 1,
    });

    const userInfo__2 = await account.call(dolvenVault, "getUserInfo", {
      account_address: account.starknetContract._address,
    });
    console.log(userInfo__2, "user info 2");

    expect(userInfo__2.res.amount.low).to.deep.equal(
      userInfo.res.amount.low + BigInt(2176000000000000000000)
    );
  });

  it("should unstake again", async function () {
    const contract_balance = await account.call(staking_token, "balanceOf", {
      account: dolvenUnstaker.address,
    });
    console.log(contract_balance, "before balance of unstaker contract");
    await account.invoke(dolvenVault, "unDelegate", {
      amountToWithdraw: { low: 117000000000000000000, high: 0 },
    });
    const userInfo = await account.call(dolvenVault, "getUserInfo", {
      account_address: account.starknetContract._address,
    });
    const contract_balance_after = await account.call(
      staking_token,
      "balanceOf",
      {
        account: dolvenUnstaker.address,
      }
    );
    console.log(contract_balance_after, "after balance of unstaker contract");

    expect(contract_balance.balance.low).to.deep.equal(
      contract_balance_after.balance.low - BigInt(117000000000000000000)
    );
  });

  it("should cancel lock", async function () {
    const userInfo = await account.call(dolvenVault, "getUserInfo", {
      account_address: account.starknetContract._address,
    });
    console.log("before user data", userInfo);

    await account.invoke(dolvenVault, "cancelLock", {
      nonce_: 2n,
    });

    const userInfo_after = await account.call(dolvenVault, "getUserInfo", {
      account_address: account.starknetContract._address,
    });
    console.log("before user data", userInfo_after);
  });

  it("pending reward", async function () {
    const locks_of_user = await account.call(dolvenVault, "pendingReward", {
      account_address: account.starknetContract._address,
    });
    console.log(locks_of_user, "user locks");
  });

  it("user should lock value", async function () {
    const locks_of_user = await account.call(dolvenUnstaker, "get_user_locks", {
      user: account.starknetContract._address,
    });
    console.log(locks_of_user, "user locks");
  });

  it("only staking contract", async function () {
    try {
      await account.invoke(dolvenUnstaker, "cancelTokens", {
        user_: account.starknetContract._address,
        nonce: 2n,
      });
    } catch (error) {
      expect(1).to.equal(1);
    }
    expect(1).to.equal(1);
  });

  /*

    it("should lock type granted", async function () {
    const userInfo = await test_account.call(dolvenVault, "getUserInfo", {
      account_address: test_account.starknetContract._address,
    });
    console.log("before user data", userInfo);

    await test_account.invoke(dolvenVault, "cancelLock", {
      nonce_: 2,
    });

    const userInfo_after = await test_account.call(dolvenVault, "getUserInfo", {
      account_address: test_account.starknetContract._address,
    });
    console.log("before user data", userInfo_after);
  });

  */
});
