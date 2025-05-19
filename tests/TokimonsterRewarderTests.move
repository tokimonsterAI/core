#[test_only]
module Tokimonster::TokimonsterRewarderTests {
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::object;
    use Tokimonster::TokimonsterRewarder;
    use Tokimonster::TokimonsterTests;

    const EINVALID_AMOUNT: u64 = 1;
    const EINVALID_RECIPIENT: u64 = 2;
    const EINVALID_OWNER: u64 = 3;

    struct Position has key {
        id: u64
    }

    fun setup_test(): (signer, signer, signer) {
        let tokimonster = account::create_account_for_test(@Tokimonster);
        let user = account::create_account_for_test(@0x123);
        let team_recipient = account::create_account_for_test(@0x456);

        (tokimonster, user, team_recipient)
    }

    #[test]
    fun test_initialize() {
        let (tokimonster, _, team_recipient) = setup_test();
        let team_reward = 10;

        TokimonsterRewarder::initialize(&tokimonster, signer::address_of(&team_recipient), team_reward);
    }

    #[test]
    #[expected_failure(abort_code = 1000001)]
    fun test_initialize_not_tokimonster() {
        let (_, user, team_recipient) = setup_test();
        let team_reward = 10;

        TokimonsterRewarder::initialize(&user, signer::address_of(&team_recipient), team_reward);
    }

    #[test]
    #[expected_failure(abort_code = 1000003)]
    fun test_update_team_reward_failure() {
        let (tokimonster, _, team_recipient) = setup_test();
        let team_reward = 1000;
        let new_reward = 2000;

        TokimonsterRewarder::initialize(&tokimonster, signer::address_of(&team_recipient), team_reward);
        TokimonsterRewarder::update_team_reward(&tokimonster, new_reward);
    }

    #[test]
    fun test_update_team_reward() {
        let (tokimonster, _, team_recipient) = setup_test();
        let team_reward = 10;
        let new_reward = 20;

        TokimonsterRewarder::initialize(&tokimonster, signer::address_of(&team_recipient), team_reward);
        assert!(TokimonsterRewarder::get_team_reward() == team_reward, EINVALID_AMOUNT);
        TokimonsterRewarder::update_team_reward(&tokimonster, new_reward);
        assert!(TokimonsterRewarder::get_team_reward() == new_reward, EINVALID_AMOUNT);
    }

    #[test]
    #[expected_failure(abort_code = 1000001)]
    fun test_update_team_reward_not_tokimonster() {
        let (tokimonster, user, team_recipient) = setup_test();
        let team_reward = 10;
        let new_reward = 20;

        TokimonsterRewarder::initialize(&tokimonster, signer::address_of(&team_recipient), team_reward);
        TokimonsterRewarder::update_team_reward(&user, new_reward);
    }

    #[test]
    fun test_update_team_recipient() {
        let (tokimonster, _, team_recipient) = setup_test();
        let team_reward = 10;
        let new_recipient = account::create_account_for_test(@0x789);

        TokimonsterRewarder::initialize(&tokimonster, signer::address_of(&team_recipient), team_reward);
        TokimonsterRewarder::update_team_recipient(&tokimonster, signer::address_of(&new_recipient));
    }

    #[test]
    #[expected_failure(abort_code = 1000001)]
    fun test_update_team_recipient_not_tokimonster() {
        let (tokimonster, user, team_recipient) = setup_test();
        let team_reward = 10;
        let new_recipient = account::create_account_for_test(@0x789);

        TokimonsterRewarder::initialize(&tokimonster, signer::address_of(&team_recipient), team_reward);
        TokimonsterRewarder::update_team_recipient(&user, signer::address_of(&new_recipient));
    }

    #[test]
    fun test_set_override_team_rewards_for_token() {
        let (tokimonster, _user, team_recipient) = setup_test();
        let team_reward = 10;
        let new_recipient = account::create_account_for_test(@0x789);
        let new_reward = 50;
        let deployer = TokimonsterTests::deploy_token();
        let positions = TokimonsterRewarder::get_positions_for_user(deployer);

        TokimonsterRewarder::set_override_team_rewards_for_token(&tokimonster, *positions.borrow(0), signer::address_of(&new_recipient), new_reward);
        let (recipient, reward) = TokimonsterRewarder::get_override_team_reward_for_token(*positions.borrow(0));
        assert!(recipient == signer::address_of(&new_recipient), EINVALID_RECIPIENT);
        assert!(reward == new_reward, EINVALID_AMOUNT);
    }

    #[test]
    #[expected_failure(abort_code = 1000001)]
    fun test_set_override_team_rewards_for_token_not_tokimonster() {
        let (tokimonster, user, team_recipient) = setup_test();
        let team_reward = 10;
        let new_recipient = account::create_account_for_test(@0x789);
        let new_reward = 50;
        let deployer = TokimonsterTests::deploy_token();
        let positions = TokimonsterRewarder::get_positions_for_user(deployer);

        TokimonsterRewarder::set_override_team_rewards_for_token(&user, *positions.borrow(0), signer::address_of(&new_recipient), new_reward);
    }

    #[test]
    fun test_get_postions_for_user() {
        let (tokimonster, _user, team_recipient) = setup_test();
        let user = TokimonsterTests::deploy_token();
        let positions = TokimonsterRewarder::get_positions_for_user(user);
        assert!(vector::length(&positions) == 1, EINVALID_AMOUNT);
    }

    #[test]
    fun test_replace_user_reward_recipient() {
        let (tokimonster, _user, team_recipient) = setup_test();
        let new_recipient = account::create_account_for_test(@0x789);

        let (tokimonster, _user, team_recipient) = setup_test();
        let user = TokimonsterTests::deploy_token();
        let positions = TokimonsterRewarder::get_positions_for_user(user);

        TokimonsterRewarder::replace_user_reward_recipient(&tokimonster, *positions.borrow(0), signer::address_of(&new_recipient));
        positions = TokimonsterRewarder::get_positions_for_user(user);
        assert!(positions.length() == 0, EINVALID_AMOUNT);
        let new_positions = TokimonsterRewarder::get_positions_for_user(signer::address_of(&new_recipient));
        assert!(new_positions.length() == 1, EINVALID_AMOUNT);
    }

    #[test]
    #[expected_failure(abort_code = 1000002)]
    fun test_replace_user_reward_recipient_not_owner() {
        let (tokimonster, _user, team_recipient) = setup_test();
        let new_recipient = account::create_account_for_test(@0x789);

        let (tokimonster, _user, team_recipient) = setup_test();
        let user = TokimonsterTests::deploy_token();
        let positions = TokimonsterRewarder::get_positions_for_user(user);

        TokimonsterRewarder::replace_user_reward_recipient(&new_recipient, *positions.borrow(0), signer::address_of(&new_recipient));
        positions = TokimonsterRewarder::get_positions_for_user(user);
        assert!(positions.length() == 0, EINVALID_AMOUNT);
        let new_positions = TokimonsterRewarder::get_positions_for_user(signer::address_of(&new_recipient));
        assert!(new_positions.length() == 1, EINVALID_AMOUNT);
    }
} 