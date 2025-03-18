# SatLayer on Sui

## Overview

SatLayer brings shared security, powered by Bitcoin, over to Sui. SatLayer currently issues receipt tokens of Bitcoin LSTs upon staking through our [SatLayer Deposit App](https://app.satlayer.xyz).

This repo contains our Move smart contracts deployed onto Sui:

1. Vault contract: Manages deposits, withdrawal requests, and receipt token minting. This is similar to our [EVM-based deposit pool contracts](https://github.com/satlayer/deposit-contract-public).

2. Token contract: Implements a basic token representing receipt tokens issued upon deposits.

## Functionality

- The SatLayer vault allows users to deposit a base token (e.g. Lombard's LBTC) and receive a corresponding receipt token (e.g., satLBTC).
- Users can later request withdrawals, burn their receipt tokens, and retrieve their deposited assets after a specified withdrawal period.

## Flow Diagram

![Flow Diagram](./images/satlayer_deposit_flow.png)

## System Flow

**Deployment**

- Vault & receipt token contracts are deployed by the admin.
- Admin sets up vaults with token pairs.

**Deposit & Minting**

- Users deposit tokens and receive receipt tokens, through our frontend.

**Withdrawal Process**

- Users burn receipt tokens to initiate withdrawal.
- Users retrieve original tokens after the waiting period.

**Admin Controls**

- Admin can set staking limits, pause vaults, and modify withdrawal times.
- New vaults can be created as needed.

## Installation and Deployment Guide

### Install Sui
Follow the official Sui installation guide [here](https://docs.sui.io/guides/developer/getting-started/sui-install).

### Build the Contract
Navigate to the `core` directory and build the contracts using:

```sh
sui move build
```

### Test the Contract
Run the following command to test the contracts:

```sh
sui move test
```

### Deploy the Contract

Navigate to the `core` directory and install dependencies:

```sh
npm install
```

Configure the `.env` file with your deployment credentials:

```ini
MNEMONICS=""
NETWORK="testnet" # Change to "mainnet" if deploying on mainnet
```

Deploy the vault contract and an input token contract (e.g. Lombard's LBTC) by running:

```sh
ts-node core/scripts/utils/setup.ts
```

 Necessary parameters will be updated in `core/scripts/utils/packageInfo.ts`.

Deploy the receipt token contract using the same process:
```sh
ts-node coin/scripts/utils/setup.ts
```

After deployment of receipt token, you will see the following output in the console:

```
{
  packageId: '0x90e1cb85b60c87f629eb3c1dbcea1ddfd0ab2c1093b10c15a1697146730f8b60',
  TreasuryCap: '0xf29dc8cb304a406ed528faee4b3e956d74f307975fee3ef9a219e1b162b816fd'
}
```

The `packageId` is the contract package ID, and the `TreasuryCap` is the treasury cap for the receipt token contract, which is used to mint receipt tokens.

NOTE: The `lbtc.move` module is intended solely for testing purposes from the scripts side and will be removed later.

### Example

To deploy a new vault and its associated tokens, follow the runbook below.

#### For the new test token MBTC

Deploy a new test token (e.g. a random token with symbol MBTC) using `coin/scripts/utils/newPublishAsset.ts`, ensuring the respective `CoinMetadata` is updated.

This process will retrieve the type name and treasury cap of MBTC.

Update `packageInfo.ts` in `core/scripts/utils/newPublishAsset` with the retrieved values:

```ts
export const CoinLBTCTreasuryCap = ''; // Replace with actual treasury cap 
export const COIN_A_TYPE = ''; // replace with actual MBTC typename
```

On Sui mainnet, you will not need this since the Bitcoin LST issuer will already have the token.

#### For the receipt token satMBTC

Deploy the new receipt token for the above test token (e.g. satMBTC) using `coin/scripts/utils/newPublishAsset.ts`, ensure the respective CoinMetadata is updated.

This process will retrieve the type name and treasury cap of satMBTC.

Update `packageInfo.ts` in `core/scripts/utils/newPublishAsset` with the retrieved values:

```ts
export const COIN_B_TYPE = ''; // Replace with actual type nameof sat.Mbtc
export const ReceiptTokenTreasuryCap = ''; // Replace with actual treasury cap satMBTC
```

Once the setup is complete, the address holding the AdminCap can perform the initialize vault function call.

Update `core/scripts/utils/packageInfo.ts` with the TreasuryCap value in `coin/scripts/utils/packageInfo.ts`:

```ts
export const ReceiptTokenTreasuryCap = '0xf29dc8cb304a406ed528faee4b3e956d74f307975fee3ef9a219e1b162b816fd';
```

Add `COIN_B_TYPE` in `core/scripts/utils/packageInfo.ts` from `coin/scripts/utils/packageInfo.ts` `TYPENAME`:

 ```ts
 export const COIN_B_TYPE = '0x90e1cb85b60c87f629eb3c1dbcea1ddfd0ab2c1093b10c15a1697146730f8b60::template::TEMPLATE';
 ```

 This represents the coin type of the receipt token, using the `packageId` from the deployed coin contract.

#### Finalizing Setup

Create a vault by running the script:

```sh
ts-node core/scripts/src/admin/initializeVault.ts
```

The vault is initially paused. Start it by running:

```sh
ts-node core/scripts/src/admin/toggleVaultPause.ts
```

Mint some test tokens by running: 

```sh
ts-node core/scripts/src/mintTestDepositToken.ts
```

Do note to change the respective `recipient` and `mint_amount`. It provides `deposit_coin_object_id` which is necessary while depositing into the vault.

Deposit this test BTC asset and receive the receipt tokens by calling:

```sh
ts-node core/scripts/src/depositFor.ts
```

The script requires the following arguments:

```ts
arguments: [
  tx.object(Vault),
  tx.object('0xc12d8c856ed73d9974084024c7bc19d34c6ea36e70caa1ab65e3a4f00aaf7d8b'),
  tx.object(Version)
];
```

The second argument is a coin object representing the input token (e.g. LBTC in this case).
