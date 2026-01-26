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
}
main().catch(console.error);