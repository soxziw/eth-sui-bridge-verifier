// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { useState, useEffect } from "react";
import { Button, Dialog, Flex, TextField, Text, Select } from "@radix-ui/themes";
import toast from "react-hot-toast";

interface SettingsDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

const STORAGE_KEY_ALCHEMY_API_KEY = "alchemy_api_key";
const STORAGE_KEY_ETH_NETWORK = "eth_network";

export function SettingsDialog({ open, onOpenChange }: SettingsDialogProps) {
  const [alchemyApiKey, setAlchemyApiKey] = useState("");
  const [ethNetwork, setEthNetwork] = useState("eth-sepolia");

  useEffect(() => {
    // Load saved settings from localStorage
    const savedApiKey = localStorage.getItem(STORAGE_KEY_ALCHEMY_API_KEY);
    const savedNetwork = localStorage.getItem(STORAGE_KEY_ETH_NETWORK);
    
    if (savedApiKey) {
      setAlchemyApiKey(savedApiKey);
    }
    if (savedNetwork) {
      setEthNetwork(savedNetwork);
    }
  }, [open]);

  const handleSave = () => {
    if (!alchemyApiKey) {
      toast.error("Please provide Alchemy API Key");
      return;
    }

    // Save to localStorage
    localStorage.setItem(STORAGE_KEY_ALCHEMY_API_KEY, alchemyApiKey);
    localStorage.setItem(STORAGE_KEY_ETH_NETWORK, ethNetwork);
    
    toast.success("Settings saved successfully");
    onOpenChange(false);
  };

  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Content style={{ maxWidth: 450 }}>
        <Dialog.Title>Settings</Dialog.Title>
        <Dialog.Description size="2" mb="4">
          Configure your Alchemy API key and Ethereum network settings.
        </Dialog.Description>

        <Flex direction="column" gap="3">
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
          <Button onClick={handleSave}>
            Save Settings
          </Button>
        </Flex>
      </Dialog.Content>
    </Dialog.Root>
  );
}

// Helper functions to get settings from localStorage
export function getAlchemyApiKey(): string {
  return localStorage.getItem(STORAGE_KEY_ALCHEMY_API_KEY) || "";
}

export function getEthNetwork(): string {
  return localStorage.getItem(STORAGE_KEY_ETH_NETWORK) || "eth-sepolia";
}

