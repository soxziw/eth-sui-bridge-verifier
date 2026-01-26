import { useCurrentAccount, useSuiClientInfiniteQuery } from "@mysten/dapp-kit";
import { CONSTANTS } from "@/constants";

/**
 * A hook that fetches all the admin cap objects owned by the connected wallet address
 */
export function useConditionTxExecutorAdminCapObjects() {
    const account = useCurrentAccount();

    const { data } = useSuiClientInfiniteQuery(
            "getOwnedObjects",
            {
                filter: {
                    StructType: `${CONSTANTS.proofVerifierContract.packageId}::condition_tx_executor::AdminCap`,
                },
                owner: account?.address!,
                options: {
                    showDisplay: true,
                    showType: true,
                },
            },
            {
                enabled: !!account?.address,
            }
        );

    return (data?.pages.flatMap((page) => page.data).map((x) => {
        return {
            objectId: x.data?.objectId,
            type: x.data?.type,
        };
    })) || [];
}
