// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { useInfiniteQuery } from "@tanstack/react-query";
import { CONSTANTS, QueryKey } from "@/constants";
import { InfiniteScrollArea } from "@/components/InfiniteScrollArea";
import { constructUrlSearchParams, getNextPageParam } from "@/utils/helpers";
import { ApiConditionTxObject, ConditionTxListingQuery } from "@/types/types";
import { useState } from "react";
import { TextField } from "@radix-ui/themes";
import { ConditionTx } from "./ConditionTx";

/**
 * A component that fetches and displays a list of escrows.
 * It works by using the API to fetch them, and can be re-used with different
 * API params, as well as an optional search by escrow ID functionality.
 */
export function ConditionTxList({
  params,
  enableSearch,
}: {
  params: ConditionTxListingQuery;
  enableSearch?: boolean;
}) {
    const [conditionTxId, setConditionTxId] = useState("");
    const { data, fetchNextPage, hasNextPage, isLoading, isFetchingNextPage } =
        useInfiniteQuery({
            initialPageParam: null,
            queryKey: [QueryKey.ConditionTxs, params],
            queryFn: async ({ pageParam }) => {
                const data = await fetch(
                    CONSTANTS.apiEndpoint +
                    "condition-txs" +
                    constructUrlSearchParams({
                        ...params,
                        ...(pageParam ? { cursor: pageParam as string } : {}),
                        ...(conditionTxId ? { objectId: conditionTxId } : {}),
                    }),
                );
                return data.json();
            },
            select: (data) => data.pages.flatMap((page) => page.data),
            getNextPageParam,
        });

    return (
        <div>
            {enableSearch && (
                <TextField.Root
                    placeholder="Search by mpt proof id"
                    value={conditionTxId}
                    onChange={(e) => setConditionTxId(e.target.value)}
                />
            )}
            <InfiniteScrollArea
                loadMore={() => fetchNextPage()}
                hasNextPage={hasNextPage}
                loading={isFetchingNextPage || isLoading}
            >
                {data?.map((conditionTx: ApiConditionTxObject) => (
                    <ConditionTx key={conditionTx.objectId} conditionTx={conditionTx} />
                ))}
            </InfiniteScrollArea>
        </div>
    );
}