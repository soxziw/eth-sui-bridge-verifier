module proof_verifier::condition_tx_executor {
    use std::string::String;
    use std::string;
    use std::u256;
    use sui::dynamic_object_field as dof;
    use sui::package;
    use sui::balance;
    use sui::coin;
    use sui::sui::SUI;
    use sui::event;
    use sui::hex;

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
        NEQ,
        FI, // Full transfer initial
        FS, // Full transfer set
        PI, // Partial transfer initial
        PS, // Partial transfer set
    }

    public struct Condition has copy, drop, store {
        account: vector<u8>,
        operator: Operator,
        value: u256,
        expected_transfer_amount: u64,
    }

    public struct TxAction has copy, drop, store {
        source: address,
        recipient: address,
        amount: u64,
    }

    public struct ConditionTx has copy, drop, store {
        id: u256,
        after_block_number: u64,
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

        transfer::share_object(ConditionTxOracle {
            id: object::new(ctx),
            address: ctx.sender(),
            next_condition_tx_id: 0,
            vault: balance::zero<SUI>(),
            name: b"ConditionTxOracle".to_string(),
            description: b"A condition tx oracle.".to_string(),
        });
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
            after_block_number: condition_tx.after_block_number,
            condition_account: string::utf8(hex::encode(condition_tx.list_of_conditions[0].account)),
            condition_operator: match (condition_tx.list_of_conditions[0].operator) {
                Operator::GT => string::utf8(b"GT"),
                Operator::GTE => string::utf8(b"GTE"),
                Operator::LT => string::utf8(b"LT"),
                Operator::LTE => string::utf8(b"LTE"),
                Operator::EQ => string::utf8(b"EQ"),
                Operator::NEQ => string::utf8(b"NEQ"),
                _ => abort E_BAD_INPUT,
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
            after_block_number: condition_tx.after_block_number,
            condition_account: string::utf8(hex::encode(condition_tx.list_of_conditions[0].account)),
            condition_operator: match (condition_tx.list_of_conditions[0].operator) {
                Operator::GT => string::utf8(b"GT"),
                Operator::GTE => string::utf8(b"GTE"),
                Operator::LT => string::utf8(b"LT"),
                Operator::LTE => string::utf8(b"LTE"),
                Operator::EQ => string::utf8(b"EQ"),
                Operator::NEQ => string::utf8(b"NEQ"),
                _ => abort E_BAD_INPUT,
            },
            condition_value: condition_tx.list_of_conditions[0].value,
        });
    }

    fun emit_transfer_condition_tx_created(
        condition_tx: ConditionTx
    ) {
        event::emit(TransferConditionTxCreated {
            id: condition_tx.id,
            after_block_number: condition_tx.after_block_number,
            transfer_account: string::utf8(hex::encode(condition_tx.list_of_conditions[0].account)),
            transfer_operator: match (condition_tx.list_of_conditions[0].operator) {
                Operator::FI => string::utf8(b"FI"),
                Operator::PI => string::utf8(b"PI"),
                _ => abort E_BAD_INPUT,
            },
            expected_transfer_amount: condition_tx.list_of_conditions[0].expected_transfer_amount,
            action_target: condition_tx.action.recipient,
            action_value: condition_tx.action.amount,
        });
    }

    fun emit_transfer_condition_tx_updated(
        condition_tx: ConditionTx
    ) {
        event::emit(TransferConditionTxUpdated {
            id: condition_tx.id,
            after_block_number: condition_tx.after_block_number,
            transfer_account: string::utf8(hex::encode(condition_tx.list_of_conditions[0].account)),
            transfer_operator: match (condition_tx.list_of_conditions[0].operator) {
                Operator::FI => string::utf8(b"FI"),
                Operator::FS => string::utf8(b"FS"),
                Operator::PI => string::utf8(b"PI"),
                Operator::PS => string::utf8(b"PS"),
                _ => abort E_BAD_INPUT,
            },
            expected_transfer_amount: condition_tx.list_of_conditions[0].expected_transfer_amount,
        });
    }

    public fun submit_command_with_escrow(
        oracle: &mut ConditionTxOracle,
        after_block_number: u64,
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
                expected_transfer_amount: 0,
            });
            i = i + 1;
        };

        let condition_tx = ConditionTx {
            id: oracle.next_condition_tx_id,
            after_block_number: after_block_number,
            list_of_conditions,
            action: TxAction { source: ctx.sender(), recipient: action_target, amount: coin::value(&action_escrow)},
        };
        oracle.next_condition_tx_id = oracle.next_condition_tx_id + 1;
        emit_condition_tx_created(condition_tx);
        push_condition_tx_to_oracle(oracle, condition_tx, ctx);
        balance::join(&mut oracle.vault, coin::into_balance(action_escrow));
    }

    public fun submit_transfer_command_with_escrow(
        oracle: &mut ConditionTxOracle,
        after_block_number: u64,
        transfer_account: vector<u8>,
        transfer_operator: u8,
        expected_transfer_amount: u64,
        action_target: address,
        action_escrow: coin::Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let mut list_of_conditions = vector::empty<Condition>();
        vector::push_back(&mut list_of_conditions, Condition {
            account: transfer_account,
            operator: match (transfer_operator) {
                6 => Operator::FI,
                8 => Operator::PI,
                _ => abort E_BAD_INPUT,
            },
            value: 0,
            expected_transfer_amount: expected_transfer_amount,
        });

        let condition_tx = ConditionTx {
            id: oracle.next_condition_tx_id,
            after_block_number: after_block_number,
            list_of_conditions,
            action: TxAction { source: ctx.sender(), recipient: action_target, amount: coin::value(&action_escrow)},
        };
        oracle.next_condition_tx_id = oracle.next_condition_tx_id + 1;
        emit_transfer_condition_tx_created(condition_tx);
        push_condition_tx_to_oracle(oracle, condition_tx, ctx);
        balance::join(&mut oracle.vault, coin::into_balance(action_escrow));
    }

    fun meets_condition(
        condition_tx_id: u256,
        block_number: u64,
        balance: u256,
        condition_tx: &ConditionTx
    ): bool {
        let condition = condition_tx.list_of_conditions[0];
        match (&condition.operator) {
            Operator::GT => balance > condition.value,
            Operator::GTE => balance >= condition.value,
            Operator::LT => balance < condition.value,
            Operator::LTE => balance <= condition.value,
            Operator::EQ => balance == condition.value,
            Operator::NEQ => balance != condition.value,
            Operator::FI => true,
            Operator::FS => balance >= condition.value + (condition.expected_transfer_amount as u256),
            Operator::PI => true,
            Operator::PS => balance > condition.value,
        } && block_number > condition_tx.after_block_number && condition_tx_id == condition_tx.id
    }

    public(package) fun submit_verified_account(
        oracle: &mut ConditionTxOracle,
        condition_tx_id: u256,
        block_number: u64,
        account: vector<u8>,
        balance: u256,
        ctx: &mut TxContext
    ) {
        if (dof::exists_with_type<vector<u8>, AccountConditionTxOracle>(&oracle.id, account)) {
            let mut list_of_condition_met = vector::empty<bool>();
            let mut new_condition_tx: Option<ConditionTx> = option::none();
            {
                let account_condition_tx_oracle = dof::borrow<vector<u8>, AccountConditionTxOracle>(&oracle.id, account);
                let mut i: u64 = 0;
                while (i < vector::length(&account_condition_tx_oracle.list_of_condition_tx)) {
                    let condition_tx = account_condition_tx_oracle.list_of_condition_tx[i];
                    let condition = condition_tx.list_of_conditions[0];
                    let condition_met = meets_condition(condition_tx_id, block_number,  balance, &condition_tx);
                    if (condition_met) {
                        if (vector::length(&condition_tx.list_of_conditions) == 1) {
                            if (condition.operator == Operator::FI || condition.operator == Operator::PI) {
                                let mut new_list_of_conditions = vector::empty<Condition>();
                                vector::push_back(&mut new_list_of_conditions, Condition {
                                    account: condition.account,
                                    operator: match (condition.operator) {
                                        Operator::FI => Operator::FS,
                                        Operator::PI => Operator::PS,
                                        _ => abort E_BAD_INPUT,
                                    },
                                    value: balance,
                                    expected_transfer_amount: condition.expected_transfer_amount,
                                });
                                new_condition_tx = option::some(ConditionTx {
                                    id: condition_tx.id,
                                    after_block_number: block_number,
                                    list_of_conditions: new_list_of_conditions,
                                    action: condition_tx.action,
                                });
                            } else if (condition.operator == Operator::PS) {
                                let action = condition_tx.action;
                                let transfer_amount = (u256::min(balance - condition.value, condition.expected_transfer_amount as u256) * (action.amount as u256) / (condition.expected_transfer_amount as u256)) as u64;
                                let back_amount = action.amount - transfer_amount;
                                transfer::public_transfer(coin::from_balance(balance::split(&mut oracle.vault, transfer_amount), ctx), action.recipient);
                                transfer::public_transfer(coin::from_balance(balance::split(&mut oracle.vault, back_amount), ctx), action.source);
                                event::emit(ConditionTxCompleted {
                                    id: condition_tx.id,
                                });
                            } else {
                                let action = condition_tx.action;
                                transfer::public_transfer(coin::from_balance(balance::split(&mut oracle.vault, action.amount), ctx), action.recipient);
                                event::emit(ConditionTxCompleted {
                                    id: condition_tx.id,
                                });
                            }
                        } else {
                            let mut new_list_of_conditions = vector::empty<Condition>();
                            let mut j: u64 = 1;
                            while (j < vector::length(&condition_tx.list_of_conditions)) {
                                vector::push_back(&mut new_list_of_conditions, condition_tx.list_of_conditions[j]);
                                j = j + 1;
                            };
                            new_condition_tx = option::some(ConditionTx {
                                id: condition_tx.id,
                                after_block_number: block_number,
                                list_of_conditions: new_list_of_conditions,
                                action: condition_tx.action,
                            });
                        }
                    };
                    vector::push_back(&mut list_of_condition_met, condition_met);
                    i = i + 1;
                };
            };

            if (new_condition_tx.is_some()) {
                let operator = new_condition_tx.borrow().list_of_conditions[0].operator;
                if (operator == Operator::FS || operator == Operator::PS) {
                    emit_transfer_condition_tx_updated(*new_condition_tx.borrow());
                } else {
                    emit_condition_tx_updated(*new_condition_tx.borrow());
                };
                push_condition_tx_to_oracle(oracle, *new_condition_tx.borrow(), ctx);

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
                };
            };
        } else {
            abort E_NO_COMMAND
        }
    }

    public struct ConditionTxCreated has copy, drop {
        id: u256,
        after_block_number: u64,
        condition_account: String,
        condition_operator: String,
        condition_value: u256,
        action_target: address,
        action_value: u64,
    }

    public struct ConditionTxUpdated has copy, drop {
        id: u256,
        after_block_number: u64,
        condition_account: String,
        condition_operator: String,
        condition_value: u256,
    }

    public struct ConditionTxCompleted has copy, drop {
        id: u256,
    }


    public struct TransferConditionTxCreated has copy, drop {
        id: u256,
        after_block_number: u64,
        transfer_account: String,
        transfer_operator: String,
        expected_transfer_amount: u64,
        action_target: address,
        action_value: u64,
    }

    public struct TransferConditionTxUpdated has copy, drop {
        id: u256,
        after_block_number: u64,
        transfer_account: String,
        transfer_operator: String,
        expected_transfer_amount: u64,
    }

    #[test_only]
    public fun new_for_testing(ctx: &mut TxContext): ConditionTxOracle {
        let oracle = ConditionTxOracle {
            id: object::new(ctx),
            address: ctx.sender(),
            next_condition_tx_id: 0,
            vault: balance::zero<SUI>(),
            name: b"ConditionTxOracle(test)".to_string(),
            description: b"test condition tx oracle".to_string(),
        };
        oracle
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
}