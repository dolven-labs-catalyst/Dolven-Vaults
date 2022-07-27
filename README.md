<h1 align="center">
  <br>
  <img src="https://dolvenlabs.com/logo.png" alt="Dolvenlabs" width="256">
  <br>
</h1>

<h4 align="center">🏦 Dolven Labs StarkNet smartcontract. DAO-Based Ecosystem Catalyst for Starknet.</h4>

<p align="center"><i>For more information, <a href="https://dolveblabs.com">click here</a>.</i></p>

<p align="center"><i>To learn more about StarkNet, <a href="https://starknet.io/what-is-starknet/">click here</a>.</i></p>

## What is DolvenLabs?

Dolven Labs is a DAO Based Ecosystem Catalyst for projects built on the StarkNet Network, Dolven Labs aims to be the future of investing, deal flow, and value creation in the StarkNet Ecosystem. With this contract, you will be able to lock your tokens and liquidity for the dates you choose. Also, anyone can use it.

## Dolven Strategy

These strategy contracts are the vaults of Dolven Labs. More technical details will be available on our notion soon.

## To Do List

- [x] All Good

# Basic Sample Hardhat Project - with Starknet Plugin

This project demonstrates a basic Hardhat project, but with [Starknet plugin](https://github.com/Shard-Labs/starknet-hardhat-plugin).

## Get started

#### Clone this repo

```
git clone git@github.com:Shard-Labs/starknet-hardhat-example.git
cd starknet-hardhat-example
```

#### Install dependencies

```
npm ci
```

#### Compile a contract

```
npx hardhat starknet-compile contracts/contract.cairo
```

#### Run a test that interacts with the compiled contract

```
npx hardhat test test/DeployStrategy.ts
```

## Supported `starknet-hardhat-plugin` version

`package.json` is fixed to use the latest `starknet-hardhat-plugin` version this example repository is synced with.

## Troubleshooting

If you're having issues trying to use this example repo with the Starknet plugin, try running `npm install` or `npm update`, as it may be due to version mismatch in the dependencies.

## Branches

- `master` - latest stable examples
- `plugin` - used for testing by [Starknet Hardhat Plugin](https://github.com/Shard-Labs/starknet-hardhat-plugin)

### Branch updating (for developers)

- New PRs and features should be targeted to the `plugin` branch.
- After releasing a new plugin version, `master` should ideally be reset (fast forwarded) to `plugin` (less ideally merged).
