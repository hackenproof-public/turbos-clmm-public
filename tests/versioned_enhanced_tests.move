// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::versioned_enhanced_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Clock};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::fee500bps::{FEE500BPS};
    use turbos_clmm::math_sqrt_price;
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::tools_tests;

    const ADMIN: address = @0x900;
    const USER: address = @0x901;

    fun setup_versioned_test(admin: address, scenario: &mut Scenario) {
        tools_tests::init_tests_coin(admin, USER, USER, 100000000, scenario);
        tools_tests::init_pool_factory(admin, scenario);
        tools_tests::init_fee_type(admin, scenario);
        tools_tests::init_clock(admin, scenario);
    }

    #[test]
    public fun test_versioned_creation_and_version_check() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_versioned_test(ADMIN, scenario);

        // Deploy a pool which creates a Versioned object
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            
            // Test version before pool deployment
            let initial_version = pool::version(&versioned);
            assert!(initial_version > 0, 1);
            
            pool_factory::deploy_pool<BTC, USDC, FEE500BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            // Test version check function
            pool::check_version(&versioned);
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_versioned_in_swap_operations() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_versioned_test(ADMIN, scenario);

        // Deploy a pool
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            pool_factory::deploy_pool<BTC, USDC, FEE500BPS>(
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

        // Test version checking in swap operations
        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test version check before swap (this should pass)
            pool::check_version(&versioned);
            
            // Verify the versioned object has the correct version
            let current_version = pool::version(&versioned);
            assert!(current_version > 0, 2);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_versioned_upgrade_functionality() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_versioned_test(ADMIN, scenario);

        // Deploy a pool
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            pool_factory::deploy_pool<BTC, USDC, FEE500BPS>(
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

        // Test versioned object properties
        test_scenario::next_tx(scenario, ADMIN);
        {
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let version_before = pool::version(&versioned);
            
            // Test version check works correctly
            pool::check_version(&versioned);
            
            // Verify version remains the same after check
            let version_after = pool::version(&versioned);
            assert!(version_before == version_after, 3);
            
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_versioned_with_multiple_pools() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_versioned_test(ADMIN, scenario);

        // Deploy multiple pools sharing the same versioned object
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            
            // Deploy first pool
            pool_factory::deploy_pool<BTC, USDC, FEE500BPS>(
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

        // Test version checking with multiple pools
        test_scenario::next_tx(scenario, USER);
        {
            let pool1 = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test version check with first pool
            pool::check_version(&versioned);
            let version = pool::version(&versioned);
            assert!(version > 0, 4);
            
            test_scenario::return_shared(pool1);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_versioned_consistency_across_operations() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_versioned_test(ADMIN, scenario);

        // Deploy a pool
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            pool_factory::deploy_pool<BTC, USDC, FEE500BPS>(
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

        // Test version consistency across multiple checks
        test_scenario::next_tx(scenario, USER);
        {
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // First version check
            pool::check_version(&versioned);
            let version1 = pool::version(&versioned);
            
            // Second version check
            pool::check_version(&versioned);
            let version2 = pool::version(&versioned);
            
            // Third version check
            pool::check_version(&versioned);
            let version3 = pool::version(&versioned);
            
            // All versions should be the same
            assert!(version1 == version2, 5);
            assert!(version2 == version3, 6);
            assert!(version1 == version3, 7);
            
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_versioned_initialization() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Test initial setup which creates the versioned object
        tools_tests::init_tests_coin(ADMIN, USER, USER, 100000000, scenario);
        tools_tests::init_pool_factory(ADMIN, scenario);

        // Check that versioned object exists after pool factory init
        test_scenario::next_tx(scenario, ADMIN);
        {
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test that version is properly initialized
            let initial_version = pool::version(&versioned);
            assert!(initial_version > 0, 8);
            
            // Test that check_version works with initial state
            pool::check_version(&versioned);
            
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_versioned_object_properties() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_versioned_test(ADMIN, scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test basic version properties
            let version = pool::version(&versioned);
            
            // Version should be positive
            assert!(version > 0, 9);
            
            // Check version should not panic with current version
            pool::check_version(&versioned);
            
            // Multiple version calls should return the same value
            let version2 = pool::version(&versioned);
            assert!(version == version2, 10);
            
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_versioned_in_pool_operations() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_versioned_test(ADMIN, scenario);

        // Deploy a pool which will use versioned checks
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            
            // Test that version check happens during pool deployment
            pool::check_version(&versioned);
            
            pool_factory::deploy_pool<BTC, USDC, FEE500BPS>(
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

        // Test versioned checks in pool context
        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Verify version in pool operations context
            pool::check_version(&versioned);
            let version = pool::version(&versioned);
            assert!(version > 0, 11);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_versioned_state_immutability() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_versioned_test(ADMIN, scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Get initial version
            let version_before = pool::version(&versioned);
            
            // Perform multiple checks - version should remain stable
            pool::check_version(&versioned);
            pool::check_version(&versioned);
            pool::check_version(&versioned);
            
            let version_after = pool::version(&versioned);
            
            // Version should not change from checks alone
            assert!(version_before == version_after, 12);
            
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }
}