// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import cors from 'cors';
import express from 'express';

import { prisma } from './db.js';
import {
	formatPaginatedResponse,
	parsePaginationForQuery,
	parseWhereStatement,
	WhereParam,
	WhereParamTypes,
} from './utils/api-queries.js';

const app = express();
app.use(cors());

app.use(express.json());

app.get('/', async (req, res) => {
	return res.send({ message: '🚀 API is functional 🚀' });
});

app.get('/state-roots', async (req, res) => {
	const acceptedQueries: WhereParam[] = [
		{
			key: 'blockNumber',
			type: WhereParamTypes.STRING,
		},
        {
            key: 'stateRoot',
            type: WhereParamTypes.STRING,
        }
	];

	try {
		const stateRoots = await prisma.stateRoot.findMany({
			where: parseWhereStatement(req.query, acceptedQueries)!,
			...parsePaginationForQuery(req.query),
		});

		return res.send(formatPaginatedResponse(stateRoots));
	} catch (e) {
		console.error(e);
		return res.status(400).send(e);
	}
});

app.get('/condition-txs', async (req, res) => {
    const acceptedConditions: WhereParam[] = [
        {
            key: 'account',
            type: WhereParamTypes.STRING,
        },
        {
            key: 'operator',
            type: WhereParamTypes.STRING,
        },
        {
            key: 'value',
            type: WhereParamTypes.STRING,
        },
    ];
    const acceptedAction: WhereParam[] = [
        {
            key: 'recipient',
            type: WhereParamTypes.STRING,
        },
        {
            key: 'amount',
            type: WhereParamTypes.STRING,
        },
    ];
	const acceptedQueries: WhereParam[] = [
		{
			key: 'conditionTxId',
			type: WhereParamTypes.STRING,
		},
        {
            key: 'conditions',
            type: WhereParamTypes.JSON,
        },
        {
            key: 'action',
            type: WhereParamTypes.JSON,
        },
	];

	try {
		const conditionTxs = await prisma.conditionTx.findMany({
			where: parseWhereStatement(req.query, acceptedQueries)!,
			...parsePaginationForQuery(req.query),
		});

		return res.send(formatPaginatedResponse(conditionTxs));
	} catch (e) {
		console.error(e);
		return res.status(400).send(e);
	}
});

app.get('/mpt-proofs', async (req, res) => {
	const acceptedQueries: WhereParam[] = [
		{
			key: 'objectId',
			type: WhereParamTypes.STRING,
		},
	];

	try {
		const mptProofs = await prisma.mPTProof.findMany({
			where: parseWhereStatement(req.query, acceptedQueries)!,
			...parsePaginationForQuery(req.query),
		});

		return res.send(formatPaginatedResponse(mptProofs));
	} catch (e) {
		console.error(e);
		return res.status(400).send(e);
	}
});
app.listen(3000, () => console.log(`🚀 Server ready at: http://localhost:3000`));