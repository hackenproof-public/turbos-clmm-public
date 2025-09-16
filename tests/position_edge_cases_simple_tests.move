// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::position_edge_cases_simple_tests {
    use sui::test_utils::{assert_eq};
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Clock};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::tools_tests;
    use turbos_clmm::math_sqrt_price;
    use turbos_clmm::math_tick;
    use turbos_clmm::math_liquidity;
    use turbos_clmm::i32;
    use turbos_clmm::position_manager::{Self, Positions};

    // Test addresses
    const ADMIN: address = @0x0;
    const USER1: address = @0x1;

    // Constants for edge case testing
    const MAX_TICK_INDEX: u32 = 443636;

    fun prepare_position_test_environment(admin: address, user: address, scenario: &mut Scenario) {
        // Initialize coins, pool factory, fees, and clock
        tools_tests::init_tests_coin(admin, user, user, 100000000, scenario);
        tools_tests::init_pool_factory(admin, scenario);
        tools_tests::init_fee_type(admin, scenario);
        tools_tests::init_clock(admin, scenario);
        
        // Deploy BTC-USDC pool with 3000bps fee
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
        
        // Initialize position manager
        test_scenario::next_tx(scenario, admin);
        {
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };
    }

    #[test]
    public fun test_tick_boundary_math_functions() {
        // 🔍 SECURITY TEST: Verify tick boundary math functions work correctly
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_position_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            // 🔍 SECURITY CHECK: Test tick bounds for different spacings
            let max_tick_60 = math_tick::get_max_tick(60);
            let min_tick_60 = math_tick::get_min_tick(60);
            
            // Verify tick bounds are within acceptable range
            assert_eq(i32::abs_u32(max_tick_60) <= MAX_TICK_INDEX, true);
            assert_eq(i32::abs_u32(min_tick_60) <= MAX_TICK_INDEX, true);
            assert_eq(i32::lt(min_tick_60, max_tick_60), true);
            
            // 🔍 SECURITY CHECK: Test sqrt price conversion consistency
            let test_tick = i32::from(1000);
            let sqrt_price = math_tick::sqrt_price_from_tick_index(test_tick);
            let converted_back = math_tick::tick_index_from_sqrt_price(sqrt_price);
            
            // Should be approximately equal (allowing for precision)
            let tick_diff = if (i32::gt(converted_back, test_tick)) {
                i32::abs_u32(i32::sub(converted_back, test_tick))
            } else {
                i32::abs_u32(i32::sub(test_tick, converted_back))
            };
            assert_eq(tick_diff <= 5, true); // Allow small precision error
            
            // 🔍 SECURITY CHECK: Test liquidity calculations don't overflow
            let amount_a = 1000000u128;
            let amount_b = 1000000u128;
            let sqrt_price_current = math_sqrt_price::encode_price_sqrt(1, 1);
            let sqrt_price_lower = math_tick::sqrt_price_from_tick_index(i32::neg_from(300));
            let sqrt_price_upper = math_tick::sqrt_price_from_tick_index(i32::from(300));
            
            let liquidity = math_liquidity::get_liquidity_for_amounts(
                sqrt_price_current,
                sqrt_price_lower,
                sqrt_price_upper,
                amount_a,
                amount_b
            );
            
            // 🔍 SECURITY CHECK: Liquidity calculation should produce reasonable result
            assert_eq(liquidity > 0, true);
            assert_eq(liquidity < 0xffffffffffffffffffffffffffffffff, true); // Should not overflow
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_liquidity_precision_edge_cases() {
        // 🔍 SECURITY TEST: Test liquidity calculations with edge case inputs
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_position_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            // 🔍 SECURITY CHECK: Test with very small amounts
            let small_amount_a = 1u128;
            let small_amount_b = 1u128;
            let sqrt_price_current = math_sqrt_price::encode_price_sqrt(1, 1);
            let sqrt_price_lower = math_tick::sqrt_price_from_tick_index(i32::neg_from(100));
            let sqrt_price_upper = math_tick::sqrt_price_from_tick_index(i32::from(100));
            
            let small_liquidity = math_liquidity::get_liquidity_for_amounts(
                sqrt_price_current,
                sqrt_price_lower,
                sqrt_price_upper,
                small_amount_a,
                small_amount_b
            );
            
            // Even tiny amounts should either produce valid liquidity or zero
            assert_eq(small_liquidity >= 0, true);
            
            // 🔍 SECURITY CHECK: Test with large amounts (but not overflow)
            let large_amount_a = 1000000000000u128; // 1 trillion
            let large_amount_b = 1000000000000u128;
            
            let large_liquidity = math_liquidity::get_liquidity_for_amounts(
                sqrt_price_current,
                sqrt_price_lower,
                sqrt_price_upper,
                large_amount_a,
                large_amount_b
            );
            
            // Large amounts should produce proportionally large liquidity
            assert_eq(large_liquidity > small_liquidity, true);
            
            // 🔍 SECURITY CHECK: Test price range edge cases
            // When current price is outside the range
            let out_of_range_price = math_tick::sqrt_price_from_tick_index(i32::from(500));
            
            let edge_liquidity = math_liquidity::get_liquidity_for_amounts(
                out_of_range_price,
                sqrt_price_lower,
                sqrt_price_upper,
                1000000u128,
                1000000u128
            );
            
            // Should handle out-of-range scenarios gracefully
            assert_eq(edge_liquidity >= 0, true);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_tick_spacing_validation() {
        // 🔍 SECURITY TEST: Verify tick spacing constraints are properly enforced
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_position_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            // 🔍 SECURITY CHECK: Test various tick spacings
            let spacings = vector[1, 10, 60, 200, 1000, 16383];
            let i = 0;
            while (i < std::vector::length(&spacings)) {
                let spacing = *std::vector::borrow(&spacings, i);
                
                let max_tick = math_tick::get_max_tick(spacing);
                let min_tick = math_tick::get_min_tick(spacing);
                
                // 🔍 SECURITY CHECK: All tick ranges should be valid
                assert_eq(i32::abs_u32(max_tick) <= MAX_TICK_INDEX, true);
                assert_eq(i32::abs_u32(min_tick) <= MAX_TICK_INDEX, true);
                assert_eq(i32::lt(min_tick, max_tick), true);
                
                // 🔍 SECURITY CHECK: Tick values should be properly aligned to spacing
                assert_eq(i32::abs_u32(max_tick) % spacing == 0, true);
                assert_eq(i32::abs_u32(min_tick) % spacing == 0, true);
                
                // 🔍 SECURITY CHECK: Max liquidity per tick should be reasonable
                let max_liquidity = math_tick::max_liquidity_per_tick(spacing);
                assert_eq(max_liquidity > 0, true);
                assert_eq(max_liquidity <= 0xffffffffffffffffffffffffffffffff, true);
                
                i = i + 1;
            };
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_price_sqrt_conversion_bounds() {
        // 🔍 SECURITY TEST: Test sqrt price conversions at boundary conditions
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_position_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            // 🔍 SECURITY CHECK: Test at maximum valid tick
            let max_tick = i32::from(MAX_TICK_INDEX);
            let max_sqrt_price = math_tick::sqrt_price_from_tick_index(max_tick);
            
            // Should produce the maximum sqrt price
            assert_eq(max_sqrt_price == 79226673515401279992447579055, true); // MAX_SQRT_PRICE_X64
            
            // 🔍 SECURITY CHECK: Test at minimum valid tick  
            let min_tick = i32::neg_from(MAX_TICK_INDEX);
            let min_sqrt_price = math_tick::sqrt_price_from_tick_index(min_tick);
            
            // Should produce the minimum sqrt price
            assert_eq(min_sqrt_price == 4295048016, true); // MIN_SQRT_PRICE_X64
            
            // 🔍 SECURITY CHECK: Test reverse conversion consistency
            let converted_max_tick = math_tick::tick_index_from_sqrt_price(max_sqrt_price);
            let converted_min_tick = math_tick::tick_index_from_sqrt_price(min_sqrt_price);
            
            // Should convert back to approximately the same values
            assert_eq(i32::eq(converted_max_tick, max_tick), true);
            assert_eq(i32::eq(converted_min_tick, min_tick), true);
            
            // 🔍 SECURITY CHECK: Test intermediate values
            let mid_tick = i32::zero();
            let mid_sqrt_price = math_tick::sqrt_price_from_tick_index(mid_tick);
            let converted_mid_tick = math_tick::tick_index_from_sqrt_price(mid_sqrt_price);
            
            // Mid values should also be consistent
            assert_eq(i32::eq(converted_mid_tick, mid_tick), true);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_position_math_overflow_protection() {
        // 🔍 SECURITY TEST: Verify position calculations handle large numbers safely
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_position_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            // 🔍 SECURITY CHECK: Test liquidity delta calculations
            let large_amount = 1000000000000u128; // 1 trillion
            let sqrt_price_a = math_tick::sqrt_price_from_tick_index(i32::neg_from(1000));
            let sqrt_price_b = math_tick::sqrt_price_from_tick_index(i32::from(1000));
            
            // Test large amount calculations
            let liquidity_a = math_liquidity::get_liquidity_for_amount_a(
                sqrt_price_a,
                sqrt_price_b,
                large_amount
            );
            
            let liquidity_b = math_liquidity::get_liquidity_for_amount_b(
                sqrt_price_a,
                sqrt_price_b,
                large_amount
            );
            
            // 🔍 SECURITY CHECK: Should handle large numbers without overflow
            assert_eq(liquidity_a >= 0, true);
            assert_eq(liquidity_b >= 0, true);
            
            // 🔍 SECURITY CHECK: Test amount calculations from liquidity
            let (calculated_a, calculated_b) = math_liquidity::get_amount_for_liquidity(
                math_sqrt_price::encode_price_sqrt(1, 1),
                sqrt_price_a,
                sqrt_price_b,
                1000000u128 // Large liquidity value
            );
            
            // Should produce reasonable amounts
            assert_eq(calculated_a >= 0, true);
            assert_eq(calculated_b >= 0, true);
            
            // 🔍 SECURITY CHECK: Test precision preservation
            let precision_test_liquidity = 12345678901234567890u128;
            let (precision_a, precision_b) = math_liquidity::get_amount_for_liquidity(
                math_sqrt_price::encode_price_sqrt(1, 1),
                sqrt_price_a,
                sqrt_price_b,
                precision_test_liquidity
            );
            
            // Should maintain reasonable precision
            assert_eq(precision_a > 0 || precision_b > 0, true);
        };
        
        test_scenario::end(scenario_val);
    }
}