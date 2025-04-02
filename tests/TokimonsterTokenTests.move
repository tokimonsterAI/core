#[test_only]
module Tokimonster::TokimonsterTokenTests {
    use std::string::utf8;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::object;
    use aptos_framework::fungible_asset;
    use aptos_framework::object::Object;
    use aptos_framework::primary_fungible_store;
    use Tokimonster::TokimonsterToken::TokimonsterToken;
    use Tokimonster::TokimonsterToken;

    const TEST_NAME_BYTES: vector<u8> = b"Test Token";
    const TEST_SYMBOL_BYTES: vector<u8> = b"TEST";
    const TEST_MAX_SUPPLY: u64 = 1000000;
    const TEST_IMAGE_BYTES: vector<u8> = b"https://test.com/image.png";
    const TEST_CAST_HASH_BYTES: vector<u8> = b"0x123";
    const TEST_FID: u128 = 123;
    const TEST_TRANSFER_AMOUNT: u64 = 100;

    fun setup_test(test_name: vector<u8>): (signer, signer, Object<TokimonsterToken>) {
        // Create admin account
        let admin = account::create_account_for_test(@0xCafe);
        // Create deployer account
        let deployer = account::create_account_for_test(@0xDaef);

        // Create token
        let tokimonsterToken = TokimonsterToken::create_token_and_mint_for_test(
            &admin,
            utf8(TEST_NAME_BYTES),
            utf8(TEST_SYMBOL_BYTES),
            TEST_MAX_SUPPLY,
            test_name,
            signer::address_of(&deployer),
            TEST_FID,
            utf8(TEST_IMAGE_BYTES),
            utf8(TEST_CAST_HASH_BYTES),
        );

        (admin, deployer, tokimonsterToken)
    }

    #[test]
    fun test_new_token() {
        let (admin, deployer, token) = setup_test(b"test_new_token");
        let external_metadata = TokimonsterToken::get_external_metadata(token);
        assert!(TokimonsterToken::get_deployer(&external_metadata) == signer::address_of(&deployer), 0);
        assert!(TokimonsterToken::get_fid(&external_metadata) == TEST_FID, 1);
        assert!(TokimonsterToken::get_image(&external_metadata) == utf8(TEST_IMAGE_BYTES), 2);
        assert!(TokimonsterToken::get_cast_hash(&external_metadata) == utf8(TEST_CAST_HASH_BYTES), 3);

        let admin_addr = signer::address_of(&admin);
        let admin_balance = fungible_asset::balance(primary_fungible_store::ensure_primary_store_exists(admin_addr, TokimonsterToken::get_metadata(token)));
        assert!(admin_balance == TEST_MAX_SUPPLY, 4);
    }

    #[test]
    fun test_update_image() {
        let (_, deployer_signer, token) = setup_test(b"test_update_image");
        let new_image = utf8(b"https://new-image.com/image.png");

        // Test image update
        TokimonsterToken::update_image(&deployer_signer, token, new_image);

        // Verify image update
        let external_metadata = TokimonsterToken::get_external_metadata(token);
        assert!(TokimonsterToken::get_image(&external_metadata) == new_image, 0);
    }

    #[test]
    #[expected_failure(abort_code = 101, location = Tokimonster::TokimonsterToken)]
    fun test_update_image_not_deployer() {
        let (_, _, token) = setup_test(b"test_update_image_not_deployer");
        let new_image = utf8(b"https://new-image.com/image.png");
        let other = account::create_account_for_test(@0x3);

        // Test that non-deployer cannot update image
        TokimonsterToken::update_image(&other, token, new_image);
    }

    #[test]
    fun test_get_metadata() {
        let (_, deployer, token) = setup_test(b"test_get_metadata");
        let external_metadata = TokimonsterToken::get_external_metadata(token);

        // Verify metadata correctness
        assert!(TokimonsterToken::get_deployer(&external_metadata) == signer::address_of(&deployer), 0);
        assert!(TokimonsterToken::get_fid(&external_metadata) == TEST_FID, 1);
        assert!(TokimonsterToken::get_image(&external_metadata) == utf8(TEST_IMAGE_BYTES), 2);
        assert!(TokimonsterToken::get_cast_hash(&external_metadata) == utf8(TEST_CAST_HASH_BYTES), 3);
    }

    #[test]
    fun test_transfer() {
        let (admin, _, token) = setup_test(b"test_transfer");
        let recipient = account::create_account_for_test(@0x3);
        let recipient_addr = signer::address_of(&recipient);
        let admin_addr = signer::address_of(&admin);

        // Get metadata and stores
        let metadata = TokimonsterToken::get_metadata(token);
        let admin_store = primary_fungible_store::ensure_primary_store_exists(admin_addr, metadata);
        let recipient_store = primary_fungible_store::ensure_primary_store_exists(recipient_addr, metadata);

        // Transfer tokens
        let fa = fungible_asset::withdraw(&admin, admin_store, TEST_TRANSFER_AMOUNT);
        fungible_asset::deposit(recipient_store, fa);

        // Verify balances
        assert!(fungible_asset::balance(admin_store) == TEST_MAX_SUPPLY - TEST_TRANSFER_AMOUNT, 0);
        assert!(fungible_asset::balance(recipient_store) == TEST_TRANSFER_AMOUNT, 1);
    }

    #[test]
    #[expected_failure(abort_code = 65540)]
    fun test_transfer_insufficient_balance() {
        let (_, _, token) = setup_test(b"test_transfer_insufficient_balance");
        let sender = account::create_account_for_test(@0x3);
        let recipient = account::create_account_for_test(@0x4);
        let sender_addr = signer::address_of(&sender);
        let recipient_addr = signer::address_of(&recipient);

        // Get metadata and stores
        let metadata = TokimonsterToken::get_metadata(token);
        let sender_store = primary_fungible_store::ensure_primary_store_exists(sender_addr, metadata);
        let recipient_store = primary_fungible_store::ensure_primary_store_exists(recipient_addr, metadata);

        // Try to transfer more than balance
        let fa = fungible_asset::withdraw(&sender, sender_store, TEST_MAX_SUPPLY + 1);
        fungible_asset::deposit(recipient_store, fa);
    }

    #[test]
    fun test_transfer_zero_amount() {
        let (admin, _, token) = setup_test(b"test_transfer_zero_amount");
        let recipient = account::create_account_for_test(@0x3);
        let recipient_addr = signer::address_of(&recipient);
        let admin_addr = signer::address_of(&admin);

        // Get metadata and stores
        let metadata = TokimonsterToken::get_metadata(token);
        let admin_store = primary_fungible_store::ensure_primary_store_exists(admin_addr, metadata);
        let recipient_store = primary_fungible_store::ensure_primary_store_exists(recipient_addr, metadata);

        // Transfer zero amount
        let fa = fungible_asset::withdraw(&admin, admin_store, 0);
        fungible_asset::deposit(recipient_store, fa);

        // Verify balances remain unchanged
        assert!(fungible_asset::balance(admin_store) == TEST_MAX_SUPPLY, 0);
        assert!(fungible_asset::balance(recipient_store) == 0, 1);
    }

    #[test]
    fun test_transfer_with_transfer_func() {
        let (admin, _, token) = setup_test(b"test_transfer_zero_amount");
        let recipient = account::create_account_for_test(@0x4);
        let recipient_addr = signer::address_of(&recipient);
        let admin_addr = signer::address_of(&admin);

        // Get metadata and stores
        let metadata = TokimonsterToken::get_metadata(token);
        let admin_store = primary_fungible_store::ensure_primary_store_exists(admin_addr, metadata);
        let recipient_store = primary_fungible_store::ensure_primary_store_exists(recipient_addr, metadata);

        // Transfer tokens
        fungible_asset::transfer(&admin, admin_store, recipient_store, TEST_TRANSFER_AMOUNT);
        assert!(fungible_asset::balance(admin_store) == TEST_MAX_SUPPLY - TEST_TRANSFER_AMOUNT, 0);
        assert!(fungible_asset::balance(recipient_store) == TEST_TRANSFER_AMOUNT, 1);
    }
} 