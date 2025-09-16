// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::acl_tests {
    use turbos_clmm::acl;
    use sui::test_scenario::{Self};
    use sui::test_utils::{assert_eq};
    use std::vector;

    // Test addresses
    const USER1: address = @0x111;
    const USER2: address = @0x222;
    const USER3: address = @0x333;

    // Test roles
    const ROLE_ADMIN: u8 = 0;
    const ROLE_MANAGER: u8 = 1;
    const ROLE_USER: u8 = 2;
    const ROLE_VIEWER: u8 = 3;

    // Error codes
    const EInvalidRole: u64 = 0;

    #[test]
    public fun test_new_acl() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            
            // Verify initial state - getting permission for non-existent user returns 0
            assert_eq(acl::get_permission(&acl, USER1), 0);
            assert_eq(acl::get_permission(&acl, USER2), 0);
            
            // Verify no roles initially
            assert!(!acl::has_role(&acl, USER1, ROLE_ADMIN), 0);
            assert!(!acl::has_role(&acl, USER2, ROLE_MANAGER), 1);
            
            // Verify get_members returns empty vector
            let members = acl::get_members(&acl);
            assert_eq(vector::length(&members), 0);
            
            sui::transfer::public_share_object(acl);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_add_role() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create ACL
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            sui::transfer::public_share_object(acl);
        };
        
        // Test adding roles
        test_scenario::next_tx(scenario, USER1);
        {
            let acl = test_scenario::take_shared<acl::ACL>(scenario);
            
            // Add first role to USER1
            acl::add_role(&mut acl, USER1, ROLE_ADMIN);
            assert!(acl::has_role(&acl, USER1, ROLE_ADMIN), 0);
            assert_eq(acl::get_permission(&acl, USER1), 1); // 2^0 = 1
            
            // Add second role to USER1
            acl::add_role(&mut acl, USER1, ROLE_MANAGER);
            assert!(acl::has_role(&acl, USER1, ROLE_ADMIN), 1);
            assert!(acl::has_role(&acl, USER1, ROLE_MANAGER), 2);
            assert_eq(acl::get_permission(&acl, USER1), 3); // 2^0 + 2^1 = 3
            
            // Add role to another user
            acl::add_role(&mut acl, USER2, ROLE_USER);
            assert!(acl::has_role(&acl, USER2, ROLE_USER), 3);
            assert_eq(acl::get_permission(&acl, USER2), 4); // 2^2 = 4
            
            // Verify USER1 still has their roles
            assert!(acl::has_role(&acl, USER1, ROLE_ADMIN), 4);
            assert!(acl::has_role(&acl, USER1, ROLE_MANAGER), 5);
            
            test_scenario::return_shared(acl);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = EInvalidRole, location = turbos_clmm::acl)]
    public fun test_add_role_invalid_role() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create ACL
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            sui::transfer::public_share_object(acl);
        };
        
        // Try to add invalid role
        test_scenario::next_tx(scenario, USER1);
        {
            let acl = test_scenario::take_shared<acl::ACL>(scenario);
            
            // Try to add invalid role (>= 128)
            acl::add_role(&mut acl, USER1, 128);
            
            test_scenario::return_shared(acl);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_get_members() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create ACL
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            sui::transfer::public_share_object(acl);
        };
        
        // Test get_members
        test_scenario::next_tx(scenario, USER1);
        {
            let acl = test_scenario::take_shared<acl::ACL>(scenario);
            
            // Initially no members
            let members = acl::get_members(&acl);
            assert_eq(vector::length(&members), 0);
            
            // Add some members with different roles
            acl::add_role(&mut acl, USER1, ROLE_ADMIN);
            acl::add_role(&mut acl, USER1, ROLE_MANAGER);
            acl::add_role(&mut acl, USER2, ROLE_USER);
            acl::add_role(&mut acl, USER3, ROLE_VIEWER);
            
            let members = acl::get_members(&acl);
            assert_eq(vector::length(&members), 3);
            
            test_scenario::return_shared(acl);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_get_permission() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create ACL
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            sui::transfer::public_share_object(acl);
        };
        
        // Test permissions
        test_scenario::next_tx(scenario, USER1);
        {
            let acl = test_scenario::take_shared<acl::ACL>(scenario);
            
            // Test non-existent user
            assert_eq(acl::get_permission(&acl, USER1), 0);
            
            // Add roles and test permissions
            acl::add_role(&mut acl, USER1, ROLE_ADMIN);
            assert_eq(acl::get_permission(&acl, USER1), 1);
            
            acl::add_role(&mut acl, USER1, ROLE_MANAGER);
            assert_eq(acl::get_permission(&acl, USER1), 3);
            
            acl::add_role(&mut acl, USER1, ROLE_USER);
            assert_eq(acl::get_permission(&acl, USER1), 7);
            
            // Test another user
            acl::add_role(&mut acl, USER2, ROLE_VIEWER);
            assert_eq(acl::get_permission(&acl, USER2), 8);
            
            test_scenario::return_shared(acl);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_has_role() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create ACL
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            sui::transfer::public_share_object(acl);
        };
        
        // Test has_role
        test_scenario::next_tx(scenario, USER1);
        {
            let acl = test_scenario::take_shared<acl::ACL>(scenario);
            
            // Test non-existent user
            assert!(!acl::has_role(&acl, USER1, ROLE_ADMIN), 0);
            
            // Add role and test
            acl::add_role(&mut acl, USER1, ROLE_ADMIN);
            assert!(acl::has_role(&acl, USER1, ROLE_ADMIN), 1);
            assert!(!acl::has_role(&acl, USER1, ROLE_MANAGER), 2);
            
            // Add multiple roles
            acl::add_role(&mut acl, USER1, ROLE_MANAGER);
            acl::add_role(&mut acl, USER1, ROLE_USER);
            
            assert!(acl::has_role(&acl, USER1, ROLE_ADMIN), 3);
            assert!(acl::has_role(&acl, USER1, ROLE_MANAGER), 4);
            assert!(acl::has_role(&acl, USER1, ROLE_USER), 5);
            assert!(!acl::has_role(&acl, USER1, ROLE_VIEWER), 6);
            
            // Test with different user
            assert!(!acl::has_role(&acl, USER2, ROLE_ADMIN), 7);
            
            test_scenario::return_shared(acl);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = EInvalidRole, location = turbos_clmm::acl)]
    public fun test_has_role_invalid_role() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create ACL
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            sui::transfer::public_share_object(acl);
        };
        
        // Test invalid role
        test_scenario::next_tx(scenario, USER1);
        {
            let acl = test_scenario::take_shared<acl::ACL>(scenario);
            acl::add_role(&mut acl, USER1, ROLE_ADMIN);
            
            // Try to check invalid role (>= 128)
            acl::has_role(&acl, USER1, 128);
            
            test_scenario::return_shared(acl);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_remove_member() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create ACL
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            sui::transfer::public_share_object(acl);
        };
        
        // Test remove_member
        test_scenario::next_tx(scenario, USER1);
        {
            let acl = test_scenario::take_shared<acl::ACL>(scenario);
            
            // Add some members
            acl::add_role(&mut acl, USER1, ROLE_ADMIN);
            acl::add_role(&mut acl, USER1, ROLE_MANAGER);
            acl::add_role(&mut acl, USER2, ROLE_USER);
            
            // Verify members exist
            assert!(acl::has_role(&acl, USER1, ROLE_ADMIN), 0);
            assert!(acl::has_role(&acl, USER2, ROLE_USER), 1);
            
            // Remove USER1
            acl::remove_member(&mut acl, USER1);
            assert!(!acl::has_role(&acl, USER1, ROLE_ADMIN), 2);
            assert!(!acl::has_role(&acl, USER1, ROLE_MANAGER), 3);
            assert_eq(acl::get_permission(&acl, USER1), 0);
            
            // USER2 should still exist
            assert!(acl::has_role(&acl, USER2, ROLE_USER), 4);
            
            // Remove non-existent member should not fail
            acl::remove_member(&mut acl, USER3);
            
            // Remove already removed member should not fail
            acl::remove_member(&mut acl, USER1);
            
            test_scenario::return_shared(acl);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_remove_role() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create ACL
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            sui::transfer::public_share_object(acl);
        };
        
        // Test remove_role
        test_scenario::next_tx(scenario, USER1);
        {
            let acl = test_scenario::take_shared<acl::ACL>(scenario);
            
            // Add multiple roles to USER1
            acl::add_role(&mut acl, USER1, ROLE_ADMIN);
            acl::add_role(&mut acl, USER1, ROLE_MANAGER);
            acl::add_role(&mut acl, USER1, ROLE_USER);
            
            // Verify all roles exist
            assert!(acl::has_role(&acl, USER1, ROLE_ADMIN), 0);
            assert!(acl::has_role(&acl, USER1, ROLE_MANAGER), 1);
            assert!(acl::has_role(&acl, USER1, ROLE_USER), 2);
            assert_eq(acl::get_permission(&acl, USER1), 7); // 1 + 2 + 4 = 7
            
            // Remove MANAGER role
            acl::remove_role(&mut acl, USER1, ROLE_MANAGER);
            assert!(acl::has_role(&acl, USER1, ROLE_ADMIN), 3);
            assert!(!acl::has_role(&acl, USER1, ROLE_MANAGER), 4);
            assert!(acl::has_role(&acl, USER1, ROLE_USER), 5);
            assert_eq(acl::get_permission(&acl, USER1), 5); // 1 + 4 = 5
            
            // Remove role from non-existent user should not fail
            acl::remove_role(&mut acl, USER2, ROLE_ADMIN);
            
            // Remove non-existent role should not fail
            acl::remove_role(&mut acl, USER1, ROLE_VIEWER);
            
            test_scenario::return_shared(acl);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = EInvalidRole, location = turbos_clmm::acl)]
    public fun test_remove_role_invalid_role() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create ACL
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            sui::transfer::public_share_object(acl);
        };
        
        // Test invalid role removal
        test_scenario::next_tx(scenario, USER1);
        {
            let acl = test_scenario::take_shared<acl::ACL>(scenario);
            acl::add_role(&mut acl, USER1, ROLE_ADMIN);
            
            // Try to remove invalid role (>= 128)
            acl::remove_role(&mut acl, USER1, 128);
            
            test_scenario::return_shared(acl);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_set_roles() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create ACL
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            sui::transfer::public_share_object(acl);
        };
        
        // Test set_roles
        test_scenario::next_tx(scenario, USER1);
        {
            let acl = test_scenario::take_shared<acl::ACL>(scenario);
            
            // Set roles for new user
            acl::set_roles(&mut acl, USER1, 7); // ADMIN + MANAGER + USER = 1 + 2 + 4 = 7
            assert!(acl::has_role(&acl, USER1, ROLE_ADMIN), 0);
            assert!(acl::has_role(&acl, USER1, ROLE_MANAGER), 1);
            assert!(acl::has_role(&acl, USER1, ROLE_USER), 2);
            assert!(!acl::has_role(&acl, USER1, ROLE_VIEWER), 3);
            assert_eq(acl::get_permission(&acl, USER1), 7);
            
            // Update existing user's roles
            acl::set_roles(&mut acl, USER1, 8); // Only VIEWER = 8
            assert!(!acl::has_role(&acl, USER1, ROLE_ADMIN), 4);
            assert!(!acl::has_role(&acl, USER1, ROLE_MANAGER), 5);
            assert!(!acl::has_role(&acl, USER1, ROLE_USER), 6);
            assert!(acl::has_role(&acl, USER1, ROLE_VIEWER), 7);
            assert_eq(acl::get_permission(&acl, USER1), 8);
            
            // Set roles to 0 (no roles)
            acl::set_roles(&mut acl, USER1, 0);
            assert!(!acl::has_role(&acl, USER1, ROLE_ADMIN), 8);
            assert!(!acl::has_role(&acl, USER1, ROLE_MANAGER), 9);
            assert!(!acl::has_role(&acl, USER1, ROLE_USER), 10);
            assert!(!acl::has_role(&acl, USER1, ROLE_VIEWER), 11);
            assert_eq(acl::get_permission(&acl, USER1), 0);
            
            // Set maximum roles (all 128 bits)
            acl::set_roles(&mut acl, USER2, 0xffffffffffffffffffffffffffffffff);
            assert!(acl::has_role(&acl, USER2, 0), 12);
            assert!(acl::has_role(&acl, USER2, 127), 13);
            
            test_scenario::return_shared(acl);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_edge_case_role_127() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create ACL
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            sui::transfer::public_share_object(acl);
        };
        
        // Test edge case
        test_scenario::next_tx(scenario, USER1);
        {
            let acl = test_scenario::take_shared<acl::ACL>(scenario);
            
            // Test maximum valid role (127)
            acl::add_role(&mut acl, USER1, 127);
            assert!(acl::has_role(&acl, USER1, 127), 0);
            
            // Remove maximum valid role
            acl::remove_role(&mut acl, USER1, 127);
            assert!(!acl::has_role(&acl, USER1, 127), 1);
            
            test_scenario::return_shared(acl);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_role_bit_operations() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create ACL
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            sui::transfer::public_share_object(acl);
        };
        
        // Test bit operations
        test_scenario::next_tx(scenario, USER1);
        {
            let acl = test_scenario::take_shared<acl::ACL>(scenario);
            
            // Test individual role bits
            acl::add_role(&mut acl, USER1, 0);
            assert_eq(acl::get_permission(&acl, USER1), 1); // 2^0 = 1
            
            acl::add_role(&mut acl, USER1, 1);
            assert_eq(acl::get_permission(&acl, USER1), 3); // 2^0 + 2^1 = 3
            
            acl::add_role(&mut acl, USER1, 7);
            assert_eq(acl::get_permission(&acl, USER1), 131); // 3 + 2^7 = 131
            
            // Test removing specific bits
            acl::remove_role(&mut acl, USER1, 0);
            assert_eq(acl::get_permission(&acl, USER1), 130); // 131 - 1 = 130
            
            acl::remove_role(&mut acl, USER1, 7);
            assert_eq(acl::get_permission(&acl, USER1), 2); // 130 - 128 = 2
            
            test_scenario::return_shared(acl);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_complex_scenario() {
        let scenario_val = test_scenario::begin(USER1);
        let scenario = &mut scenario_val;
        
        // Create ACL
        test_scenario::next_tx(scenario, USER1);
        {
            let ctx = test_scenario::ctx(scenario);
            let acl = acl::new(ctx);
            sui::transfer::public_share_object(acl);
        };
        
        // Test complex scenario
        test_scenario::next_tx(scenario, USER1);
        {
            let acl = test_scenario::take_shared<acl::ACL>(scenario);
            
            // Add multiple users with different role combinations
            acl::add_role(&mut acl, USER1, ROLE_ADMIN);
            acl::add_role(&mut acl, USER1, ROLE_MANAGER);
            
            acl::add_role(&mut acl, USER2, ROLE_USER);
            acl::add_role(&mut acl, USER2, ROLE_VIEWER);
            
            acl::set_roles(&mut acl, USER3, 15); // All first 4 roles
            
            // Verify initial state
            let members = acl::get_members(&acl);
            assert_eq(vector::length(&members), 3);
            
            // Remove a specific role from USER1
            acl::remove_role(&mut acl, USER1, ROLE_MANAGER);
            assert!(acl::has_role(&acl, USER1, ROLE_ADMIN), 0);
            assert!(!acl::has_role(&acl, USER1, ROLE_MANAGER), 1);
            
            // Remove entire USER2
            acl::remove_member(&mut acl, USER2);
            let members = acl::get_members(&acl);
            assert_eq(vector::length(&members), 2);
            
            // Update USER3's roles
            acl::set_roles(&mut acl, USER3, 1); // Only ADMIN
            assert!(acl::has_role(&acl, USER3, ROLE_ADMIN), 2);
            assert!(!acl::has_role(&acl, USER3, ROLE_MANAGER), 3);
            assert!(!acl::has_role(&acl, USER3, ROLE_USER), 4);
            assert!(!acl::has_role(&acl, USER3, ROLE_VIEWER), 5);
            
            test_scenario::return_shared(acl);
        };
        
        test_scenario::end(scenario_val);
    }
}