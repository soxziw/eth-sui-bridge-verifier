import { createBrowserRouter, Navigate } from "react-router-dom";

import { Root } from "@/routes/root";
import { StateRootsDashboard } from "@/routes/StateRootsDashboard";
import { ConditionTxsDashboard } from "@/routes/ConditionTxsDashboard";
import { MPTProofsDashboard } from "@/routes/MPTProofsDashboard";

export const router = createBrowserRouter([
  {
    path: "/",
    element: <Root />,
    children: [
      {
        path: "/",
        element: <Navigate to="condition-txs" replace />,
      },
      {
        path: "state-roots",
        element: <StateRootsDashboard />,
      },
      {
        path: "condition-txs",
        element: <ConditionTxsDashboard />,
      },
      {
        path: "mpt-proofs",
        element: <MPTProofsDashboard />,
      }
    ],
  },
]);