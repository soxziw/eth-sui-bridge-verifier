// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

function hexToNumberArray(hex: string): number[] {
    const h = hex.startsWith("0x") ? hex.slice(2) : hex;
    return Array.from(Buffer.from(h, "hex"));
}

const submitStateRoots = async (stateRoots: [blockNumber: string, stateRoot: string][]) => {
    const listOfBlockNumbers = stateRoots.map(([blockNumber, _]) => BigInt(blockNumber));
    const listOfStateRoots = stateRoots.map(([_, stateRoot]) => hexToNumberArray(stateRoot));

    console.log("submitStateRoots: ");
    console.log("listOfBlockNumbers: ", listOfBlockNumbers);
    console.log("listOfStateRoots: ", listOfStateRoots);
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
const submitCommandWithEscrow = async (conditions: [account: string, operator: string, balance: string][], actionTarget: string, escrowCoinObjectId: string) => {
    const listOfConditionAccounts = conditions.map(([account, _, __]) => hexToNumberArray(account));
    const listOfConditionOperators = conditions.map(([_, operator, __]) => OP_MAP[operator as Operator]);
    const listOfConditionBalances = conditions.map(([_, __, balance]) => BigInt(balance));

    console.log("submitCommandWithEscrow: ");
    console.log("listOfConditionAccounts: ", listOfConditionAccounts);
    console.log("listOfConditionOperators: ", listOfConditionOperators);
    console.log("listOfConditionBalances: ", listOfConditionBalances);
    console.log("actionTarget: ", actionTarget);
    console.log("escrowCoinObjectId: ", escrowCoinObjectId);
};

const verifyMPTProof = async (blockNumber: string, account: string) => {
    // eth_getProof (POST /:apiKey)
    const response = await fetch("https://eth-mainnet.g.alchemy.com/v2/SZIIYGbKh3CuqTLZDlBNh", {
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
    console.log(body);


    console.log("verifyMPTProof: ");
    console.log("blockNumber: ", BigInt(blockNumber));
    console.log("account: ", hexToNumberArray(account));
    console.log("proof: ", body.result.accountProof.map((x: string) => hexToNumberArray(x)));
    console.log("nonce: ", BigInt(body.result.nonce));
    console.log("balance: ", BigInt(body.result.balance));
    console.log("storageHash: ", hexToNumberArray(body.result.storageHash));
    console.log("codeHash: ", hexToNumberArray(body.result.codeHash));
}

const zeroBlockNumber = '0x172b8ce';
const zeroStateRoot = '0xcb07c9b25d3070b7567fe0f9d7d5cb7600d910a20adc307fd1897ad55139d07c';
const zeroAccount = '0x936ab482d6bd111910a42849d3a51ff80bb0a711';

const nonZeroBlockNumber = '0x17159f1';
const nonZeroStateRoot = '0xf2fbda72af80ff49713383cb988697dcfabc880832eb91fafbf7e79257846a25';
const nonZeroAccount = '0x6c8f2a135f6ed072de4503bd7c4999a1a17f824b';

const receiver = '0x08866b897d05fc1fc955248612f09e30f9684da753765272735df63a6490a8d9';
const escrowCoinObjectId = '0x578b9396e6bb6e1742c75f83e12386b68b337486a48ed58d273cb58f443e5335';

async function main() {
    await submitStateRoots([
        [zeroBlockNumber, zeroStateRoot],
        [nonZeroBlockNumber, nonZeroStateRoot],
    ]);

    await submitCommandWithEscrow(
        [
            [zeroAccount, 'EQ', '0x0'],
            [nonZeroAccount, 'GTE', '0x470de4df8200000'],
        ], receiver, escrowCoinObjectId
    );

    await verifyMPTProof(zeroBlockNumber, zeroAccount);
    await verifyMPTProof(nonZeroBlockNumber, nonZeroAccount);
}
main().catch(console.error);