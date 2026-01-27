// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { Transaction } from '@mysten/sui/transactions';

import 'dotenv/config';
import { CONFIG } from '../config';
import { ACTIVE_NETWORK, getActiveAddress, getClient, signAndExecute } from '../sui-utils';

const getOwnedObjects = async (module: string, structType: string) => {
	const client = getClient(CONFIG.NETWORK);

	const res = await client.getOwnedObjects({
		filter: {
			StructType: `${CONFIG.PROOF_VERIFIER_CONTRACT.packageId}::${module}::${structType}`,
		},
		options: {
			showContent: true,
			showType: true,
		},
		owner: getActiveAddress(),
	});

	const formatted = res.data.map((x) => {
		return {
			objectId: x.data?.objectId,
			type: x.data?.type,
		};
	});

	return formatted;
};

function hexToNumberArray(hex: string): number[] {
    const h = hex.startsWith("0x") ? hex.slice(2) : hex;
    return Array.from(Buffer.from(h, "hex"));
}

const submitStateRoots = async (blockNumbers: string[]) => {
    let stateRoots: string[] = [];
    for (const blockNumber of blockNumbers) {
        // eth_getBlockByNumber (POST /:apiKey)
        const response = await fetch(`https://${process.env.ETH_NETWORK}.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({
                "jsonrpc": "2.0",
                "method": "eth_getBlockByNumber",
                "params": [
                    blockNumber,
                    false
                ],
                "id": 1
            }),
        });
        const body = await response.json();
        // console.log(body);
        stateRoots.push(body.result.stateRoot);
    }

	const txb = new Transaction();
    const stateRootAdminCap = await getOwnedObjects('state_root_registry', 'AdminCap');

    if (!stateRootAdminCap || !stateRootAdminCap[0]) throw new Error('State root admin cap not found');
    const stateRootAdminCapObjectId = stateRootAdminCap[0].objectId;
    const stateRootOracleObjectId = CONFIG.PROOF_VERIFIER_CONTRACT.stateRootOracleId;
    if (!stateRootAdminCapObjectId || !stateRootOracleObjectId) throw new Error('State root admin cap or oracle object id not found');

    const listOfBlockNumbers = blockNumbers.map((blockNumber) => BigInt(blockNumber));
    const listOfStateRoots = stateRoots.map((stateRoot) => hexToNumberArray(stateRoot));

    txb.moveCall({
        target: `${CONFIG.PROOF_VERIFIER_CONTRACT.packageId}::state_root_registry::submit_state_roots`,
        arguments: [
            txb.object(stateRootAdminCapObjectId),
            txb.object(stateRootOracleObjectId),
            txb.pure.vector('u64', listOfBlockNumbers),
            txb.pure.vector('vector<u8>', listOfStateRoots)
        ],
    });

    const res = await signAndExecute(txb, ACTIVE_NETWORK);

    if (!res.objectChanges || res.objectChanges.length === 0)
        throw new Error('Something went wrong while creating state roots.');

    console.log('Successfully created state roots.');
};

type Operator = 'GT' | 'GTE' | 'LT' | 'LTE' | 'EQ' | 'NEQ';

const OP_MAP: Record<Operator, number> = {
  GT: 0,
  GTE: 1,
  LT: 2,
  LTE: 3,
  EQ: 4,
  NEQ: 5,
};
const submitCommandWithEscrow = async (conditions: [account: string, operator: string, balance: string][], actionTarget: string, escrowCoinValue: string) => {
	const txb = new Transaction();
    const conditionTxOracleObjectId = CONFIG.PROOF_VERIFIER_CONTRACT.conditionTxOracleId;
    if (!conditionTxOracleObjectId) throw new Error('Condition tx oracle object id not found');


    const listOfConditionAccounts = conditions.map(([account, _, __]) => hexToNumberArray(account));
    const listOfConditionOperators = conditions.map(([_, operator, __]) => OP_MAP[operator as Operator]);
    const listOfConditionBalances = conditions.map(([_, __, balance]) => BigInt(balance));

    const escrowCoin = txb.splitCoins(txb.gas, [txb.pure.u64(escrowCoinValue)]);
    txb.moveCall({
        target: `${CONFIG.PROOF_VERIFIER_CONTRACT.packageId}::condition_tx_executor::submit_command_with_escrow`,
        arguments: [
            txb.object(conditionTxOracleObjectId),
            txb.pure.vector('vector<u8>', listOfConditionAccounts),
            txb.pure.vector('u8', listOfConditionOperators),
            txb.pure.vector('u256', listOfConditionBalances),
            txb.pure.address(actionTarget),
            escrowCoin,
        ],
    });

    const res = await signAndExecute(txb, ACTIVE_NETWORK);

    if (!res.objectChanges || res.objectChanges.length === 0)
        throw new Error('Something went wrong while submitting command with escrow.');

    console.log('Successfully submitted command with escrow.');
};

const verifyMPTProof = async (blockNumber: string, account: string) => {
    // eth_getProof (POST /:apiKey)
    const response = await fetch(`https://${process.env.ETH_NETWORK}.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            "jsonrpc": "2.0",
            "method": "eth_getProof",
            "params": [
                account,
                [
                    "0x0",
                    "0x1"
                ],
                blockNumber
            ],
            "id": 1
        }),
    });
    
    const body = await response.json();
    // console.log(body);


    const txb = new Transaction();
    const mptProofVerifierObjectId = CONFIG.PROOF_VERIFIER_CONTRACT.mptProofVerifierId;
    const stateRootOracleObjectId = CONFIG.PROOF_VERIFIER_CONTRACT.stateRootOracleId;
    const conditionTxOracleObjectId = CONFIG.PROOF_VERIFIER_CONTRACT.conditionTxOracleId;
    if (!mptProofVerifierObjectId || !stateRootOracleObjectId || !conditionTxOracleObjectId) throw new Error('MPT proof verifier, state root oracle or condition tx oracle object id not found');

    txb.moveCall({
        target: `${CONFIG.PROOF_VERIFIER_CONTRACT.packageId}::mpt_proof_verifier::verify_mpt_proof`,
        arguments: [
            txb.object(mptProofVerifierObjectId),
            txb.object(stateRootOracleObjectId),
            txb.object(conditionTxOracleObjectId),
            txb.pure.u64(BigInt(blockNumber)),
            txb.pure.vector('u8', hexToNumberArray(account)),
            txb.pure.vector('vector<u8>', body.result.accountProof.map((x: string) => hexToNumberArray(x))),
            txb.pure.u256(BigInt(body.result.nonce)),
            txb.pure.u256(BigInt(body.result.balance)),
            txb.pure.vector('u8', hexToNumberArray(body.result.storageHash)),
            txb.pure.vector('u8', hexToNumberArray(body.result.codeHash)),
        ],
    });

    const res = await signAndExecute(txb, ACTIVE_NETWORK);

    if (!res.objectChanges || res.objectChanges.length === 0)
        throw new Error('Something went wrong while verifying MPT proof.');

    console.log('Successfully verified MPT proof.');
}

const Condition1BlockNumber = '0x9a9a20';
const Condition1Account = '0xded4e253d606d27daee949b862e7a18645cda442';

const Condition2BlockNumber = '0x9a9b05';
const Condition2Account = '0xded4e253d606d27daee949b862e7a18645cda442';

const receiver = '0x08866b897d05fc1fc955248612f09e30f9684da753765272735df63a6490a8d9';
const escrowCoinValue = '123';

async function main() {
    await submitStateRoots([Condition1BlockNumber, Condition2BlockNumber]);

    await submitCommandWithEscrow(
        [
            [Condition1Account, 'LTE', '0xb1a2bc2ec50000'],
            [Condition2Account, 'GTE', '0x213b3b464cd0000'],
        ], receiver, escrowCoinValue
    );

    await verifyMPTProof(Condition1BlockNumber, Condition1Account);
    await verifyMPTProof(Condition2BlockNumber, Condition2Account);
}
main().catch(console.error);