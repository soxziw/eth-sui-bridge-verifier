// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import cors from 'cors';
import express from 'express';

import { prisma } from './db';
import {
	formatPaginatedResponse,
	parsePaginationForQuery,
	parseWhereStatement,
	WhereParam,
	WhereParamTypes,
} from './utils/api-queries';

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
	const acceptedQueries: WhereParam[] = [
		{
			key: 'nextConditionAccount',
			type: WhereParamTypes.STRING,
		},
        {
            key: 'actionTarget',
            type: WhereParamTypes.STRING,
        },
        {
            key: 'completed',
            type: WhereParamTypes.BOOLEAN,
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
			key: 'blockNumber',
			type: WhereParamTypes.STRING,
		},
		{
			key: 'account',
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