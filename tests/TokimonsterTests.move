#[test_only]
module Tokimonster::TokimonsterTests {
    use std::string::utf8;
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::object::Object;
    use Tokimonster::TokimonsterRewarder;
    use Tokimonster::Tokimonster;
    use dex_contract::pool_v3;
    use dex_contract::position_v3;

    // Test constants
    const TEST_NAME_BYTES: vector<u8> = b"Test Token";
    const TEST_SYMBOL_BYTES: vector<u8> = b"TEST";
    const TEST_MAX_SUPPLY: u64 = 1000000;
    const TEST_IMAGE_BYTES: vector<u8> = b"https://test.com/image.png";
    const TEST_CAST_HASH_BYTES: vector<u8> = b"0x123";
    const TEST_FID: u128 = 123;
    const TEST_FEE_TIER: u8 = 1;
    const TEST_TICK: u32 = 100;

    public fun deploy_token(): address {
        let (tokimonster, lp_locker, deployer, dex) = setup_test(b"test_deploy_token");
        let lp_locker_addr = signer::address_of(&lp_locker);
        let deployer_addr = signer::address_of(&deployer);

        // Initialize first
        Tokimonster::initialize(&tokimonster, lp_locker_addr);

        // Create a paired token for testing
        let paired_token = create_test_paired_token(&tokimonster);

        Tokimonster::toggle_allow_paired_token(&tokimonster, paired_token, true);

        // Deploy token
        Tokimonster::deploy_token(
            &tokimonster,
            utf8(TEST_NAME_BYTES),
            utf8(TEST_SYMBOL_BYTES),
            TEST_MAX_SUPPLY,
            TEST_FEE_TIER,
            b"test_salt",
            deployer_addr,
            TEST_FID,
            utf8(TEST_IMAGE_BYTES),
            utf8(TEST_CAST_HASH_BYTES),
            TEST_TICK,
            paired_token
        );

        deployer_addr
    }

    public fun setup_test(test_name: vector<u8>): (signer, signer, signer, signer) {
        // Create Tokimonster account
        let tokimonster = account::create_account_for_test(@Tokimonster);
        // Create LP locker account
        let lp_locker = account::create_account_for_test(@0x2);
        // Create deployer account
        let deployer = account::create_account_for_test(@0x3);
        let dex = account::create_account_for_test(@dex_contract);

        TokimonsterRewarder::initialize(&tokimonster, @0x4, 50);

        (tokimonster, lp_locker, deployer, dex)
    }

    #[test]
    fun test_initialize() {
        let (tokimonster, lp_locker, _, _) = setup_test(b"test_initialize");
        let lp_locker_addr = signer::address_of(&lp_locker);

        // Initialize Tokimonster
        Tokimonster::initialize(&tokimonster, lp_locker_addr);

        // Verify initialization
        let (lp_locker, deprecated) = Tokimonster::get_tokimonster_config();
        assert!(lp_locker == lp_locker_addr, 0);
        assert!(!deprecated, 1);
    }

    #[test]
    #[expected_failure(abort_code = 1000001)]
    fun test_initialize_not_tokimonster() {
        let (_, lp_locker, deployer, dex) = setup_test(b"test_initialize_not_tokimonster");
        let lp_locker_addr = signer::address_of(&lp_locker);

        // Try to initialize with non-Tokimonster account - should fail
        Tokimonster::initialize(&deployer, lp_locker_addr);
    }

    #[test]
    fun test_deploy_token() {
        let (tokimonster, lp_locker, deployer, dex) = setup_test(b"test_deploy_token");
        let lp_locker_addr = signer::address_of(&lp_locker);
        let deployer_addr = signer::address_of(&deployer);

        // Initialize first
        Tokimonster::initialize(&tokimonster, lp_locker_addr);

        // Create a paired token for testing
        let paired_token = create_test_paired_token(&tokimonster);

        Tokimonster::toggle_allow_paired_token(&tokimonster, paired_token, true);

        // Deploy token
        Tokimonster::deploy_token(
            &tokimonster,
            utf8(TEST_NAME_BYTES),
            utf8(TEST_SYMBOL_BYTES),
            TEST_MAX_SUPPLY,
            TEST_FEE_TIER,
            b"test_salt",
            deployer_addr,
            TEST_FID,
            utf8(TEST_IMAGE_BYTES),
            utf8(TEST_CAST_HASH_BYTES),
            TEST_TICK,
            paired_token
        );

        // Verify token deployment
        let deployed_tokens = Tokimonster::get_tokens_deployed_by_user(deployer_addr);
        assert!(vector::length(&deployed_tokens) == 1, 1000);
    }

    #[test]
    #[expected_failure(abort_code = 1000001)]
    fun test_deploy_token_not_tokimonster() {
        let (tokimonster, lp_locker, deployer, dex) = setup_test(b"test_deploy_token_not_tokimonster");
        let lp_locker_addr = signer::address_of(&lp_locker);
        let deployer_addr = signer::address_of(&deployer);

        // Initialize first
        Tokimonster::initialize(&tokimonster, lp_locker_addr);

        // Create a paired token for testing
        let paired_token = create_test_paired_token(&tokimonster);

        // Try to deploy token with non-Tokimonster account - should fail
        Tokimonster::deploy_token(
            &deployer,
            utf8(TEST_NAME_BYTES),
            utf8(TEST_SYMBOL_BYTES),
            TEST_MAX_SUPPLY,
            TEST_FEE_TIER,
            b"test_salt",
            deployer_addr,
            TEST_FID,
            utf8(TEST_IMAGE_BYTES),
            utf8(TEST_CAST_HASH_BYTES),
            TEST_TICK,
            paired_token
        );
    }

    #[test]
    #[expected_failure(abort_code = 1000002)]
    fun test_deploy_token_deprecated() {
        let (tokimonster, lp_locker, deployer, dex) = setup_test(b"test_deploy_token_deprecated");
        let lp_locker_addr = signer::address_of(&lp_locker);
        let deployer_addr = signer::address_of(&deployer);

        // Initialize first
        Tokimonster::initialize(&tokimonster, lp_locker_addr);

        // Note: We need a function to set deprecated flag
        Tokimonster::set_deprecated(&tokimonster, true);

        // Create a paired token for testing
        let paired_token = create_test_paired_token(&tokimonster);

        // Try to deploy token when deprecated - should fail
        Tokimonster::deploy_token(
            &tokimonster,
            utf8(TEST_NAME_BYTES),
            utf8(TEST_SYMBOL_BYTES),
            TEST_MAX_SUPPLY,
            TEST_FEE_TIER,
            b"test_salt",
            deployer_addr,
            TEST_FID,
            utf8(TEST_IMAGE_BYTES),
            utf8(TEST_CAST_HASH_BYTES),
            TEST_TICK,
            paired_token
        );
    }

    #[test]
    fun test_toggle_allow_paired_token() {
        let (tokimonster, lp_locker, _, dex) = setup_test(b"test_toggle_allow_paired_token");
        let lp_locker_addr = signer::address_of(&lp_locker);

        // Initialize first
        Tokimonster::initialize(&tokimonster, lp_locker_addr);

        // Create a test token to toggle
        let test_token = create_test_paired_token(&tokimonster);

        // Toggle token to allowed
        Tokimonster::toggle_allow_paired_token(&tokimonster, test_token, true);
        // Toggle token to not allowed
        Tokimonster::toggle_allow_paired_token(&tokimonster, test_token, false);
    }

    #[test]
    #[expected_failure(abort_code = 1000001)]
    fun test_toggle_allow_paired_token_not_tokimonster() {
        let (tokimonster, lp_locker, deployer, dex) = setup_test(b"test_toggle_allow_paired_token_not_tokimonster");
        let lp_locker_addr = signer::address_of(&lp_locker);

        // Initialize first
        Tokimonster::initialize(&tokimonster, lp_locker_addr);

        // Create a test token to toggle
        let test_token = create_test_paired_token(&tokimonster);

        // Try to toggle token with non-Tokimonster account - should fail
        Tokimonster::toggle_allow_paired_token(&deployer, test_token, true);
    }

    #[test]
    fun test_get_tokens_deployed_by_user() {
        let (tokimonster, lp_locker, deployer, dex) = setup_test(b"test_get_tokens_deployed_by_user");
        let lp_locker_addr = signer::address_of(&lp_locker);
        let deployer_addr = signer::address_of(&deployer);

        // Initialize first
        Tokimonster::initialize(&tokimonster, lp_locker_addr);

        // Create a paired token for testing
        let paired_token = create_test_paired_token(&tokimonster);

        // toggle token to allowed
        Tokimonster::toggle_allow_paired_token(&tokimonster, paired_token, true);

        // Deploy first token
        Tokimonster::deploy_token(
            &tokimonster,
            utf8(TEST_NAME_BYTES),
            utf8(TEST_SYMBOL_BYTES),
            TEST_MAX_SUPPLY,
            TEST_FEE_TIER,
            b"test_salt_1",
            deployer_addr,
            TEST_FID,
            utf8(TEST_IMAGE_BYTES),
            utf8(TEST_CAST_HASH_BYTES),
            TEST_TICK,
            paired_token
        );

        // Deploy second token with different salt
        Tokimonster::deploy_token(
            &tokimonster,
            utf8(TEST_NAME_BYTES),
            utf8(TEST_SYMBOL_BYTES),
            TEST_MAX_SUPPLY,
            TEST_FEE_TIER,
            b"test_salt_2",
            deployer_addr,
            TEST_FID,
            utf8(TEST_IMAGE_BYTES),
            utf8(TEST_CAST_HASH_BYTES),
            TEST_TICK,
            paired_token
        );

        // Verify tokens deployed by user
        let deployed_tokens = Tokimonster::get_tokens_deployed_by_user(deployer_addr);
        assert!(vector::length(&deployed_tokens) == 2, 1000);

        // Test non-existent user
        let non_existent_tokens = Tokimonster::get_tokens_deployed_by_user(@0x999);
        assert!(vector::length(&non_existent_tokens) == 0, 1001);
    }

    // Helper function to create a test paired token
    fun create_test_paired_token(admin: &signer): Object<Metadata> {
        // This is a placeholder that needs to be implemented based on your token creation logic
        let (_, _, _, _, metadata) = fungible_asset::create_fungible_asset(admin);
        metadata
    }
} 