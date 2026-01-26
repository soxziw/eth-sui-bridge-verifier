// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { Card, Flex, Text, Badge } from "@radix-ui/themes";
import { ApiStateRootObject } from "@/types/types";

export function StateRoot({ stateRoot }: { stateRoot: ApiStateRootObject }) {
  return (
    <Card className="mb-4">
      <Flex direction="column" gap="3">
        <Flex justify="between" align="center">
          <Text size="2" weight="bold">Block Number</Text>
          <Badge color="blue">{stateRoot.blockNumber}</Badge>
        </Flex>
        <Flex direction="column" gap="1">
          <Text size="2" weight="bold">State Root</Text>
          <Text size="1" className="break-all font-mono text-gray-600">
            {stateRoot.stateRoot}
          </Text>
        </Flex>
      </Flex>
    </Card>
  );
}

