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

    console.log('Submitting state roots...');
    console.log("Block numbers:", listOfBlockNumbers);
    
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

const deleteStateRoots = async (blockNumbers: string[]) => {
	const txb = new Transaction();
    const stateRootAdminCap = await getOwnedObjects('state_root_registry', 'AdminCap');

    if (!stateRootAdminCap || !stateRootAdminCap[0]) throw new Error('State root admin cap not found');
    const stateRootAdminCapObjectId = stateRootAdminCap[0].objectId;
    const stateRootOracleObjectId = CONFIG.PROOF_VERIFIER_CONTRACT.stateRootOracleId;
    if (!stateRootAdminCapObjectId || !stateRootOracleObjectId) throw new Error('State root admin cap or oracle object id not found');

    const listOfBlockNumbers = blockNumbers.map((blockNumber) => BigInt(blockNumber));

    console.log('Deleting state roots...');
    console.log("Block numbers:", listOfBlockNumbers);

    txb.moveCall({
        target: `${CONFIG.PROOF_VERIFIER_CONTRACT.packageId}::state_root_registry::delete_state_roots`,
        arguments: [
            txb.object(stateRootAdminCapObjectId),
            txb.object(stateRootOracleObjectId),
            txb.pure.vector('u64', listOfBlockNumbers),
        ],
    });

    const res = await signAndExecute(txb, ACTIVE_NETWORK);

    if (!res.objectChanges || res.objectChanges.length === 0)
        throw new Error('Something went wrong while deleting state roots.');

    console.log('Successfully deleted state roots.');
};

const getFinalizedBlockStateRoot = async (): Promise<[blockNumber: bigint, stateRoot: string]> => {
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
            "finalized",
            false
        ],
        "id": 1
        }),
    });
    
    const body = await response.json();
    console.log("Finalized block number:", body.result.number);
    return [BigInt(body.result.number), body.result.stateRoot];
}

const initializeStateRootRegistry = async (bufferSize: number): Promise<bigint> => {
    const [blockNumber, stateRoot]: [bigint, string] = await getFinalizedBlockStateRoot();
    const stateRoots: [blockNumber: bigint, stateRoot: string][] = [[blockNumber, stateRoot]];
    for (let i: bigint = blockNumber - 1n; i >= blockNumber - BigInt(bufferSize) + 1n; i -= 1n) {
        const response = await fetch(`https://${process.env.ETH_NETWORK}.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`, {
            method: "POST",
            headers: {
            "Content-Type": "application/json"
            },
            body: JSON.stringify({
            "jsonrpc": "2.0",
            "method": "eth_getBlockByNumber",
            "params": [
                "0x" + i.toString(16),
                false
            ],
            "id": 1
            }),
        });
        
        const body = await response.json();
        stateRoots.push([BigInt(body.result.number), body.result.stateRoot]);
    }
    await submitStateRoots(stateRoots.map(([blockNumber, stateRoot]) => [blockNumber.toString(), stateRoot]));
    return blockNumber;
}
const maxBigInt = (a: bigint, b: bigint) => (a > b ? a : b);
const minBigInt = (a: bigint, b: bigint) => (a < b ? a : b);
const updateStateRootRegistry = async (bufferSize: number, lastFinalizedBlockNumber: bigint): Promise<bigint> => {
    const [blockNumber, stateRoot]: [bigint, string] = await getFinalizedBlockStateRoot();
    if (blockNumber <= lastFinalizedBlockNumber) return lastFinalizedBlockNumber;
    const stateRootsToSubmit: [blockNumber: bigint, stateRoot: string][] = [[blockNumber, stateRoot]];
    for (let i: bigint = blockNumber - 1n; i >= maxBigInt(lastFinalizedBlockNumber, blockNumber - BigInt(bufferSize)) + 1n; i -= 1n) {
        const response = await fetch(`https://${process.env.ETH_NETWORK}.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`, {
            method: "POST",
            headers: {
            "Content-Type": "application/json"
            },
            body: JSON.stringify({
            "jsonrpc": "2.0",
            "method": "eth_getBlockByNumber",
            "params": [
                "0x" + i.toString(16),
                false
            ],
            "id": 1
            }),
        });
        
        const body = await response.json();
        stateRootsToSubmit.push([BigInt(body.result.number), body.result.stateRoot]);
    }
    await submitStateRoots(stateRootsToSubmit.map(([blockNumber, stateRoot]) => [blockNumber.toString(), stateRoot]));

    const blockNumbersToDelete: string[] = [];
    for (let i: bigint = minBigInt(lastFinalizedBlockNumber, blockNumber - BigInt(bufferSize)); i >= lastFinalizedBlockNumber - BigInt(bufferSize) + 1n; i -= 1n) {
        blockNumbersToDelete.push(i.toString());
    }
    await deleteStateRoots(blockNumbersToDelete);
    return blockNumber;
}

async function main() {
    const bufferSize = 32;
    let lastFinalizedBlockNumber = await initializeStateRootRegistry(bufferSize);
    while (true) {
        await new Promise(resolve => setTimeout(resolve, 30000));
        lastFinalizedBlockNumber = await updateStateRootRegistry(bufferSize, lastFinalizedBlockNumber);
    }
}
main().catch(console.error);