module eth_proof_verifier::condition_tx_executor {
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

    public struct TxActionOracle has key {
        id: UID,
        address: address,
        vault: balance::Balance<SUI>,
        name: String,
        description: String,
    }

    const E_CONDITION_NOT_MET: u64 = 1;
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
        operator: Operator,
        value: u64,
    }

    public struct TxAction has copy, drop, store {
        recipient: address,
        amount: u64,
    }

    public struct ConditionTxActionOracle has key, store {
        id: UID,
        account: vector<u8>,
        condition: Condition,
        action: TxAction,
    }

    fun init(otw: CONDITION_TX_EXECUTOR, ctx: &mut TxContext) {
        package::claim_and_keep(otw, ctx); // Claim ownership of the one-time witness and keep it

        let admin_cap = AdminCap { id: object::new(ctx) }; // Create a new admin capability object
        transfer::share_object(TxActionOracle {
            id: object::new(ctx),
            address: ctx.sender(),
            vault: balance::zero<SUI>(),
            name: b"TxActionOracle".to_string(),
            description: b"A tx action oracle.".to_string(),
        });
        transfer::public_transfer(admin_cap, ctx.sender()); // Transfer the admin capability to the sender.
    }

    public fun deposit_sui(
        _: &AdminCap,
        oracle: &mut TxActionOracle,
        coin: balance::Balance<SUI>
    ) {
        balance::join(&mut oracle.vault, coin::into_balance(coin));
    }

    public fun submit_command(
        _: &AdminCap,
        oracle: &mut TxActionOracle,
        account: vector<u8>,
        conditionOperator: Operator,
        conditionValue: u64,
        actionTarget: address,
        actionValue: u64,
        ctx: &mut TxContext
    ) {
        if (!dof::exists_with_type<vector<u8>, ConditionTxActionOracle>(&oracle.id, account)) {
        dof::add(&mut oracle.id, account, ConditionTxActionOracle {
            id: object::new(ctx),
                account,
                condition: Condition { operator: conditionOperator, value: conditionValue },
                action: TxAction { recipient: actionTarget, amount: actionValue },
            });
        } else {
            let condition_tx_action_oracle_mut = dof::borrow_mut<vector<u8>, ConditionTxActionOracle>(&mut oracle.id, account);
            condition_tx_action_oracle_mut.condition = Condition { operator: conditionOperator, value: conditionValue };
            condition_tx_action_oracle_mut.action = TxAction { recipient: actionTarget, amount: actionValue };
        }
    }

    fun meets_condition(
        balance: u64,
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
        oracle: &mut TxActionOracle,
        account: vector<u8>,
        balance: u64,
        ctx: &mut TxContext
    ) {
        if (dof::exists_with_type<vector<u8>, ConditionTxActionOracle>(&oracle.id, account)) {
            let condition_tx_action_oracle = dof::borrow<vector<u8>, ConditionTxActionOracle>(&oracle.id, account);
            let bool_condition_met = meets_condition(
                balance,
                &condition_tx_action_oracle.condition
            );
            if (bool_condition_met) {
                let action = condition_tx_action_oracle.action;
                transfer::public_transfer(coin::from_balance(balance::split(&mut oracle.vault, action.amount), ctx), action.recipient);
                
                let ConditionTxActionOracle {
                    id,
                    account: _,
                    condition: _,
                    action: _,
                } = dof::remove(&mut oracle.id, account);
                object::delete(id);
            } else {
                abort E_CONDITION_NOT_MET
            }
        } else {
            abort E_NO_COMMAND
        }
    }
}