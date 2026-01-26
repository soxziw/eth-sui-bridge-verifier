module proof_verifier::condition_tx_executor {
    use std::string::String;
    use std::string;
    use sui::dynamic_object_field as dof;
    use sui::package;
    use sui::balance;
    use sui::coin;
    use sui::sui::SUI;
    use sui::event;
    use sui::hex;

    /// Define a capability for the admin of the oracle.
    public struct AdminCap has key, store { id: UID }

    /// // Define a one-time witness to create the `Publisher` of the oracle.
    public struct CONDITION_TX_EXECUTOR has drop {}

    public struct ConditionTxOracle has key {
        id: UID,
        address: address,
        next_condition_tx_id: u256,
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
        amount: u64,
    }

    public struct ConditionTx has copy, drop, store {
        id: u256,
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
            next_condition_tx_id: 0,
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

    fun emit_condition_tx_created(
        condition_tx: ConditionTx
    ) {
        event::emit(ConditionTxCreated {
            id: condition_tx.id,
            condition_account: string::utf8(hex::encode(condition_tx.list_of_conditions[0].account)),
            condition_operator: match (condition_tx.list_of_conditions[0].operator) {
                Operator::GT => string::utf8(b"GT"),
                Operator::GTE => string::utf8(b"GTE"),
                Operator::LT => string::utf8(b"LT"),
                Operator::LTE => string::utf8(b"LTE"),
                Operator::EQ => string::utf8(b"EQ"),
                Operator::NEQ => string::utf8(b"NEQ"),
            },
            condition_value: condition_tx.list_of_conditions[0].value,
            action_target: condition_tx.action.recipient,
            action_value: condition_tx.action.amount,
        });
    }

    fun emit_condition_tx_updated(
        condition_tx: ConditionTx
    ) {
        event::emit(ConditionTxUpdated {
            id: condition_tx.id,
            condition_account: string::utf8(hex::encode(condition_tx.list_of_conditions[0].account)),
            condition_operator: match (condition_tx.list_of_conditions[0].operator) {
                Operator::GT => string::utf8(b"GT"),
                Operator::GTE => string::utf8(b"GTE"),
                Operator::LT => string::utf8(b"LT"),
                Operator::LTE => string::utf8(b"LTE"),
                Operator::EQ => string::utf8(b"EQ"),
                Operator::NEQ => string::utf8(b"NEQ"),
            },
            condition_value: condition_tx.list_of_conditions[0].value,
        });
    }

    public fun submit_command_with_escrow(
        _: &AdminCap,
        oracle: &mut ConditionTxOracle,
        list_of_condition_accounts: vector<vector<u8>>,
        list_of_condition_operators: vector<u8>,
        list_of_condition_values: vector<u256>,
        action_target: address,
        action_escrow: coin::Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let length = vector::length(&list_of_condition_accounts);
        assert!(length == vector::length(&list_of_condition_operators), E_BAD_INPUT);
        assert!(length == vector::length(&list_of_condition_values), E_BAD_INPUT);
        assert!(length > 0, E_BAD_INPUT);

        let mut list_of_conditions = vector::empty<Condition>();
        let mut i: u64 = 0;
        while (i < length) {
            vector::push_back(&mut list_of_conditions, Condition {
                account: list_of_condition_accounts[i],
                operator: match (list_of_condition_operators[i]) {
                    0 => Operator::GT,
                    1 => Operator::GTE,
                    2 => Operator::LT,
                    3 => Operator::LTE,
                    4 => Operator::EQ,
                    5 => Operator::NEQ,
                    _ => abort E_BAD_INPUT,
                },
                value: list_of_condition_values[i],
            });
            i = i + 1;
        };

        let condition_tx = ConditionTx {
            id: oracle.next_condition_tx_id,
            list_of_conditions,
            action: TxAction { recipient: action_target, amount: coin::value(&action_escrow)},
        };
        oracle.next_condition_tx_id = oracle.next_condition_tx_id + 1;
        emit_condition_tx_created(condition_tx);
        push_condition_tx_to_oracle(oracle, condition_tx, ctx);
        balance::join(&mut oracle.vault, coin::into_balance(action_escrow));
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
                            transfer::public_transfer(coin::from_balance(balance::split(&mut oracle.vault, action.amount), ctx), action.recipient);
                            event::emit(ConditionTxCompleted {
                                id: condition_tx.id,
                            });
                        } else {
                            let mut new_list_of_conditions = vector::empty<Condition>();
                            let mut j: u64 = 1;
                            while (j < vector::length(&condition_tx.list_of_conditions)) {
                                vector::push_back(&mut new_list_of_conditions, condition_tx.list_of_conditions[j]);
                                j = j + 1;
                            };
                            let new_condition_tx = ConditionTx {
                                id: condition_tx.id,
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
                emit_condition_tx_updated(list_of_new_condition_tx[k]);
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

    public struct ConditionTxCreated has copy, drop {
        id: u256,
        condition_account: String,
        condition_operator: String,
        condition_value: u256,
        action_target: address,
        action_value: u64,
    }

    public struct ConditionTxUpdated has copy, drop {
        id: u256,
        condition_account: String,
        condition_operator: String,
        condition_value: u256,
    }

    public struct ConditionTxCompleted has copy, drop {
        id: u256,
    }

    #[test_only]
    public fun new_for_testing(ctx: &mut TxContext): (AdminCap, ConditionTxOracle) {
        let cap = AdminCap { id: object::new(ctx) };
        let oracle = ConditionTxOracle {
            id: object::new(ctx),
            address: ctx.sender(),
            next_condition_tx_id: 0,
            vault: balance::zero<SUI>(),
            name: b"ConditionTxOracle(test)".to_string(),
            description: b"test condition tx oracle".to_string(),
        };
        (cap, oracle)
    }

    #[test_only]
    public fun destroy_oracle_for_testing(oracle: ConditionTxOracle, ctx: &mut TxContext) {
        let ConditionTxOracle {
            id,
            address: _,
            next_condition_tx_id: _,
            vault: mut vault,
            name: _,
            description: _,
        } = oracle;
        let amount: u64 = balance::value(&vault);
        coin::burn_for_testing(coin::from_balance(balance::split(&mut vault, amount), ctx));
        balance::destroy_zero(vault);
        object::delete(id);
    }

    #[test_only]
    public fun destroy_admin_for_testing(cap: AdminCap) {
        let AdminCap { id } = cap;
        object::delete(id);
    }
}