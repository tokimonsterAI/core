/// TokimonsterToken is a fungible token created by Tokimonster.
/// @Tokimonster is the owner of all the TokimonsterToken.
module Tokimonster::TokimonsterToken {
    use std::string::{String, utf8};
    use std::object::{Self, Object};
    use std::signer;
    use std::option;
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::event::emit;
    use aptos_framework::primary_fungible_store;

    friend Tokimonster::Tokimonster;

    const PROJECT_URL_BYTES: vector<u8> = b"https://tokimonster.io";
    const ENOT_DEPLOYER: u64 = 101;

    struct ExtralMetadata has store, copy, drop {
        deployer: address,
        fid: u128,
        image: String,
        cast_hash: String,
    }

    struct TokimonsterToken has key, drop {
        metadata: Object<Metadata>,
        external_metadata: ExtralMetadata
    }

    #[event]
    struct CreateTokenEvent has store, drop {
        store_address: address,
        token: Object<TokimonsterToken>,
        deployer: address,
        name: String,
        symbol: String,
        max_supply: u64,
        salt: vector<u8>,
        fid: u128,
        image: String,
        cast_hash: String,
    }

    #[event]
    struct UpdateImageEvent has store, drop {
        token: Object<TokimonsterToken>,
        operator: address,
        image: String,
    }

    #[test_only]
    public fun create_token_and_mint_for_test(
        admin: &signer,
        name: String,
        symbol: String,
        max_supply: u64,
        salt: vector<u8>,
        deployer: address,
        fid: u128,
        image: String,
        cast_hash: String,
    ) : Object<TokimonsterToken> {
        create_token_and_mint(admin, name, symbol, max_supply, salt, deployer, fid, image, cast_hash)
    }

    public(friend) fun create_token_and_mint(
        admin: &signer,
        name: String,
        symbol: String,
        max_supply: u64,
        salt: vector<u8>,
        deployer: address,
        fid: u128,
        image: String,
        cast_hash: String,
    ) : Object<TokimonsterToken> {
        let admin_address = signer::address_of(admin);
        let unique_salt = generate_unique_salt(deployer, salt);
        let constructor_ref = object::create_named_object(admin, unique_salt);

        // Create fungible asset
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            option::some((max_supply as u128)),
            name,
            symbol,
            8,
            utf8(b""),
            utf8(PROJECT_URL_BYTES),
        );

        // mint the max supply to the admin
        let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let fa = fungible_asset::mint(&mint_ref, max_supply);
        let metadata = object::object_from_constructor_ref<Metadata>(&constructor_ref);
        let store = primary_fungible_store::ensure_primary_store_exists(admin_address, metadata);
        fungible_asset::deposit(store, fa);

        let extral_metadata = ExtralMetadata {
            deployer,
            fid,
            image,
            cast_hash,
        };

        // store the metadata to the token
        move_to(&object::generate_signer(&constructor_ref), TokimonsterToken {
            metadata,
            external_metadata: extral_metadata
        });

        let tokimonsterToken = object::object_from_constructor_ref<TokimonsterToken>(&constructor_ref);

        let event = CreateTokenEvent {
            store_address: object::address_from_constructor_ref(&constructor_ref),
            token: tokimonsterToken,
            deployer,
            name,
            symbol,
            max_supply,
            salt,
            fid,
            image,
            cast_hash,
        };
        emit(event);

        tokimonsterToken
    }

    public fun generate_unique_salt(deployer: address, salt: vector<u8>): vector<u8> {
        let unique_salt = salt;
        unique_salt.append(std::bcs::to_bytes(&deployer));
        unique_salt
    }

    public entry fun update_image(deployer: &signer, token: Object<TokimonsterToken>, image: String) acquires TokimonsterToken {
        let token_address = object::object_address(&token);
        let token_data = borrow_global_mut<TokimonsterToken>(token_address);
        assert!(token_data.external_metadata.deployer == signer::address_of(deployer), ENOT_DEPLOYER);
        token_data.external_metadata.image = image;
        let event = UpdateImageEvent {
            token,
            operator: signer::address_of(deployer),
            image,
        };
        emit(event);
    }

    #[view]
    public fun get_metadata(token: Object<TokimonsterToken>): Object<Metadata> acquires TokimonsterToken {
        let token_data = borrow_global<TokimonsterToken>(object::object_address(&token));
        token_data.metadata
    }

    #[view]
    public fun get_external_metadata(token: Object<TokimonsterToken>): ExtralMetadata acquires TokimonsterToken {
        let token_data = borrow_global<TokimonsterToken>(object::object_address(&token));
        token_data.external_metadata
    }

    #[view]
    public fun get_tokimonster_token(token: Object<TokimonsterToken>): TokimonsterToken acquires TokimonsterToken {
        let token_data = borrow_global<TokimonsterToken>(object::object_address(&token));
        TokimonsterToken {
            metadata: token_data.metadata,
            external_metadata: token_data.external_metadata
        }
    }

    #[test_only]
    public fun get_deployer(metadata: &ExtralMetadata): address {
        metadata.deployer
    }

    #[test_only]
    public fun get_fid(metadata: &ExtralMetadata): u128 {
        metadata.fid
    }

    #[test_only]
    public fun get_image(metadata: &ExtralMetadata): String {
        metadata.image
    }

    #[test_only]
    public fun get_cast_hash(metadata: &ExtralMetadata): String {
        metadata.cast_hash
    }
}
