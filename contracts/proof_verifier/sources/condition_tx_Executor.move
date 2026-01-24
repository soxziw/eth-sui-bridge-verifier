module proof_verifier::condition_tx_executor {
    use std::string::String;
    use sui::dynamic_object_field as dof;
    use sui::package;
    use sui::balance;
    use sui::coin;
    use sui::sui::SUI;

    /// Define a capability for the admin of the oracle.
    public struct AdminCap has key, store { id: UID }

    /// // Define a one-time witness to create the `Publisher` of the oracle.
    public struct CONDITION_TX_EXECUTOR has drop {}

    public struct ConditionTxOracle has key {
        id: UID,
        address: address,
        vault: balance::Balance<SUI>,
        name: String,
        description: String,
    }

    const E_BAD_INPUT: u64 = 1;
    const E_NO_COMMAND: u64 = 2;

    public enum Operator has copy, drop, store {
        GT,
        GTE,
        LT,
        LTE,
        EQ,
        NEQ
    }

    public struct Condition has copy, drop, store {
        account: vector<u8>,
        operator: Operator,
        value: u256,
    }

    public struct TxAction has copy, drop, store {
        recipient: address,
        amount: u256,
    }

    public struct ConditionTx has copy, drop, store {
        list_of_conditions: vector<Condition>,
        action: TxAction,
    }

    public struct AccountConditionTxOracle has key, store {
        id: UID,
        account: vector<u8>,
        list_of_condition_tx: vector<ConditionTx>,
    }

    fun init(otw: CONDITION_TX_EXECUTOR, ctx: &mut TxContext) {
        package::claim_and_keep(otw, ctx); // Claim ownership of the one-time witness and keep it

        let admin_cap = AdminCap { id: object::new(ctx) }; // Create a new admin capability object
        transfer::share_object(ConditionTxOracle {
            id: object::new(ctx),
            address: ctx.sender(),
            vault: balance::zero<SUI>(),
            name: b"ConditionTxOracle".to_string(),
            description: b"A condition tx oracle.".to_string(),
        });
        transfer::public_transfer(admin_cap, ctx.sender()); // Transfer the admin capability to the sender.
    }

    fun push_condition_tx_to_oracle(
        oracle: &mut ConditionTxOracle,
        condition_tx: ConditionTx,
        ctx: &mut TxContext
    ) {
        if (!dof::exists_with_type<vector<u8>, AccountConditionTxOracle>(&oracle.id, condition_tx.list_of_conditions[0].account)) {
            dof::add(&mut oracle.id, condition_tx.list_of_conditions[0].account, AccountConditionTxOracle {
                id: object::new(ctx),
                account: condition_tx.list_of_conditions[0].account,
                list_of_condition_tx: vector::empty<ConditionTx>(),
            });
        };
        let account_condition_tx_oracle = dof::borrow_mut<vector<u8>, AccountConditionTxOracle>(&mut oracle.id, condition_tx.list_of_conditions[0].account);
        vector::push_back(&mut account_condition_tx_oracle.list_of_condition_tx, condition_tx);
    }

    public fun submit_command_with_escrow(
        _: &AdminCap,
        oracle: &mut ConditionTxOracle,
        list_of_condition_accounts: vector<vector<u8>>,
        list_of_condition_operators: vector<Operator>,
        list_of_condition_values: vector<u256>,
        actionTarget: address,
        actionValue: u256,
        escrow: coin::Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let length = vector::length(&list_of_condition_accounts);
        assert!(length == vector::length(&list_of_condition_operators), E_BAD_INPUT);
        assert!(length == vector::length(&list_of_condition_values), E_BAD_INPUT);
        assert!(length > 0, E_BAD_INPUT);
        assert!((coin::value(&escrow) as u256) == actionValue, E_BAD_INPUT);

        let mut list_of_conditions = vector::empty<Condition>();
        let mut i: u64 = 0;
        while (i < length) {
            vector::push_back(&mut list_of_conditions, Condition {
                account: list_of_condition_accounts[i],
                operator: list_of_condition_operators[i],
                value: list_of_condition_values[i],
            });
            i = i + 1;
        };

        let condition_tx = ConditionTx {
            list_of_conditions,
            action: TxAction { recipient: actionTarget, amount: actionValue },
        };
        push_condition_tx_to_oracle(oracle, condition_tx, ctx);
        balance::join(&mut oracle.vault, coin::into_balance(escrow));
    }

    fun meets_condition(
        balance: u256,
        condition: &Condition
    ): bool {
        match (&condition.operator) {
            Operator::GT => balance > condition.value,
            Operator::GTE => balance >= condition.value,
            Operator::LT => balance < condition.value,
            Operator::LTE => balance <= condition.value,
            Operator::EQ => balance == condition.value,
            Operator::NEQ => balance != condition.value,
        }
    }

    public(package) fun submit_verified_account(
        oracle: &mut ConditionTxOracle,
        account: vector<u8>,
        balance: u256,
        ctx: &mut TxContext
    ) {
        if (dof::exists_with_type<vector<u8>, AccountConditionTxOracle>(&oracle.id, account)) {
            let mut list_of_condition_met = vector::empty<bool>();
            let mut list_of_new_condition_tx = vector::empty<ConditionTx>();
            {
                let account_condition_tx_oracle = dof::borrow<vector<u8>, AccountConditionTxOracle>(&oracle.id, account);
                let mut i: u64 = 0;
                while (i < vector::length(&account_condition_tx_oracle.list_of_condition_tx)) {
                    let condition_tx = account_condition_tx_oracle.list_of_condition_tx[i];
                    let condition = condition_tx.list_of_conditions[0];
                    let condition_met = meets_condition(balance, &condition);
                    if (condition_met) {
                        if (vector::length(&condition_tx.list_of_conditions) == 1) {
                            let action = condition_tx.action;
                            transfer::public_transfer(coin::from_balance(balance::split(&mut oracle.vault, action.amount as u64), ctx), action.recipient); 
                        } else {
                            let mut new_list_of_conditions = vector::empty<Condition>();
                            let mut j: u64 = 1;
                            while (j < vector::length(&condition_tx.list_of_conditions)) {
                                vector::push_back(&mut new_list_of_conditions, condition_tx.list_of_conditions[j]);
                                j = j + 1;
                            };
                            let new_condition_tx = ConditionTx {
                                list_of_conditions: new_list_of_conditions,
                                action: condition_tx.action,
                            };
                            vector::push_back(&mut list_of_new_condition_tx, new_condition_tx);
                        }
                    };
                    vector::push_back(&mut list_of_condition_met, condition_met);
                    i = i + 1;
                };
            };

            let mut k = 0;
            while (k < vector::length(&list_of_new_condition_tx)) {
                push_condition_tx_to_oracle(oracle, list_of_new_condition_tx[k], ctx);
                k = k + 1;
            };

            let mut new_list_of_condition_tx = vector::empty<ConditionTx>();
            {
                let account_condition_tx_oracle = dof::borrow<vector<u8>, AccountConditionTxOracle>(&oracle.id, account);
                let mut l = vector::length(&list_of_condition_met);
                while (l < vector::length(&account_condition_tx_oracle.list_of_condition_tx)) {
                    vector::push_back(&mut list_of_condition_met, false);
                    l = l + 1;
                };

                let mut m: u64 = 0;
                while (m < vector::length(&account_condition_tx_oracle.list_of_condition_tx)) {
                    if (!list_of_condition_met[m]) {
                        vector::push_back(&mut new_list_of_condition_tx, account_condition_tx_oracle.list_of_condition_tx[m]);
                    };
                    m = m + 1;
                };
            };

            if (vector::length(&new_list_of_condition_tx) == 0) {
                let AccountConditionTxOracle {
                    id,
                    account: _,
                    list_of_condition_tx: _,
                } = dof::remove(&mut oracle.id, account);
                object::delete(id);
            } else {
                let account_condition_tx_oracle_mut = dof::borrow_mut<vector<u8>, AccountConditionTxOracle>(&mut oracle.id, account);
                account_condition_tx_oracle_mut.list_of_condition_tx = new_list_of_condition_tx;
            }
        } else {
            abort E_NO_COMMAND
        }
    }
}