module Tokimonster::Tokimonster {
    use std::signer;
    use std::string::String;
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::event::emit;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object::{Self, Object, object_address};
    use Tokimonster::TokimonsterRewarder;
    use dex_contract::router_v3;
    use Tokimonster::TokimonsterToken::{Self, TokimonsterToken};
    use dex_contract::pool_v3;

    const TOKIMONSTER_NAME: vector<u8> = b"Tokimonster";
    const ENOT_TOKIMONSTER: u64 = 1000001;
    const EDEPRECATED: u64 = 1000002;
    const EPOOL_ALREADY_EXISTS: u64 = 1000003;
    const EPAIRED_TOKEN_NOT_ALLOWED: u64 = 1000004;
    const ENOT_POSITION_OWNER: u64 = 1000005;
    const ENOT_EXIST_DEPLOYMENT_INFO: u64 = 1000006;
    const EFEE_TIER_OUT_OF_RANGE: u64 = 1000007;
    const ETICK_NOT_VALID: u64 = 1000008;

    const TICK_SPACING_VECTOR: vector<u8> = vector[1, 10, 60, 200];
    const TICK_BOUND: u32 = 443636;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct TokimonsterConfig has key {
        lp_locker: address,
        deprecated: bool,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct DeploymentInfo has key, store {
        token: Object<Metadata>,
        paired_token: Object<Metadata>,
        position: address,
        lp_locker: address,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct TokimonsterStorage has key {
        allowed_paired_tokens: Table<Object<Metadata>, bool>,
        tokens_deployed_by_users: Table<address, vector<Object<Metadata>>>,
        deployment_info_for_token: Table<Object<Metadata>, DeploymentInfo>,
    }

    #[event]
    struct InitializeEvent has store, drop {
        store_address: address,
        lp_locker: address
    }

    #[event]
    struct DeployTokenEvent has store, drop {
        store_address: address,
        token: Object<Metadata>,
        paired_token: Object<Metadata>,
        position: address,
        lp_locker: address,
        deployer: address,
        name: String,
        symbol: String,
        supply: u64,
        fee_tier: u8,
        salt: vector<u8>,
        fid: u128,
        image: String,
        cast_hash: String,
        tick: u32
    }

    #[event]
    struct ToggleAllowPairedTokenEvent has store, drop {
        store_address: address,
        token: Object<Metadata>,
        allowed: bool
    }

    #[event]
    struct ClaimRewardsEvent has store, drop {
        store_address: address,
        token: Object<Metadata>,
        position: address,
        claimer: address
    }

    public entry fun initialize(signer: &signer, lp_locker: address) {
        let signer_addr = signer::address_of(signer);
        assert!(signer_addr == @Tokimonster, ENOT_TOKIMONSTER);

        let constructor_ref = object::create_named_object(signer, TOKIMONSTER_NAME);
        let object_signer = object::generate_signer(&constructor_ref);

        let config = TokimonsterConfig {
            lp_locker,
            deprecated: false,
        };

        let storage = TokimonsterStorage {
            allowed_paired_tokens: table::new(),
            tokens_deployed_by_users: table::new(),
            deployment_info_for_token: table::new(),
        };

        move_to(&object_signer, config);
        move_to(&object_signer, storage);

        let event = InitializeEvent {
            store_address: signer::address_of(&object_signer),
            lp_locker
        };
        emit(event);
    }

    public entry fun deploy_token(
        locker: &signer,
        name: String,
        symbol: String,
        max_supply: u64,
        fee_tier: u8,
        salt: vector<u8>,
        deployer: address,
        fid: u128,
        image: String,
        cast_hash: String,
        tick: u32,
        paired_token: Object<Metadata>) acquires TokimonsterConfig, TokimonsterStorage {
        let signer_addr = signer::address_of(locker);
        assert!(signer_addr == @Tokimonster, ENOT_TOKIMONSTER);
        assert!(fee_tier < (TICK_SPACING_VECTOR.length() as u8), EFEE_TIER_OUT_OF_RANGE);
        assert!(tick % (TICK_SPACING_VECTOR[(fee_tier as u64)] as u32) == 0 && tick < TICK_BOUND, ETICK_NOT_VALID);

        let object_address = object::create_object_address(&signer_addr, TOKIMONSTER_NAME);
        let tokimonster_config = borrow_global<TokimonsterConfig>(object_address);
        let tokimonster_storage_mut = borrow_global_mut<TokimonsterStorage>(object_address);
        assert!(!tokimonster_config.deprecated, EDEPRECATED);

        assert!(tokimonster_storage_mut.allowed_paired_tokens.contains(paired_token), EPAIRED_TOKEN_NOT_ALLOWED);
        assert!(*tokimonster_storage_mut.allowed_paired_tokens.borrow(paired_token), EPAIRED_TOKEN_NOT_ALLOWED);

        let tokimonster_token = TokimonsterToken::create_token_and_mint(
            locker,
            name,
            symbol,
            max_supply,
            salt,
            deployer,
            fid,
            image,
            cast_hash,
        );

        let new_token = object::convert<TokimonsterToken, Metadata>(tokimonster_token);
        let pool_exists = pool_v3::liquidity_pool_exists(new_token, paired_token, fee_tier);
        assert!(!pool_exists, EPOOL_ALREADY_EXISTS);

        let _pool = pool_v3::create_pool(new_token, paired_token, fee_tier, tick);
        let position = pool_v3::open_position(locker, new_token, paired_token, fee_tier, tick, get_max_usable_tick(fee_tier));
        router_v3::add_liquidity(
            locker,
            position,
            new_token,
            paired_token,
            fee_tier,
            max_supply,
            0,
            0,
            0,
            0
        );

        let deployment_info = DeploymentInfo {
            token: new_token,
            paired_token,
            position: object::object_address(&position),
            lp_locker: tokimonster_config.lp_locker,
        };

        tokimonster_storage_mut.deployment_info_for_token.add(new_token, deployment_info);
        
        if (!tokimonster_storage_mut.tokens_deployed_by_users.contains(deployer)) {
            tokimonster_storage_mut.tokens_deployed_by_users.add(deployer, vector::empty());
        };
        let user_tokens = tokimonster_storage_mut.tokens_deployed_by_users.borrow_mut(deployer);
        user_tokens.push_back(new_token);

        TokimonsterRewarder::add_user_reward_recipient(object::object_address(&position), deployer);

        let event = DeployTokenEvent {
            store_address: object_address,
            token: new_token,
            paired_token,
            position: object::object_address(&position),
            lp_locker: tokimonster_config.lp_locker,
            deployer,
            name,
            symbol,
            supply: max_supply,
            fee_tier,
            salt,
            fid,
            image,
            cast_hash,
            tick
        };
        emit(event);
    }

    fun get_max_usable_tick(fee_tier: u8): u32 {
        let tick_spacing = (TICK_SPACING_VECTOR[(fee_tier as u64)] as u32);
        (TICK_BOUND / tick_spacing) * tick_spacing
    }

    public entry fun set_deprecated(signer: &signer, deprecated: bool) acquires TokimonsterConfig {
        let signer_addr = signer::address_of(signer);
        assert!(signer_addr == @Tokimonster, ENOT_TOKIMONSTER);
        let object_address = object::create_object_address(&signer_addr, TOKIMONSTER_NAME);
        let tokimonster_config = borrow_global_mut<TokimonsterConfig>(object_address);
        tokimonster_config.deprecated = deprecated;
    }

    public entry fun toggle_allow_paired_token(signer: &signer, token: Object<Metadata>, allowed: bool) acquires TokimonsterStorage {
        let signer_addr = signer::address_of(signer);
        assert!(signer_addr == @Tokimonster, ENOT_TOKIMONSTER);
        let object_address = object::create_object_address(&signer_addr, TOKIMONSTER_NAME);
        let tokimonster_storage = borrow_global_mut<TokimonsterStorage>(object_address);
        tokimonster_storage.allowed_paired_tokens.add(token, allowed);

        let event = ToggleAllowPairedTokenEvent {
            store_address: object_address,
            token,
            allowed
        };
        emit(event);
    }

    #[view]
    public fun get_tokimonster_config(): (address, bool) acquires TokimonsterConfig {
        let object_address = object::create_object_address(&@Tokimonster, TOKIMONSTER_NAME);
        let tokimonster_config = borrow_global<TokimonsterConfig>(object_address);
        (tokimonster_config.lp_locker, tokimonster_config.deprecated)
    }

    #[view]
    public fun get_tokens_deployed_by_user(user: address): vector<Object<Metadata>> acquires TokimonsterStorage {
        let object_address = object::create_object_address(&@Tokimonster, TOKIMONSTER_NAME);
        let tokimonster_storage = borrow_global<TokimonsterStorage>(object_address);
        
        if (tokimonster_storage.tokens_deployed_by_users.contains(user)) {
            *tokimonster_storage.tokens_deployed_by_users.borrow(user)
        } else {
            vector::empty<Object<Metadata>>()
        }
    }

    public entry fun claim_rewards(signer: &signer, token: Object<Metadata>) acquires TokimonsterStorage {
        let signer_addr = signer::address_of(signer);
        assert!(signer_addr == @Tokimonster, ENOT_TOKIMONSTER);

        let object_address = get_obj_address();
        let tokimonster_storage = borrow_global_mut<TokimonsterStorage>(object_address);
        assert!(tokimonster_storage.deployment_info_for_token.contains(token), ENOT_EXIST_DEPLOYMENT_INFO);
        let deployment_info = tokimonster_storage.deployment_info_for_token.borrow(token);
        TokimonsterRewarder::collect_rewards(signer, deployment_info.position);

        let event = ClaimRewardsEvent {
            store_address: object_address,
            token,
            position: deployment_info.position,
            claimer: signer_addr
        };
        emit(event);
    }

    fun get_obj_address(): address {
        object::create_object_address(&@Tokimonster, TOKIMONSTER_NAME)
    }
}
