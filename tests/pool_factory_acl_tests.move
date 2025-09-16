// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::pool_factory_acl_tests {
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, AclConfig};
    use turbos_clmm::pool::{Versioned};
    use turbos_clmm::acl;
    use sui::test_scenario::{Self};
    use sui::test_utils::{assert_eq};
    use std::vector;

    // Test addresses
    const ADMIN: address = @0x111;
    const USER1: address = @0x222;
    const USER2: address = @0x333;
    const USER3: address = @0x444;
    const UNAUTHORIZED_USER: address = @0x555;

    // ACL roles
    const ACL_CLMM_MANAGER: u8 = 0;
    const ACL_REWARD_MANAGER: u8 = 1;
    const ACL_CLAIM_PROTOCOL_FEE_MANAGER: u8 = 2;
    const ACL_PAUSE_POOL_MANAGER: u8 = 3;

    // Error codes
    const EInvalidClmmManagerRole: u64 = 6;
    const EInvalidRewardManagerRole: u64 = 7;
    const EInvalidClaimProtocolFeeRoleManager: u64 = 8;
    const EInvalidPausePoolManagerRole: u64 = 9;

    fun setup_acl_config_and_versioned(scenario: &mut sui::test_scenario::Scenario) {
        // Initialize pool factory
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            pool_factory::init_for_testing(ctx);
        };

        // Initialize pool
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            turbos_clmm::pool::init_for_testing(ctx);
        };

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
    }

    #[test]
    public fun test_create_acl_config() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            // Verify ACL config was created successfully
            let acl = pool_factory::acl(&acl_config);
            let members = acl::get_members(acl);
            assert_eq(vector::length(&members), 1);
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_add_role() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Add CLMM manager role to USER1
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_CLMM_MANAGER,
                &versioned
            );
            
            // Add reward manager role to USER2
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER2,
                ACL_REWARD_MANAGER,
                &versioned
            );
            
            // Verify roles were added
            let acl = pool_factory::acl(&acl_config);
            assert!(acl::has_role(acl, USER1, ACL_CLMM_MANAGER), 0);
            assert!(acl::has_role(acl, USER2, ACL_REWARD_MANAGER), 1);
            assert!(!acl::has_role(acl, USER1, ACL_REWARD_MANAGER), 2);
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    public fun test_add_role_unauthorized() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        test_scenario::next_tx(scenario, UNAUTHORIZED_USER);
        {
            // Attempt to get admin cap from unauthorized user (this should fail)
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_CLMM_MANAGER,
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_remove_role() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        // First add roles
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_CLMM_MANAGER,
                &versioned
            );
            
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
        
        // Then remove one role
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::remove_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_CLMM_MANAGER,
                &versioned
            );
            
            // Verify only reward manager role remains
            let acl = pool_factory::acl(&acl_config);
            assert!(!acl::has_role(acl, USER1, ACL_CLMM_MANAGER), 0);
            assert!(acl::has_role(acl, USER1, ACL_REWARD_MANAGER), 1);
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_remove_member() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        // First add roles
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_CLMM_MANAGER,
                &versioned
            );
            
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
        
        // Then remove entire member
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::remove_member(
                &admin_cap,
                &mut acl_config,
                USER1,
                &versioned
            );
            
            // Verify all roles are removed
            let acl = pool_factory::acl(&acl_config);
            assert!(!acl::has_role(acl, USER1, ACL_CLMM_MANAGER), 0);
            assert!(!acl::has_role(acl, USER1, ACL_REWARD_MANAGER), 1);
            assert_eq(acl::get_permission(acl, USER1), 0);
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_set_roles() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Set multiple roles at once: CLMM_MANAGER + REWARD_MANAGER = 1 + 2 = 3
            pool_factory::set_roles(
                &admin_cap,
                &mut acl_config,
                USER1,
                3, // Binary: 11 (roles 0 and 1)
                &versioned
            );
            
            // Verify roles were set
            let acl = pool_factory::acl(&acl_config);
            assert!(acl::has_role(acl, USER1, ACL_CLMM_MANAGER), 0);
            assert!(acl::has_role(acl, USER1, ACL_REWARD_MANAGER), 1);
            assert!(!acl::has_role(acl, USER1, ACL_CLAIM_PROTOCOL_FEE_MANAGER), 2);
            assert_eq(acl::get_permission(acl, USER1), 3);
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_check_clmm_manager_role() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        // Add CLMM manager role to USER1
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_CLMM_MANAGER,
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        // Test role check
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            // This should pass for USER1
            pool_factory::check_clmm_manager_role(&acl_config, USER1);
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = EInvalidClmmManagerRole, location = turbos_clmm::pool_factory)]
    public fun test_check_clmm_manager_role_unauthorized() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            // This should fail for unauthorized user
            pool_factory::check_clmm_manager_role(&acl_config, UNAUTHORIZED_USER);
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_check_reward_manager_role() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        // Add reward manager role to USER2
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
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
        
        // Test role check
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            // This should pass for USER2
            pool_factory::check_reward_manager_role(&acl_config, USER2);
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = EInvalidRewardManagerRole, location = turbos_clmm::pool_factory)]
    public fun test_check_reward_manager_role_unauthorized() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            // This should fail for unauthorized user
            pool_factory::check_reward_manager_role(&acl_config, UNAUTHORIZED_USER);
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_check_claim_protocol_fee_manager_role() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        // Add claim protocol fee manager role to USER3
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER3,
                ACL_CLAIM_PROTOCOL_FEE_MANAGER,
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        // Test role check
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            // This should pass for USER3
            pool_factory::check_claim_protocol_fee_manager_role(&acl_config, USER3);
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = EInvalidClaimProtocolFeeRoleManager, location = turbos_clmm::pool_factory)]
    public fun test_check_claim_protocol_fee_manager_role_unauthorized() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            // This should fail for unauthorized user
            pool_factory::check_claim_protocol_fee_manager_role(&acl_config, UNAUTHORIZED_USER);
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_check_pause_pool_manager_role() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        // Add pause pool manager role to USER1
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_PAUSE_POOL_MANAGER,
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        // Test role check
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            // This should pass for USER1
            pool_factory::check_pause_pool_manager_role(&acl_config, USER1);
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = EInvalidPausePoolManagerRole, location = turbos_clmm::pool_factory)]
    public fun test_check_pause_pool_manager_role_unauthorized() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            // This should fail for unauthorized user
            pool_factory::check_pause_pool_manager_role(&acl_config, UNAUTHORIZED_USER);
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_get_members() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        // Add multiple users with different roles
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_CLMM_MANAGER,
                &versioned
            );
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER2,
                ACL_REWARD_MANAGER,
                &versioned
            );
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER3,
                ACL_CLAIM_PROTOCOL_FEE_MANAGER,
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        // Check members
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            let members = pool_factory::get_members(&acl_config);
            assert_eq(vector::length(&members), 4);
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_role_isolation() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_acl_config_and_versioned(scenario);
        
        // Add different roles to different users
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                USER1,
                ACL_CLMM_MANAGER,
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
        
        // Test that users only have their assigned roles
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            // USER1 should only have CLMM_MANAGER role
            pool_factory::check_clmm_manager_role(&acl_config, USER1);
            
            // USER2 should only have REWARD_MANAGER role
            pool_factory::check_reward_manager_role(&acl_config, USER2);
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }
}