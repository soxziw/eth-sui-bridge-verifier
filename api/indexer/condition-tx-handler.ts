// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
import { SuiEvent } from '@mysten/sui/client';
import { Prisma } from '@prisma/client';

import { prisma } from '../db';

type ConditionTxEvent = ConditionTxCreated | ConditionTxUpdated | ConditionTxCompleted;

type ConditionTxCreated = {
	id: string;
	after_block_number: string;
	condition_account: string;
	condition_operator: string;
	condition_value: string;
	action_target: string;
	action_value: string;
};

type ConditionTxUpdated = {
	id: string;
	after_block_number: string;
	condition_account: string;
	condition_operator: string;
	condition_value: string;
};

type ConditionTxCompleted = {
	id: string;
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
		const isCreationEvent = 'action_target' in data;
		const isCompletionEvent = !('condition_account' in data);

		if (isCreationEvent) {
			updates[data.id] = {
				objectId: data.id,
				condition: "After block 0x" + BigInt(data.after_block_number).toString(16) + ", 0x" + data.condition_account + ".balance " + data.condition_operator + " " + "0x" + BigInt(data.condition_value).toString(16) + " Wei",
				action: "Transfer " + data.action_value + " MIST to " + data.action_target,
				nextConditionAccount: "0x" + data.condition_account,
				actionTarget: data.action_target,
			};
			continue;
		}

		let existing = updates[data.id];
		if (!existing) {
			const dbRow = await prisma.conditionTx.findUnique({
				where: { objectId: String(data.id) },
			});
			if (dbRow) {
				existing = updates[data.id] = {
					objectId: dbRow.objectId,
					condition: dbRow.condition,
					action: dbRow.action,
					nextConditionAccount: dbRow.nextConditionAccount,
					actionTarget: dbRow.actionTarget,
				};
			} else {
				throw new Error('Condition tx not found: ' + data.id);
			}
		}
		if (isCompletionEvent) {
			existing.completed = true;
			existing.condition = "";
			existing.nextConditionAccount = "";
			continue;
		}

		existing.condition = "After block 0x" + BigInt(data.after_block_number).toString(16) + ", 0x" + data.condition_account + ".balance " + data.condition_operator + " " + "0x" + BigInt(data.condition_value).toString(16);
		existing.nextConditionAccount = "0x" + data.condition_account;
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