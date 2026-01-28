import { ConnectButton, useCurrentAccount } from "@mysten/dapp-kit";
import { SizeIcon, GearIcon } from "@radix-ui/react-icons";
import { Box, Container, Flex, Heading, Button, IconButton } from "@radix-ui/themes";
import { NavLink } from "react-router-dom";
import { useState } from "react";
import { SubmitCommandDialog } from "./SubmitCommandDialog";
import { SettingsDialog } from "./SettingsDialog";

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
  const [submitCommandOpen, setSubmitCommandOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  
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
          <IconButton
            variant="soft"
            color="gray"
            onClick={() => setSettingsOpen(true)}
            title="Settings"
          >
            <GearIcon width={18} height={18} />
          </IconButton>

          {account && (
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

      <SettingsDialog
        open={settingsOpen}
        onOpenChange={setSettingsOpen}
      />

      <SubmitCommandDialog
        open={submitCommandOpen}
        onOpenChange={setSubmitCommandOpen}
      />
    </Container>
  );
}