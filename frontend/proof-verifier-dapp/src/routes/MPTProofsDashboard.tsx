import { Container, Heading, Flex, TextField } from "@radix-ui/themes";
import { MPTProofList } from "@/mpt_proof/MPTProofList.tsx";
import { useState } from "react";

export function MPTProofsDashboard() {
  const [blockNumber, setBlockNumber] = useState("");
  const [account, setAccount] = useState("");

  return (
    <Container className="py-8">
      <Flex direction="column" gap="4">
        <Heading size="8">MPT Proofs Dashboard</Heading>
        
        <Flex direction="column" gap="3">
          <Heading size="4">Filters</Heading>
          <TextField.Root
            placeholder="Filter by Block Number"
            value={blockNumber}
            onChange={(e) => setBlockNumber(e.target.value)}
          />
          <TextField.Root
            placeholder="Filter by Account"
            value={account}
            onChange={(e) => setAccount(e.target.value)}
          />
        </Flex>

        <MPTProofList 
          params={{ 
            blockNumber: blockNumber || undefined,
            account: account || undefined
          }} 
          enableSearch={false}
        />
      </Flex>
    </Container>
  );
}