// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { publishPackage } from '../sui-utils.js';

/// A demo showing how we could publish the escrow contract
/// and our DEMO objects contract.
///
/// We're publishing both as part of our demo.
(async () => {
	await publishPackage({
		packagePath: __dirname + '/../../contracts/proof_verifier',
		network: 'testnet',
		exportFileName: 'proof-verifier-contract',
	});
})();