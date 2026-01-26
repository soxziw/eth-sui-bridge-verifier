// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { useState } from "react";
import { Button, Dialog, Flex, TextField, Text, Select, IconButton } from "@radix-ui/themes";
import { PlusIcon, TrashIcon } from "@radix-ui/react-icons";
import { useTransactionExecution } from "@/hooks/useTransactionExecution";
import { createSubmitCommandTransaction, Condition, Operator } from "@/utils/transactions";
import toast from "react-hot-toast";

interface SubmitCommandDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function SubmitCommandDialog({ 
  open, 
  onOpenChange,
}: SubmitCommandDialogProps) {
  const [conditions, setConditions] = useState<Condition[]>([
    { account: "", operator: "EQ" as Operator, balance: "" },
  ]);
  const [actionTarget, setActionTarget] = useState("");
  const [escrowValue, setEscrowValue] = useState("");
  const [loading, setLoading] = useState(false);
  
  const executeTransaction = useTransactionExecution();

  const addCondition = () => {
    setConditions([
      ...conditions,
      { account: "", operator: "EQ" as Operator, balance: "" },
    ]);
  };

  const removeCondition = (index: number) => {
    if (conditions.length > 1) {
      setConditions(conditions.filter((_, i) => i !== index));
    }
  };

  const updateCondition = (
    index: number,
    field: keyof Condition,
    value: string
  ) => {
    const newConditions = [...conditions];
    newConditions[index] = { ...newConditions[index], [field]: value };
    setConditions(newConditions);
  };

  const handleSubmit = async () => {
    // Validation
    if (!actionTarget || !escrowValue) {
      toast.error("Please fill in all required fields");
      return;
    }

    const invalidCondition = conditions.find(
      (c) => !c.account || !c.balance
    );
    if (invalidCondition) {
      toast.error("Please fill in all condition fields");
      return;
    }

    setLoading(true);
    try {
      const txb = await createSubmitCommandTransaction(
        conditions,
        actionTarget,
        escrowValue,
      );
      await executeTransaction(txb);
      // Reset form
      setConditions([{ account: "", operator: "EQ" as Operator, balance: "" }]);
      setActionTarget("");
      setEscrowValue("");
      onOpenChange(false);
    } catch (error: any) {
      toast.error(`Failed to submit command: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Content style={{ maxWidth: 600, maxHeight: '90vh', overflow: 'auto' }}>
        <Dialog.Title>Submit Command with Escrow</Dialog.Title>
        <Dialog.Description size="2" mb="4">
          Submit conditions and action target with an escrow object.
        </Dialog.Description>

        <Flex direction="column" gap="4">
          {/* Conditions */}
          <div>
            <Flex justify="between" align="center" mb="2">
              <Text size="2" weight="bold">
                Conditions
              </Text>
              <Button size="1" variant="soft" onClick={addCondition}>
                <PlusIcon /> Add Condition
              </Button>
            </Flex>

            {conditions.map((condition, index) => (
              <Flex key={index} direction="column" gap="2" mb="3" className="p-3 border rounded">
                <Flex justify="between" align="center">
                  <Text size="2" weight="bold">Condition {index + 1}</Text>
                  {conditions.length > 1 && (
                    <IconButton
                      size="1"
                      variant="soft"
                      color="red"
                      onClick={() => removeCondition(index)}
                    >
                      <TrashIcon />
                    </IconButton>
                  )}
                </Flex>

                <label>
                  <Text as="div" size="1" mb="1">
                    Account Address *
                  </Text>
                  <TextField.Root
                    placeholder="e.g., 0x936ab482d6bd111910a42849d3a51ff80bb0a711"
                    value={condition.account}
                    onChange={(e) =>
                      updateCondition(index, "account", e.target.value)
                    }
                  />
                </label>

                <label>
                  <Text as="div" size="1" mb="1">
                    Operator *
                  </Text>
                  <Select.Root
                    value={condition.operator}
                    onValueChange={(value) =>
                      updateCondition(index, "operator", value)
                    }
                  >
                    <Select.Trigger />
                    <Select.Content>
                      <Select.Item value="EQ">Equal (EQ)</Select.Item>
                      <Select.Item value="NEQ">Not Equal (NEQ)</Select.Item>
                      <Select.Item value="GT">Greater Than (GT)</Select.Item>
                      <Select.Item value="GTE">Greater Than or Equal (GTE)</Select.Item>
                      <Select.Item value="LT">Less Than (LT)</Select.Item>
                      <Select.Item value="LTE">Less Than or Equal (LTE)</Select.Item>
                    </Select.Content>
                  </Select.Root>
                </label>

                <label>
                  <Text as="div" size="1" mb="1">
                    Balance *
                  </Text>
                  <TextField.Root
                    placeholder="e.g., 0x0 or 0x470de4df8200000"
                    value={condition.balance}
                    onChange={(e) =>
                      updateCondition(index, "balance", e.target.value)
                    }
                  />
                </label>
              </Flex>
            ))}
          </div>

          {/* Action Target */}
          <label>
            <Text as="div" size="2" mb="1" weight="bold">
              Action Target (Receiver Address) *
            </Text>
            <TextField.Root
              placeholder="e.g., 0x08866b897d05fc1fc955248612f09e30f9684da753765272735df63a6490a8d9"
              value={actionTarget}
              onChange={(e) => setActionTarget(e.target.value)}
            />
          </label>

          {/* Escrow Value */}
          <label>
            <Text as="div" size="2" mb="1" weight="bold">
              Escrow Value *
            </Text>
            <TextField.Root
              placeholder="e.g., 123"
              value={escrowValue}
              onChange={(e) => setEscrowValue(e.target.value)}
            />
          </label>
        </Flex>

        <Flex gap="3" mt="4" justify="end">
          <Dialog.Close>
            <Button variant="soft" color="gray">
              Cancel
            </Button>
          </Dialog.Close>
          <Button onClick={handleSubmit} disabled={loading}>
            {loading ? "Submitting..." : "Submit Command"}
          </Button>
        </Flex>
      </Dialog.Content>
    </Dialog.Root>
  );
}

