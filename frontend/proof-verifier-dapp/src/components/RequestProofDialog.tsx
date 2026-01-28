// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { useState } from "react";
import { Button, Dialog, Flex, TextField, Text, Select } from "@radix-ui/themes";
import { useTransactionExecution } from "@/hooks/useTransactionExecution";
import { createVerifyMPTProofTransaction } from "@/utils/transactions";
import toast from "react-hot-toast";

interface RequestProofDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  conditionTxId: string;
}

export function RequestProofDialog({ open, onOpenChange, conditionTxId }: RequestProofDialogProps) {
  const [blockNumber, setBlockNumber] = useState("");
  const [account, setAccount] = useState("");
  const [alchemyApiKey, setAlchemyApiKey] = useState("");
  const [ethNetwork, setEthNetwork] = useState("eth-sepolia");
  const [loading, setLoading] = useState(false);
  
  const executeTransaction = useTransactionExecution();

  const handleSubmit = async () => {
    if (!blockNumber || !account) {
      toast.error("Please fill in all required fields");
      return;
    }

    if (!alchemyApiKey) {
      toast.error("Please provide Alchemy API Key");
      return;
    }

    setLoading(true);
    try {
      const txb = await createVerifyMPTProofTransaction(
        conditionTxId,
        blockNumber,
        account,
        alchemyApiKey,
        ethNetwork
      );
      
      await executeTransaction(txb);
      
      // Reset form
      setBlockNumber("");
      setAccount("");
      onOpenChange(false);
    } catch (error: any) {
      toast.error(`Failed to verify proof: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Content style={{ maxWidth: 500 }}>
        <Dialog.Title>Request Proof Verification</Dialog.Title>
        <Dialog.Description size="2" mb="4">
          Submit a block number and account address to verify the MPT proof for this condition transaction.
        </Dialog.Description>
        
        <Flex direction="column" gap="1" mb="3">
          <Text size="1" weight="bold" color="gray">Condition Transaction ID:</Text>
          <Text size="1" className="font-mono break-all text-gray-600">{conditionTxId}</Text>
        </Flex>

        <Flex direction="column" gap="3">
          <label>
            <Text as="div" size="2" mb="1" weight="bold">
              Block Number *
            </Text>
            <TextField.Root
              placeholder="e.g., 0x172b8ce"
              value={blockNumber}
              onChange={(e) => setBlockNumber(e.target.value)}
            />
          </label>

          <label>
            <Text as="div" size="2" mb="1" weight="bold">
              Account Address *
            </Text>
            <TextField.Root
              placeholder="e.g., 0x936ab482d6bd111910a42849d3a51ff80bb0a711"
              value={account}
              onChange={(e) => setAccount(e.target.value)}
            />
          </label>

          <label>
            <Text as="div" size="2" mb="1" weight="bold">
              Alchemy API Key *
            </Text>
            <TextField.Root
              type="password"
              placeholder="Your Alchemy API Key"
              value={alchemyApiKey}
              onChange={(e) => setAlchemyApiKey(e.target.value)}
            />
          </label>

          <label>
            <Text as="div" size="2" mb="1" weight="bold">
              Ethereum Network
            </Text>
            <Select.Root
              value={ethNetwork}
              onValueChange={(value) => setEthNetwork(value)}
            >
              <Select.Trigger placeholder="Select Ethereum Network" />
              <Select.Content>
                <Select.Item value="eth-mainnet">Mainnet</Select.Item>
                <Select.Item value="eth-sepolia">Sepolia</Select.Item>
              </Select.Content>
            </Select.Root>
          </label>
        </Flex>

        <Flex gap="3" mt="4" justify="end">
          <Dialog.Close>
            <Button variant="soft" color="gray">
              Cancel
            </Button>
          </Dialog.Close>
          <Button onClick={handleSubmit} disabled={loading}>
            {loading ? "Submitting..." : "Verify Proof"}
          </Button>
        </Flex>
      </Dialog.Content>
    </Dialog.Root>
  );
}

