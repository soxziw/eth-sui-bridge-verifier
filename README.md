# Ethereum-Sui Bridge Verifier

A decentralized cross-chain oracle system that verifies Ethereum account states on Sui blockchain and executes conditional transactions based on verified Ethereum account balances.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Ethereum Network                          │
│                    (State Roots & Account Data)                  │
└────────────────────────────┬────────────────────────────────────┘
                             │ eth_getProof (via Alchemy)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                          Sui Blockchain                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          Smart Contracts (Move Modules)                  │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │ State Root   │  │ MPT Proof    │  │ Condition Tx │  │  │
│  │  │  Registry    │  │  Verifier    │  │  Executor    │  │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │  │
│  │         │                  │                  │          │  │
│  │         └──────────────────┴──────────────────┘          │  │
│  │                    Events Emitted                        │  │
│  └──────────────────────────┬───────────────────────────────┘  │
└─────────────────────────────┼────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Event Indexer                             │
│          (Listens to Sui events & stores in DB)                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      REST API Server                            │
│          (Express + Prisma + SQLite)                            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Frontend dApp                               │
│        (React + Sui dApp Kit + Radix UI)                       │
└─────────────────────────────────────────────────────────────────┘
```

## Key Features

- **Cross-chain State Verification**: Verify Ethereum account states on Sui using Merkle Patricia Trie (MPT) proofs
- **Conditional Execution**: Execute transactions on Sui based on Ethereum account balances
- **Transfer Verification**: Monitor and verify Ethereum transfers with full and partial transfer modes
- **Decentralized Oracle**: State roots are submitted by trusted oracles (AdminCap holders)
- **Event-driven Architecture**: Real-time indexing of on-chain events
- **Full-stack dApp**: Complete solution from smart contracts to user interface

---

## Smart Contracts (Move Modules)

Located in: `contracts/proof-verifier/sources/`

### 1. State Root Registry (`state_root_registry.move`)

**Purpose**: Store and manage Ethereum state roots for specific block numbers.

**Key Components**:
- `StateRootOracle`: Shared object that stores state roots indexed by block number
- `AdminCap`: Capability object for authorized state root submissions
- Dynamic Object Fields (DOF): Used to store `BlockStateRootOracle` objects keyed by block number

**Key Functions**:
```move
// Submit or update state roots for multiple blocks
public fun submit_state_roots(
    _: &AdminCap,
    oracle: &mut StateRootOracle,
    list_of_block_numbers: vector<u64>,
    list_of_state_roots: vector<vector<u8>>,
    ctx: &mut TxContext
)

// Retrieve state root for a specific block
public fun get_state_root_by_block_number(
    oracle: &StateRootOracle,
    block_number: u64
): vector<u8>
```

**Events Emitted**:
- `StateRootCreated`: When a new state root is added
- `StateRootUpdated`: When an existing state root is modified
- `StateRootDeleted`: When a state root is removed

---

### 2. MPT Proof Verifier (`mpt_proof_verifier.move`)

**Purpose**: Verify Ethereum account states using Merkle Patricia Trie proofs.

**Key Components**:
- **RLP Decoding**: Full implementation of RLP (Recursive Length Prefix) decoding
- **MPT Traversal**: Navigate through branch and leaf nodes to verify account data
- **Account Structure**: Stores nonce, balance, storage_root, code_hash

**Core Algorithm**:
```
1. Retrieve state root from StateRootOracle
2. Convert Ethereum address to keccak256 hash → nibbles
3. Traverse MPT using proof nodes:
   - Branch nodes (17 items): Navigate by nibble
   - Leaf/Extension nodes (2 items): Match compact path
4. Decode account RLP: [nonce, balance, storageRoot, codeHash]
5. Verify all fields match expected values
6. Emit MPTProofVerified event
7. Trigger conditional transaction execution
```

**Key Function**:
```move
public fun verify_mpt_proof(
    mpt_proof_verifier: &mut MPTProofVerifier,
    state_root_oracle: &state_root_registry::StateRootOracle,
    condition_tx_oracle: &mut condition_tx_executor::ConditionTxOracle,
    block_number: u64,
    account: vector<u8>,        // 20 bytes (Ethereum address)
    account_proof: vector<vector<u8>>,  // MPT proof nodes
    expected_nonce: u256,
    expected_balance: u256,
    expected_storage_root: vector<u8>,  // 32 bytes
    expected_code_hash: vector<u8>,     // 32 bytes
    ctx: &mut TxContext
)
```

**MPT Implementation Details**:
- Supports branch nodes (16 children + value)
- Supports leaf and extension nodes with compact encoding
- Keccak256 hashing for node references
- Full RLP parser with nested list support

---

### 3. Condition TX Executor (`condition_tx_executor.move`)

**Purpose**: Execute conditional transactions when Ethereum account conditions are met.

**Key Components**:
- `ConditionTxOracle`: Stores conditional transactions with escrow vault
- `AccountConditionTxOracle`: Groups conditions by Ethereum account (stored as DOF)
- **Balance Comparison Operators**: GT, GTE, LT, LTE, EQ, NEQ for balance comparisons
- **Transfer Operators**: FI/FS (Full Transfer), PI/PS (Partial Transfer)
- **Escrow System**: Holds SUI tokens until conditions are met

**Conditional Transaction Flow**:

**Standard Balance Conditions (GT, GTE, LT, LTE, EQ, NEQ)**:
```
1. User submits command with escrow
   - Define conditions: account + operator + value
   - Define action: recipient + amount
   - Deposit SUI to oracle vault

2. When MPT proof is verified:
   - Check if conditions exist for the verified account
   - Evaluate each condition against verified balance
   - If condition met:
     * Single condition: Transfer full escrow to recipient
     * Multiple conditions: Update to next condition
   - Remove or update condition transactions

3. Emit events for tracking
```

**Full Transfer Verification (FI → FS)**:
```
1. User submits transfer command with expected_transfer_amount
   - Operator: FI (Full Transfer Initial)
   - Expected amount to be transferred (in Wei)
   - Escrow amount on Sui blockchain

2. First verification (FI state):
   - Verify initial Ethereum account balance
   - Transition to FS (Full Transfer Set) state
   - Record baseline balance value

3. Second verification (FS state):
   - Verify new balance ≥ baseline + expected_transfer_amount
   - If condition met: Transfer full escrow to recipient
   - If not met: Condition remains active for future verification

4. Use case: Verify that a specific full amount was transferred to an Ethereum account
   before releasing payment on Sui
```

**Partial Transfer Verification (PI → PS)**:
```
1. User submits transfer command with expected_transfer_amount
   - Operator: PI (Partial Transfer Initial)
   - Maximum expected amount (in Wei)
   - Escrow amount on Sui blockchain

2. First verification (PI state):
   - Verify initial Ethereum account balance
   - Transition to PS (Partial Transfer Set) state
   - Record baseline balance value

3. Second verification (PS state):
   - Calculate actual_transfer = current_balance - baseline
   - Calculate proportional_amount = min(actual_transfer, expected) * escrow / expected
   - Transfer proportional_amount to recipient
   - Return remaining escrow to sender

4. Use case: Flexible payment verification where the actual transferred amount may be
   less than expected, with proportional reward distribution
```

**Key Functions**:
```move
// Submit a conditional transaction with balance comparison
public fun submit_command_with_escrow(
    oracle: &mut ConditionTxOracle,
    after_block_number: u64,
    list_of_condition_accounts: vector<vector<u8>>,
    list_of_condition_operators: vector<u8>,     // 0=GT, 1=GTE, 2=LT, 3=LTE, 4=EQ, 5=NEQ
    list_of_condition_values: vector<u256>,
    action_target: address,
    action_escrow: coin::Coin<SUI>,
    ctx: &mut TxContext
)

// Submit a transfer verification condition
public fun submit_transfer_command_with_escrow(
    oracle: &mut ConditionTxOracle,
    after_block_number: u64,
    transfer_account: vector<u8>,
    transfer_operator: u8,                        // 6=FI (Full), 8=PI (Partial)
    expected_transfer_amount: u64,                // Expected Wei amount on Ethereum
    action_target: address,
    action_escrow: coin::Coin<SUI>,
    ctx: &mut TxContext
)

// Called by MPT verifier when account is verified
public(package) fun submit_verified_account(
    oracle: &mut ConditionTxOracle,
    condition_tx_id: u256,
    block_number: u64,
    account: vector<u8>,
    balance: u256,
    ctx: &mut TxContext
)
```

**Events Emitted**:

*Standard Balance Conditions:*
- `ConditionTxCreated`: When a new condition is submitted
- `ConditionTxUpdated`: When a multi-condition advances to next condition
- `ConditionTxCompleted`: When all conditions are met and escrow is released

*Transfer Conditions:*
- `TransferConditionTxCreated`: When a new transfer condition is submitted (FI or PI)
- `TransferConditionTxUpdated`: When transfer transitions to verification state (FI→FS or PI→PS)
- `ConditionTxCompleted`: When transfer is verified and funds are distributed

---

## Transfer Verification Features

The system supports two advanced modes for verifying Ethereum transfers and executing corresponding actions on Sui:

### Full Transfer (FI/FS)

**Purpose**: Verify that a specific full amount has been transferred to an Ethereum account before releasing payment on Sui.

**How it works**:
1. **Initial State (FI - Full Transfer Initial)**:
   - User submits a transfer condition specifying the expected transfer amount (in Wei)
   - Locks escrow in the Sui contract
   - System waits for first proof verification

2. **Set State (FS - Full Transfer Set)**:
   - First MPT proof is submitted, recording the baseline Ethereum balance
   - Condition automatically transitions from FI → FS
   - System now knows the starting balance

3. **Verification**:
   - Second MPT proof is submitted with updated balance
   - Checks: `new_balance >= baseline_balance + expected_transfer_amount`
   - If true: Full escrow is transferred to the recipient
   - If false: Condition remains active for future verification

**Example Use Case**:
```
Scenario: Seller wants 0.05 ETH before releasing an NFT on Sui
- Expected transfer: 50000000000000000 Wei (0.05 ETH)
- Escrow: 1000 MIST (NFT transfer or payment)
- Buyer transfers exactly 0.05 ETH to seller's Ethereum address
- System verifies the transfer via MPT proofs
- Seller receives the full 1000 MIST on Sui
```

### Partial Transfer (PI/PS)

**Purpose**: Support flexible payment amounts where users can transfer any amount up to the expected maximum, with proportional reward distribution.

**How it works**:
1. **Initial State (PI - Partial Transfer Initial)**:
   - User submits a transfer condition with maximum expected amount
   - Locks escrow in the Sui contract
   - System waits for first proof verification

2. **Set State (PS - Partial Transfer Set)**:
   - First MPT proof is submitted, recording baseline balance
   - Condition transitions from PI → PS
   - System captures the starting point

3. **Verification**:
   - Second MPT proof is submitted with updated balance
   - Calculates: `actual_transfer = new_balance - baseline_balance`
   - Checks: `actual_transfer > 0`
   - Proportional calculation:
     ```
     transfer_to_recipient = min(actual_transfer, expected_amount) * escrow / expected_amount
     refund_to_sender = escrow - transfer_to_recipient
     ```
   - Distributes funds proportionally

**Example Use Case**:
```
Scenario: Crowdfunding campaign with flexible contributions
- Maximum expected: 100000000000000000 Wei (0.1 ETH)
- Escrow: 1000 MIST reward pool
- Contributor A transfers 0.03 ETH (30% of max)
  → Receives: 300 MIST (30% of escrow)
  → Refund: 700 MIST back to campaign creator
- Contributor B transfers 0.12 ETH (120% of max, capped at 100%)
  → Receives: 1000 MIST (100% of escrow)
  → Refund: 0 MIST
```

### Transfer Verification Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Full Transfer (FI → FS)                          │
├─────────────────────────────────────────────────────────────────────┤
│  1. Submit Condition (FI)                                           │
│     ├─ Expected: 50000000000000000 Wei (0.05 ETH)                  │
│     ├─ Escrow: 1000 MIST                                           │
│     └─ State: FI (Waiting for baseline)                            │
│                                                                      │
│  2. First Verification ──► Record Baseline                          │
│     ├─ Ethereum Balance: 100000000000000000 Wei                    │
│     ├─ State: FI → FS (Baseline set)                               │
│     └─ Waiting for transfer...                                     │
│                                                                      │
│  3. Second Verification ──► Check Full Amount                       │
│     ├─ New Balance: 150000000000000000 Wei                         │
│     ├─ Actual Transfer: 50000000000000000 Wei ✓                    │
│     ├─ Condition Met: transfer >= expected                         │
│     └─ Result: Transfer 1000 MIST to recipient                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                   Partial Transfer (PI → PS)                        │
├─────────────────────────────────────────────────────────────────────┤
│  1. Submit Condition (PI)                                           │
│     ├─ Max Expected: 100000000000000000 Wei (0.1 ETH)              │
│     ├─ Escrow: 1000 MIST                                           │
│     └─ State: PI (Waiting for baseline)                            │
│                                                                      │
│  2. First Verification ──► Record Baseline                          │
│     ├─ Ethereum Balance: 200000000000000000 Wei                    │
│     ├─ State: PI → PS (Baseline set)                               │
│     └─ Waiting for transfer...                                     │
│                                                                      │
│  3. Second Verification ──► Calculate Proportional                  │
│     ├─ New Balance: 230000000000000000 Wei                         │
│     ├─ Actual Transfer: 30000000000000000 Wei (0.03 ETH)           │
│     ├─ Percentage: 30% of expected                                 │
│     ├─ To Recipient: 300 MIST (30% of escrow)                      │
│     └─ Refund to Sender: 700 MIST (70% of escrow)                  │
└─────────────────────────────────────────────────────────────────────┘
```

### Transfer Operators Summary

| Operator | State Transition | Description | Payout Model |
|----------|------------------|-------------|--------------|
| **FI** | Initial | Full Transfer Initial - waiting for baseline | N/A |
| **FS** | Set | Full Transfer Set - verifying full amount received | All-or-nothing |
| **PI** | Initial | Partial Transfer Initial - waiting for baseline | N/A |
| **PS** | Set | Partial Transfer Set - accepting any amount | Proportional |

### Key Differences

| Feature | Full Transfer (FI/FS) | Partial Transfer (PI/PS) |
|---------|----------------------|--------------------------|
| **Flexibility** | Requires exact amount | Accepts any amount up to max |
| **Payout** | 100% or 0% | Proportional based on actual |
| **Refund** | No refund (all to recipient or stays in escrow) | Unused escrow refunded to sender |
| **Use Case** | Fixed price agreements | Crowdfunding, flexible payments |
| **Condition Met** | `balance >= baseline + expected` | `balance > baseline` |

---

## Indexer

Located in: `api/indexer/`

### Event Indexer (`event-indexer.ts`)

**Purpose**: Listen to Sui blockchain events and index them into a local database.

**Architecture**:
```typescript
const EVENTS_TO_TRACK = [
  {
    type: `${packageId}::state_root_registry`,
    filter: { MoveEventModule: { module: 'state_root_registry', package } },
    callback: handleStateRootObjects
  },
  {
    type: `${packageId}::condition_tx_executor`,
    filter: { MoveEventModule: { module: 'condition_tx_executor', package } },
    callback: handleConditionTxsObjects
  },
  {
    type: `${packageId}::mpt_proof_verifier`,
    filter: { MoveEventModule: { module: 'mpt_proof_verifier', package } },
    callback: handleMPTProofsObjects
  }
]
```

**Features**:
- **Cursor-based pagination**: Resume from last processed event
- **Continuous polling**: Configurable polling interval (default: 1 second)
- **Ascending order**: Process events chronologically
- **Persistent state**: Store cursor in database for recovery

### Event Handlers

#### 1. `state-root-handler.ts`
- Processes `StateRootCreated`, `StateRootUpdated`, `StateRootDeleted` events
- Stores block number and state root mapping
- Supports upsert operations for idempotency

#### 2. `condition-tx-handler.ts`
- Processes `ConditionTxCreated`, `ConditionTxUpdated`, `ConditionTxCompleted` events
- Processes `TransferConditionTxCreated`, `TransferConditionTxUpdated` events
- Tracks condition transactions with their current state
- Formats conditions and actions as human-readable strings
- Examples:
  - Balance condition: `"0x1234...balance GT 0x100"` → `"transfer 1000MIST to 0xabcd..."`
  - Transfer condition: `"Transfer a full amount of X MIST to recipient, in exchange for Y Wei on Ethereum"`

#### 3. `mpt-proof-handler.ts`
- Processes `MPTProofVerified` events
- Records verified account balances at specific block numbers
- Links proof verification to condition execution

---

## API Server

Located in: `api/server.ts`

**Tech Stack**: Express.js + Prisma + SQLite

### Endpoints

#### 1. `GET /state-roots`
Query state roots with pagination and filtering.

**Query Parameters**:
- `blockNumber`: Filter by specific block number
- `cursor`: Pagination cursor
- `limit`: Results per page

**Response**:
```json
{
  "data": [
    {
      "id": 1,
      "blockNumber": "0x123456",
      "stateRoot": "0xabcd..."
    }
  ],
  "nextCursor": "...",
  "hasNextPage": true
}
```

#### 2. `GET /condition-txs`
Query conditional transactions (including both balance comparisons and transfer verifications).

**Query Parameters**:
- `nextConditionAccount`: Filter by Ethereum account
- `actionTarget`: Filter by recipient address
- `completed`: Filter by completion status (true/false)

**Response**:
```json
{
  "data": [
    {
      "objectId": "123",
      "condition": "After block 0x9a9a00, 0x1234...balance GT 0x100",
      "action": "Transfer 1000 MIST to 0xabcd...",
      "nextConditionAccount": "0x1234...",
      "actionTarget": "0xabcd...",
      "completed": false
    },
    {
      "objectId": "124",
      "condition": "After block 0x9a9b05, 0x5678... has received 50000000000000000 Wei on Ethereum",
      "action": "Transfer a full amount of 2000 MIST to 0xdef0..., in exchange for 50000000000000000 Wei on Ethereum",
      "nextConditionAccount": "0x5678...",
      "actionTarget": "0xdef0...",
      "completed": false
    },
    {
      "objectId": "125",
      "condition": "After block 0x9a9c20, 0x9abc... has received a proportional amount of 100000000000000000 Wei on Ethereum",
      "action": "Transfer a proportional amount of 5000 MIST to 0x1111..., based on the ratio of the actual Wei transferred on Ethereum to the expected amount of 100000000000000000 Wei",
      "nextConditionAccount": "0x9abc...",
      "actionTarget": "0x1111...",
      "completed": false
    }
  ]
}
```

#### 3. `GET /mpt-proofs`
Query verified MPT proofs.

**Query Parameters**:
- `blockNumber`: Filter by block number
- `account`: Filter by Ethereum account

**Response**:
```json
{
  "data": [
    {
      "objectId": "1",
      "blockNumber": "0x123456",
      "account": "0x1234...",
      "balance": "0x100"
    }
  ]
}
```

### Database Schema (Prisma)

```prisma
model StateRoot {
  blockNumber String @unique
  stateRoot   String
}

model ConditionTx {
  objectId             String  @unique
  condition            String
  action               String
  nextConditionAccount String
  actionTarget         String
  completed            Boolean @default(false)
}

model MPTProof {
  objectId    String @unique
  blockNumber String
  account     String
  balance     String
}

model Cursor {
  id       String @id  // Event tracker type
  eventSeq String
  txDigest String
}
```

---

## Frontend dApp

Located in: `frontend/proof-verifier-dapp/`

**Tech Stack**: React + TypeScript + Vite + Radix UI + Sui dApp Kit

### Key Features

#### 1. **State Root Dashboard** (`routes/StateRootsDashboard.tsx`)
- View all submitted Ethereum state roots
- Display block numbers and corresponding state roots
- Real-time updates from indexer API

#### 2. **Condition TX Dashboard** (`routes/ConditionTxsDashboard.tsx`)
- View all conditional transactions (balance comparisons and transfers)
- Submit new conditions with escrow via dialog
  - Balance comparison modes: GT, GTE, LT, LTE, EQ, NEQ
  - Transfer verification modes: FI (Full Transfer), PI (Partial Transfer)
- Filter by completion status, account, or recipient
- Shows condition details and action targets
- Displays transfer-specific parameters (expected transfer amounts)

#### 3. **MPT Proof Dashboard** (`routes/MPTProofsDashboard.tsx`)
- View all verified proofs
- Request new proof verification via dialog
- Fetches proof from Alchemy API (`eth_getProof`)
- Submits proof to Sui blockchain for verification

### Core Transaction Utilities (`utils/transactions.ts`)

#### Create Verify MPT Proof Transaction
```typescript
async function createVerifyMPTProofTransaction(
  blockNumber: string,
  account: string,
  alchemyApiKey: string,
  ethNetwork: string
): Promise<Transaction>
```

**Flow**:
1. Call Alchemy API `eth_getProof` for Ethereum account
2. Extract `nonce`, `balance`, `storageHash`, `codeHash`, `accountProof`
3. Create Sui transaction calling `verify_mpt_proof`
4. Converts hex strings to byte arrays for Move function

#### Create Submit Command Transaction
```typescript
async function createSubmitCommandTransaction(
  conditions: Condition[],
  actionTarget: string,
  escrowObjectId: string,
  adminCapObjectId: string
): Promise<Transaction>
```

**Flow**:
1. Convert conditions to Move format (accounts, operators, values)
2. Create transaction calling `submit_command_with_escrow`
3. Attach escrow coin object and admin capability

### User Experience

1. **Connect Wallet**: Uses `@mysten/dapp-kit` for Sui wallet integration
2. **View Data**: Infinite scroll lists for state roots, conditions, proofs
3. **Submit Transactions**: Modal dialogs with form validation
4. **Real-time Updates**: Polling API endpoints for latest data
5. **Transaction Execution**: Direct blockchain interaction with user approval

---

## Comparison with Other Systems

### vs. NEAR Protocol

| Feature | Eth-Sui Bridge Verifier | NEAR Aurora Bridge |
|---------|------------------------|-------------------|
| **Proof System** | MPT proofs with RLP decoding | Light client + merkle proofs |
| **Architecture** | Oracle-based (trusted admins) | Trustless light client on-chain |
| **State Storage** | Dynamic Object Fields (DOF) | Contract storage |
| **Consensus** | Sui consensus (Narwhal+Bullshark) | NEAR's Nightshade PoS |
| **Verification** | On-demand proof verification | Continuous block header relay |
| **Language** | Move | Rust (compiled to Wasm) |
| **Gas Model** | Object-based gas (per-object computation) | Compute units + storage staking |

**Key Differences**:
- **NEAR** maintains a full light client with header verification, making it trustless but more complex
- **Sui** approach uses trusted oracles for state roots, simpler but requires trust in AdminCap holders
- **NEAR** stores headers continuously; **Sui** stores state roots on-demand
- **Move's** object model (DOF) provides better composability than NEAR's flat storage

---

### vs. Internet Computer (Dfinity)

| Feature | Eth-Sui Bridge Verifier | IC Ethereum Integration |
|---------|------------------------|------------------------|
| **Trust Model** | Oracle-based (AdminCap) | Threshold signatures (chain-key crypto) |
| **Verification** | Client-side + on-chain MPT | On-chain HTTPS outcalls + consensus |
| **Data Source** | Alchemy API (off-chain) | Direct RPC calls from canister |
| **Execution** | Conditional transactions | Full EVM state queries |
| **Language** | Move | Motoko / Rust |
| **Consensus** | Byzantine consensus | Chain-key cryptography + BFT |
| **Decentralization** | Depends on oracle trustworthiness | Subnet-level decentralization |

**Key Differences**:
- **IC** can make HTTPS outcalls directly from smart contracts (canisters) using threshold signatures
- **Sui** requires off-chain data providers, then verifies on-chain
- **IC's** chain-key cryptography eliminates need for oracles entirely
- **Sui's** approach is more gas-efficient but less trustless
- **IC** can query any Ethereum data; **Sui** is limited to what's proven via MPT

---

### vs. Weiroll (Ethereum Scripting)

| Feature | Eth-Sui Bridge Verifier | Weiroll |
|---------|------------------------|---------|
| **Purpose** | Cross-chain conditional execution | On-chain DeFi composability |
| **Scope** | Ethereum → Sui bridge | Ethereum-only operations |
| **Conditions** | Based on Ethereum account state | Based on return values in same tx |
| **Execution** | Asynchronous (separate txs) | Synchronous (single tx) |
| **Programming Model** | State-based triggers | Functional piping |
| **State Management** | Persistent conditions in oracle | Ephemeral execution state |
| **Language** | Move | Solidity + custom bytecode |

**Architecture Comparison**:

**Weiroll**:
```
┌─────────────────────────────────────┐
│  Single Ethereum Transaction        │
│  ┌───────┐   ┌───────┐   ┌───────┐ │
│  │ Call1 │──►│ Call2 │──►│ Call3 │ │
│  └───────┘   └───────┘   └───────┘ │
│  (check) → (swap) → (stake)        │
└─────────────────────────────────────┘
```

**Eth-Sui Bridge Verifier**:
```
┌──────────────────┐      ┌──────────────────┐
│  Ethereum Block  │      │  Sui Blockchain  │
│  (State = X)     │─────►│  IF X > 100      │
└──────────────────┘ Proof└───►THEN Transfer │
   Time T                      Time T+1        │
                               └──────────────┘
```

**Key Differences**:
- **Weiroll** enables complex DeFi operations in a single atomic transaction
- **Eth-Sui** enables cross-chain event-driven execution
- **Weiroll** conditions are based on function return values (e.g., swap amount > X)
- **Eth-Sui** conditions are based on external blockchain state (e.g., ETH balance > X)
- **Weiroll** has no cross-chain capability
- **Eth-Sui** has latency between condition evaluation and execution

---

## Setup & Deployment

### Prerequisites
- Node.js 20+
- pnpm
- Sui CLI
- Alchemy API key (for Ethereum state access)

### Demo

> Make sure you have enough Testnet (or any net) SUI in the active address of the CLI.

To produce demo data:

1. Run API server and indexer (This will automatically publish smart contracts and update package id and object id in api/proof-verifier-contract.json)

```bash
# Under api/
pnpm demo
```

2. Run Frontend
```bash
# Under frontend/proof-verifier-dapp/
pnpm demo
```

If you want to reset the database (start from scratch), run:

```bash
# Under api/
pnpm db:reset:dev && pnpm db:setup:dev
```
---

## Security Considerations

### General Security

1. **Trusted Oracle**: State roots must be submitted by AdminCap holder - requires trust
2. **MPT Proof Validity**: Only as secure as the state root source
3. **Escrow Safety**: Funds locked in oracle until conditions met or admin intervention
4. **RLP Parsing**: Thoroughly tested but custom implementation - audit recommended
5. **Reentrancy**: Move's object ownership prevents reentrancy attacks
6. **Dynamic Object Fields**: Properly cleaned up to prevent storage bloat

### Transfer Verification Security

7. **Baseline Recording**: First proof establishes baseline balance. Ensure block number ordering is correct
8. **Balance Manipulation**: 
   - An Ethereum account owner can manipulate their balance between proofs
   - For Full Transfer: Account could receive funds from multiple sources (not just the expected payer)
   - For Partial Transfer: Proportional payout caps at 100% to prevent over-distribution
9. **Block Number Verification**: System checks `after_block_number` to prevent replay attacks
10. **Integer Overflow**: Transfer calculations use u256 for Ethereum balances and u64 for Sui amounts
11. **Condition ID Matching**: Each verification must provide correct `condition_tx_id` to prevent condition hijacking
12. **State Transition Validation**: 
    - FI can only transition to FS (not directly to completion)
    - PI can only transition to PS (not directly to completion)
    - Prevents skipping verification steps

---

## Use Cases

1. **Conditional Airdrops**: Send SUI to users when their ETH balance exceeds threshold
2. **Cross-chain Incentives**: Reward users for maintaining liquidity on Ethereum
3. **Insurance Triggers**: Payout when account balance drops below threshold
4. **Governance**: Grant voting power based on Ethereum token holdings
5. **Cross-chain Lending**: Collateralization based on Ethereum assets
6. **Payment Verification**: 
   - **Full Transfer**: Escrow release requires exact amount to be transferred on Ethereum
   - **Partial Transfer**: Proportional escrow release based on actual transfer amount
7. **Cross-chain Atomic Swaps**: Lock funds on Sui until verified transfer on Ethereum
8. **Crowdfunding with Ethereum**: Release milestone payments based on verified deposits to Ethereum address

---

## References

- [Sui Move Documentation](https://docs.sui.io/guides/developer/sui-101)
- [Ethereum MPT Specification](https://ethereum.org/en/developers/docs/data-structures-and-encoding/patricia-merkle-trie/)
- [RLP Encoding](https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/)
- [Alchemy eth_getProof API](https://docs.alchemy.com/reference/eth-getproof)
- [Sui dApp Kit](https://sdk.mystenlabs.com/dapp-kit)

---

## License

Apache-2.0

---

## Contributing

Contributions welcome! Please ensure:
- Smart contract changes include tests
- API changes update OpenAPI documentation
- Frontend changes maintain responsive design
- Follow existing code style and conventions

---
