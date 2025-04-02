module dex_contract::position_v3 {

    use aptos_framework::fungible_asset::{Metadata};
    use aptos_framework::object::{Object, ExtendRef};
    use std::object;

    use dex_contract::rewarder::PositionReward;
    use dex_contract::i32::{Self, I32};

    const NAME: vector<u8> = b"Position_v3";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Info has key {
        num: u64,
    }


    #[event]
    struct CreatePositionEvent has store,drop {
        object_id: address,
        pool_id: address,
        token_a: Object<Metadata>,
        token_b: Object<Metadata>,
        fee_tier: u8,
        tick_lower: I32,
        tick_upper: I32
    }

    const ENOT_POSITION_OWNER: u64 = 1200001;
    const EPOSITION_NOT_INITIALIZED: u64 = 1200002;
    const EPOSITION_NOT_EMPTY: u64 = 12000003;

    public fun get_tick(
        _position: Object<Info>
    ): (I32, I32) {
        (i32::zero(), i32::zero())
    }

    public fun get_liquidity(
        _position: Object<Info>
    ): u128 {
        0
    }

    public fun create_p(): Object<Info> {
        let constructor_ref = object::create_object(@dex_contract);
        let object_signer = object::generate_signer(&constructor_ref);
        move_to(&object_signer, Info { num: 0 });
        object::object_from_constructor_ref<Info>(&constructor_ref)
    }

    struct Config has key {
        extend_ref: ExtendRef,
    }
}