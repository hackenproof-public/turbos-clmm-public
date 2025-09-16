# Turbos CLMM Protocol

## Overview
Turbos CLMM (Concentrated Liquidity Market Maker) is a high-performance, modular, and secure on-chain liquidity protocol implemented in Move. It enables users to provide liquidity within custom price ranges, perform efficient swaps, and manage positions with fine-grained control. The protocol is designed for composability, extensibility, and robust security.

## Modules

### 1. pool.move
- **Purpose:** Implements the core CLMM pool logic, including liquidity management, swaps, fee accrual, and reward distribution.
- **Key Features:**
  - Add/remove liquidity within tick ranges
  - Swap tokens with concentrated liquidity
  - Collect fees and protocol rewards
  - Tick and position management

### 2. pool_factory.move
- **Purpose:** Manages pool creation, configuration, and administration.
- **Key Features:**
  - Deploy new pools with custom parameters
  - Set and update fee tiers
  - Manage protocol-level settings

### 3. position_manager.move
- **Purpose:** Handles user positions, NFT minting/burning, and position metadata.
- **Key Features:**
  - Mint/burn position NFTs
  - Track user positions and rewards
  - Update NFT metadata (name, description, image)

### 4. position_nft.move
- **Purpose:** Defines the NFT standard for representing liquidity positions.
- **Key Features:**
  - Mint and burn position NFTs
  - Store position-specific metadata

### 5. fee.move & feeXXXXbps.move
- **Purpose:** Define fee tiers and tick spacing for pools.
- **Key Features:**
  - Create and manage fee configurations
  - Support multiple fee levels (e.g., 100bps, 500bps, 3000bps, etc.)

### 6. math_liquidity.move
- **Purpose:** Provides core math for liquidity calculations.
- **Key Features:**
  - Compute liquidity for given amounts and price ranges
  - Convert between liquidity and token amounts

### 7. math_sqrt_price.move
- **Purpose:** Math utilities for price and tick calculations using Q64.64 fixed-point arithmetic.
- **Key Features:**
  - Calculate next sqrt price after swaps
  - Convert between price and tick

### 8. math_swap.move
- **Purpose:** Swap math logic for CLMM swaps.
- **Key Features:**
  - Compute swap steps and amounts
  - Handle fee and price impact calculations

### 9. math_tick.move
- **Purpose:** Tick and price range management.
- **Key Features:**
  - Convert between ticks and sqrt prices
  - Tick spacing and range validation

### 10. partner.move
- **Purpose:** Partner/referral system for protocol integrations.
- **Key Features:**
  - Register and manage partners
  - Distribute referral fees

### 11. reward_manager.move
- **Purpose:** Manage additional reward programs for liquidity providers.
- **Key Features:**
  - Track and distribute external rewards

### 12. swap_router.move
- **Purpose:** High-level router for multi-hop swaps and user-friendly interfaces.
- **Key Features:**
  - Route swaps across multiple pools
  - Support for complex swap paths

### 13. pool_fetcher.move
- **Purpose:** Utility for querying pool and position data.
- **Key Features:**
  - Fetch pool state and user positions

### 14. lib/math_*.move, lib/i*.move
- **Purpose:** Low-level math and integer utilities (u64, u128, i32, i64, i128, bit operations).
- **Key Features:**
  - Safe arithmetic, overflow checks
  - Bitwise and fixed-point math

## Security
- All modules are designed with strict overflow checks, input validation, and permission controls.
- Extensive unit tests cover edge cases and extreme values.

## Getting Started
1. Clone the repository.
2. Install Move toolchain and dependencies.
3. Run unit tests:
   ```
   move test
   ```
4. Deploy modules to your Move-compatible blockchain.

## License
MIT © Turbos Finance, Inc.