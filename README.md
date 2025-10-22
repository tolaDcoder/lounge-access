# Airport Lounge Access Smart Contract

A comprehensive Clarity smart contract for the Stacks blockchain that manages airport lounge access through NFT-based day passes, upgrade auctions, and frequent flyer rewards.

## Overview

This smart contract enables decentralized management of airport lounge access with the following key features:

- **Transferable Day Passes**: Purchase and transfer lounge access passes with expiration dates
- **Tiered Access System**: Bronze, Gold, and Platinum tiers with different pricing
- **Upgrade Auctions**: Bid on pass upgrades in a decentralized auction marketplace
- **Frequent Flyer Integration**: Earn miles, unlock tiers, and redeem rewards
- **Lounge Management**: Track capacity, occupancy, and entry validation

## Features

### 1. Day Pass Management

Purchase lounge access passes with customizable validity periods and tier levels:

```clarity
(purchase-pass "lounge-jfk-terminal-4" "gold" u144)
```

- **Tiers**: Bronze (1x), Gold (2x), Platinum (3x base price)
- **Transferable**: Passes can be transferred to other users
- **Expiration**: Validity tracked in blocks (~10 minutes per block)
- **Unique IDs**: Each pass has a unique identifier

### 2. Pass Transfers

Transfer your pass to another user:

```clarity
(transfer-pass u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

- Only the pass owner can transfer
- Pass must not be expired
- Must be marked as transferable

### 3. Lounge Entry

Use your pass to enter a lounge:

```clarity
(enter-lounge u1)
```

- Validates pass ownership and expiration
- Checks lounge capacity
- Updates occupancy counter
- Awards 50 frequent flyer miles
- Increments visit counter

### 4. Upgrade Auctions

Create and participate in pass upgrade auctions:

**Create an auction:**
```clarity
(create-upgrade-auction u1 "platinum" u500000 u1000)
```

**Place a bid:**
```clarity
(bid-on-upgrade u1 u600000)
```

**Finalize auction:**
```clarity
(finalize-upgrade u1)
```

- Previous bidders automatically refunded
- Winner receives upgraded pass
- Seller receives winning bid amount
- Auction must reach end block before finalization

### 5. Frequent Flyer Miles

Earn and redeem miles:

**Check your miles:**
```clarity
(get-flyer-miles tx-sender)
```

**Redeem miles for a pass:**
```clarity
(redeem-miles-for-pass "lounge-lax-terminal-1" u500)
```

**Miles earning:**
- 100 miles per pass purchase
- 50 miles per lounge entry
- Automatic tier upgrades:
  - Bronze: 0-1,999 miles
  - Gold: 2,000-4,999 miles
  - Platinum: 5,000+ miles

### 6. Lounge Registration

Contract owner can register new lounges:

```clarity
(register-lounge "lounge-ord-terminal-5" "United Club" "Chicago O'Hare T5" u150)
```

## Contract Functions

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-pass` | Retrieve pass details by ID |
| `get-flyer-miles` | Get user's miles, tier, and visit count |
| `get-auction` | Get auction details by ID |
| `get-lounge` | Get lounge information |
| `get-base-price` | Get current base pass price |
| `calculate-tier-price` | Calculate price for a specific tier |

### Public Functions

| Function | Description |
|----------|-------------|
| `register-lounge` | Register a new lounge (owner only) |
| `purchase-pass` | Buy a day pass for a lounge |
| `transfer-pass` | Transfer pass to another user |
| `enter-lounge` | Use pass to enter lounge |
| `create-upgrade-auction` | Create auction to upgrade pass |
| `bid-on-upgrade` | Place bid on upgrade auction |
| `finalize-upgrade` | Complete auction after end block |
| `redeem-miles-for-pass` | Exchange miles for a gold pass |
| `set-base-price` | Update base price (owner only) |

## Data Structures

### Day Pass
```clarity
{
    owner: principal,
    lounge-id: (string-ascii 50),
    valid-until: uint,
    tier: (string-ascii 20),
    transferable: bool
}
```

### Frequent Flyer Data
```clarity
{
    miles: uint,
    tier: (string-ascii 20),
    total-visits: uint
}
```

### Upgrade Auction
```clarity
{
    pass-id: uint,
    from-tier: (string-ascii 20),
    to-tier: (string-ascii 20),
    highest-bidder: (optional principal),
    highest-bid: uint,
    end-block: uint,
    active: bool
}
```

### Lounge
```clarity
{
    name: (string-ascii 100),
    location: (string-ascii 100),
    capacity: uint,
    current-occupancy: uint,
    active: bool
}
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | `err-owner-only` | Caller is not contract owner |
| u101 | `err-not-found` | Resource not found |
| u102 | `err-insufficient-balance` | Insufficient funds or capacity |
| u103 | `err-expired` | Pass has expired |
| u104 | `err-invalid-bid` | Bid amount too low |
| u105 | `err-auction-ended` | Auction has ended or not ended |
| u106 | `err-unauthorized` | Caller not authorized |
| u107 | `err-already-exists` | Resource already exists |

## Pricing

- **Base Price**: 1 STX (1,000,000 microSTX)
- **Bronze Tier**: 1x base price
- **Gold Tier**: 2x base price (2 STX)
- **Platinum Tier**: 3x base price (3 STX)

Prices can be adjusted by contract owner using `set-base-price`.

## Block Time

Stacks blocks are produced approximately every 10 minutes:
- 144 blocks ≈ 1 day
- 1000 blocks ≈ 7 days
- 4320 blocks ≈ 30 days

## Example Usage Flows

### Purchase and Use a Pass

1. Purchase a gold pass for 24 hours:
```clarity
(purchase-pass "lounge-jfk-t4" "gold" u144)
;; Returns: (ok u1)
```

2. Enter the lounge:
```clarity
(enter-lounge u1)
;; Returns: (ok true)
```

### Auction an Upgrade

1. Purchase a bronze pass:
```clarity
(purchase-pass "lounge-lax-t1" "bronze" u1000)
```

2. Create upgrade auction:
```clarity
(create-upgrade-auction u1 "platinum" u1000000 u100)
;; Returns: (ok u1)
```

3. Another user bids:
```clarity
(bid-on-upgrade u1 u1500000)
```

4. After 100 blocks, finalize:
```clarity
(finalize-upgrade u1)
```

### Build Up Miles

1. Purchase passes and enter lounges to earn miles
2. Check your status:
```clarity
(get-flyer-miles 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
;; Returns: {miles: u650, tier: "gold", total-visits: u5}
```

3. Redeem miles for free pass:
```clarity
(redeem-miles-for-pass "lounge-ord-t5" u500)
```

## Security Features

- **Ownership Validation**: All transfers and usage validate pass ownership
- **Expiration Checks**: Expired passes cannot be used or transferred
- **Capacity Limits**: Lounges cannot exceed maximum capacity
- **Automatic Refunds**: Auction bidders automatically refunded when outbid
- **Access Control**: Only contract owner can register lounges and adjust prices

## Deployment

1. Deploy the contract to Stacks blockchain
2. Contract owner registers lounges using `register-lounge`
3. Users can start purchasing passes and participating in the ecosystem

## Development

Built with Clarity for Stacks blockchain. Compatible with:
- Clarinet for local testing
- Stacks CLI for deployment
- Hiro Wallet for user interaction

## License

This smart contract is provided as-is for demonstration purposes.

## Support

For issues or questions, please refer to the Stacks documentation at [docs.stacks.co](https://docs.stacks.co)