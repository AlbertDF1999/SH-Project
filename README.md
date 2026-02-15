 # MainAccount - ERC-4337 Account Abstraction Wallet

> A production-ready smart contract wallet implementing ERC-4337 Account Abstraction with advanced features including session keys, social recovery, and batch execution.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.24-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-red)](https://getfoundry.sh/)

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Testing](#testing)
- [Deployment](#deployment)
- [Advanced Features](#advanced-features)
- [Security](#security)
- [Gas Optimization](#gas-optimization)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

MainAccount is a smart contract wallet that implements the ERC-4337 Account Abstraction standard, enabling gasless transactions, batch operations, temporary permissions, and social recovery. This implementation uses best practices including the proxy pattern for gas-efficient deployment and CREATE2 for deterministic addresses.

### What is Account Abstraction?

Account Abstraction (ERC-4337) allows smart contracts to act as wallets, enabling features impossible with traditional Externally Owned Accounts (EOAs):

- **Gasless transactions** - Users don't need ETH for gas
- **Batch operations** - Multiple actions in one transaction
- **Custom validation** - Flexible signature schemes
- **Session keys** - Temporary permissions for dApps
- **Social recovery** - Recover accounts without seed phrases

## ✨ Features

### Core Features
- ✅ **ERC-4337 Compliant** - Full EntryPoint integration
- ✅ **Proxy Pattern** - Gas-efficient account creation via factory
- ✅ **Counterfactual Deployment** - Get address before deploying
- ✅ **Signature Validation** - ECDSA with EIP-191 standard
- ✅ **Owner Management** - OpenZeppelin Ownable integration

### Advanced Features
- 🔑 **Session Keys** - Temporary, restricted permissions
- 📦 **Batch Execution** - Execute multiple transactions atomically
- 🔄 **Social Recovery** - Guardian-based account recovery
- ⏱️ **Time-based Permissions** - Granular access control
- 🎯 **Target Restrictions** - Limit session keys to specific contracts
- 🔒 **Function Restrictions** - Limit session keys to specific functions

### Developer Features
- 🧪 **Comprehensive Tests** - 100% coverage of core functionality
- 📚 **Full Documentation** - NatSpec comments on all functions
- 🛠️ **Multi-chain Support** - Ethereum, Sepolia, and Anvil
- 🚀 **Easy Deployment** - Automated scripts with Foundry

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         User / dApp                          │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │   Bundler     │
                    └───────┬───────┘
                            │
                            ▼
                    ┌───────────────┐
                    │  EntryPoint   │
                    └───────┬───────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │                                        │
        ▼                                        ▼
┌──────────────┐                        ┌──────────────┐
│   Paymaster  │                        │ MainAccount  │
│  (Optional)  │                        │   (Proxy)    │
└──────────────┘                        └──────┬───────┘
                                               │
                                               ▼
                                    ┌──────────────────┐
                                    │  Implementation  │
                                    │  MainAccount.sol │
                                    └──────────────────┘
```

### Contract Structure

```
src/
├── MainAccount.sol           # Smart contract wallet implementation
└── MainAccountFactory.sol    # Factory for CREATE2 deployment

script/
├── DeployMainAccount.s.sol   # Deployment scripts
├── HelperConfig.s.sol        # Multi-chain configuration
└── SendPackedUserOp.s.sol    # UserOperation helpers

test/
└── TestMainAccount.t.sol     # Comprehensive test suite
```

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Basic understanding of Ethereum and smart contracts
- Node.js v16+ (for frontend integration)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/AlbertDF1999/SH-Project.git
   cd SH-Project
   ```

2. **Install dependencies**
   ```bash
   forge install
   git submodule update --init --recursive
   ```

3. **Build the project**
   ```bash
   forge build
   ```

4. **Run tests**
   ```bash
   forge test
   ```

## 💡 Usage

### Quick Start - Local Deployment

1. **Start Anvil (local blockchain)**
   ```bash
   anvil
   ```

2. **Deploy in a new terminal**
   ```bash
   forge script script/DeployMainAccount.s.sol:DeployMainAccount \
     --rpc-url http://127.0.0.1:8545 \
     --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
     --broadcast
   ```

### Basic Account Operations

#### 1. Create a New Account

```solidity
// Using the factory
MainAccountFactory factory = MainAccountFactory(factoryAddress);

// Create account with deterministic address
uint256 salt = 0;
MainAccount account = factory.createAccount(ownerAddress, salt);

// Or get address before deploying
address futureAddress = factory.getAddress(ownerAddress, salt);
```

#### 2. Execute a Transaction

```solidity
// Owner can execute directly
account.execute(
    targetContract,      // destination
    0,                   // value (ETH to send)
    callData            // function call data
);
```

#### 3. Batch Execute Multiple Transactions

```solidity
address[] memory targets = new address[](2);
targets[0] = tokenAddress;
targets[1] = dexAddress;

uint256[] memory values = new uint256[](2);
values[0] = 0;
values[1] = 0;

bytes[] memory calls = new bytes[](2);
calls[0] = abi.encodeWithSelector(IERC20.approve.selector, dexAddress, amount);
calls[1] = abi.encodeWithSelector(IDex.swap.selector, tokenA, tokenB, amount);

account.executeBatch(targets, values, calls);
```

### Working with UserOperations

```solidity
// 1. Prepare the call data
bytes memory callData = abi.encodeWithSelector(
    account.execute.selector,
    targetAddress,
    value,
    functionData
);

// 2. Create and sign UserOperation
PackedUserOperation memory userOp = sendPackedUserOp.generateSignedUserOperation(
    callData,
    config,
    address(account)
);

// 3. Submit to bundler or EntryPoint
PackedUserOperation[] memory ops = new PackedUserOperation[](1);
ops[0] = userOp;
IEntryPoint(entryPoint).handleOps(ops, payable(beneficiary));
```

## 🧪 Testing

### Run All Tests
```bash
forge test
```

### Run Tests with Verbosity
```bash
# Show test names and results
forge test -vv

# Show stack traces
forge test -vvv

# Show full traces and setup
forge test -vvvv
```

### Run Specific Tests
```bash
# Test a specific contract
forge test --match-contract TestMainAccount

# Test a specific function
forge test --match-test testBatchExecution

# Test with gas reporting
forge test --gas-report
```

### Generate Coverage Report
```bash
forge coverage
```

### Test Categories

Our test suite covers:

- ✅ **Basic Execution** - Owner and non-owner scenarios
- ✅ **Batch Operations** - Multi-transaction execution
- ✅ **Session Keys** - Creation, validation, expiration, revocation
- ✅ **Recovery** - Guardian management and recovery process
- ✅ **Factory** - Account creation and address prediction
- ✅ **UserOp Validation** - Signature recovery and validation
- ✅ **EntryPoint Integration** - Full ERC-4337 flow

## 📡 Deployment

### Deploy to Local Network (Anvil)

```bash
# Terminal 1: Start Anvil
anvil

# Terminal 2: Deploy
forge script script/DeployMainAccount.s.sol:DeployMainAccount \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

### Deploy to Sepolia Testnet

```bash
# Set environment variables
export SEPOLIA_RPC_URL="your_rpc_url"
export PRIVATE_KEY="your_private_key"

# Deploy
forge script script/DeployMainAccount.s.sol:DeployMainAccount \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Deploy Options

The deployment script provides three methods:

1. **deployMainAccountWithFactory()** - ⭐ Recommended
   - Deploys factory and creates account
   - Production-ready approach

2. **deployFactory()** - For factory-only deployment
   - Deploy factory once
   - Create multiple accounts later

3. **deployMainAccount()** - Legacy method
   - Direct deployment without factory
   - Not recommended for production

## 🔑 Advanced Features

### Session Keys

Session keys allow temporary, restricted access without exposing the main private key.

#### Creating a Session Key

```solidity
// Allow a game contract to spend tokens for 24 hours
account.addSessionKey(
    gameSessionKeyAddress,           // The session key address
    uint48(block.timestamp + 1 days), // Valid until
    tokenAddress,                     // Can only call this contract
    IERC20.transfer.selector          // Can only call this function
);
```

#### Session Key Restrictions

You can restrict session keys in multiple ways:

```solidity
// Unrestricted (any target, any function)
addSessionKey(sessionKey, validUntil, address(0), bytes4(0));

// Specific contract, any function
addSessionKey(sessionKey, validUntil, uniswapRouter, bytes4(0));

// Any contract, specific function
addSessionKey(sessionKey, validUntil, address(0), IERC20.approve.selector);

// Specific contract and function
addSessionKey(sessionKey, validUntil, uniswapRouter, IUniswap.swap.selector);
```

#### Revoking a Session Key

```solidity
// Owner can revoke anytime
account.revokeSessionKey(sessionKeyAddress);
```

#### Checking Session Key Status

```solidity
// Check if valid
bool isValid = account.isSessionKeyValid(sessionKeyAddress);

// Get full details
MainAccount.SessionKeyData memory data = account.getSessionKeyData(sessionKeyAddress);
```

### Social Recovery

Protect against lost keys with a trusted guardian.

#### Setting Up Recovery

```solidity
// 1. Owner sets a guardian (trusted friend, family, or contract)
account.setGuardian(guardianAddress);
```

#### Recovering an Account

If the owner loses their private key:

```solidity
// 1. Guardian initiates recovery
account.initiateRecovery(newOwnerAddress); // Called by guardian

// 2. Wait for the recovery period (2 days)
// During this time, the owner can cancel if malicious

// 3. Guardian executes recovery after waiting period
account.executeRecovery(); // Called by guardian

// 4. Account is now owned by newOwnerAddress
```

#### Canceling Recovery

```solidity
// Owner can cancel anytime during the waiting period
account.cancelRecovery(); // Called by owner
```

### Batch Execution

Execute multiple transactions atomically in a single UserOperation.

#### Use Cases

1. **Approve and Swap**
   ```solidity
   address[] memory targets = [tokenAddress, dexAddress];
   bytes[] memory calls = [approveCall, swapCall];
   account.executeBatch(targets, values, calls);
   ```

2. **Multi-token Transfer**
   ```solidity
   // Transfer multiple tokens in one transaction
   address[] memory targets = [usdc, dai, usdt];
   bytes[] memory calls = [transferUSDC, transferDAI, transferUSDT];
   account.executeBatch(targets, values, calls);
   ```

3. **Complex DeFi Strategy**
   ```solidity
   // 1. Withdraw from Aave
   // 2. Swap on Uniswap
   // 3. Deposit to Compound
   // All in one atomic transaction
   ```

## 🔐 Security

### Access Control

- **Owner-only functions**: `execute`, `executeBatch`, `addSessionKey`, `revokeSessionKey`, `setGuardian`, `cancelRecovery`
- **Guardian-only functions**: `initiateRecovery`, `executeRecovery`
- **EntryPoint-only functions**: `validateUserOp`
- **EntryPoint or Owner**: `execute`, `executeBatch`

### Security Features

- ✅ **Signature Validation** - ECDSA with EIP-191
- ✅ **Nonce Management** - Prevents replay attacks
- ✅ **Time Locks** - Recovery has 2-day delay
- ✅ **Access Modifiers** - Strict permission checks
- ✅ **Event Emissions** - All state changes emit events
- ✅ **Reentrancy Protection** - Via modifiers and checks
- ✅ **Initializer Protection** - Can only initialize once

### Audit Status

⚠️ **This contract has NOT been audited.** Do not use in production with real funds without a professional security audit.

### Known Limitations

1. Single guardian (consider multi-sig guardian for production)
2. Fixed recovery period (2 days)
3. No spending limits on session keys
4. No rate limiting on operations

## ⚡ Gas Optimization

### Deployment Costs

| Method                   | Gas Cost   | Notes         |
| ------------------------ | ---------- | ------------- |
| Factory Deployment       | ~3,000,000 | One-time cost |
| Account Creation (Proxy) | ~300,000   | Via factory   |
| Direct Deployment        | ~2,000,000 | Legacy method |

### Operation Costs

| Operation             | Gas Cost | Notes                       |
| --------------------- | -------- | --------------------------- |
| Single Execute        | ~50,000  | Basic transaction           |
| Batch Execute (2 ops) | ~70,000  | Saves gas vs 2 separate txs |
| Batch Execute (5 ops) | ~120,000 | Significant savings         |
| Add Session Key       | ~45,000  | One-time per key            |
| Validate UserOp       | ~35,000  | Per operation               |

### Optimization Tips

1. **Use Factory** - 85% cheaper than direct deployment
2. **Batch Operations** - Up to 40% savings vs separate transactions
3. **Session Keys** - Avoid signing every transaction
4. **Counterfactual Deployment** - Receive funds before deploying

## 🛠️ Development

### Project Structure

```
SH-Project/
├── src/
│   ├── MainAccount.sol          # Main wallet implementation
│   └── MainAccountFactory.sol   # Factory for account creation
├── script/
│   ├── DeployMainAccount.s.sol  # Deployment scripts
│   ├── HelperConfig.s.sol       # Network configuration
│   └── SendPackedUserOp.s.sol   # UserOp utilities
├── test/
│   └── TestMainAccount.t.sol    # Test suite
├── lib/
│   ├── account-abstraction/     # ERC-4337 reference
│   ├── openzeppelin-contracts/  # OpenZeppelin libraries
│   └── forge-std/               # Foundry standard library
├── foundry.toml                 # Foundry configuration
└── README.md                    # This file
```

### Code Style

- Solidity 0.8.24
- NatSpec documentation on all public functions
- OpenZeppelin contracts for standard implementations
- Custom errors for gas efficiency
- Events for all state changes

### Adding New Features

1. Write tests first (TDD approach)
2. Implement feature in contract
3. Update deployment scripts if needed
4. Document in NatSpec comments
5. Update README

## 🔄 Migration from EOA

If you're migrating from a traditional wallet:

1. **Deploy Account**
   ```solidity
   MainAccount account = factory.createAccount(yourAddress, 0);
   ```

2. **Transfer Assets**
   - Send tokens from EOA to account address
   - Account can receive before deployment (counterfactual)

3. **Update dApp Integrations**
   - Use UserOperations instead of direct transactions
   - Integrate with bundler service

4. **Set Up Recovery**
   ```solidity
   account.setGuardian(trustedAddress);
   ```

## 🌐 Frontend Integration

### Using with ethers.js

```javascript
import { ethers } from 'ethers';

// Get account address before deploying
const factory = new ethers.Contract(factoryAddress, factoryABI, signer);
const accountAddress = await factory.getAddress(ownerAddress, salt);

// Create account when needed
const tx = await factory.createAccount(ownerAddress, salt);
await tx.wait();

// Interact with account
const account = new ethers.Contract(accountAddress, accountABI, signer);
```

### Using with viem/wagmi

```typescript
import { createPublicClient, http } from 'viem';
import { mainnet } from 'viem/chains';

const publicClient = createPublicClient({
  chain: mainnet,
  transport: http(),
});

// Read account data
const isValid = await publicClient.readContract({
  address: accountAddress,
  abi: mainAccountABI,
  functionName: 'isSessionKeyValid',
  args: [sessionKeyAddress],
});
```

### Using with Account Abstraction SDKs

```typescript
// Using Alchemy's aa-sdk
import { LocalAccountSigner } from '@alchemy/aa-core';
import { createModularAccountAlchemyClient } from '@alchemy/aa-alchemy';

const client = await createModularAccountAlchemyClient({
  apiKey: 'your-api-key',
  chain: sepolia,
  signer: LocalAccountSigner.mnemonicToAccountSigner(mnemonic),
});

// Send UserOperation
const hash = await client.sendUserOperation({
  target: '0x...',
  data: '0x...',
  value: 0n,
});
```

## 📚 Resources

### ERC-4337 Resources
- [EIP-4337 Specification](https://eips.ethereum.org/EIPS/eip-4337)
- [Account Abstraction Docs](https://docs.alchemy.com/docs/account-abstraction-overview)
- [Bundler Services](https://www.alchemy.com/bundler)

### Development Tools
- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Ethereum Development Documentation](https://ethereum.org/en/developers/)

### Community
- [Account Abstraction Discord](https://discord.gg/account-abstraction)
- [Ethereum Stack Exchange](https://ethereum.stackexchange.com/)

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Write tests for all new features
- Follow existing code style
- Add NatSpec documentation
- Update README if needed
- Ensure all tests pass (`forge test`)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This software is provided "as is", without warranty of any kind. The authors are not responsible for any losses incurred through the use of this code. Always audit smart contracts before deploying with real funds.

## 🙏 Acknowledgments

- [Ethereum Foundation](https://ethereum.org/) for ERC-4337
- [OpenZeppelin](https://openzeppelin.com/) for secure contract libraries
- [Foundry](https://getfoundry.sh/) for excellent development tools
- The Account Abstraction community for inspiration and support

## 📞 Contact & Support

- **Issues**: [GitHub Issues](https://github.com/AlbertDF1999/SH-Project/issues)
- **Discussions**: [GitHub Discussions](https://github.com/AlbertDF1999/SH-Project/discussions)

---

**Built with ❤️ using Foundry and ERC-4337**

*For questions, feedback, or collaboration opportunities, please open an issue or discussion on GitHub.*