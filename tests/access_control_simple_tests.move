// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::access_control_simple_tests {
    use sui::test_utils::{assert_eq};
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::pool::{Self, Versioned};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig, AclConfig};
    use turbos_clmm::acl::{Self, ACL};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::tools_tests;

    // Test addresses for different privilege levels
    const ADMIN: address = @0x0;
    const MALICIOUS_USER: address = @0x1;
    const LEGITIMATE_MANAGER: address = @0x2;
    
    // ACL role constants (from pool_factory.move)
    const ACL_CLMM_MANAGER: u8 = 0;
    const ACL_REWARD_MANAGER: u8 = 1;

    fun prepare_simple_acl_test(admin: address, scenario: &mut Scenario) {
        tools_tests::init_tests_coin(admin, LEGITIMATE_MANAGER, MALICIOUS_USER, 100000000, scenario);
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
    }

    #[test]
    public fun test_acl_basic_functionality() {
        // 🔍 SECURITY TEST: Verify basic ACL functionality works correctly
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_simple_acl_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Add roles to legitimate manager
            pool_factory::add_role(&admin_cap, &mut acl_config, LEGITIMATE_MANAGER, ACL_CLMM_MANAGER, &versioned);
            
            // Verify role was added correctly
            let acl = pool_factory::acl(&acl_config);
            assert_eq(acl::has_role(acl, LEGITIMATE_MANAGER, ACL_CLMM_MANAGER), true);
            assert_eq(acl::has_role(acl, LEGITIMATE_MANAGER, ACL_REWARD_MANAGER), false);
            
            // Verify malicious user has no roles
            assert_eq(acl::has_role(acl, MALICIOUS_USER, ACL_CLMM_MANAGER), false);
            assert_eq(acl::has_role(acl, MALICIOUS_USER, ACL_REWARD_MANAGER), false);
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::acl::EInvalidRole)]
    public fun test_acl_invalid_role_rejection() {
        // 🚨 SECURITY TEST: Verify ACL rejects invalid roles (>=128)
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_simple_acl_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🚨 ATTACK: Try to add invalid role (should abort)
            pool_factory::add_role(&admin_cap, &mut acl_config, MALICIOUS_USER, 128, &versioned);
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::pool_factory::EInvalidClmmManagerRole)]
    public fun test_unauthorized_pool_configuration_attack() {
        // 🚨 SECURITY TEST: Verify unauthorized users cannot configure pools
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_simple_acl_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, MALICIOUS_USER);
        {
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🚨 ATTACK: Malicious user tries to configure fee tiers without permission
            pool_factory::set_fee_tier_v2<FEE3000BPS>(
                &acl_config,
                &mut pool_config,
                &fee_type,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(acl_config);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_role_permission_isolation() {
        // 🔍 SECURITY TEST: Verify different roles are properly isolated
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_simple_acl_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Give different roles to different users
            pool_factory::add_role(&admin_cap, &mut acl_config, LEGITIMATE_MANAGER, ACL_CLMM_MANAGER, &versioned);
            pool_factory::add_role(&admin_cap, &mut acl_config, MALICIOUS_USER, ACL_REWARD_MANAGER, &versioned);
            
            // Verify role isolation
            let acl = pool_factory::acl(&acl_config);
            
            // LEGITIMATE_MANAGER should have CLMM role but not REWARD role
            assert_eq(acl::has_role(acl, LEGITIMATE_MANAGER, ACL_CLMM_MANAGER), true);
            assert_eq(acl::has_role(acl, LEGITIMATE_MANAGER, ACL_REWARD_MANAGER), false);
            
            // MALICIOUS_USER should have REWARD role but not CLMM role  
            assert_eq(acl::has_role(acl, MALICIOUS_USER, ACL_CLMM_MANAGER), false);
            assert_eq(acl::has_role(acl, MALICIOUS_USER, ACL_REWARD_MANAGER), true);
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_role_removal_security() {
        // 🔍 SECURITY TEST: Verify role removal works correctly
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_simple_acl_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Add multiple roles to a user
            pool_factory::add_role(&admin_cap, &mut acl_config, LEGITIMATE_MANAGER, ACL_CLMM_MANAGER, &versioned);
            pool_factory::add_role(&admin_cap, &mut acl_config, LEGITIMATE_MANAGER, ACL_REWARD_MANAGER, &versioned);
            
            // Verify both roles exist
            let acl = pool_factory::acl(&acl_config);
            assert_eq(acl::has_role(acl, LEGITIMATE_MANAGER, ACL_CLMM_MANAGER), true);
            assert_eq(acl::has_role(acl, LEGITIMATE_MANAGER, ACL_REWARD_MANAGER), true);
            
            // Remove one role
            pool_factory::remove_role(&admin_cap, &mut acl_config, LEGITIMATE_MANAGER, ACL_REWARD_MANAGER, &versioned);
            
            // Verify only one role remains
            let acl = pool_factory::acl(&acl_config);
            assert_eq(acl::has_role(acl, LEGITIMATE_MANAGER, ACL_CLMM_MANAGER), true);
            assert_eq(acl::has_role(acl, LEGITIMATE_MANAGER, ACL_REWARD_MANAGER), false);
            
            // Remove the user completely
            pool_factory::remove_member(&admin_cap, &mut acl_config, LEGITIMATE_MANAGER, &versioned);
            
            // Verify no roles remain
            let acl = pool_factory::acl(&acl_config);
            assert_eq(acl::has_role(acl, LEGITIMATE_MANAGER, ACL_CLMM_MANAGER), false);
            assert_eq(acl::has_role(acl, LEGITIMATE_MANAGER, ACL_REWARD_MANAGER), false);
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_permission_bitmask_precision() {
        // 🔍 SECURITY TEST: Verify permission bitmask calculations are precise
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_simple_acl_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Set multiple roles using bitmask
            let roles_bitmask = (1 << ACL_CLMM_MANAGER) | (1 << ACL_REWARD_MANAGER);
            pool_factory::set_roles(&admin_cap, &mut acl_config, LEGITIMATE_MANAGER, roles_bitmask, &versioned);
            
            // Verify roles were set correctly
            let acl = pool_factory::acl(&acl_config);
            assert_eq(acl::has_role(acl, LEGITIMATE_MANAGER, ACL_CLMM_MANAGER), true);
            assert_eq(acl::has_role(acl, LEGITIMATE_MANAGER, ACL_REWARD_MANAGER), true);
            
            // Verify permission value matches expected bitmask
            let permission = acl::get_permission(acl, LEGITIMATE_MANAGER);
            assert_eq(permission, roles_bitmask);
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }
}