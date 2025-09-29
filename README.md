# Uniswap V2 Core - Foundry Edition

This is the Uniswap V2 Core contracts repository, converted to use Foundry for development and testing.

## Overview

Uniswap V2 is a decentralized exchange protocol that allows users to swap ERC20 tokens directly on the Ethereum blockchain.

## Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Installation

```bash
# Clone the repository
git clone git@github.com:guzus/uniswap-v2-tutorial.git
cd uniswap-v2-tutorial

# Install dependencies
forge install
```

## Project Structure

```
├── src/                    # Core contracts
│   ├── UniswapV2Factory.sol
│   ├── UniswapV2Pair.sol
│   ├── UniswapV2ERC20.sol
│   ├── interfaces/         # Contract interfaces
│   └── libraries/          # Helper libraries
├── test/                   # Test files
│   └── UniswapV2Factory.t.sol
├── lib/                    # Dependencies
│   └── forge-std/          # Foundry standard library
└── foundry.toml           # Foundry configuration
```

## Commands

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Test with gas reporting

```bash
forge test --gas-report
```

### Format

```bash
forge fmt
```

### Generate coverage report

```bash
forge coverage
```

### Create a local testnet

```bash
anvil
```

## Configuration

The project is configured to use:
- Solidity version: 0.6.12
- Optimizer: Enabled with 999,999 runs
- EVM version: Istanbul

See `foundry.toml` for detailed configuration.

## Core Contracts

- **UniswapV2Factory**: Creates and manages Uniswap V2 pairs
- **UniswapV2Pair**: The core pair contract that holds reserves and enables swapping
- **UniswapV2ERC20**: ERC20 implementation for LP tokens

## License

GPL-3.0-or-later