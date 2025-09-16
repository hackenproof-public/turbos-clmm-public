// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::reward_simple_tests {
    use sui::test_utils::{assert_eq};
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, AclConfig};
    use turbos_clmm::acl::{Self};
    use turbos_clmm::reward_manager::{Self};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::trb::{TRB};
    use turbos_clmm::tools_tests;

    // Test addresses
    const ADMIN: address = @0x0;
    const USER1: address = @0x1;
    const REWARD_MANAGER: address = @0x2;
    
    // Test constants
    const REWARD_INDEX: u64 = 0;

    fun prepare_reward_test(admin: address, scenario: &mut Scenario) {
        tools_tests::init_tests_coin(admin, USER1, REWARD_MANAGER, 100000000, scenario);
        tools_tests::init_pool_factory(admin, scenario);
        tools_tests::init_fee_type(admin, scenario);
        tools_tests::init_clock(admin, scenario);
        
        // Initialize ACL configuration
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            pool_factory::init_acl_config(&admin_cap, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, admin_cap);
        };
        
        // Set up reward manager role
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(&admin_cap, &mut acl_config, REWARD_MANAGER, 1, &versioned); // ACL_REWARD_MANAGER = 1
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
    }

    #[test]
    public fun test_reward_manager_role_validation() {
        // 🔍 SECURITY TEST: Verify reward manager role validation works
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_reward_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            // Verify reward manager has the correct role
            let acl = pool_factory::acl(&acl_config);
            assert_eq(acl::has_role(acl, REWARD_MANAGER, 1), true); // ACL_REWARD_MANAGER = 1
            assert_eq(acl::has_role(acl, USER1, 1), false); // USER1 should not have reward manager role
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::pool_factory::EInvalidRewardManagerRole)]
    public fun test_unauthorized_reward_management() {
        // 🚨 SECURITY TEST: Verify unauthorized users cannot manage rewards
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_reward_test(ADMIN, scenario);
        
        // Deploy a pool first
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<turbos_clmm::pool_factory::PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<turbos_clmm::fee::Fee<FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<sui::clock::Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let sqrt_price = turbos_clmm::math_sqrt_price::encode_price_sqrt(1, 1);
            
            turbos_clmm::pool_factory::deploy_pool<BTC, USDC, FEE3000BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🚨 ATTACK: Unauthorized user tries to initialize rewards (should fail)
            reward_manager::init_reward_v2<BTC, USDC, FEE3000BPS, TRB>(
                &acl_config,
                &mut pool,
                REWARD_INDEX,
                USER1,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_reward_initialization_success() {
        // 🔍 SECURITY TEST: Verify authorized reward initialization works
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_reward_test(ADMIN, scenario);
        
        // Deploy a pool first
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<turbos_clmm::pool_factory::PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<turbos_clmm::fee::Fee<FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<sui::clock::Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let sqrt_price = turbos_clmm::math_sqrt_price::encode_price_sqrt(1, 1);
            
            turbos_clmm::pool_factory::deploy_pool<BTC, USDC, FEE3000BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::next_tx(scenario, REWARD_MANAGER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🔍 SECURITY CHECK: Authorized reward manager should be able to initialize rewards
            reward_manager::init_reward_v2<BTC, USDC, FEE3000BPS, TRB>(
                &acl_config,
                &mut pool,
                REWARD_INDEX,
                REWARD_MANAGER,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_acl_permission_checks() {
        // 🔍 SECURITY TEST: Verify ACL permission system works for rewards
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_reward_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            // Test permission checks
            let acl = pool_factory::acl(&acl_config);
            
            // Verify permission bitmasks
            let reward_manager_permission = acl::get_permission(acl, REWARD_MANAGER);
            assert_eq(reward_manager_permission, 1 << 1); // Should have bit 1 set (ACL_REWARD_MANAGER)
            
            let user1_permission = acl::get_permission(acl, USER1);
            assert_eq(user1_permission, 0); // Should have no permissions
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_reward_role_isolation() {
        // 🔍 SECURITY TEST: Verify reward roles are properly isolated from other roles
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_reward_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Give USER1 CLMM manager role (but not reward manager role)
            pool_factory::add_role(&admin_cap, &mut acl_config, USER1, 0, &versioned); // ACL_CLMM_MANAGER = 0
            
            // Verify role isolation
            let acl = pool_factory::acl(&acl_config);
            
            // USER1 should have CLMM role but not reward role
            assert_eq(acl::has_role(acl, USER1, 0), true); // CLMM_MANAGER
            assert_eq(acl::has_role(acl, USER1, 1), false); // REWARD_MANAGER
            
            // REWARD_MANAGER should have reward role but not CLMM role
            assert_eq(acl::has_role(acl, REWARD_MANAGER, 0), false); // CLMM_MANAGER
            assert_eq(acl::has_role(acl, REWARD_MANAGER, 1), true); // REWARD_MANAGER
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }
}