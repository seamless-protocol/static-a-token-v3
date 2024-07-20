# stataToken - Static aToken vault/wrapper

## Disclaimer

<p align="center">
<img src="./wrapping.jpg" width="300">
</p>

## About

This repository contains an [EIP-4626](https://eips.ethereum.org/EIPS/eip-4626) generic token vault/wrapper for all [Aave v3](https://github.com/aave/aave-v3-core) pools.

## Features

- **Full [EIP-4626](https://eips.ethereum.org/EIPS/eip-4626) compatibility.**
- **Accounting for any potential liquidity mining rewards.** Let’s say some team of the Aave ecosystem (or the Aave community itself) decides to incentivize deposits of USDC on Aave v3 Ethereum. By holding `stataUSDC`, the user will still be eligible for those incentives.
  It is important to highlight that while currently the wrapper supports infinite reward tokens by design (e.g. AAVE incentivizing stETH & Lido incentivizing stETH as well), each reward needs to be permissionlessly registered which bears some [⁽¹⁾](#limitations).
- **Meta-transactions support.** To enable interfaces to offer gas-less transactions to deposit/withdraw on the wrapper/Aave protocol (also supported on Aave v3). Including permit() for transfers of the `stataAToken` itself.
- **Upgradable by the Aave governance.** Similar to other contracts of the Aave ecosystem, the Level 1 executor (short executor) will be able to add new features to the deployed instances of the `stataTokens`.
- **Powered by a stataToken Factory.** Whenever a token will be listed on Aave v3, anybody will be able to call the stataToken Factory to deploy an instance for the new asset, permissionless, but still assuring the code used and permissions are properly configured without any extra headache.

See [IStaticATokenLM.sol](./src/interfaces/IStaticATokenLM.sol) for detailed method documentation.

## Deployed Addresses

The staticATokenFactory is deployed for all major Aave v3 pools.
An up to date address can be fetched from the respective [address-book pool library](https://github.com/bgd-labs/aave-address-book/blob/main/src/AaveV3Ethereum.sol#L67).

## Limitations

The `stataToken` is not natively integrated into the aave protocol and therefore cannot hook into the emissionManager.
This means a `reward` added **after** `statToken` creation needs to be registered manually on the token via the permissionless `refreshRewardTokens()` method.
As this process is not currently automated users might be missing out on rewards until the method is called.

## Security procedures

For this project, the security procedures applied/being finished are:

- The test suite of the codebase itself.
- Certora [audit/property checking](./audits/Formal_Verification_Report_staticAToken.pdf) for all the dynamics of the `stataToken`, including respecting all the specs of [EIP-4626](https://eips.ethereum.org/EIPS/eip-4626).
- Certora [manual review of static aToken oracle](./audits/Certora-Review-StatAToken-Oracle.pdf)

## Development

### Base Mainnet

| Contract                     | Address                                      |
| ---------------------------- | -------------------------------------------- | 
| StaticATokenFactory          | `0x6Bb79764b405955a22C2e850c40d9DAF82A3f407` | 
| StataOracle                  | `0x5c24D71F079443384FD47CdaD2372C9aeD653163` |
| Static Seamless USDbC        | `0xd32906B4EbA7F0ca077352152073188b7D74AAe5` |
| Static Seamless WETH         | `0x527E4cd7A406a65af222c8D5062759491365CA44` | 
| Static Seamless cbETH        | `0x508A60c7227e3623Fcb9EEf75934A288D10Fbaf2` | 
| Static Seamless USDC         | `0x96474402180b5e468A912aE3034A9B122d6d4f19` | 
| Static Seamless DAI          | `0xD3531DA85E9892A2B094b432914cfDbD676bd9bA` | 
| Static Seamless wstETH       | `0xB969a4189625b5A55E9d65a57A9F3CBc2714b270` | 
| Static Seamless SEAM         | `0x41dfec21b709FD5e7e82171E1699D641c1Ef1136` | 
| Static Seamless DEGEN        | `0x87FECcbcBa4ac9B9CA38a24A9ea07380Ad04dD64` | 
| Static Seamless AERO         | `0x511f4b406949a1C3E4267A9a165A163FA07D30D0` | 
| Static Seamless BRETT        | `0xFE3020d26Aa48dd21d0417B4255e24d34Ef2c8b1` | 

This project uses [Foundry](https://getfoundry.sh). See the [book](https://book.getfoundry.sh/getting-started/installation.html) for detailed instructions on how to install and use Foundry.
The template ships with sensible default so you can use default `foundry` commands without resorting to `MakeFile`.

### Setup

```sh
cp .env.example .env
forge install
```

### Test

```sh
forge test
```
