// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { useInfiniteQuery } from "@tanstack/react-query";
import { CONSTANTS, QueryKey } from "@/constants";
import { InfiniteScrollArea } from "@/components/InfiniteScrollArea";
import { constructUrlSearchParams, getNextPageParam } from "@/utils/helpers";
import { ApiMPTProofObject, MPTProofListingQuery } from "@/types/types";
import { useState } from "react";
import { TextField } from "@radix-ui/themes";

/**
 * A component that fetches and displays a list of escrows.
 * It works by using the API to fetch them, and can be re-used with different
 * API params, as well as an optional search by escrow ID functionality.
 */
export function MPTProofList({
    params,
    enableSearch,
}: {
    params: MPTProofListingQuery;
    enableSearch?: boolean;
}) {
    const [mptProofId, setMPTProofId] = useState("");

    const { data, fetchNextPage, hasNextPage, isLoading, isFetchingNextPage } =
        useInfiniteQuery({
            initialPageParam: null,
            queryKey: [QueryKey.MPTProofs, params],
            queryFn: async ({ pageParam }) => {
                const data = await fetch(
                    CONSTANTS.apiEndpoint +
                    "mpt-proofs" +
                    constructUrlSearchParams({
                        ...params,
                        ...(pageParam ? { cursor: pageParam as string } : {}),
                        ...(mptProofId ? { objectId: mptProofId } : {}),
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
                    value={mptProofId}
                    onChange={(e) => setMPTProofId(e.target.value)}
                />
            )}
            <InfiniteScrollArea
                loadMore={() => fetchNextPage()}
                hasNextPage={hasNextPage}
                loading={isFetchingNextPage || isLoading}
            >
                {data?.map((mptProof: ApiMPTProofObject) => (
                    <MPTProof key={mptProof.objectId} mptProof={mptProof} />
                ))}
            </InfiniteScrollArea>
        </div>
    );
}