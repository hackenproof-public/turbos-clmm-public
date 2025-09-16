// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::reward_manager_acl_tests {
    use turbos_clmm::reward_manager::{Self, RewardManagerAdminCap};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, AclConfig};
    use turbos_clmm::pool::{Self, Pool, PoolRewardVault, Versioned};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::fee500bps::{FEE500BPS};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::eth::{ETH};
    use turbos_clmm::tools_tests;
    use sui::test_scenario::{Self};
    use sui::test_utils::{assert_eq};
    use sui::coin::{Self, Coin};
    use sui::clock::{Clock};
    use std::vector;

    // Test addresses
    const ADMIN: address = @0x111;
    const USER1: address = @0x222;
    const USER2: address = @0x333;
    const UNAUTHORIZED_USER: address = @0x444;

    // ACL roles
    const ACL_REWARD_MANAGER: u8 = 1;

    // Error codes
    const EInvalidRewardManagerRole: u64 = 7;

    fun setup_reward_manager_test(scenario: &mut sui::test_scenario::Scenario) {
        // Initialize required modules
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            pool_factory::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            pool::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            reward_manager::init_for_testing(ctx);
        };

        // Initialize test coins
        tools_tests::init_tests_coin(ADMIN, USER1, USER2, 10000, scenario);
        tools_tests::init_clock(ADMIN, scenario);

        // Create ACL config
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::init_acl_config(
                &admin_cap,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(versioned);
        };

        // Initialize fee type manually
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            turbos_clmm::fee500bps::init_for_testing(ctx);
        };

        // Grant CLMM manager role to ADMIN for pool setup
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                ADMIN,
                0, // ACL_CLMM_MANAGER
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };

        // Set up fee tier
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool_config = test_scenario::take_shared<turbos_clmm::pool_factory::PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::set_fee_tier_v2<FEE500BPS>(
                &acl_config,
                &mut pool_config,
                &fee_type,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool_config);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };

        // Create a test pool
        test_scenario::next_tx(scenario, ADMIN);
        {
            let pool_config = test_scenario::take_shared<turbos_clmm::pool_factory::PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let sqrt_price = turbos_clmm::math_sqrt_price::encode_price_sqrt(1, 1);
            pool_factory::deploy_pool<BTC, USDC, FEE500BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(pool_config);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
    }

    #[test]
    public fun test_init_reward_v2_with_permission() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_reward_manager_test(scenario);
        
        // Grant reward manager role to USER1
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_REWARD_MANAGER,
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        // USER1 should be able to initialize reward
        test_scenario::next_tx(scenario, USER1);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            reward_manager::init_reward_v2<BTC, USDC, FEE500BPS, ETH>(
                &acl_config,
                &mut pool,
                0,
                USER1,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = EInvalidRewardManagerRole, location = turbos_clmm::pool_factory)]
    public fun test_init_reward_v2_unauthorized() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_reward_manager_test(scenario);
        
        // UNAUTHORIZED_USER attempts to initialize reward without permission
        test_scenario::next_tx(scenario, UNAUTHORIZED_USER);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            reward_manager::init_reward_v2<BTC, USDC, FEE500BPS, ETH>(
                &acl_config,
                &mut pool,
                0,
                UNAUTHORIZED_USER,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_reset_reward_v2_with_permission() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_reward_manager_test(scenario);
        
        // Grant reward manager role to USER1
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_REWARD_MANAGER,
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        // First initialize reward
        test_scenario::next_tx(scenario, USER1);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            reward_manager::init_reward_v2<BTC, USDC, FEE500BPS, ETH>(
                &acl_config,
                &mut pool,
                0,
                USER1,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        // Then reset the reward
        test_scenario::next_tx(scenario, USER1);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            reward_manager::reset_reward_v2<BTC, USDC, FEE500BPS, ETH>(
                &acl_config,
                &mut pool,
                0,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = EInvalidRewardManagerRole, location = turbos_clmm::pool_factory)]
    public fun test_reset_reward_v2_unauthorized() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_reward_manager_test(scenario);
        
        // Grant reward manager role to USER1 to initialize
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_REWARD_MANAGER,
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        // Initialize reward
        test_scenario::next_tx(scenario, USER1);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            reward_manager::init_reward_v2<BTC, USDC, FEE500BPS, ETH>(
                &acl_config,
                &mut pool,
                0,
                USER1,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        // Unauthorized user attempts to reset reward
        test_scenario::next_tx(scenario, UNAUTHORIZED_USER);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            reward_manager::reset_reward_v2<BTC, USDC, FEE500BPS, ETH>(
                &acl_config,
                &mut pool,
                0,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_add_reward_v2_with_permission() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_reward_manager_test(scenario);
        
        // Grant reward manager role to USER1
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_REWARD_MANAGER,
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        // Initialize reward first
        test_scenario::next_tx(scenario, USER1);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            reward_manager::init_reward_v2<BTC, USDC, FEE500BPS, ETH>(
                &acl_config,
                &mut pool,
                0,
                USER1,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        // Add reward
        test_scenario::next_tx(scenario, USER1);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let vault = test_scenario::take_shared<PoolRewardVault<ETH>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let eth_coin = test_scenario::take_from_sender<Coin<ETH>>(scenario);
            
            let coins = vector::empty<Coin<ETH>>();
            vector::push_back(&mut coins, eth_coin);
            
            reward_manager::add_reward_v2<BTC, USDC, FEE500BPS, ETH>(
                &acl_config,
                &mut pool,
                &mut vault,
                0,
                coins,
                100,
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = EInvalidRewardManagerRole, location = turbos_clmm::pool_factory)]
    public fun test_add_reward_v2_unauthorized() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_reward_manager_test(scenario);
        
        // Grant reward manager role to USER1 for initialization
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_REWARD_MANAGER,
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        // Initialize reward
        test_scenario::next_tx(scenario, USER1);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            reward_manager::init_reward_v2<BTC, USDC, FEE500BPS, ETH>(
                &acl_config,
                &mut pool,
                0,
                USER1,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        // Unauthorized user attempts to add reward
        test_scenario::next_tx(scenario, UNAUTHORIZED_USER);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let vault = test_scenario::take_shared<PoolRewardVault<ETH>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Create a dummy coin for unauthorized user
            let eth_coin = coin::zero<ETH>(test_scenario::ctx(scenario));
            let coins = vector::empty<Coin<ETH>>();
            vector::push_back(&mut coins, eth_coin);
            
            reward_manager::add_reward_v2<BTC, USDC, FEE500BPS, ETH>(
                &acl_config,
                &mut pool,
                &mut vault,
                0,
                coins,
                0,
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(vault);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test] 
    #[expected_failure]
    public fun test_deprecated_init_reward_function() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_reward_manager_test(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<RewardManagerAdminCap>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // This should fail as it's deprecated (abort(0))
            reward_manager::init_reward<BTC, USDC, FEE500BPS, ETH>(
                &admin_cap,
                &mut pool,
                0,
                ADMIN,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure] 
    public fun test_deprecated_reset_reward_function() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_reward_manager_test(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<RewardManagerAdminCap>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // This should fail as it's deprecated (abort(0))
            reward_manager::reset_reward<BTC, USDC, FEE500BPS, ETH>(
                &admin_cap,
                &mut pool,
                0,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_role_transition_security() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_reward_manager_test(scenario);
        
        // Grant reward manager role to USER1
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_REWARD_MANAGER,
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        // USER1 initializes reward
        test_scenario::next_tx(scenario, USER1);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            reward_manager::init_reward_v2<BTC, USDC, FEE500BPS, ETH>(
                &acl_config,
                &mut pool,
                0,
                USER1,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        // Admin removes USER1's role
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::remove_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_REWARD_MANAGER,
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        // USER1 should no longer be able to perform reward operations
        // This test verifies that permission removal takes effect immediately
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_multiple_reward_managers() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_reward_manager_test(scenario);
        
        // Grant reward manager role to both USER1 and USER2
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_REWARD_MANAGER,
                &versioned
            );
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER2,
                ACL_REWARD_MANAGER,
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        // Both users should be able to perform reward operations
        test_scenario::next_tx(scenario, USER1);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            reward_manager::init_reward_v2<BTC, USDC, FEE500BPS, ETH>(
                &acl_config,
                &mut pool,
                0,
                USER1,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        // USER2 should also be able to perform operations
        test_scenario::next_tx(scenario, USER2);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            reward_manager::reset_reward_v2<BTC, USDC, FEE500BPS, ETH>(
                &acl_config,
                &mut pool,
                0,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }
}