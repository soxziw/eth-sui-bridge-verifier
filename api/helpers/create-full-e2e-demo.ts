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

const submitStateRoots = async (stateRoots: [blockNumber: string, stateRoot: string][]) => {
	const txb = new Transaction();
    const stateRootAdminCap = await getOwnedObjects('state_root_registry', 'AdminCap');

    if (!stateRootAdminCap || !stateRootAdminCap[0]) throw new Error('State root admin cap not found');
    const stateRootAdminCapObjectId = stateRootAdminCap[0].objectId;
    const stateRootOracleObjectId = CONFIG.PROOF_VERIFIER_CONTRACT.stateRootOracleId;
    if (!stateRootAdminCapObjectId || !stateRootOracleObjectId) throw new Error('State root admin cap or oracle object id not found');

    const listOfBlockNumbers = stateRoots.map(([blockNumber, _]) => BigInt(blockNumber));
    const listOfStateRoots = stateRoots.map(([_, stateRoot]) => hexToNumberArray(stateRoot));

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
    const conditionTxAdminCap = await getOwnedObjects('condition_tx_executor', 'AdminCap');

    if (!conditionTxAdminCap || !conditionTxAdminCap[0]) throw new Error('Condition tx admin cap not found');
    const conditionTxAdminCapObjectId = conditionTxAdminCap[0].objectId;
    const conditionTxOracleObjectId = CONFIG.PROOF_VERIFIER_CONTRACT.conditionTxOracleId;
    if (!conditionTxAdminCapObjectId || !conditionTxOracleObjectId) throw new Error('Condition tx admin cap or oracle object id not found');


    const listOfConditionAccounts = conditions.map(([account, _, __]) => hexToNumberArray(account));
    const listOfConditionOperators = conditions.map(([_, operator, __]) => OP_MAP[operator as Operator]);
    const listOfConditionBalances = conditions.map(([_, __, balance]) => BigInt(balance));

    const escrowCoin = txb.splitCoins(txb.gas, [txb.pure.u64(escrowCoinValue)]);
    txb.moveCall({
        target: `${CONFIG.PROOF_VERIFIER_CONTRACT.packageId}::condition_tx_executor::submit_command_with_escrow`,
        arguments: [
            txb.object(conditionTxAdminCapObjectId),
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

const zeroBlockNumber = '0x172b8ce';
const zeroStateRoot = '0xcb07c9b25d3070b7567fe0f9d7d5cb7600d910a20adc307fd1897ad55139d07c';
const zeroAccount = '0x936ab482d6bd111910a42849d3a51ff80bb0a711';

const nonZeroBlockNumber = '0x17159f1';
const nonZeroStateRoot = '0xf2fbda72af80ff49713383cb988697dcfabc880832eb91fafbf7e79257846a25';
const nonZeroAccount = '0x6c8f2a135f6ed072de4503bd7c4999a1a17f824b';

const receiver = '0x08866b897d05fc1fc955248612f09e30f9684da753765272735df63a6490a8d9';
const escrowCoinValue = '123';

async function main() {
    await submitStateRoots([
        [zeroBlockNumber, zeroStateRoot],
        [nonZeroBlockNumber, nonZeroStateRoot],
    ]);

    await submitCommandWithEscrow(
        [
            [zeroAccount, 'EQ', '0x0'],
            [nonZeroAccount, 'GTE', '0x470de4df8200000'],
        ], receiver, escrowCoinValue
    );

    await verifyMPTProof(zeroBlockNumber, zeroAccount);
    await verifyMPTProof(nonZeroBlockNumber, nonZeroAccount);
}
main().catch(console.error);