module Tokimonster::TokimonsterRewarder {

    use std::signer;
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::fungible_asset;
    use aptos_framework::fungible_asset::FungibleAsset;
    use aptos_framework::object;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::event::emit;
    use dex_contract::position_v3::Info;
    use dex_contract::pool_v3;

    friend Tokimonster::Tokimonster;

    const NAME:vector<u8> = b"TokimonsterRewarder";
    const ENOT_TOKIMONSTER: u64 = 1000001;
    const ENOT_OWNER: u64 = 1000002;
    const EINVALID_AMOUNT: u64 = 1000003;

    struct RewarderConfig has key, store {
        team_recipient: address,
        team_reward: u64,
    }

    struct RewarderStorage has key, store {
        user_reward_recipient_for_token: Table<address, address>,
        overrided_reward_recipient_for_token: Table<address, RewarderConfig>,
        user_positions: Table<address, vector<address>>,
    }

    #[event]
    struct InitializeEvent has store, drop {
        store_address: address,
        team_recipient: address,
        team_reward: u64,
    }

    #[event]
    struct UpdateTeamRewardEvent has store, drop {
        operator: address,
        store_address: address,
        team_reward: u64,
    }

    #[event]
    struct UpdateTeamRecipientEvent has store, drop {
        operator: address,
        store_address: address,
        team_recipient: address,
    }

    #[event]
    struct SetOverrideTeamRewardForTokenEvent has store, drop {
        operator: address,
        store_address: address,
        position: address,
        team_recipient: address,
        team_reward: u64,
    }

    #[event]
    struct AddUserRewardRecipientEvent has store, drop {
        store_address: address,
        position: address,
        recipient: address,
    }

    #[event]
    struct ReplaceUserRewardRecipientEvent has store, drop {
        operator: address,
        store_address: address,
        position: address,
        old_recipient: address,
        recipient: address,
    }

    #[event]
    struct CollectRewardsEvent has store, drop {
        operator: address,
        store_address: address,
        position: address,
    }

    #[event]
    struct DepositEvent has store, drop {
        recipient: address,
        amount: u64,
    }

    public entry fun initialize(signer: &signer, team_recipient: address, team_reward: u64) {
        let signer_addr = signer::address_of(signer);
        assert!(signer_addr == @Tokimonster, ENOT_TOKIMONSTER);
        assert!(team_recipient != @0x0, ENOT_OWNER);
        assert!(team_reward <= 100, EINVALID_AMOUNT);

        let constructor_ref = object::create_named_object(signer, NAME);
        let object_signer = object::generate_signer(&constructor_ref);

        let config = RewarderConfig {
            team_recipient,
            team_reward,
        };

        let storage = RewarderStorage {
            user_reward_recipient_for_token: table::new(),
            overrided_reward_recipient_for_token: table::new(),
            user_positions: table::new(),
        };

        move_to(&object_signer, config);
        move_to(&object_signer, storage);

        let event = InitializeEvent {
            store_address: object::address_from_constructor_ref(&constructor_ref),
            team_recipient,
            team_reward,
        };
        emit(event);
    }

    public entry fun update_team_reward(signer: &signer, team_reward: u64) acquires RewarderConfig {
        let signer_addr = signer::address_of(signer);
        assert!(signer_addr == @Tokimonster, ENOT_TOKIMONSTER);
        let obj_address = get_obj_address();
        let rewarder = borrow_global_mut<RewarderConfig>(obj_address);
        rewarder.team_reward = team_reward;

        let event = UpdateTeamRewardEvent {
            operator: signer_addr,
            store_address: obj_address,
            team_reward,
        };
        emit(event);
    }

    public entry fun update_team_recipient(signer: &signer, team_recipient: address) acquires RewarderConfig {
        let signer_addr = signer::address_of(signer);
        assert!(signer_addr == @Tokimonster, ENOT_TOKIMONSTER);

        let obj_address = get_obj_address();
        let rewarder = borrow_global_mut<RewarderConfig>(obj_address);
        rewarder.team_recipient = team_recipient;

        let event = UpdateTeamRecipientEvent {
            operator: signer_addr,
            store_address: obj_address,
            team_recipient,
        };
        emit(event);
    }

    #[view]
    public fun get_team_reward(): u64 acquires RewarderConfig {
        let obj_address = get_obj_address();
        let rewarder = borrow_global<RewarderConfig>(obj_address);
        rewarder.team_reward
    }

    #[view]
    public fun get_team_recipient(): address acquires RewarderConfig {
        let obj_address = get_obj_address();
        let rewarder = borrow_global<RewarderConfig>(obj_address);
        rewarder.team_recipient
    }

    #[view]
    public fun get_override_team_reward_for_token(position: address): (address, u64) acquires RewarderStorage {
        let obj_address = get_obj_address();
        let rewarder = borrow_global<RewarderStorage>(obj_address);
        if (rewarder.overrided_reward_recipient_for_token.contains(position)) {
            let config = rewarder.overrided_reward_recipient_for_token.borrow(position);
            (config.team_recipient, config.team_reward)
        } else {
            (@0x0, 0)
        }
    }

    public entry fun set_override_team_rewards_for_token(signer: &signer, position: address, team_recipient: address, team_reward: u64) acquires RewarderStorage {
        let signer_addr = signer::address_of(signer);
        assert!(signer_addr == @Tokimonster, ENOT_TOKIMONSTER);

        let obj_address = get_obj_address();
        let rewarder = borrow_global_mut<RewarderStorage>(obj_address);
        let config = RewarderConfig {
            team_recipient,
            team_reward,
        };
        rewarder.overrided_reward_recipient_for_token.add(position, config);

        let event = SetOverrideTeamRewardForTokenEvent {
            operator: signer_addr,
            store_address: obj_address,
            position,
            team_recipient,
            team_reward,
        };
        emit(event);
    }

    #[view]
    public fun get_postions_for_user(user: address): vector<address> acquires RewarderStorage {
        let obj_address = get_obj_address();
        let rewarder = borrow_global<RewarderStorage>(obj_address);
        if (rewarder.user_positions.contains(user)) {
            *rewarder.user_positions.borrow(user)
        } else {
            vector::empty()
        }
    }

    #[view]
    public fun get_recipient_for_postion(position: address): address acquires RewarderStorage {
        let obj_address = get_obj_address();
        let rewarder = borrow_global<RewarderStorage>(obj_address);
        if (rewarder.user_reward_recipient_for_token.contains(position)) {
            *rewarder.user_reward_recipient_for_token.borrow(position)
        } else {
            @0x0
        }
    }

    public entry fun replace_user_reward_recipient(signer: &signer, position: address, recipient: address) acquires RewarderStorage {
        let signer_addr = signer::address_of(signer);
        let obj_address = get_obj_address();
        let rewarder = borrow_global_mut<RewarderStorage>(obj_address);
        
        let old_recipient = if (rewarder.user_reward_recipient_for_token.contains(position)) {
            rewarder.user_reward_recipient_for_token.remove(position)
        } else {
            @0x0
        };
        
        assert!(signer_addr == old_recipient || signer_addr == @Tokimonster, ENOT_OWNER);

        rewarder.user_reward_recipient_for_token.add(position, recipient);
        
        if (old_recipient != @0x0) {
            if (rewarder.user_positions.contains(old_recipient)) {
                let old_positions = rewarder.user_positions.borrow_mut(old_recipient);
                let i = 0;
                let len = old_positions.length();
                while (i < len) {
                    let pos = *old_positions.borrow(i);
                    if (pos == position) {
                        old_positions.remove(i);
                        break
                    };
                    i = i + 1;
                };
            };
        };
        
        if (!rewarder.user_positions.contains(recipient)) {
            rewarder.user_positions.add(recipient, vector::empty());
        };
        let new_positions = rewarder.user_positions.borrow_mut(recipient);
        new_positions.push_back(position);

        let event = ReplaceUserRewardRecipientEvent {
            operator: signer_addr,
            store_address: obj_address,
            position,
            old_recipient,
            recipient,
        };
        emit(event);
    }

    public(friend) fun add_user_reward_recipient(position: address, recipient: address) acquires RewarderStorage {
        let obj_address = get_obj_address();
        let rewarder = borrow_global_mut<RewarderStorage>(obj_address);
        rewarder.user_reward_recipient_for_token.add(position, recipient);
        
        if (!rewarder.user_positions.contains(recipient)) {
            rewarder.user_positions.add(recipient, vector::empty());
        };
        let positions = rewarder.user_positions.borrow_mut(recipient);
        positions.push_back(position);

        let event = AddUserRewardRecipientEvent {
            store_address: obj_address,
            position,
            recipient,
        };
        emit(event);
    }

    public(friend) fun collect_rewards(signer: &signer, position: address) acquires RewarderStorage, RewarderConfig {
        let signer_addr = signer::address_of(signer);
        assert!(signer_addr == @Tokimonster, ENOT_TOKIMONSTER);

        let position_obj = object::address_to_object<Info>(position);

        let obj_address = get_obj_address();
        let rewarderConfig = borrow_global<RewarderConfig>(obj_address);
        let rewarder = borrow_global_mut<RewarderStorage>(obj_address);

        // Get reward recipient for this position
        assert!(rewarder.user_reward_recipient_for_token.contains(position), ENOT_OWNER);
        let recipient = rewarder.user_reward_recipient_for_token.borrow(position);

        // Get team reward configuration
        let team_recipient = rewarderConfig.team_recipient;
        let team_reward = rewarderConfig.team_reward;

        // Check if there's an override team reward configuration
        if (rewarder.overrided_reward_recipient_for_token.contains(position)) {
            let override_config = rewarder.overrided_reward_recipient_for_token.borrow(position);
            team_recipient = override_config.team_recipient;
            team_reward = override_config.team_reward;
        };

        // Deposit fees to user and team
        let (tokimonster_token_fa, lp_token_fa) = pool_v3::claim_fees(signer, position_obj);
        deposite_fa_to_user_and_team(tokimonster_token_fa, team_reward, team_recipient, *recipient);
        deposite_fa_to_user_and_team(lp_token_fa, team_reward, team_recipient, *recipient);

        // Deposit rewards to user and team
        let reward_fas = pool_v3::claim_rewards(signer, position_obj);
        let rewards_len = reward_fas.length();
        while (rewards_len > 0) {
            deposite_fa_to_user_and_team(reward_fas.remove(rewards_len - 1), team_reward, team_recipient, *recipient);
            rewards_len = rewards_len - 1;
        };
        reward_fas.destroy_empty();

        let event = CollectRewardsEvent {
            operator: signer_addr,
            store_address: obj_address,
            position,
        };
        emit(event);
    }

    fun deposite_fa_to_user_and_team(fa: FungibleAsset, team_reward: u64, team_recipient: address, user_recipient: address) {
        let amount = fungible_asset::amount(&fa);
        let team_amount = (amount * team_reward) / 100;
        let team_fa = fungible_asset::extract(&mut fa, team_amount);

        let team_event = DepositEvent {
            recipient: team_recipient,
            amount: fungible_asset::amount(&team_fa),
        };
        let user_event = DepositEvent {
            recipient: user_recipient,
            amount: fungible_asset::amount(&fa),
        };
        emit(team_event);
        emit(user_event);

        primary_fungible_store::deposit(team_recipient, team_fa);
        primary_fungible_store::deposit(user_recipient, fa);
    }

    fun get_obj_address(): address {
        object::create_object_address(&@Tokimonster, NAME)
    }

}
