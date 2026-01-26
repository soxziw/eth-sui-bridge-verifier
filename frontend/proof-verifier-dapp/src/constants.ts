// You can choose a different env (e.g. using a .env file, or a predefined list)
/** @ts-ignore */
import proofVerifierContract from "../../../api/proof-verifier-contract.json";

export enum QueryKey {
  StateRoots = "state-roots",
  ConditionTxs = "condition-txs",
  MPTProofs = "mpt-proofs",
  GetOwnedObjects = "getOwnedObjects",
}

export const CONSTANTS = {
  proofVerifierContract: {
    ...proofVerifierContract,
  },
  apiEndpoint: "http://localhost:3000/",
};