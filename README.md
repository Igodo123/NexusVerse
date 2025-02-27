# NexuVaz Platform Smart Contract

A blockchain-based solution for managing in-game asset ownership and trading functionality in the NexuVaz gaming ecosystem.

## Overview

This smart contract enables secure ownership, transfer, and trading of in-game assets (NFTs) within the NexuVaz gaming platform. It incorporates a bazaar (marketplace) system for players to list and purchase items, as well as user progression tracking.

## Features

- **NFT Management**
  - Mint individual and batch gaming items as NFTs
  - Transfer ownership of items between players
  - View detailed item information

- **Marketplace (Bazaar) System**
  - List items for sale with custom pricing
  - Purchase items from other players
  - Remove listings from the marketplace

- **User Progress Tracking**
  - Store and retrieve player experience (exp) and rank
  - Enforced caps on maximum levels and experience

## Smart Contract Functions

### Administrative Functions

- `mint-item`: Create a single new gaming item (admin only)
- `batch-mint-items`: Create multiple gaming items in one transaction (admin only)

### Player Item Management

- `transfer-item`: Transfer a single item to another player
- `batch-transfer-items`: Transfer multiple items in one transaction

### Marketplace Functions

- `list-item-for-sale`: Add an item to the bazaar with a specified price
- `purchase-item`: Buy an item listed in the bazaar
- `delist-item`: Remove an item from sale in the bazaar

### Progress Tracking

- `update-user-progress`: Update a player's experience and rank

### Read-Only Functions

- `get-item-details`: Retrieve information about a specific item
- `get-bazaar-listing`: View details of an item listed for sale
- `get-user-progress`: Check a player's experience and rank
- `get-total-items`: Get the total number of items minted in the system

## Security Measures

- Ownership validation for all asset transfers and marketplace actions
- Admin-only minting functions to control item creation
- Transaction validation to prevent common attack vectors
- Batch operation limits to prevent gas-related issues

## Limitations

- Maximum metadata URI length: 256 characters
- Maximum batch operation size: 10 items
- Level cap: 100
- Experience cap: 10,000

## Implementation Notes

This contract uses Clarity, the smart contract language for the Stacks blockchain. It utilizes maps for efficient data storage and includes comprehensive error handling for secure operation.