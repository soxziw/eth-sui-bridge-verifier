import { ConnectButton, useCurrentAccount } from "@mysten/dapp-kit";
import { SizeIcon } from "@radix-ui/react-icons";
import { Box, Container, Flex, Heading, Button } from "@radix-ui/themes";
import { NavLink } from "react-router-dom";
import { useState } from "react";
import { RequestProofDialog } from "./RequestProofDialog";
import { SubmitCommandDialog } from "./SubmitCommandDialog";
import { useConditionTxExecutorAdminCapObjects } from "@/admincap/AdminCapOwnedObjects";

const menu = [
  {
    title: "State Roots",
    link: "/state-roots",
  },
  {
    title: "Condition Txs",
    link: "/condition-txs",
  },
  {
    title: "MPT Proofs",
    link: "/mpt-proofs",
  },
];

export function Header() {
  const account = useCurrentAccount();
  const [requestProofOpen, setRequestProofOpen] = useState(false);
  const [submitCommandOpen, setSubmitCommandOpen] = useState(false);
  
  // Get admin cap objects if wallet is connected
  const adminCapObjects = useConditionTxExecutorAdminCapObjects();
  const hasAdminCap = adminCapObjects && adminCapObjects.length > 0;
  const adminCapObjectId = hasAdminCap ? adminCapObjects[0]?.objectId : undefined;

  return (
    <Container>
      <Flex
        position="sticky"
        px="4"
        py="2"
        justify="between"
        className="border-b flex flex-wrap gap-4"
      >
        <Box>
          <Heading className="flex items-center gap-3">
            <SizeIcon width={24} height={24} />
            Proof Verifier DApp
          </Heading>
        </Box>

        <Box className="flex gap-5 items-center">
          {menu.map((item) => (
            <NavLink
              key={item.link}
              to={item.link}
              className={({ isActive, isPending }) =>
                `cursor-pointer flex items-center gap-2 ${
                  isPending
                    ? "pending"
                    : isActive
                      ? "font-bold text-blue-600"
                      : ""
                }`
              }
            >
              {item.title}
            </NavLink>
          ))}
        </Box>

        <Box className="flex gap-3 items-center">
          <Button
            variant="soft"
            onClick={() => setRequestProofOpen(true)}
          >
            Request Proof
          </Button>

          {account && hasAdminCap && (
            <Button
              variant="solid"
              color="green"
              onClick={() => setSubmitCommandOpen(true)}
            >
              Submit Command
            </Button>
          )}

          <ConnectButton />
        </Box>
      </Flex>

      <RequestProofDialog
        open={requestProofOpen}
        onOpenChange={setRequestProofOpen}
      />

      <SubmitCommandDialog
        open={submitCommandOpen}
        onOpenChange={setSubmitCommandOpen}
        adminCapObjectId={adminCapObjectId}
      />
    </Container>
  );
}