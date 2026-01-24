// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
import { SuiEvent } from '@mysten/sui/client';
import { Prisma } from '@prisma/client';

import { prisma } from '../db.js';

type ConditionTxEvent = ConditionTxCreated;

type Condition = {
	account: string;
	operator: string;
	value: string;
};

type TxAction = {
	recipient: string;
	amount: string;
};

type ConditionTxCreated = {
	conditionTxId: string;
	conditions: Condition[];
	action: TxAction;
};

/**
 * Handles all events emitted by the `escrow` module.
 * Data is modelled in a way that allows writing to the db in any order (DESC or ASC) without
 * resulting in data inconsistencies.
 * We're constructing the updates to support multiple events involving a single record
 * as part of the same batch of events (but using a single write/record to the DB).
 * */
export const handleConditionTxsObjects = async (events: SuiEvent[], type: string) => {
	const updates: Record<string, Prisma.ConditionTxCreateInput> = {};

	for (const event of events) {
		if (!event.type.startsWith(type)) throw new Error('Invalid event module origin');
		const data = event.parsedJson as ConditionTxEvent;
		updates[data.conditionTxId].conditions = data.conditions;
		updates[data.conditionTxId].action = data.action;
	}

	//  As part of the demo and to avoid having external dependencies, we use SQLite as our database.
	// 	Prisma + SQLite does not support bulk insertion & conflict handling, so we have to insert these 1 by 1
	// 	(resulting in multiple round-trips to the database).
	//  Always use a single `bulkInsert` query with proper `onConflict` handling in production databases (e.g Postgres)
	const promises = Object.values(updates).map((update) =>
		prisma.conditionTx.upsert({
			where: {
				objectId: update.objectId,
			},
			create: update,
			update,
		}),
	);
	await Promise.all(promises);
};