// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { useInfiniteQuery } from "@tanstack/react-query";
import { CONSTANTS, QueryKey } from "@/constants";
import { InfiniteScrollArea } from "@/components/InfiniteScrollArea";
import { constructUrlSearchParams, getNextPageParam } from "@/utils/helpers";
import { ApiStateRootObject, StateRootListingQuery } from "@/types/types";
import { useState } from "react";
import { TextField } from "@radix-ui/themes";
import { StateRoot } from "./StateRoot";

/**
 * A component that fetches and displays a list of escrows.
 * It works by using the API to fetch them, and can be re-used with different
 * API params, as well as an optional search by escrow ID functionality.
 */
export function StateRootList({
    params,
    enableSearch,
}: {
    params: StateRootListingQuery;
    enableSearch?: boolean;
}) {
    const [stateRootId, setStateRootId] = useState("");

    const { data, fetchNextPage, hasNextPage, isLoading, isFetchingNextPage } =
        useInfiniteQuery({
            initialPageParam: null,
            queryKey: [QueryKey.StateRoots, params],
            queryFn: async ({ pageParam }) => {
                const data = await fetch(
                    CONSTANTS.apiEndpoint +
                    "state-roots" +
                    constructUrlSearchParams({
                        ...params,
                        ...(pageParam ? { cursor: pageParam as string } : {}),
                        ...(stateRootId ? { objectId: stateRootId } : {}),
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
                    placeholder="Search by state root id"
                    value={stateRootId}
                    onChange={(e) => setStateRootId(e.target.value)}
                />
            )}
            <InfiniteScrollArea
                loadMore={() => fetchNextPage()}
                hasNextPage={hasNextPage}
                loading={isFetchingNextPage || isLoading}
            >
                {data?.map((stateRoot: ApiStateRootObject) => (
                    <StateRoot key={stateRoot.blockNumber} stateRoot={stateRoot} />
                ))}
            </InfiniteScrollArea>
        </div>
    );
}