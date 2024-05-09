#[test_only]
module farm_pool::farm_pool_tests {
    use std::option::{none, some};
    use aptos_framework::account;
    use aptos_framework::fungible_asset;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::timestamp;

    use farm_pool::farm_pool;
    use farm_pool::helper::{create_fa, mint_fa};

    #[test]
    fun test_stake() {
        let framework_signer = &account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(framework_signer);
        farm_pool::init_for_test(&account::create_signer_for_test(@farm_pool));
        let stake_metadata = create_fa();
        let reward_metadata = create_fa();
        let stake_fa = mint_fa(stake_metadata, 100000000);
        let reward_fa = mint_fa(reward_metadata, 1000000000000000000);

        let farm_pool_object = farm_pool::create(
            framework_signer,
            stake_metadata,
            reward_metadata,
            reward_fa,
            100_0000_0000
        );

        let user_1 = @0xcafe;

        let stake_object = farm_pool::stake(
            user_1,
            none(),
            farm_pool_object,
            stake_fa
        );

        timestamp::fast_forward_seconds(5);

        let stake_fa = mint_fa(stake_metadata, 100000000);
        farm_pool::stake(
            user_1,
            some(stake_object),
            farm_pool_object,
            stake_fa
        );

        timestamp::fast_forward_seconds(5);
    }

    #[test]
    fun test_unstake() {
        let framework_signer = &account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(framework_signer);
        farm_pool::init_for_test(&account::create_signer_for_test(@farm_pool));
        let stake_metadata = create_fa();
        let reward_metadata = create_fa();
        let stake_fa = mint_fa(stake_metadata, 100000000);
        let reward_fa = mint_fa(reward_metadata, 1000000000000000000);

        let farm_pool_object = farm_pool::create(
            framework_signer,
            stake_metadata,
            reward_metadata,
            reward_fa,
            100_0000_0000
        );

        let user_1 = @0xcafe;

        let stake_object = farm_pool::stake(
            user_1,
            none(),
            farm_pool_object,
            stake_fa
        );

        timestamp::fast_forward_seconds(5);

        let stake_fa = mint_fa(stake_metadata, 100000000);
        farm_pool::stake(
            user_1,
            some(stake_object),
            farm_pool_object,
            stake_fa
        );

        timestamp::fast_forward_seconds(5);

        timestamp::fast_forward_seconds(5);

        let fa = farm_pool::unstake(
            &account::create_signer_for_test(user_1),
            stake_object,
            100000000
        );

        assert!(fungible_asset::amount(&fa) == 100000000, 1);

        let user_1 = @0x131;

        primary_fungible_store::deposit(
            user_1,
            fa
        );
    }

    #[test]
    fun test_2_user_stake() {
        let framework_signer = &account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(framework_signer);
        farm_pool::init_for_test(&account::create_signer_for_test(@farm_pool));
        let stake_metadata = create_fa();
        let reward_metadata = create_fa();
        let stake_fa = mint_fa(stake_metadata, 100000000);
        let reward_fa = mint_fa(reward_metadata, 1000000000000000000);

        let farm_pool_object = farm_pool::create(
            framework_signer,
            stake_metadata,
            reward_metadata,
            reward_fa,
            100_0000_0000
        );

        let user_1 = @0xcafe;
        let user_2 = @0x134;

        let user_1_stake_object = farm_pool::stake(
            user_1,
            none(),
            farm_pool_object,
            stake_fa
        );

        let stake_fa = mint_fa(stake_metadata, 100000000);
        let user_2_stake_object = farm_pool::stake(
            user_2,
            none(),
            farm_pool_object,
            stake_fa
        );

        timestamp::fast_forward_seconds(5);

        assert!(farm_pool::claimable_rewards(user_1_stake_object) == 25000000000, 0);
        assert!(farm_pool::claimable_rewards(user_2_stake_object) == 25000000000, 1);

        let user_2_stake_fa = farm_pool::unstake(
            &account::create_signer_for_test(user_2),
            user_2_stake_object,
            100000000
        );
        assert!(fungible_asset::amount(&user_2_stake_fa) == 100000000, 2);
        primary_fungible_store::deposit(
            user_2,
            user_2_stake_fa
        );

        timestamp::fast_forward_seconds(5);

        assert!(farm_pool::claimable_rewards(user_1_stake_object) == 75000000000, 0);
        assert!(farm_pool::claimable_rewards(user_2_stake_object) == 25000000000, 1);

        let user_2_rewards_fa = farm_pool::claim_rewards(
            &account::create_signer_for_test(user_2),
            user_2_stake_object
        );

        assert!(fungible_asset::amount(&user_2_rewards_fa) == 25000000000, 3);
        primary_fungible_store::deposit(
            user_2,
            user_2_rewards_fa
        );

        let user_1_rewards_fa = farm_pool::claim_rewards(
            &account::create_signer_for_test(user_1),
            user_1_stake_object
        );

        assert!(fungible_asset::amount(&user_1_rewards_fa) == 75000000000, 4);
        primary_fungible_store::deposit(
            user_1,
            user_1_rewards_fa
        );

        assert!(farm_pool::claimable_rewards(user_1_stake_object) == 0, 5);
    }

    #[test]
    fun test_2_user_stake_set_reward_sec() {
        let framework_signer = &account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(framework_signer);
        farm_pool::init_for_test(&account::create_signer_for_test(@farm_pool));
        let stake_metadata = create_fa();
        let reward_metadata = create_fa();
        let stake_fa = mint_fa(stake_metadata, 100000000);
        let reward_fa = mint_fa(reward_metadata, 1000000000000000000);

        let farm_pool_object = farm_pool::create(
            framework_signer,
            stake_metadata,
            reward_metadata,
            reward_fa,
            100_0000_0000
        );

        let user_1 = @0xcafe;
        let user_2 = @0x134;

        let user_1_stake_object = farm_pool::stake(
            user_1,
            none(),
            farm_pool_object,
            stake_fa
        );

        let stake_fa = mint_fa(stake_metadata, 100000000);
        let user_2_stake_object = farm_pool::stake(
            user_2,
            none(),
            farm_pool_object,
            stake_fa
        );

        timestamp::fast_forward_seconds(5);

        assert!(farm_pool::claimable_rewards(user_1_stake_object) == 25000000000, 0);
        assert!(farm_pool::claimable_rewards(user_2_stake_object) == 25000000000, 1);

        let user_2_stake_fa = farm_pool::unstake(
            &account::create_signer_for_test(user_2),
            user_2_stake_object,
            100000000
        );
        assert!(fungible_asset::amount(&user_2_stake_fa) == 100000000, 2);
        primary_fungible_store::deposit(
            user_2,
            user_2_stake_fa
        );

        timestamp::fast_forward_seconds(5);

        assert!(farm_pool::claimable_rewards(user_1_stake_object) == 75000000000, 0);
        assert!(farm_pool::claimable_rewards(user_2_stake_object) == 25000000000, 1);

        let user_2_rewards_fa = farm_pool::claim_rewards(
            &account::create_signer_for_test(user_2),
            user_2_stake_object
        );

        assert!(fungible_asset::amount(&user_2_rewards_fa) == 25000000000, 3);
        primary_fungible_store::deposit(
            user_2,
            user_2_rewards_fa
        );

        farm_pool::set_reward_token_per_sec(
            framework_signer,
            farm_pool_object,
            200_0000_0000
        );

        timestamp::fast_forward_seconds(5);
        assert!(farm_pool::claimable_rewards(user_1_stake_object) == 175000000000, 0);
    }
}
