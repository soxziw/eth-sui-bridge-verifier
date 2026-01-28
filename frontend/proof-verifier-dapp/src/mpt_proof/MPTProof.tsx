// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { Card, Flex, Text, Badge } from "@radix-ui/themes";
import { ApiMPTProofObject } from "@/types/types";

export function MPTProof({ mptProof }: { mptProof: ApiMPTProofObject }) {
  return (
    <Card className="mb-4">
      <Flex direction="column" gap="3">
        <Flex justify="between" align="center">
          <Text size="2" weight="bold">Object ID</Text>
          <Text size="1" className="break-all font-mono text-gray-600">
            {mptProof.objectId}
          </Text>
        </Flex>
        <Flex justify="between" align="center">
          <Text size="2" weight="bold">Condition Tx ID</Text>
          <Text size="1" className="break-all font-mono text-gray-600">
            {mptProof.conditionTxId}
          </Text>
        </Flex>
        <Flex justify="between" align="center">
          <Text size="2" weight="bold">Block Number</Text>
          <Badge color="blue">{mptProof.blockNumber}</Badge>
        </Flex>
        <Flex direction="column" gap="1">
          <Text size="2" weight="bold">Account</Text>
          <Text size="1" className="break-all font-mono text-gray-600">
            {mptProof.account}
          </Text>
        </Flex>
        <Flex direction="column" gap="1">
          <Text size="2" weight="bold">Balance</Text>
          <Text size="2" className="font-mono text-green-600">
            {mptProof.balance}
          </Text>
        </Flex>
      </Flex>
    </Card>
  );
}

