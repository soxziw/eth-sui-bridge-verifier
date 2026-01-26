import { Container, Heading, Flex, TextField, Select } from "@radix-ui/themes";
import { ConditionTxList } from "@/condition_tx/ConditionTxList.tsx";
import { useState } from "react";

export function ConditionTxsDashboard() {
  const [nextConditionAccount, setNextConditionAccount] = useState("");
  const [actionTarget, setActionTarget] = useState("");
  const [completed, setCompleted] = useState<boolean | undefined>(undefined);

  return (
    <Container className="py-8">
      <Flex direction="column" gap="4">
        <Heading size="8">Condition Transactions Dashboard</Heading>
        
        <Flex direction="column" gap="3">
          <Heading size="4">Filters</Heading>
          <TextField.Root
            placeholder="Filter by Next Condition Account"
            value={nextConditionAccount}
            onChange={(e) => setNextConditionAccount(e.target.value)}
          />
          <TextField.Root
            placeholder="Filter by Action Target"
            value={actionTarget}
            onChange={(e) => setActionTarget(e.target.value)}
          />
          <Select.Root
            value={completed === undefined ? "all" : completed ? "true" : "false"}
            onValueChange={(value) => 
              setCompleted(value === "all" ? undefined : value === "true")
            }
          >
            <Select.Trigger placeholder="Filter by Status" />
            <Select.Content>
              <Select.Item value="all">All</Select.Item>
              <Select.Item value="true">Completed</Select.Item>
              <Select.Item value="false">Pending</Select.Item>
            </Select.Content>
          </Select.Root>
        </Flex>

        <ConditionTxList 
          params={{ 
            nextConditionAccount: nextConditionAccount || undefined,
            actionTarget: actionTarget || undefined,
            completed
          }} 
          enableSearch={false}
        />
      </Flex>
    </Container>
  );
}