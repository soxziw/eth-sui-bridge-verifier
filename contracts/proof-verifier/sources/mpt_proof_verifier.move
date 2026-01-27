module proof_verifier::mpt_proof_verifier {
    use std::string::String;
    use std::string;
    use sui::package;
    use sui::hash::keccak256;
    use proof_verifier::condition_tx_executor;
    use proof_verifier::state_root_registry;
    use sui::event;
    use sui::hex;
    
    const E_MISSING_STATE_ROOT: u64 = 1;
    const E_ACCOUNT_NOT_FOUND: u64 = 2;
    const E_FIELD_MISMATCH: u64 = 3;
    const E_PROOF_INVALID: u64 = 4;
    const E_BAD_INPUT: u64 = 5;

    /// // Define a one-time witness to create the `Publisher` of the oracle.
    public struct MPT_PROOF_VERIFIER has drop {}

    public struct Account has copy, drop, store {
        nonce: u256,
        balance: u256,
        storage_root: vector<u8>, // 32
        code_hash: vector<u8>,    // 32
    }

    /// RLP “view” item: points into a byte array by (offset, len), and whether it’s a list.
    public struct RlpItem has copy, drop, store {
        offset: u64,
        len: u64,     // total item length (prefix + payload)
        is_list: bool,
    }

    public struct MPTProofVerifier has key {
        id: UID,
        address: address,
        next_mpt_proof_id: u256,
        name: String,
        description: String,
    }

    fun init(otw: MPT_PROOF_VERIFIER, ctx: &mut TxContext) {
        package::claim_and_keep(otw, ctx); // Claim ownership of the one-time witness and keep it

        transfer::share_object(MPTProofVerifier {
            id: object::new(ctx),
            address: ctx.sender(),
            next_mpt_proof_id: 0,
            name: b"EthProofVerifier".to_string(),
            description: b"A eth proof verifier.".to_string(),
        });
    }

    public fun verify_mpt_proof(
        mpt_proof_verifier: &mut MPTProofVerifier,
        state_root_oracle: &state_root_registry::StateRootOracle,
        condition_tx_oracle: &mut condition_tx_executor::ConditionTxOracle,
        block_number: u64,
        account: vector<u8>,
        account_proof: vector<vector<u8>>,
        expected_nonce: u256,
        expected_balance: u256,
        expected_storage_root: vector<u8>,
        expected_code_hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(vector::length(&account) == 20, E_BAD_INPUT);
        assert!(vector::length(&expected_storage_root) == 32, E_BAD_INPUT);
        assert!(vector::length(&expected_code_hash) == 32, E_BAD_INPUT);

        let state_root : vector<u8> = state_root_registry::get_state_root_by_block_number(state_root_oracle, block_number);
        assert!(vector::length(&state_root) == 32, E_MISSING_STATE_ROOT);

        // key = keccak256(account_eth20)
        let key32 = keccak256(&account);
        let nibbles = to_nibbles(&key32); // 64 bytes each in 0..15

        let rlp_value = mpt_get(&state_root, &nibbles, &account_proof);
        assert!(vector::length(&rlp_value) > 0, E_ACCOUNT_NOT_FOUND);

        let decoded = decode_account_rlp(&rlp_value);

        let mpt_proof_id = mpt_proof_verifier.next_mpt_proof_id;
        mpt_proof_verifier.next_mpt_proof_id = mpt_proof_id + 1;
        assert!(decoded.nonce == expected_nonce, E_FIELD_MISMATCH);
        assert!(decoded.balance == expected_balance, E_FIELD_MISMATCH);
        assert!(decoded.storage_root == expected_storage_root, E_FIELD_MISMATCH);
        assert!(decoded.code_hash == expected_code_hash, E_FIELD_MISMATCH);

        event::emit(MPTProofVerified {
            id: mpt_proof_id,
            block_number: block_number,
            account: string::utf8(hex::encode(account)),
            balance: decoded.balance,
        });

        condition_tx_executor::submit_verified_account(
            condition_tx_oracle,
            block_number,
            account,
            expected_balance,
            ctx
        );
    }

    /// -------------------------
    /// MPT Get (root + key nibbles + proof nodes)
    /// -------------------------
    fun mpt_get(
        root_hash32: &vector<u8>,             // 32
        key_nibbles: &vector<u8>,             // bytes in 0..15
        proof: &vector<vector<u8>>
    ): vector<u8> {
        let mut node_ref = *root_hash32;      // 32 bytes
        let mut key_index: u64 = 0;

        loop {
            let node_rlp = find_node_rlp(&node_ref, proof);
            if (vector::length(&node_rlp) == 0) abort E_PROOF_INVALID;

            // node is an RLP list
            let node_item = rlp_to_item(&node_rlp, 0);
            if (!node_item.is_list) abort E_PROOF_INVALID;

            let items = rlp_list_items(&node_rlp, &node_item);

            let n = vector::length(&items);
            if (n == 17) {
                // Branch node: 16 children + value at index 16
                if (key_index == (vector::length(key_nibbles) as u64)) {
                    return rlp_item_payload_bytes(&node_rlp, *vector::borrow(&items, 16))
                };

                let nib = *vector::borrow(key_nibbles, key_index as u64);
                key_index = key_index + 1;

                let child_item = *vector::borrow(&items, nib as u64);
                let child_bytes = rlp_item_payload_bytes(&node_rlp, child_item);
                if (vector::length(&child_bytes) == 0) return vector::empty<u8>();

                node_ref = child_ref(&child_bytes);
                continue;
            };

            if (n == 2) {
                // Extension or Leaf: [compact_path, valueOrChild]
                let compact = rlp_item_payload_bytes(&node_rlp, *vector::borrow(&items, 0));
                let (is_leaf, partial) = decode_compact(&compact);

                if (!nibbles_equal(&partial, key_nibbles, key_index)) return vector::empty<u8>();
                key_index = key_index + (vector::length(&partial) as u64);

                if (is_leaf) {
                    if (key_index != (vector::length(key_nibbles) as u64)) return vector::empty<u8>();
                    return rlp_item_payload_bytes(&node_rlp, *vector::borrow(&items, 1))
                } else {
                    let child2 = rlp_item_payload_bytes(&node_rlp, *vector::borrow(&items, 1));
                    node_ref = child_ref(&child2);
                    continue
                }
            };

            abort E_PROOF_INVALID;
        };

        // unreachable
        vector::empty<u8>()
    }

    /// proof nodes are RLP bytes; node_ref should match keccak256(node_rlp)
    fun find_node_rlp(want_hash32: &vector<u8>, proof: &vector<vector<u8>>): vector<u8> {
        let mut i: u64 = 0;
        while (i < (vector::length(proof) as u64)) {
            let n = vector::borrow(proof, i);
            let h = keccak256(n);
            if (h == *want_hash32) {
                return *n
            };
            i = i + 1;
        };
        vector::empty<u8>()
    }

    /// child reference: if len==32 => hash, else keccak256(embedded_rlp)
    fun child_ref(rlp_or_hash: &vector<u8>): vector<u8> {
        if (vector::length(rlp_or_hash) == 32) return *rlp_or_hash;
        keccak256(rlp_or_hash)
    }

    /// -------------------------
    /// Decode account RLP value: [nonce, balance, storageRoot, codeHash]
    /// -------------------------
    fun decode_account_rlp(rlp: &vector<u8>): Account {
        let item = rlp_to_item(rlp, 0);
        if (!item.is_list) abort E_PROOF_INVALID;

        let items = rlp_list_items(rlp, &item);
        if (vector::length(&items) != 4) abort E_PROOF_INVALID;

        let nonce_b = rlp_item_payload_bytes(rlp, *vector::borrow(&items, 0));
        let bal_b   = rlp_item_payload_bytes(rlp, *vector::borrow(&items, 1));
        let sr_b    = rlp_item_payload_bytes(rlp, *vector::borrow(&items, 2));
        let ch_b    = rlp_item_payload_bytes(rlp, *vector::borrow(&items, 3));

        let nonce = rlp_be_uint_u256(&nonce_b);
        let balance = rlp_be_uint_u256(&bal_b);

        if (vector::length(&sr_b) != 32) abort E_PROOF_INVALID;
        if (vector::length(&ch_b) != 32) abort E_PROOF_INVALID;

        Account { nonce, balance, storage_root: sr_b, code_hash: ch_b }
    }

    /// -------------------------
    /// Helpers: nibble conversion and compact path
    /// -------------------------
    fun to_nibbles(b: &vector<u8>): vector<u8> {
        let mut out = vector::empty<u8>();
        let mut i: u64 = 0;
        while (i < (vector::length(b) as u64)) {
            let x = *vector::borrow(b, i);
            vector::push_back(&mut out, x >> 4);
            vector::push_back(&mut out, x & 0x0f);
            i = i + 1;
        };
        out
    }

    /// Ethereum hex-prefix compact decode:
    /// returns (isLeaf, nibbles)
    fun decode_compact(compact: &vector<u8>): (bool, vector<u8>) {
        if (vector::length(compact) == 0) abort E_PROOF_INVALID;

        let first = *vector::borrow(compact, 0);
        let flag = first >> 4;            // high nibble
        let odd_len = (flag & 1) == 1;
        let is_leaf = (flag & 2) == 2;

        let mut nibbles = vector::empty<u8>();

        let mut i: u64 = 0;
        while (i < (vector::length(compact) as u64)) {
            let x = *vector::borrow(compact, i);
            let hi = x >> 4;
            let lo = x & 0x0f;

            if (i == 0) {
                if (odd_len) {
                    // take low nibble only
                    vector::push_back(&mut nibbles, lo);
                } else {
                    // skip both padding nibbles
                }
            } else {
                vector::push_back(&mut nibbles, hi);
                vector::push_back(&mut nibbles, lo);
            };

            i = i + 1;
        };

        (is_leaf, nibbles)
    }

    fun nibbles_equal(prefix: &vector<u8>, full: &vector<u8>, offset: u64): bool {
        let p_len = vector::length(prefix) as u64;
        let f_len = vector::length(full) as u64;
        if (offset + p_len > f_len) return false;

        let mut i: u64 = 0;
        while (i < p_len) {
            if (*vector::borrow(prefix, i) != *vector::borrow(full, offset + i)) return false;
            i = i + 1;
        };
        true
    }

    /// -------------------------
    /// Minimal RLP reader (string/list only)
    /// -------------------------

    /// Create an item view starting at `pos`
    fun rlp_to_item(b: &vector<u8>, pos: u64): RlpItem {
        let b0 = *vector::borrow(b, pos);

        if (b0 < 0x80) {
            return RlpItem { offset: pos, len: 1, is_list: false }
        };

        if (b0 < 0xB8) {
            let l = (b0 - 0x80) as u64;
            return RlpItem { offset: pos, len: 1 + l, is_list: false }
        };

        if (b0 < 0xC0) {
            let len_of_len = (b0 - 0xB7) as u64;
            let l = read_be_len(b, pos + 1, len_of_len);
            return RlpItem { offset: pos, len: 1 + len_of_len + l, is_list: false }
        };

        if (b0 < 0xF8) {
            let l = (b0 - 0xC0) as u64;
            return RlpItem { offset: pos, len: 1 + l, is_list: true }
        };

        let len_of_len = (b0 - 0xF7) as u64;
        let l = read_be_len(b, pos + 1, len_of_len);
        RlpItem { offset: pos, len: 1 + len_of_len + l, is_list: true }
    }

    /// For an item, return (payload_offset, payload_len)
    fun rlp_payload_bounds(b: &vector<u8>, it: &RlpItem): (u64, u64) {
        let b0 = *vector::borrow(b, it.offset);

        if (b0 < 0x80) return (it.offset, 1);

        if (b0 < 0xB8) {
            let l = (b0 - 0x80) as u64;
            return (it.offset + 1, l)
        };

        if (b0 < 0xC0) {
            let len_of_len = (b0 - 0xB7) as u64;
            let l = read_be_len(b, it.offset + 1, len_of_len);
            return (it.offset + 1 + len_of_len, l)
        };

        if (b0 < 0xF8) {
            let l = (b0 - 0xC0) as u64;
            return (it.offset + 1, l)
        };

        let len_of_len = (b0 - 0xF7) as u64;
        let l = read_be_len(b, it.offset + 1, len_of_len);
        (it.offset + 1 + len_of_len, l)
    }

    /// Parse list items (top-level children) into RlpItem views
    fun rlp_list_items(b: &vector<u8>, list_it: &RlpItem): vector<RlpItem> {
        if (!list_it.is_list) abort E_PROOF_INVALID;

        let (p_off, p_len) = rlp_payload_bounds(b, list_it);
        let end = p_off + p_len;

        let mut out = vector::empty<RlpItem>();
        let mut p = p_off;

        while (p < end) {
            let it = rlp_to_item(b, p);
            vector::push_back(&mut out, it);
            p = p + it.len;
        };

        // must end exactly
        if (p != end) abort E_PROOF_INVALID;
        out
    }

    /// Extract payload bytes for an item (string or embedded rlp), as a fresh vector<u8>
    fun rlp_item_payload_bytes(b: &vector<u8>, it: RlpItem): vector<u8> {
        let (p_off, p_len) = rlp_payload_bounds(b, &it);
        slice(b, p_off, p_len)
    }

    fun slice(b: &vector<u8>, start: u64, len: u64): vector<u8> {
        let mut out = vector::empty<u8>();
        let mut i: u64 = 0;
        while (i < len) {
            vector::push_back(&mut out, *vector::borrow(b, start + i));
            i = i + 1;
        };
        out
    }

    fun read_be_len(b: &vector<u8>, start: u64, n: u64): u64 {
        let mut out: u64 = 0;
        let mut i: u64 = 0;
        while (i < n) {
            out = (out << 8) | (*vector::borrow(b, start + i) as u64);
            i = i + 1;
        };
        out
    }

    /// RLP integer decoding (big-endian, empty => 0)
    fun rlp_be_uint_u256(bytes: &vector<u8>): u256 {
        let mut out: u256 = 0;
        let mut i: u64 = 0;
        while (i < (vector::length(bytes) as u64)) {
            out = (out << 8) | (*vector::borrow(bytes, i) as u256);
            i = i + 1;
        };
        out
    }

    public struct MPTProofVerified has copy, drop {
        id: u256,
        block_number: u64,
        account: String,
        balance: u256,
    }

    #[test_only]
    public fun new_for_testing(ctx: &mut TxContext): MPTProofVerifier {
        let verifier = MPTProofVerifier {
            id: object::new(ctx),
            address: ctx.sender(),
            next_mpt_proof_id: 0,
            name: b"MPTProofVerifier(test)".to_string(),
            description: b"test mpt proof verifier".to_string(),
        };
        verifier
    }

    #[test_only]
    public fun destroy_verifier_for_testing(verifier: MPTProofVerifier) {
        let MPTProofVerifier {
            id,
            address: _,
            next_mpt_proof_id: _,
            name: _,
            description: _,
        } = verifier;
        object::delete(id);
    }
}