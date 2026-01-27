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

const Condition1BlockNumber = '0x9a9a20';
const Condition2BlockNumber = '0x9a9b05';

async function main() {
    await submitStateRoots([Condition1BlockNumber, Condition2BlockNumber]);
}
main().catch(console.error);