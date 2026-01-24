
// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module proof_verifier::state_root_registry {
    use std::string::String;
    use sui::dynamic_object_field as dof;
    use sui::package;
    
    const E_MISSING_STATE_ROOT: u64 = 1;
    
    /// Define a capability for the admin of the oracle.
    public struct AdminCap has key, store { id: UID }

    /// // Define a one-time witness to create the `Publisher` of the oracle.
    public struct STATE_ROOT_REGISTRY has drop {}

    // Define a struct for the weather oracle
    public struct StateRootOracle has key {
        id: UID,
        /// The address of the oracle.
        address: address,
        /// The name of the oracle.
        name: String,
        /// The description of the oracle.
        description: String,
    }

    public struct BlockStateRootOracle has key, store {
        id: UID,
        block_number: u64, // The block number
        state_root: vector<u8>, // The state root
    }

    fun init(otw: STATE_ROOT_REGISTRY, ctx: &mut TxContext) {
        package::claim_and_keep(otw, ctx); // Claim ownership of the one-time witness and keep it

        let cap = AdminCap { id: object::new(ctx) }; // Create a new admin capability object
        transfer::share_object(StateRootOracle {
            id: object::new(ctx),
            address: ctx.sender(),
            name: b"StateRootOracle".to_string(),
            description: b"A state root oracle.".to_string(),
        });
        transfer::public_transfer(cap, ctx.sender()); // Transfer the admin capability to the sender.
    }

    public fun submit_state_root(
        _: &AdminCap, // The admin capability
        oracle: &mut StateRootOracle, // A mutable reference to the oracle object
        block_number: u64, // The block number
        state_root: vector<u8>, // The state root
        ctx: &mut TxContext // A mutable reference to the transaction context
    ) {
        if (!dof::exists_with_type<u64, BlockStateRootOracle>(&oracle.id, block_number)) {
            dof::add(&mut oracle.id, block_number, // Add a new dynamic object field to the oracle object with the block number as the key and a new block state root oracle object as the value.
                BlockStateRootOracle {
                    id: object::new(ctx), // Assign a unique ID to the block state root oracle object
                    block_number, // Set the block number of the block state root oracle object
                    state_root, // Set the state root of the block state root oracle object
                }
            );
        } else {
            let block_state_root_oracle_mut = dof::borrow_mut<u64, BlockStateRootOracle>(&mut oracle.id, block_number);
            block_state_root_oracle_mut.state_root = state_root;
        }
    }

    /// Returns the `state_root` of the `StateRootOracle` with the given `block_number`.
    public fun get_state_root_by_block_number(
        oracle: &StateRootOracle,
        block_number: u64
    ): vector<u8> {
        assert!(
            dof::exists_with_type<u64, BlockStateRootOracle>(&oracle.id, block_number),
            E_MISSING_STATE_ROOT
        );
        let rec = dof::borrow<u64, BlockStateRootOracle>(&oracle.id, block_number);
        rec.state_root
    }
}