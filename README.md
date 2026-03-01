# ERC-4337 Account Abstraction Smart Wallet

A production-level ERC-4337 smart contract wallet built with Foundry, implementing account abstraction on Ethereum. This project demonstrates a complete smart wallet system with advanced features including batch execution, session key delegation, guardian-based social recovery, and a factory deployment pattern using CREATE2 and ERC1967 proxies.

**Deployed on Sepolia Testnet:**

| Contract                     | Address                                                                                                                         |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| MainAccountFactory           | [`0xb2Dbf10b4a35EF65060da133cfC35d5a62025749`](https://sepolia.etherscan.io/address/0xb2dbf10b4a35ef65060da133cfc35d5a62025749) |
| MainAccount (Implementation) | [`0xe9A5e69Cf322f89544a5167eD2d26a4C24551B58`](https://sepolia.etherscan.io/address/0xe9a5e69cf322f89544a5167ed2d26a4c24551b58) |
| Proxy Wallet                 | [`0x1DA62d49D8bbd8Fbe879dD7aACa7153914c47363`](https://sepolia.etherscan.io/address/0x1da62d49d8bbd8fbe879dd7aaca7153914c47363) |

## Table of Contents

- [ERC-4337 Account Abstraction Smart Wallet](#erc-4337-account-abstraction-smart-wallet)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Architecture](#architecture)
  - [Features](#features)
    - [Core Wallet Functionality](#core-wallet-functionality)
    - [Batch Execution](#batch-execution)
    - [Session Keys](#session-keys)
    - [Social Recovery](#social-recovery)
    - [Factory Pattern with CREATE2](#factory-pattern-with-create2)
  - [ERC-4337 UserOperation Flow](#erc-4337-useroperation-flow)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
    - [Build](#build)
    - [Run Tests](#run-tests)
  - [Deploy to Sepolia](#deploy-to-sepolia)
    - [Environment Setup](#environment-setup)
    - [Deploy Contracts](#deploy-contracts)
    - [Fund Your Wallet](#fund-your-wallet)
    - [Send a UserOperation](#send-a-useroperation)
    - [Verify on Etherscan](#verify-on-etherscan)
  - [Project Structure](#project-structure)
  - [Testing](#testing)
  - [Technologies](#technologies)

## Overview

Traditional Ethereum accounts (EOAs) require users to hold ETH for gas fees, manage private keys directly, and can only perform one action per transaction. ERC-4337 Account Abstraction solves these limitations by turning wallets into smart contracts that can validate signatures with custom logic, batch multiple operations into a single transaction, delegate permissions via session keys, and recover access through trusted guardians.

This project implements a complete ERC-4337 smart wallet that interacts with the canonical EntryPoint v0.7 contract (`0x0000000071727De22E5E9d8BAf0edAc6f37da032`).

## Architecture

The system consists of four main contracts:

```
┌─────────────────────────────────────────────────────────────┐
│                      EntryPoint v0.7                        │
│              (Canonical singleton on all chains)             │
│         0x0000000071727De22E5E9d8BAf0edAc6f37da032          │
└──────────┬──────────────────────────────────┬───────────────┘
           │ handleOps                        │
           ▼                                  ▼
┌─────────────────────┐          ┌──────────────────────────┐
│  MainAccountFactory │          │     ERC1967 Proxy        │
│                     │─creates─▶│    (User's Wallet)       │
│  - createAccount()  │          │                          │
│  - getAddress()     │          │  Delegates all calls to  │
│  - Staking mgmt     │          │  implementation via      │
│                     │          │  delegatecall             │
└─────────────────────┘          └────────────┬─────────────┘
                                              │ delegatecall
                                              ▼
                                 ┌──────────────────────────┐
                                 │   MainAccount (Impl)     │
                                 │                          │
                                 │  - execute()             │
                                 │  - executeBatch()        │
                                 │  - validateUserOp()      │
                                 │  - Session Keys          │
                                 │  - Social Recovery       │
                                 └──────────────────────────┘
```

The factory deploys a single MainAccount as a shared implementation contract. Each new wallet is a lightweight ERC1967 proxy (~212 bytes) that delegates all logic to this implementation via `delegatecall`, while maintaining its own separate storage for owner, session keys, guardian, and other state.

## Features

### Core Wallet Functionality

The `MainAccount` contract implements the `IAccount` interface required by ERC-4337.

**`execute(address dest, uint256 value, bytes calldata functionData)`** — Sends a single transaction from the wallet. Can call any contract, send ETH, or do both. Access is restricted to the EntryPoint (for UserOp flow) or the wallet owner directly.

**`validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)`** — Called by the EntryPoint during UserOp processing. Validates the signature (owner or session key), then pays the required gas prefund to the EntryPoint from the wallet's balance. Returns `0` for success or `1` for failure.

**`receive()`** — Allows the wallet to receive ETH transfers.

### Batch Execution

**`executeBatch(address[] calldata dest, uint256[] calldata values, bytes[] calldata functionData)`** — Executes multiple transactions in a single UserOperation. All three arrays must have the same length — each index represents one transaction. Execution is atomic: if any call fails, the entire batch reverts.

This is essential for complex DeFi interactions. For example, approving a token and swapping it on a DEX can be done in one UserOp instead of two, saving gas on repeated validation and prefund cycles.

### Session Keys

Session keys allow the owner to grant limited, temporary permissions to other addresses without sharing the owner's private key.

**`addSessionKey(address sessionKey, uint48 validUntil, address target, bytes4 selector)`** — Creates a session key with four constraints:

- **Time window**: Active from creation until `validUntil` timestamp
- **Target contract**: Restrict to a specific contract address, or `address(0)` for any contract
- **Function selector**: Restrict to a specific function, or `bytes4(0)` for any function
- **Active status**: Can be revoked at any time

**`revokeSessionKey(address sessionKey)`** — Instantly deactivates a session key by setting `isActive` to `false`.

**`isSessionKeyValid(address sessionKey)`** — Returns whether a session key is currently active and within its time window.

**Signature Validation**: The `_validateSignature` function first checks if the signer is the owner (unlimited permissions). If not, it looks up the signer in the session keys mapping and validates all four constraints: active status, time window, target contract, and function selector. The target and selector are extracted from the UserOp's calldata by parsing the ABI-encoded `execute()` call.

**Example use case**: A blockchain game creates a session key that can only call `makeMove()` on the game contract for 2 hours. If compromised, the attacker can only make game moves, not drain the wallet.

### Social Recovery

A guardian-based recovery mechanism allows ownership transfer if the owner loses access to their private key.

**`setGuardian(address newGuardian)`** — Owner-only function to set or change the guardian address. The guardian could be a trusted friend, family member, or a separate wallet you control.

**`initiateRecovery(address newOwner)`** — Guardian calls this to start the recovery process. Sets the proposed new owner and records the current timestamp. Each new call resets the timer to prevent the guardian from pre-running the clock with a benign address then swapping in a malicious one.

**`executeRecovery()`** — Guardian calls this after the 2-day recovery period has passed. Transfers ownership to the proposed address and resets all recovery state.

**`cancelRecovery()`** — Owner-only function to stop a malicious or unauthorized recovery attempt. This is the safety net — if you see a recovery was initiated that you didn't authorize, you have 2 days to cancel it.

**Security model**: The 2-day `RECOVERY_PERIOD` is the critical design element. Without it, a compromised guardian could instantly steal the wallet. With it, the owner always has time to notice and cancel. The checks and balances ensure: only the owner can set the guardian, only the guardian can initiate/execute recovery, and only the owner can cancel recovery.

### Factory Pattern with CREATE2

The `MainAccountFactory` enables gas-efficient wallet creation with deterministic addresses.

**`createAccount(address owner, uint256 salt)`** — Deploys a new ERC1967 proxy pointing to the shared implementation. Uses CREATE2 for deterministic address computation. The function is idempotent — calling it twice with the same parameters returns the existing wallet instead of reverting.

**`getAddress(address owner, uint256 salt)`** — Computes the wallet address before deployment using the CREATE2 formula: `address = keccak256(0xff ++ factory ++ salt ++ keccak256(bytecode))[12:]`. This allows users to receive funds at their wallet address before it even exists on-chain.

**Proxy pattern**: Each wallet proxy is only ~212 bytes of runtime bytecode compared to ~11,708 bytes for the full implementation. The proxy forwards all calls to the implementation via `delegatecall`, which runs the implementation's code but writes to the proxy's storage. This means every proxy has its own independent state (owner, session keys, guardian) while sharing the same logic.

**`_disableInitializers()`**: Called in the MainAccount constructor to permanently lock the implementation contract's initialization state to `type(uint64).max`. This prevents attackers from calling `initialize()` on the implementation directly, which could compromise all proxies that delegate to it. Each proxy is initialized exactly once through the factory's `createAccount`, which calls `initialize(owner)` atomically during proxy deployment.

**ERC-4337 integration**: In production, the first UserOperation includes `initCode` containing the factory address and `createAccount` calldata. The EntryPoint calls the factory to deploy the wallet, then proceeds with validation and execution — all in one transaction. The user never manually deploys their wallet.

## ERC-4337 UserOperation Flow

When a UserOperation is submitted through the EntryPoint, the following steps occur:

1. **Bundler** submits the UserOp by calling `EntryPoint.handleOps()` and pays L1 gas upfront
2. **EntryPoint** calls `validateUserOp()` on the wallet (proxy → delegatecall → implementation)
3. **Signature validation**: `ecrecover` recovers the signer, checks against owner and session keys
4. **Prefund payment**: Wallet sends `(verificationGas + callGas + preVerificationGas) × maxFeePerGas` to EntryPoint as a gas deposit
5. **Execution**: EntryPoint calls `execute()` or `executeBatch()` on the wallet to perform the actual operation
6. **Gas accounting**: EntryPoint calculates actual gas used, compensates the bundler from the deposit, and credits remaining funds back to the wallet

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast, anvil)
- [Git](https://git-scm.com/)
- A wallet with Sepolia ETH (for testnet deployment)

### Installation

```bash
git clone https://github.com/AlbertDF1999/SH-Project.git
cd SH-Project
forge install
```

### Build

```bash
forge build
```

### Run Tests

```bash
# Run all 17 tests
forge test

# Run with detailed traces
forge test -vvvv

# Run specific test
forge test --match-test testBatchExecution -vvvv
```

## Deploy to Sepolia

### Environment Setup

1. Create a `.env` file in the project root (USE A BURNER WALLET, DO NOT USE A WALLET WITH ASSETS YOU CAN'T AFFORD TO LOSE):

```env
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_KEY
```

2. Update `script/HelperConfig.s.sol` with your wallet address:

```solidity
address constant BURNER_WALLET = YOUR_WALLET_ADDRESS;
```

3. Load environment variables:

```bash
source .env
```

4. Get Sepolia ETH from the [Google Cloud Faucet](https://cloud.google.com/application/web3/faucet/ethereum/sepolia) or [Alchemy Faucet](https://www.alchemy.com/faucets/ethereum-sepolia).

### Deploy Contracts

Make sure `DeployMainAccount.s.sol` has `run()` calling `deployMainAccountWithFactory()`, then:

```bash
forge script script/DeployMainAccount.s.sol:DeployMainAccount \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    -vvvv
```

This deploys three contracts in two transactions:
1. **MainAccountFactory** (which deploys the MainAccount implementation in its constructor)
2. **Your proxy wallet** (created by calling `factory.createAccount`)

Save the deployed addresses from the output.

### Fund Your Wallet

Send Sepolia ETH to your proxy wallet address:

```bash
cast send YOUR_PROXY_ADDRESS \
    --value 0.01ether \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

### Send a UserOperation

Update `script/SendUserOpSepolia.s.sol` with your proxy wallet address:

```solidity
address mainAccountAddr = YOUR_PROXY_ADDRESS;
```

Then run:

```bash
forge script script/SendUserOpSepolia.s.sol:SendUserOpSepolia \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --gas-estimate-multiplier 500 \
    -vvvv
```

The `--gas-estimate-multiplier 500` flag is necessary because the EntryPoint's internal gas accounting requires more gas than Forge's default estimate provides. Without it, the transaction reverts with `AA95 out of gas`.

### Verify on Etherscan

```bash
# Verify the factory
forge verify-contract YOUR_FACTORY_ADDRESS \
    src/MainAccountFactory.sol:MainAccountFactory \
    --chain sepolia \
    --rpc-url $SEPOLIA_RPC_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --constructor-args $(cast abi-encode "constructor(address)" 0x0000000071727De22E5E9d8BAf0edAc6f37da032)

# Verify the implementation
forge verify-contract YOUR_IMPLEMENTATION_ADDRESS \
    src/MainAccount.sol:MainAccount \
    --chain sepolia \
    --rpc-url $SEPOLIA_RPC_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --constructor-args $(cast abi-encode "constructor(address)" 0x0000000071727De22E5E9d8BAf0edAc6f37da032)

# Verify the proxy
forge verify-contract YOUR_PROXY_ADDRESS \
    lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
    --chain sepolia \
    --rpc-url $SEPOLIA_RPC_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --constructor-args $(cast abi-encode "constructor(address,bytes)" YOUR_IMPLEMENTATION_ADDRESS $(cast calldata "initialize(address)" YOUR_WALLET_ADDRESS))
```

## Project Structure

```
SH-Project/
├── src/
│   ├── MainAccount.sol              # Core wallet contract (implementation)
│   └── MainAccountFactory.sol       # Factory for CREATE2 proxy deployment
├── script/
│   ├── DeployMainAccount.s.sol      # Deployment scripts (direct + factory)
│   ├── HelperConfig.s.sol           # Network configuration (EntryPoint, accounts)
│   ├── SendPackedUserOp.s.sol       # UserOp construction and signing helper
│   └── SendUserOpSepolia.s.sol      # Script to send UserOp on Sepolia
├── test/
│   └── TestMainAccount.t.sol        # 17 tests covering all features
├── lib/
│   ├── account-abstraction/         # ERC-4337 EntryPoint interfaces
│   ├── openzeppelin-contracts/      # OpenZeppelin (Ownable, ECDSA, ERC1967Proxy)
│   └── forge-std/                   # Foundry testing utilities
└── foundry.toml                     # Foundry configuration
```

## Testing

The test suite includes 17 tests covering all features:

| Test                                            | Description                                            |
| ----------------------------------------------- | ------------------------------------------------------ |
| `testOwnerCanExecuteCommands`                   | Owner can call execute() directly                      |
| `testNonOwnerCannotExecuteCommands`             | Random addresses are rejected                          |
| `testRecoverSignedOp`                           | ECDSA signature recovery returns correct owner         |
| `testValidateUserOp`                            | validateUserOp returns 0 (success) for valid signature |
| `testEntryPointCanExecuteCommands`              | Full UserOp flow through EntryPoint works              |
| `testBatchExecution`                            | executeBatch processes multiple calls atomically       |
| `testBatchExecutionRevertsOnInvalidArrayLength` | Mismatched array lengths revert                        |
| `testAddSessionKey`                             | Session keys are stored with correct constraints       |
| `testRevokeSessionKey`                          | Revoked keys are no longer valid                       |
| `testSessionKeyExpiration`                      | Expired keys are rejected                              |
| `testInitiateRecovery`                          | Guardian can start recovery process                    |
| `testExecuteRecoveryAfterPeriod`                | Recovery succeeds after 2-day delay                    |
| `testCannotExecuteRecoveryBeforePeriod`         | Early recovery execution reverts                       |
| `testOwnerCanCancelRecovery`                    | Owner can cancel pending recovery                      |
| `testNonGuardianCannotInitiateRecovery`         | Non-guardians are rejected                             |
| `testFactoryCreatesAccount`                     | Factory deploys working proxy wallet                   |
| `testFactoryComputesCorrectAddress`             | CREATE2 address prediction matches actual              |
| `testFactoryIdempotent`                         | Duplicate createAccount returns existing wallet        |

## Technologies

- **Solidity 0.8.24** — Smart contract language
- **Foundry** — Development framework (Forge, Cast, Anvil)
- **ERC-4337 v0.7** — Account abstraction standard (EntryPoint, PackedUserOperation)
- **OpenZeppelin Contracts** — Ownable, ECDSA, MessageHashUtils, ERC1967Proxy, Initializable
- **Sepolia Testnet** — Ethereum test network for deployment and testing
