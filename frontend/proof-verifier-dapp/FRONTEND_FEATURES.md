# Frontend Features

## 已实现的功能

### 1. Dashboard 页面

#### State Roots Dashboard (`/state-roots`)
- 展示所有 State Roots 列表
- 支持按 Block Number 筛选
- 无限滚动加载更多数据
- 显示：Block Number, State Root, ID

#### Condition Transactions Dashboard (`/condition-txs`)
- 展示所有 Condition Transactions 列表
- 支持多种筛选器：
  - Next Condition Account
  - Action Target
  - Status (All / Completed / Pending)
- 无限滚动加载更多数据
- 显示：Object ID, Status, Conditions, Actions

#### MPT Proofs Dashboard (`/mpt-proofs`)
- 展示所有 MPT Proofs 列表
- 支持筛选器：
  - Block Number
  - Account Address
- 无限滚动加载更多数据
- 显示：Object ID, Block Number, Account, Balance

### 2. Header 功能按钮

#### Request Proof 按钮
- 所有用户可见
- 点击后打开对话框，输入：
  - Block Number (必填)
  - Account Address (必填)
  - Alchemy API Key (必填)
  - Ethereum Network (可选，默认: eth-mainnet)
- 自动调用 Alchemy API 获取 proof
- 创建并提交交易到 Sui 网络以验证 MPT proof

#### Submit Command 按钮
- **仅当连接钱包且拥有 `condition_tx_executor::AdminCap` 时显示**
- 点击后打开对话框，输入：
  - Conditions (可变长度，至少一个)：
    - Account Address
    - Operator (EQ, NEQ, GT, GTE, LT, LTE)
    - Balance
  - Action Target (Receiver Address)
  - Escrow Object ID
- 创建并提交交易到 Sui 网络

### 3. 组件结构

```
src/
├── components/
│   ├── Header.tsx (包含两个功能按钮)
│   ├── RequestProofDialog.tsx
│   └── SubmitCommandDialog.tsx
├── routes/
│   ├── StateRootsDashboard.tsx
│   ├── ConditionTxsDashboard.tsx
│   └── MPTProofsDashboard.tsx
├── state_root/
│   ├── StateRoot.tsx (显示组件)
│   └── StateRootList.tsx (列表组件)
├── condition_tx/
│   ├── ConditionTx.tsx
│   └── ConditionTxList.tsx
├── mpt_proof/
│   ├── MPTProof.tsx
│   └── MPTProofList.tsx
├── utils/
│   └── transactions.ts (交易创建工具函数)
└── admincap/
    └── AdminCapOwnedObjects.tsx (AdminCap 检测)
```

### 4. API 集成

所有 Dashboard 都通过 `CONSTANTS.apiEndpoint` (默认: `http://localhost:3000/`) 连接到后端 API：

- `GET /state-roots?blockNumber=...`
- `GET /condition-txs?nextConditionAccount=...&actionTarget=...&completed=...`
- `GET /mpt-proofs?blockNumber=...&account=...`

### 5. 使用说明

1. 启动 API 服务器:
   ```bash
   cd api
   pnpm install
   pnpm dev
   ```

2. 启动前端:
   ```bash
   cd frontend/proof-verifier-dapp
   pnpm install
   pnpm dev
   ```

3. 连接钱包查看完整功能

4. 如需使用 "Submit Command" 功能，确保钱包拥有 `condition_tx_executor::AdminCap`

### 6. 环境要求

- Alchemy API Key (用于 Request Proof 功能)
- Sui Wallet (MyTen Wallet 或其他)
- 配置文件: `proof-verifier-contract.json` (包含 contract 信息)

