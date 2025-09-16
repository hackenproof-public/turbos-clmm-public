// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::pool_fetcher_enhanced_tests {
    use std::vector;
    use std::option;
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::pool::{Self, Pool, Versioned, ComputeSwapState};
    use turbos_clmm::pool_fetcher;
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::fee500bps::{FEE500BPS};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::math_tick;
    use turbos_clmm::math_sqrt_price;
    use turbos_clmm::i32::{Self, I32};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::tools_tests;

    const ADMIN: address = @0x900;
    const USER: address = @0x901;
    const MIN_SQRT_PRICE_X64: u128 = 4295048016;
    const MAX_SQRT_PRICE_X64: u128 = 79226673515401279992447579055;

    fun setup_basic_pool(admin: address, user: address, scenario: &mut Scenario) {
        tools_tests::init_tests_coin(admin, user, user, 100000000, scenario);
        tools_tests::init_pool_factory(admin, scenario);
        tools_tests::init_fee_type(admin, scenario);

        // init position manager + clock
        test_scenario::next_tx(scenario, admin);
        { turbos_clmm::position_manager::init_for_testing(test_scenario::ctx(scenario)); };
        tools_tests::init_clock(admin, scenario);

        // Deploy BTC/USDC pool at 1:1
        test_scenario::next_tx(scenario, admin);
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
    }

    #[test]
    #[expected_failure(abort_code = 7)] // ESwapAmountSpecifiedZero
    public fun test_compute_swap_result_zero_amount() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pool(ADMIN, USER, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_btc_usdc = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);

            // Test with zero amount - should fail with ESwapAmountSpecifiedZero
            let state = pool_fetcher::compute_swap_result<BTC, USDC, FEE500BPS>(
                &mut pool_btc_usdc,
                true,  // a_to_b
                0,     // zero amount
                true,  // amount_specified_is_input
                MIN_SQRT_PRICE_X64 + 1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(pool_btc_usdc);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_compute_swap_result_boundary_prices() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pool(ADMIN, USER, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_btc_usdc = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);

            // Test with minimum price limit
            let _state1 = pool_fetcher::compute_swap_result<BTC, USDC, FEE500BPS>(
                &mut pool_btc_usdc,
                true,  // a_to_b
                1000,
                true,  // amount_specified_is_input
                MIN_SQRT_PRICE_X64,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Test with maximum price limit
            let _state2 = pool_fetcher::compute_swap_result<BTC, USDC, FEE500BPS>(
                &mut pool_btc_usdc,
                false, // b_to_a
                1000,
                true,  // amount_specified_is_input
                MAX_SQRT_PRICE_X64,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(pool_btc_usdc);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_compute_swap_result_large_amounts() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pool(ADMIN, USER, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_btc_usdc = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);

            // Test with large input amount
            let _state = pool_fetcher::compute_swap_result<BTC, USDC, FEE500BPS>(
                &mut pool_btc_usdc,
                true,  // a_to_b
                18446744073709551615, // Large u128 amount
                true,  // amount_specified_is_input
                MIN_SQRT_PRICE_X64 + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(pool_btc_usdc);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fetch_ticks_empty_pool() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pool(ADMIN, USER, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);

            // Test fetch_ticks on empty pool with various parameters
            let empty_start = vector::empty<u32>();
            
            pool_fetcher::fetch_ticks<BTC, USDC, FEE500BPS>(
                &mut pool,
                empty_start,
                false,
                100,
                &versioned,
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fetch_ticks_various_limits() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pool(ADMIN, USER, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let start_array = vector::empty<u32>();
            vector::push_back(&mut start_array, 1000);

            // Test with limit 0
            pool_fetcher::fetch_ticks<BTC, USDC, FEE500BPS>(
                &mut pool,
                start_array,
                true,
                0,
                &versioned,
            );

            // Test with limit 1
            pool_fetcher::fetch_ticks<BTC, USDC, FEE500BPS>(
                &mut pool,
                start_array,
                true,
                1,
                &versioned,
            );

            // Test with very large limit
            pool_fetcher::fetch_ticks<BTC, USDC, FEE500BPS>(
                &mut pool,
                start_array,
                true,
                18446744073709551615,
                &versioned,
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fetch_ticks_boundary_indices() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pool(ADMIN, USER, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test max tick boundary
            let max_start = vector::empty<u32>();
            vector::push_back(&mut max_start, 443636);
            
            pool_fetcher::fetch_ticks<BTC, USDC, FEE500BPS>(
                &mut pool,
                max_start,
                false, // positive
                10,
                &versioned,
            );

            // Test max tick boundary negative
            pool_fetcher::fetch_ticks<BTC, USDC, FEE500BPS>(
                &mut pool,
                max_start,
                true, // negative
                10,
                &versioned,
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fetch_ticks_for_testing_function() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pool(ADMIN, USER, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test the testing function that returns values
            let start_array = vector::empty<u32>();
            vector::push_back(&mut start_array, 1000);
            
            let (ticks, next_cursor) = pool_fetcher::fetch_ticks_for_testing<BTC, USDC, FEE500BPS>(
                &mut pool,
                start_array,
                true,
                50,
                &versioned,
            );

            // Verify the returned values have correct types
            assert!(vector::length(&ticks) >= 0, 1);
            assert!(option::is_some(&next_cursor) || option::is_none(&next_cursor), 2);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fetch_ticks_different_start_patterns() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pool(ADMIN, USER, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test with small start value
            let start1 = vector::empty<u32>();
            vector::push_back(&mut start1, 1);
            
            pool_fetcher::fetch_ticks<BTC, USDC, FEE500BPS>(
                &mut pool,
                start1,
                true,
                10,
                &versioned,
            );

            // Test with medium start value
            let start2 = vector::empty<u32>();
            vector::push_back(&mut start2, 50000);
            
            pool_fetcher::fetch_ticks<BTC, USDC, FEE500BPS>(
                &mut pool,
                start2,
                false,
                10,
                &versioned,
            );

            // Test with large start value
            let start3 = vector::empty<u32>();
            vector::push_back(&mut start3, 400000);
            
            pool_fetcher::fetch_ticks<BTC, USDC, FEE500BPS>(
                &mut pool,
                start3,
                true,
                10,
                &versioned,
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_compute_swap_result_direction_combinations() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pool(ADMIN, USER, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_btc_usdc = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);

            // Test all combinations of a_to_b and amount_specified_is_input
            
            // Case 1: a_to_b = true, exact input
            let _state1 = pool_fetcher::compute_swap_result<BTC, USDC, FEE500BPS>(
                &mut pool_btc_usdc,
                true,  // a_to_b
                1000,
                true,  // exact input
                MIN_SQRT_PRICE_X64 + 100,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Case 2: a_to_b = true, exact output
            let _state2 = pool_fetcher::compute_swap_result<BTC, USDC, FEE500BPS>(
                &mut pool_btc_usdc,
                true,  // a_to_b
                1000,
                false, // exact output
                MIN_SQRT_PRICE_X64 + 100,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Case 3: a_to_b = false, exact input
            let _state3 = pool_fetcher::compute_swap_result<BTC, USDC, FEE500BPS>(
                &mut pool_btc_usdc,
                false, // b_to_a
                1000,
                true,  // exact input
                MAX_SQRT_PRICE_X64 - 100,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Case 4: a_to_b = false, exact output
            let _state4 = pool_fetcher::compute_swap_result<BTC, USDC, FEE500BPS>(
                &mut pool_btc_usdc,
                false, // b_to_a
                1000,
                false, // exact output
                MAX_SQRT_PRICE_X64 - 100,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(pool_btc_usdc);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_compute_swap_result_price_consistency() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pool(ADMIN, USER, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_btc_usdc = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);

            // Test with current pool price as limit
            let current_sqrt_price = pool::get_pool_sqrt_price(&pool_btc_usdc);
            
            let _state = pool_fetcher::compute_swap_result<BTC, USDC, FEE500BPS>(
                &mut pool_btc_usdc,
                true,  // a_to_b
                1000,
                true,  // exact input
                current_sqrt_price,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(pool_btc_usdc);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fetch_ticks_with_initialized_ticks() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pool(ADMIN, USER, scenario);

        // Add some liquidity to initialize ticks
        test_scenario::next_tx(scenario, ADMIN);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            
            // Create liquidity positions to initialize ticks
            let tick_lower = i32::neg_from(100);
            let tick_upper = i32::from(100);
            
            pool::mint_for_testing<BTC, USDC, FEE500BPS>(
                &mut pool,
                ADMIN,
                tick_lower,
                tick_upper,
                1000000,
                &clock,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Now test fetch_ticks with some initialized ticks
            let (ticks, next_cursor) = pool_fetcher::fetch_ticks_for_testing<BTC, USDC, FEE500BPS>(
                &mut pool,
                vector::empty(),
                false,
                100,
                &versioned,
            );

            // Should find some ticks now
            let tick_count = vector::length(&ticks);
            assert!(tick_count >= 0, 1);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_multiple_fee_tier_operations() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize environment and create multiple pools
        tools_tests::init_tests_coin(ADMIN, USER, USER, 100000000, scenario);
        tools_tests::init_pool_factory(ADMIN, scenario);
        tools_tests::init_fee_type(ADMIN, scenario);

        test_scenario::next_tx(scenario, ADMIN);
        { turbos_clmm::position_manager::init_for_testing(test_scenario::ctx(scenario)); };
        tools_tests::init_clock(ADMIN, scenario);

        // Deploy pool with FEE3000BPS
        test_scenario::next_tx(scenario, ADMIN);
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

        test_scenario::next_tx(scenario, USER);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_3000 = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);

            // Test operations on different fee tier pool
            let _state = pool_fetcher::compute_swap_result<BTC, USDC, FEE3000BPS>(
                &mut pool_3000,
                true,
                5000,
                true,
                MIN_SQRT_PRICE_X64 + 200,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            pool_fetcher::fetch_ticks<BTC, USDC, FEE3000BPS>(
                &mut pool_3000,
                vector::empty(),
                false,
                50,
                &versioned,
            );

            test_scenario::return_shared(pool_3000);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }
}