// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::protocol_fee_security_tests {
    use sui::test_utils::{assert_eq};
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig, AclConfig};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::tools_tests;
    use turbos_clmm::math_sqrt_price;
    use turbos_clmm::acl::{Self};
    use std::vector;

    // Test addresses
    const ADMIN: address = @0x0;
    const USER1: address = @0x1;
    const MALICIOUS_USER: address = @0x2;
    const FEE_COLLECTOR: address = @0x3;
    const CLMM_MANAGER: address = @0x4;
    
    // ACL role constants
    const ACL_CLMM_MANAGER: u8 = 0;
    const ACL_CLAIM_PROTOCOL_FEE_MANAGER: u8 = 2;
    
    // Protocol fee constants for testing
    const MAX_PROTOCOL_FEE: u32 = 999999; // Just under 1,000,000 (100%)
    const NORMAL_PROTOCOL_FEE: u32 = 100000; // 10%
    const HIGH_PROTOCOL_FEE: u32 = 500000; // 50%

    fun prepare_protocol_fee_test(admin: address, scenario: &mut Scenario) {
        // Initialize comprehensive test environment
        tools_tests::init_tests_coin(admin, USER1, MALICIOUS_USER, 100000000, scenario);
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
        
        // Set up roles
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Set up CLMM manager role for fee setting
            pool_factory::add_role(&admin_cap, &mut acl_config, CLMM_MANAGER, ACL_CLMM_MANAGER, &versioned);
            // Set up protocol fee collector role
            pool_factory::add_role(&admin_cap, &mut acl_config, FEE_COLLECTOR, ACL_CLAIM_PROTOCOL_FEE_MANAGER, &versioned);
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };
        
        // Deploy pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            
            pool_factory::deploy_pool<BTC, USDC, FEE3000BPS>(
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
    }

    #[test]
    public fun test_protocol_fee_rate_validation() {
        // 🔍 SECURITY TEST: Verify protocol fee rate validation works correctly
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_protocol_fee_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, CLMM_MANAGER);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🔍 SECURITY CHECK: Valid protocol fee should work
            pool_factory::set_fee_protocol_v2(
                &acl_config,
                &mut pool_config,
                NORMAL_PROTOCOL_FEE,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            // 🔍 SECURITY CHECK: Fee setting operation completed successfully
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::pool_factory::EInvalidFee)]
    public fun test_protocol_fee_rate_boundary_protection() {
        // 🚨 SECURITY TEST: Verify protocol fee rate boundary protection (fee >= 1,000,000 should fail)
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_protocol_fee_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, CLMM_MANAGER);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🚨 ATTACK: Try to set invalid protocol fee (>=1,000,000, which is 100%)
            pool_factory::set_fee_protocol_v2(
                &acl_config,
                &mut pool_config,
                1000000, // Invalid: exactly 100%
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::pool_factory::EInvalidClmmManagerRole)]
    public fun test_unauthorized_protocol_fee_setting() {
        // 🚨 SECURITY TEST: Verify unauthorized users cannot set protocol fees
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_protocol_fee_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, MALICIOUS_USER);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🚨 ATTACK: Unauthorized user tries to set protocol fee
            pool_factory::set_fee_protocol_v2(
                &acl_config,
                &mut pool_config,
                HIGH_PROTOCOL_FEE,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_pool_fee_protocol_update_security() {
        // 🔍 SECURITY TEST: Verify pool-specific protocol fee updates work securely
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_protocol_fee_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, CLMM_MANAGER);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🔍 SECURITY CHECK: Authorized user should be able to update pool protocol fee
            pool_factory::update_pool_fee_protocol_v2<BTC, USDC, FEE3000BPS>(
                &acl_config,
                &mut pool,
                NORMAL_PROTOCOL_FEE,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            // Verify fee was updated
            let current_fee_protocol = pool::get_pool_fee_protocol(&pool);
            assert_eq(current_fee_protocol, NORMAL_PROTOCOL_FEE);
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::pool_factory::EInvalidClmmManagerRole)]
    public fun test_unauthorized_pool_fee_update() {
        // 🚨 SECURITY TEST: Verify unauthorized users cannot update pool protocol fees
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_protocol_fee_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, MALICIOUS_USER);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🚨 ATTACK: Unauthorized user tries to update pool protocol fee
            pool_factory::update_pool_fee_protocol_v2<BTC, USDC, FEE3000BPS>(
                &acl_config,
                &mut pool,
                HIGH_PROTOCOL_FEE,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_protocol_fee_collection_authorization() {
        // 🔍 SECURITY TEST: Verify protocol fee collection requires proper authorization
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_protocol_fee_test(ADMIN, scenario);
        
        // Set up protocol fee first
        test_scenario::next_tx(scenario, CLMM_MANAGER);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::update_pool_fee_protocol_v2<BTC, USDC, FEE3000BPS>(
                &acl_config,
                &mut pool,
                NORMAL_PROTOCOL_FEE,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        // Test authorized collection
        test_scenario::next_tx(scenario, FEE_COLLECTOR);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🔍 SECURITY CHECK: Authorized fee collector should be able to collect fees
            let (coin_a, coin_b) = pool_factory::collect_protocol_fee_with_return_v2<BTC, USDC, FEE3000BPS>(
                &acl_config,
                &mut pool,
                0, // amount_a_requested (0 since no trading yet)
                0, // amount_b_requested
                FEE_COLLECTOR,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            // Verify coins are returned (should be zero since no trading occurred)
            assert_eq(coin::value(&coin_a), 0);
            assert_eq(coin::value(&coin_b), 0);
            
            coin::destroy_zero(coin_a);
            coin::destroy_zero(coin_b);
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::pool_factory::EInvalidClaimProtocolFeeRoleManager)]
    public fun test_unauthorized_protocol_fee_collection() {
        // 🚨 SECURITY TEST: Verify unauthorized users cannot collect protocol fees
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_protocol_fee_test(ADMIN, scenario);
        
        // Set up protocol fee first
        test_scenario::next_tx(scenario, CLMM_MANAGER);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::update_pool_fee_protocol_v2<BTC, USDC, FEE3000BPS>(
                &acl_config,
                &mut pool,
                NORMAL_PROTOCOL_FEE,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::next_tx(scenario, MALICIOUS_USER);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🚨 ATTACK: Unauthorized user tries to collect protocol fees
            let (coin_a, coin_b) = pool_factory::collect_protocol_fee_with_return_v2<BTC, USDC, FEE3000BPS>(
                &acl_config,
                &mut pool,
                1000, // Try to collect some fees
                1000,
                MALICIOUS_USER,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            // Should never reach here
            coin::destroy_zero(coin_a);
            coin::destroy_zero(coin_b);
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_role_separation_security() {
        // 🔍 SECURITY TEST: Verify role separation between fee setting and fee collection
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_protocol_fee_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            // Verify role separation
            let acl = pool_factory::acl(&acl_config);
            
            // CLMM_MANAGER should have CLMM role but not fee collection role
            assert_eq(acl::has_role(acl, CLMM_MANAGER, ACL_CLMM_MANAGER), true);
            assert_eq(acl::has_role(acl, CLMM_MANAGER, ACL_CLAIM_PROTOCOL_FEE_MANAGER), false);
            
            // FEE_COLLECTOR should have fee collection role but not CLMM role
            assert_eq(acl::has_role(acl, FEE_COLLECTOR, ACL_CLMM_MANAGER), false);
            assert_eq(acl::has_role(acl, FEE_COLLECTOR, ACL_CLAIM_PROTOCOL_FEE_MANAGER), true);
            
            // MALICIOUS_USER should have no roles
            assert_eq(acl::has_role(acl, MALICIOUS_USER, ACL_CLMM_MANAGER), false);
            assert_eq(acl::has_role(acl, MALICIOUS_USER, ACL_CLAIM_PROTOCOL_FEE_MANAGER), false);
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_protocol_fee_boundary_values() {
        // 🔍 SECURITY TEST: Verify protocol fee boundary value handling
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_protocol_fee_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, CLMM_MANAGER);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🔍 SECURITY CHECK: Test minimum valid fee (0)
            pool_factory::set_fee_protocol_v2(
                &acl_config,
                &mut pool_config,
                0,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            // 🔍 SECURITY CHECK: Test maximum valid fee (999999)
            pool_factory::set_fee_protocol_v2(
                &acl_config,
                &mut pool_config,
                MAX_PROTOCOL_FEE,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_acl_permission_bitmask_verification() {
        // 🔍 SECURITY TEST: Verify ACL permission bitmasks for protocol fee roles
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_protocol_fee_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            
            let acl = pool_factory::acl(&acl_config);
            
            // Verify CLMM_MANAGER permission bitmask
            let clmm_permission = acl::get_permission(acl, CLMM_MANAGER);
            assert_eq(clmm_permission, 1 << ACL_CLMM_MANAGER); // Should have bit 0 set
            
            // Verify FEE_COLLECTOR permission bitmask
            let fee_collector_permission = acl::get_permission(acl, FEE_COLLECTOR);
            assert_eq(fee_collector_permission, 1 << ACL_CLAIM_PROTOCOL_FEE_MANAGER); // Should have bit 2 set
            
            // Verify MALICIOUS_USER has no permissions
            let malicious_permission = acl::get_permission(acl, MALICIOUS_USER);
            assert_eq(malicious_permission, 0);
            
            test_scenario::return_shared(acl_config);
        };
        
        test_scenario::end(scenario_val);
    }
}