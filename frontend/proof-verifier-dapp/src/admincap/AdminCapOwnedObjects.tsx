import { useCurrentAccount, useSuiClientInfiniteQuery } from "@mysten/dapp-kit";
import { SuiObjectDisplay } from "@/components/SuiObjectDisplay";
import { InfiniteScrollArea } from "@/components/InfiniteScrollArea";
import { CONSTANTS } from "@/constants";
/**
 * A component that fetches all the admin cap objects owned by the connected wallet address
 */
export function ConditionTxExecutorAdminCapObjects() {
    const account = useCurrentAccount();

    const { data, fetchNextPage, isFetchingNextPage, hasNextPage, refetch } =
        useSuiClientInfiniteQuery(
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
            }
        );

    return (data?.pages.flatMap((page) => page.data).map((x) => {
        return {
            objectId: x.data?.objectId,
            type: x.data?.type,
        };
    }));
}
