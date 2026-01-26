import { Container, Heading, Flex, TextField } from "@radix-ui/themes";
import { StateRootList } from "@/state_root/StateRootList.tsx";
import { useState } from "react";

export function StateRootsDashboard() {
  const [blockNumber, setBlockNumber] = useState("");

  return (
    <Container className="py-8">
      <Flex direction="column" gap="4">
        <Heading size="8">State Roots Dashboard</Heading>
        
        <Flex direction="column" gap="3">
          <Heading size="4">Filters</Heading>
          <TextField.Root
            placeholder="Filter by Block Number"
            value={blockNumber}
            onChange={(e) => setBlockNumber(e.target.value)}
          />
        </Flex>

        <StateRootList 
          params={{ blockNumber: blockNumber || undefined }} 
          enableSearch={false}
        />
      </Flex>
    </Container>
  );
}