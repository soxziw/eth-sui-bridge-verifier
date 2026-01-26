// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { Transaction } from "@mysten/sui/transactions";
import { CONSTANTS } from "@/constants";

export type Operator = 'GT' | 'GTE' | 'LT' | 'LTE' | 'EQ' | 'NEQ';

export const OP_MAP: Record<Operator, number> = {
  GT: 0,
  GTE: 1,
  LT: 2,
  LTE: 3,
  EQ: 4,
  NEQ: 5,
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
  // Fetch proof from Alchemy
  const response = await fetch(
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

  const body = await response.json();

  if (body.error) {
    throw new Error(`Failed to fetch proof: ${body.error.message}`);
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
        body.result.accountProof.map((x: string) => hexToNumberArray(x))
      ),
      txb.pure.u256(BigInt(body.result.nonce)),
      txb.pure.u256(BigInt(body.result.balance)),
      txb.pure.vector("u8", hexToNumberArray(body.result.storageHash)),
      txb.pure.vector("u8", hexToNumberArray(body.result.codeHash)),
    ],
  });

  return txb;
}

/**
 * Creates a transaction to submit a command with escrow
 */
export async function createSubmitCommandTransaction(
  conditions: Condition[],
  actionTarget: string,
  escrowObjectId: string,
  adminCapObjectId: string
): Promise<Transaction> {
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

  txb.moveCall({
    target: `${CONSTANTS.proofVerifierContract.packageId}::condition_tx_executor::submit_command_with_escrow`,
    arguments: [
      txb.object(adminCapObjectId),
      txb.object(conditionTxOracleObjectId),
      txb.pure.vector("vector<u8>", listOfConditionAccounts),
      txb.pure.vector("u8", listOfConditionOperators),
      txb.pure.vector("u256", listOfConditionBalances),
      txb.pure.address(actionTarget),
      txb.object(escrowObjectId),
    ],
  });

  return txb;
}

