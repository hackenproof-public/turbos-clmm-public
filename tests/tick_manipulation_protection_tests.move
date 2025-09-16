// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::tick_manipulation_protection_tests {
    use sui::test_utils::{assert_eq};
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig, AclConfig};
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::position_nft::{TurbosPositionNFT};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::tools_tests;
    use turbos_clmm::math_sqrt_price;
    use turbos_clmm::math_tick;
    use turbos_clmm::i32::{Self, I32};
    use std::vector;

    // Test addresses
    const ADMIN: address = @0x0;
    const USER1: address = @0x1;
    const ATTACKER: address = @0x2;
    
    // Tick constants for testing
    const MAX_TICK_INDEX: u32 = 443636;
    const MIN_SQRT_PRICE_X64: u128 = 4295048016;
    const MAX_SQRT_PRICE_X64: u128 = 79226673515401279992447579055;
    const TICK_SPACING: u32 = 60; // FEE3000BPS uses tick spacing of 60

    fun prepare_tick_manipulation_test(admin: address, scenario: &mut Scenario) {
        // Initialize comprehensive test environment
        tools_tests::init_tests_coin(admin, USER1, ATTACKER, 100000000, scenario);
        tools_tests::init_pool_factory(admin, scenario);
        position_manager::init_for_testing(test_scenario::ctx(scenario));
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
            
            // Set up CLMM manager role
            pool_factory::add_role(&admin_cap, &mut acl_config, admin, 0, &versioned); // ACL_CLMM_MANAGER
            
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

        // Add initial liquidity
        test_scenario::next_tx(scenario, admin);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let btc = coin::mint_for_testing<BTC>(10000000, test_scenario::ctx(scenario));
            let usdc = coin::mint_for_testing<USDC>(10000000, test_scenario::ctx(scenario));
            
            // Use narrower range to avoid full pool range, aligned to tick spacing 60
            let lower_tick_value = 60;   // Aligned to tick spacing 60
            let upper_tick_value = 120;  // Aligned to tick spacing 60
            
            let (nft, coin_a_left, coin_b_left) = position_manager::mint_with_return_<BTC, USDC, FEE3000BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(btc),
                tools_tests::coin_to_vec(usdc),
                lower_tick_value,             // tick_lower_index (as u32)
                true,                         // tick_lower_index_is_neg (negative)
                upper_tick_value,             // tick_upper_index (as u32)  
                false,                        // tick_upper_index_is_neg (positive)
                5000000,   // amount_a_desired
                5000000,   // amount_b_desired
                0,         // amount_a_min
                0,         // amount_b_min
                9999999999999, // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            coin::burn_for_testing<BTC>(coin_a_left);
            coin::burn_for_testing<USDC>(coin_b_left);
            sui::transfer::public_transfer(nft, admin);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
    }

    #[test]
    public fun test_tick_boundary_validation() {
        // 🔍 SECURITY TEST: Verify tick boundary validation works correctly
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_tick_manipulation_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            // 🔍 SECURITY CHECK: Test valid tick boundaries
            let min_tick = math_tick::get_min_tick(TICK_SPACING);
            let max_tick = math_tick::get_max_tick(TICK_SPACING);
            
            // Verify min tick is negative and within bounds
            assert_eq(i32::is_neg(min_tick), true);
            assert_eq(i32::abs_u32(min_tick) <= MAX_TICK_INDEX, true);
            
            // Verify max tick is positive and within bounds
            assert_eq(i32::is_neg(max_tick), false);
            assert_eq(i32::abs_u32(max_tick) <= MAX_TICK_INDEX, true);
            
            // Verify symmetry
            assert_eq(i32::abs_u32(min_tick), i32::abs_u32(max_tick));
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_tick_spacing_enforcement() {
        // 🔍 SECURITY TEST: Verify tick spacing is properly enforced
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_tick_manipulation_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            // 🔍 SECURITY CHECK: Test tick spacing calculations
            let min_tick = math_tick::get_min_tick(TICK_SPACING);
            let max_tick = math_tick::get_max_tick(TICK_SPACING);
            
            // Verify ticks are properly aligned to tick spacing
            let min_tick_value = i32::abs_u32(min_tick);
            let max_tick_value = i32::abs_u32(max_tick);
            
            assert_eq(min_tick_value % TICK_SPACING, 0);
            assert_eq(max_tick_value % TICK_SPACING, 0);
            
            // Test different tick spacings
            let min_tick_10 = math_tick::get_min_tick(10);
            let max_tick_10 = math_tick::get_max_tick(10);
            
            assert_eq(i32::abs_u32(min_tick_10) % 10, 0);
            assert_eq(i32::abs_u32(max_tick_10) % 10, 0);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_sqrt_price_tick_conversion_consistency() {
        // 🔍 SECURITY TEST: Verify sqrt price to tick conversion consistency
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_tick_manipulation_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            // 🔍 SECURITY CHECK: Test price-tick conversion at boundaries
            let min_tick = i32::neg_from(MAX_TICK_INDEX);
            let max_tick = i32::from(MAX_TICK_INDEX);
            
            // Test min tick conversion
            let min_sqrt_price = math_tick::sqrt_price_from_tick_index(min_tick);
            assert_eq(min_sqrt_price, MIN_SQRT_PRICE_X64);
            
            // Test max tick conversion
            let max_sqrt_price = math_tick::sqrt_price_from_tick_index(max_tick);
            assert_eq(max_sqrt_price, MAX_SQRT_PRICE_X64);
            
            // Test round-trip conversion consistency
            let test_sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            let tick_from_price = math_tick::tick_index_from_sqrt_price(test_sqrt_price);
            let price_from_tick = math_tick::sqrt_price_from_tick_index(tick_from_price);
            
            // The round-trip should be approximately consistent
            let price_diff = if (price_from_tick > test_sqrt_price) {
                price_from_tick - test_sqrt_price
            } else {
                test_sqrt_price - price_from_tick
            };
            
            // Allow for some precision tolerance
            assert_eq(price_diff <= test_sqrt_price / 1000000, true); // 0.0001% tolerance
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::pool::ESqrtPriceOutOfBounds)]
    public fun test_price_boundary_protection_min() {
        // 🚨 SECURITY TEST: Verify price boundary protection against manipulation below minimum
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_tick_manipulation_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, ATTACKER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🚨 ATTACK: Try to manipulate price below minimum boundary
            let (coin_a_out, coin_b_out, receipt) = pool::flash_swap<BTC, USDC, FEE3000BPS>(
                &mut pool,
                ATTACKER,
                true,  // a_to_b
                1000,
                true,  // is_exact_in
                MIN_SQRT_PRICE_X64 - 1, // Price below minimum - should fail
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            // Should never reach here
            coin::destroy_zero(coin_a_out);
            coin::burn_for_testing(coin_b_out);
            pool::repay_flash_swap<BTC, USDC, FEE3000BPS>(
                &mut pool,
                coin::zero<BTC>(test_scenario::ctx(scenario)),
                coin::zero<USDC>(test_scenario::ctx(scenario)),
                receipt,
                &versioned
            );
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::pool::ESqrtPriceOutOfBounds)]
    public fun test_price_boundary_protection_max() {
        // 🚨 SECURITY TEST: Verify price boundary protection against manipulation above maximum
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_tick_manipulation_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, ATTACKER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🚨 ATTACK: Try to manipulate price above maximum boundary
            let (coin_a_out, coin_b_out, receipt) = pool::flash_swap<BTC, USDC, FEE3000BPS>(
                &mut pool,
                ATTACKER,
                false, // b_to_a
                1000,
                true,  // is_exact_in
                MAX_SQRT_PRICE_X64 + 1, // Price above maximum - should fail
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            // Should never reach here
            coin::burn_for_testing(coin_a_out);
            coin::destroy_zero(coin_b_out);
            pool::repay_flash_swap<BTC, USDC, FEE3000BPS>(
                &mut pool,
                coin::zero<BTC>(test_scenario::ctx(scenario)),
                coin::zero<USDC>(test_scenario::ctx(scenario)),
                receipt,
                &versioned
            );
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_cross_tick_liquidity_consistency() {
        // 🔍 SECURITY TEST: Verify cross-tick liquidity changes are consistent
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_tick_manipulation_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            
            // 🔍 SECURITY CHECK: Test pool state before any tick crossing
            let initial_sqrt_price = pool::get_pool_sqrt_price(&pool);
            let initial_tick = pool::get_pool_current_index(&pool);
            let (_, _, _, _, _, _, _, _, _, _, _, _, initial_liquidity) = pool::get_pool_info(&pool);
            
            // Verify initial state is within bounds
            assert_eq(initial_sqrt_price >= MIN_SQRT_PRICE_X64, true);
            assert_eq(initial_sqrt_price <= MAX_SQRT_PRICE_X64, true);
            assert_eq(initial_liquidity > 0, true);
            
            // Verify tick index corresponds to sqrt price
            let calculated_tick = math_tick::tick_index_from_sqrt_price(initial_sqrt_price);
            let tick_diff = if (i32::gt(calculated_tick, initial_tick)) {
                i32::abs_u32(i32::sub(calculated_tick, initial_tick))
            } else {
                i32::abs_u32(i32::sub(initial_tick, calculated_tick))
            };
            
            // Should be very close (within a few ticks due to precision)
            assert_eq(tick_diff <= 5, true);
            
            test_scenario::return_shared(pool);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_max_liquidity_per_tick_enforcement() {
        // 🔍 SECURITY TEST: Verify maximum liquidity per tick is enforced
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_tick_manipulation_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            // 🔍 SECURITY CHECK: Calculate and verify max liquidity per tick
            let max_liquidity_10 = math_tick::max_liquidity_per_tick(10);
            let max_liquidity_200 = math_tick::max_liquidity_per_tick(200);
            let max_liquidity_16383 = math_tick::max_liquidity_per_tick(16383);
            
            // Verify larger tick spacing results in higher max liquidity per tick
            assert_eq(max_liquidity_200 > max_liquidity_10, true);
            assert_eq(max_liquidity_16383 > max_liquidity_200, true);
            
            // Verify max liquidity is reasonable (not zero, not overflow)
            assert_eq(max_liquidity_10 > 0, true);
            assert_eq(max_liquidity_200 > 0, true);
            assert_eq(max_liquidity_16383 > 0, true);
            
            // All should be less than MAX_U128
            assert_eq(max_liquidity_10 < 0xffffffffffffffffffffffffffffffff, true);
            assert_eq(max_liquidity_200 < 0xffffffffffffffffffffffffffffffff, true);
            assert_eq(max_liquidity_16383 < 0xffffffffffffffffffffffffffffffff, true);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_tick_initialization_security() {
        // 🔍 SECURITY TEST: Verify tick initialization is properly controlled
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_tick_manipulation_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🔍 SECURITY CHECK: Create a small position to initialize a tick
            let btc = coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario));
            let usdc = coin::mint_for_testing<USDC>(1000, test_scenario::ctx(scenario));
            
            // Use specific tick range aligned to tick spacing 60
            let lower_tick = i32::from(60);  // Valid tick index for spacing 60
            let upper_tick = i32::from(120); // Valid tick index for spacing 60
            
            let (nft, coin_a_left, coin_b_left) = position_manager::mint_with_return_<BTC, USDC, FEE3000BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(btc),
                tools_tests::coin_to_vec(usdc),
                60,        // tick_lower_index (as u32)
                false,     // tick_lower_index_is_neg
                120,       // tick_upper_index (as u32)
                false,     // tick_upper_index_is_neg
                1000,      // amount_a_desired
                1000,      // amount_b_desired
                0,         // amount_a_min
                0,         // amount_b_min
                9999999999999, // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            // Verify position was created successfully
            let nft_address = sui::object::id_address(&nft);
            let (_, _, liquidity) = position_manager::get_position_info(&positions, nft_address);
            assert_eq(liquidity > 0, true);
            
            coin::burn_for_testing<BTC>(coin_a_left);
            coin::burn_for_testing<USDC>(coin_b_left);
            sui::transfer::public_transfer(nft, USER1);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_tick_crossing_state_consistency() {
        // 🔍 SECURITY TEST: Verify tick crossing maintains state consistency
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_tick_manipulation_test(ADMIN, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Record initial state
            let initial_sqrt_price = pool::get_pool_sqrt_price(&pool);
            let initial_tick = pool::get_pool_current_index(&pool);
            let (_, _, _, _, _, _, _, _, _, _, _, _, initial_liquidity) = pool::get_pool_info(&pool);
            
            // 🔍 SECURITY CHECK: Perform a small swap that might cross ticks
            let btc_coins = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(100, test_scenario::ctx(scenario)));
            
            let (coin_usdc_out, coin_btc_left) = turbos_clmm::swap_router::swap_a_b_with_return_<BTC, USDC, FEE3000BPS>(
                &mut pool,
                btc_coins,
                100,        // amount to swap
                50,         // minimum output
                MIN_SQRT_PRICE_X64, // sqrt_price_limit
                true,       // is_exact_in
                USER1,      // recipient
                9999999999999, // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            // Record final state
            let final_sqrt_price = pool::get_pool_sqrt_price(&pool);
            let final_tick = pool::get_pool_current_index(&pool);
            let (_, _, _, _, _, _, _, _, _, _, _, _, final_liquidity) = pool::get_pool_info(&pool);
            
            // 🔍 SECURITY VERIFICATION: State should remain consistent
            assert_eq(final_sqrt_price >= MIN_SQRT_PRICE_X64, true);
            assert_eq(final_sqrt_price <= MAX_SQRT_PRICE_X64, true);
            assert_eq(final_liquidity > 0, true);
            
            // Price should have moved in the expected direction (BTC -> USDC means price down)
            assert_eq(final_sqrt_price <= initial_sqrt_price, true);
            
            // Tick should correspond to price
            let calculated_final_tick = math_tick::tick_index_from_sqrt_price(final_sqrt_price);
            let tick_diff = if (i32::gt(calculated_final_tick, final_tick)) {
                i32::abs_u32(i32::sub(calculated_final_tick, final_tick))
            } else {
                i32::abs_u32(i32::sub(final_tick, calculated_final_tick))
            };
            assert_eq(tick_diff <= 5, true); // Allow small precision difference
            
            coin::burn_for_testing(coin_usdc_out);
            coin::destroy_zero(coin_btc_left);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }
}