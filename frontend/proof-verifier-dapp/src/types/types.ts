export type ApiStateRootObject = {
    id?: string;
    blockNumber: string;
    stateRoot: string;
};

export type ApiConditionTxObject = {
    id?: string;
    objectId: string;
    condition: string;
    action: string;
    nextConditionAccount: string;
    actionTarget: string;
    completed: boolean;
};

export type ApiMPTProofObject = {
    id?: string;
    objectId: string;
    conditionTxId: string;
    blockNumber: string;
    account: string;
    balance: string;
};

export type StateRootListingQuery = {
    blockNumber?: string;
};

export type ConditionTxListingQuery = {
    nextConditionAccount?: string;
    actionTarget?: string;
    completed?: boolean;
};

export type MPTProofListingQuery = {
    conditionTxId?: string;
    blockNumber?: string;
    account?: string;
};