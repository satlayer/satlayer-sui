# Vault & Receipt Token System

## Overview

This system consists of two primary smart contracts:

1.**Vault Contract**: Manages deposits, withdrawal requests, and receipt token minting.

2.**Token Contract**: Implements a basic token representing receipt tokens issued upon deposits.

## Functionality

- The vault allows users to deposit a base token (e.g., LBTC) and receive a corresponding receipt token (e.g., vLBTC).
- Users can later request withdrawals, burn their receipt tokens, and retrieve their deposited assets after a specified withdrawal period.

## Flow Diagram

![Flow Diagram](./images/satlayer_deposit_flow.png)

## System Flow

1.**Deployment**:

- Vault & receipt token contracts are deployed by the admin.
- Admin sets up vaults with token pairs.

2.**Deposit & Minting**:

- Users deposit tokens and receive receipt tokens.

3.**Withdrawal Process**:

- Users burn receipt tokens to initiate withdrawal.
- Users retrieve original tokens after the waiting period.

4.**Admin Controls**:

- Admin can set staking limits, pause vaults, and modify withdrawal times.
- New vaults can be created as needed.
