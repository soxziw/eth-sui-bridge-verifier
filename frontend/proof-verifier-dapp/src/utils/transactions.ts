// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { Transaction } from "@mysten/sui/transactions";
import { CONSTANTS } from "@/constants";

export type Operator = 'GT' | 'GTE' | 'LT' | 'LTE' | 'EQ' | 'NEQ' | 'FI' | 'PI';

export const OP_MAP: Record<Operator, number> = {
  GT: 0,
  GTE: 1,
  LT: 2,
  LTE: 3,
  EQ: 4,
  NEQ: 5,
  FI: 6,
  PI: 8,
};

function hexToNumberArray(hex: string): number[] {
  const h = hex.startsWith("0x") ? hex.slice(2) : hex;
  const bytes: number[] = [];
  for (let i = 0; i < h.length; i += 2) {
    bytes.push(parseInt(h.slice(i, i + 2), 16));
  }
  return bytes;
}

export interface Condition {
  account: string;
  operator: Operator;
  balance: string;
  expectedTransferAmount: string;
}

/**
 * Fetches proof from Alchemy API and creates a transaction to verify MPT proof
 */
export async function createVerifyMPTProofTransaction(
  blockNumber: string,
  account: string,
  alchemyApiKey: string,
  ethNetwork: string
): Promise<Transaction> {
  // Fetch finalized block from Alchemy
  const finalizedBlockResponse = await fetch(
    `https://${ethNetwork}.g.alchemy.com/v2/${alchemyApiKey}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        method: "eth_getBlockByNumber",
        params: ["finalized", false],
        id: 1,
      }),
    }
  );

  const finalizedBlockBody = await finalizedBlockResponse.json();

  if (finalizedBlockBody.error) {
    throw new Error(`Failed to fetch finalized block: ${finalizedBlockBody.error.message}`);
  }

  const finalizedBlockNumber = finalizedBlockBody.result.number;

  if (blockNumber > finalizedBlockNumber) {
    throw new Error("Block number is greater than finalized block");
  }

  // Fetch proof from Alchemy
  const proofResponse = await fetch(
    `https://${ethNetwork}.g.alchemy.com/v2/${alchemyApiKey}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        method: "eth_getProof",
        params: [account, ["0x0", "0x1"], blockNumber],
        id: 1,
      }),
    }
  );

  const proofBody = await proofResponse.json();

  if (proofBody.error) {
    throw new Error(`Failed to fetch proof: ${proofBody.error.message}`);
  }

  const txb = new Transaction();
  const mptProofVerifierObjectId =
    CONSTANTS.proofVerifierContract.mptProofVerifierId;
  const stateRootOracleObjectId =
    CONSTANTS.proofVerifierContract.stateRootOracleId;
  const conditionTxOracleObjectId =
    CONSTANTS.proofVerifierContract.conditionTxOracleId;

  if (
    !mptProofVerifierObjectId ||
    !stateRootOracleObjectId ||
    !conditionTxOracleObjectId
  ) {
    throw new Error(
      "MPT proof verifier, state root oracle or condition tx oracle object id not found"
    );
  }

  txb.moveCall({
    target: `${CONSTANTS.proofVerifierContract.packageId}::mpt_proof_verifier::verify_mpt_proof`,
    arguments: [
      txb.object(mptProofVerifierObjectId),
      txb.object(stateRootOracleObjectId),
      txb.object(conditionTxOracleObjectId),
      txb.pure.u64(BigInt(blockNumber)),
      txb.pure.vector("u8", hexToNumberArray(account)),
      txb.pure.vector(
        "vector<u8>",
        proofBody.result.accountProof.map((x: string) => hexToNumberArray(x))
      ),
      txb.pure.u256(BigInt(proofBody.result.nonce)),
      txb.pure.u256(BigInt(proofBody.result.balance)),
      txb.pure.vector("u8", hexToNumberArray(proofBody.result.storageHash)),
      txb.pure.vector("u8", hexToNumberArray(proofBody.result.codeHash)),
    ],
  });

  return txb;
}

/**
 * Creates a transaction to submit a command with escrow
 */
export async function createSubmitCommandTransaction(
  startBlock: string,
  conditions: Condition[],
  actionTarget: string,
  escrowValue: string,
  alchemyApiKey: string,
  ethNetwork: string
): Promise<Transaction> {
  // Fetch start block from Alchemy
  const startBlockResponse = await fetch(
    `https://${ethNetwork}.g.alchemy.com/v2/${alchemyApiKey}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        method: "eth_getBlockByNumber",
        params: [startBlock, false],
        id: 1,
      }),
    }
  );

  const startBlockBody = await startBlockResponse.json();

  if (startBlockBody.error) {
    throw new Error(`Failed to fetch start block: ${startBlockBody.error.message}`);
  }

  // Fetch finalized block from Alchemy
  const finalizedBlockResponse = await fetch(
    `https://${ethNetwork}.g.alchemy.com/v2/${alchemyApiKey}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        method: "eth_getBlockByNumber",
        params: ["finalized", false],
        id: 1,
      }),
    }
  );

  const finalizedBlockBody = await finalizedBlockResponse.json();

  if (finalizedBlockBody.error) {
    throw new Error(`Failed to fetch finalized block: ${finalizedBlockBody.error.message}`);
  }

  const startBlockNumber = startBlockBody.result.number;
  const finalizedBlockNumber = finalizedBlockBody.result.number;

  if (startBlockNumber > finalizedBlockNumber) {
    throw new Error("Start block is greater than finalized block");
  }

  const txb = new Transaction();
  const conditionTxOracleObjectId =
    CONSTANTS.proofVerifierContract.conditionTxOracleId;

  if (!conditionTxOracleObjectId) {
    throw new Error("Condition tx oracle object id not found");
  }

  const listOfConditionAccounts = conditions.map((c) =>
    hexToNumberArray(c.account)
  );
  const listOfConditionOperators = conditions.map((c) => OP_MAP[c.operator]);
  const listOfConditionBalances = conditions.map((c) => BigInt(c.balance));

  const escrowCoin = txb.splitCoins(txb.gas, [txb.pure.u64(escrowValue)]);
  txb.moveCall({
    target: `${CONSTANTS.proofVerifierContract.packageId}::condition_tx_executor::submit_command_with_escrow`,
    arguments: [
      txb.object(conditionTxOracleObjectId),
      txb.pure.u64(BigInt(startBlockNumber)),
      txb.pure.vector("vector<u8>", listOfConditionAccounts),
      txb.pure.vector("u8", listOfConditionOperators),
      txb.pure.vector("u256", listOfConditionBalances),
      txb.pure.address(actionTarget),
      escrowCoin,
    ],
  });

  return txb;
}

/**
 * Creates a transaction to submit a command with escrow
 */
export async function createSubmitTransferCommandTransaction(
  startBlock: string,
  condition: Condition,
  actionTarget: string,
  escrowValue: string,
  alchemyApiKey: string,
  ethNetwork: string
): Promise<Transaction> {
  // Fetch start block from Alchemy
  const startBlockResponse = await fetch(
    `https://${ethNetwork}.g.alchemy.com/v2/${alchemyApiKey}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        method: "eth_getBlockByNumber",
        params: [startBlock, false],
        id: 1,
      }),
    }
  );

  const startBlockBody = await startBlockResponse.json();

  if (startBlockBody.error) {
    throw new Error(`Failed to fetch start block: ${startBlockBody.error.message}`);
  }

  // Fetch finalized block from Alchemy
  const finalizedBlockResponse = await fetch(
    `https://${ethNetwork}.g.alchemy.com/v2/${alchemyApiKey}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        method: "eth_getBlockByNumber",
        params: ["finalized", false],
        id: 1,
      }),
    }
  );

  const finalizedBlockBody = await finalizedBlockResponse.json();

  if (finalizedBlockBody.error) {
    throw new Error(`Failed to fetch finalized block: ${finalizedBlockBody.error.message}`);
  }

  const startBlockNumber = startBlockBody.result.number;
  const finalizedBlockNumber = finalizedBlockBody.result.number;

  if (startBlockNumber > finalizedBlockNumber) {
    throw new Error("Start block is greater than finalized block");
  }

  const txb = new Transaction();
  const conditionTxOracleObjectId =
    CONSTANTS.proofVerifierContract.conditionTxOracleId;

  if (!conditionTxOracleObjectId) {
    throw new Error("Condition tx oracle object id not found");
  }

  const escrowCoin = txb.splitCoins(txb.gas, [txb.pure.u64(escrowValue)]);
  txb.moveCall({
    target: `${CONSTANTS.proofVerifierContract.packageId}::condition_tx_executor::submit_transfer_command_with_escrow`,
    arguments: [
      txb.object(conditionTxOracleObjectId),
      txb.pure.u64(BigInt(startBlockNumber)),
      txb.pure.vector("u8", hexToNumberArray(condition.account)),
      txb.pure.u8(OP_MAP[condition.operator]),
      txb.pure.u64(BigInt(condition.expectedTransferAmount)),
      txb.pure.address(actionTarget),
      escrowCoin,
    ],
  });

  return txb;
}

