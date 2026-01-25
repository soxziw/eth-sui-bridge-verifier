// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
import { SuiEvent } from '@mysten/sui/client';
import { Prisma } from '@prisma/client';

import { prisma } from '../db';

type StateRootEvent = StateRootCreatedOrUpdated | StateRootDeleted;

type StateRootCreatedOrUpdated = {
	block_number: string;
	stateRoot: string;
};

type StateRootDeleted = {
	block_number: string;
};

/**
 * Handles all events emitted by the `lock` module.
 * Data is modelled in a way that allows writing to the db in any order (DESC or ASC) without
 * resulting in data inconsistencies.
 * We're constructing the updates to support multiple events involving a single record
 * as part of the same batch of events (but using a single write/record to the DB).
 * */
export const handleStateRootObjects = async (events: SuiEvent[], type: string) => {
	const updates: Record<string, Prisma.StateRootCreateInput> = {};

	for (const event of events) {
		if (!event.type.startsWith(type)) throw new Error('Invalid event module origin');
		const data = event.parsedJson as StateRootEvent;
		const isDeletionEvent = !('stateRoot' in data);

		const blockNumberHex = "0x" + BigInt(data.block_number).toString(16);
		// Handle deletion
		if (isDeletionEvent) {
			delete updates[blockNumberHex];
			continue;
		}

		// Handle creation or update event
		if (updates[blockNumberHex]) {
			updates[blockNumberHex].stateRoot = data.stateRoot;
			continue;
		}
		updates[blockNumberHex] = {
			blockNumber: blockNumberHex,
			stateRoot: data.stateRoot,
		};
	}

	//  As part of the demo and to avoid having external dependencies, we use SQLite as our database.
	// 	Prisma + SQLite does not support bulk insertion & conflict handling, so we have to insert these 1 by 1
	// 	(resulting in multiple round-trips to the database).
	//  Always use a single `bulkInsert` query with proper `onConflict` handling in production databases (e.g Postgres)
	const promises = Object.values(updates).map((update) =>
		prisma.stateRoot.upsert({
			where: {
				blockNumber: update.blockNumber,
			},
			create: update,
			update,
		}),
	);
	await Promise.all(promises);
};