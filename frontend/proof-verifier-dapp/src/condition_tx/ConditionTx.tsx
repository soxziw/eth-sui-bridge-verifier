// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { useState } from "react";
import { Card, Flex, Text, Badge, Button } from "@radix-ui/themes";
import { ApiConditionTxObject } from "@/types/types";
import { RequestProofDialog } from "@/components/RequestProofDialog";
import { useCurrentAccount } from "@mysten/dapp-kit";

export function ConditionTx({ conditionTx }: { conditionTx: ApiConditionTxObject }) {
  const account = useCurrentAccount();
  const [dialogOpen, setDialogOpen] = useState(false);

  return (
    <>
      <Card className="mb-4">
        <Flex direction="column" gap="3">
          <Flex justify="between" align="center">
            <Text size="2" weight="bold">Object ID</Text>
            <Text size="1" className="break-all font-mono text-gray-600">
              {conditionTx.objectId}
            </Text>
          </Flex>
          <Flex direction="column" gap="1">
            <Text size="2" weight="bold">Condition</Text>
            <Text size="1" className="break-all font-mono text-gray-600">
              {conditionTx.condition}
            </Text>
          </Flex>
          <Flex direction="column" gap="1">
            <Text size="2" weight="bold">Action</Text>
            <Text size="1" className="break-all font-mono text-gray-600">
              {conditionTx.action}
            </Text>
          </Flex>
          <Flex justify="between" align="center">
            <Text size="2" weight="bold">Status</Text>
            <Badge color={conditionTx.completed ? "green" : "orange"}>
              {conditionTx.completed ? "Completed" : "Pending"}
            </Badge>
          </Flex>
          <Flex justify="end" mt="2">
            <Button 
              onClick={() => setDialogOpen(true)}
              disabled={conditionTx.completed || !account || conditionTx.actionTarget !== account.address}
            >
              Submit Proof
            </Button>
          </Flex>
        </Flex>
      </Card>
      
      <RequestProofDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        conditionTxId={conditionTx.objectId}
      />
    </>
  );
}

