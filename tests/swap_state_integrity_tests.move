// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::swap_state_integrity_tests {
    use sui::test_utils::{assert_eq};
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Clock};
    use turbos_clmm::pool::{Self, Pool, Versioned, FlashSwapReceipt};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::swap_router::{Self};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::tools_tests;
    use turbos_clmm::math_sqrt_price;
    use turbos_clmm::math_tick;
    use turbos_clmm::i32;
    use turbos_clmm::position_manager::{Self, Positions};
    use sui::coin::{Self, Coin};
    use std::vector;

    // Test addresses
    const ADMIN: address = @0x0;
    const USER1: address = @0x1;

    fun prepare_swap_test_environment(admin: address, user: address, scenario: &mut Scenario) {
        // Initialize coins, pool factory, fees, and clock
        tools_tests::init_tests_coin(admin, user, user, 100000000, scenario);
        tools_tests::init_pool_factory(admin, scenario);
        tools_tests::init_fee_type(admin, scenario);
        tools_tests::init_clock(admin, scenario);
        
        // Deploy BTC-USDC pool
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
        
        // Initialize position manager and add liquidity
        test_scenario::next_tx(scenario, admin);
        {
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let btc = test_scenario::take_from_sender<sui::coin::Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<sui::coin::Coin<USDC>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let min_tick_index = math_tick::get_min_tick(60);
            let max_tick_index = math_tick::get_max_tick(60);

            position_manager::mint<BTC, USDC, FEE3000BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(btc),
                tools_tests::coin_to_vec(usdc),
                i32::abs_u32(min_tick_index),
                i32::is_neg(min_tick_index),
                i32::abs_u32(max_tick_index),
                i32::is_neg(max_tick_index),
                50000000,  // amount_a_max  
                50000000,  // amount_b_max
                0,         // amount_a_min
                0,         // amount_b_min
                user,      // recipient
                1,         // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
    }

    #[test]
    public fun test_swap_calculation_precision() {
        // 🔍 SECURITY TEST: Verify swap calculations maintain precision and consistency
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_swap_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let initial_sqrt_price = pool::get_pool_sqrt_price(&pool);
            
            // Create input coins vector for swap_router
            let btc_coins = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario)));
            
            // Test small exact-in swap using real swap_router
            let (coin_usdc_out, coin_btc_left) = swap_router::swap_a_b_with_return_<BTC, USDC, FEE3000BPS>(
                &mut pool,
                btc_coins,
                1000,       // amount to swap
                500,        // minimum output (50% of input as safety)
                4295048016, // min sqrt_price_limit
                true,       // is_exact_in
                USER1,      // recipient
                9999999999999, // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            let amount_a = 1000; // Input amount
            let amount_b = coin::value(&coin_usdc_out);
            
            // 🔍 SECURITY CHECK: Amounts should be reasonable
            assert_eq(amount_a > 0, true);
            assert_eq(amount_b > 0, true);
            assert_eq(coin::value(&coin_btc_left), 0); // Should be zero for exact-in
            
            // 🔍 SECURITY CHECK: Price should change reasonably
            let new_sqrt_price = pool::get_pool_sqrt_price(&pool);
            
            // Price should decrease when selling A for B
            assert_eq(new_sqrt_price < initial_sqrt_price, true);
            
            // 🔍 SECURITY CHECK: Tick should be consistent with price
            let new_tick = pool::get_pool_current_index(&pool);
            let expected_tick = math_tick::tick_index_from_sqrt_price(new_sqrt_price);
            assert_eq(i32::eq(new_tick, expected_tick), true);
            
            // Clean up coins
            coin::burn_for_testing(coin_usdc_out);
            coin::destroy_zero(coin_btc_left);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_price_impact_bounds() {
        // 🔍 SECURITY TEST: Verify large swaps respect price limits using flash_swap
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_swap_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let initial_sqrt_price = pool::get_pool_sqrt_price(&pool);
            
            // Test large swap with price limit using flash_swap
            let large_amount = 50000u128; // Reduced for available liquidity
            let reasonable_price_limit = initial_sqrt_price * 90 / 100; // 10% price move limit
            
            // Use flash_swap to perform the swap
            let (coin_a_out, coin_b_out, receipt) = pool::flash_swap<BTC, USDC, FEE3000BPS>(
                &mut pool,
                USER1,
                true,  // a_to_b (sell BTC for USDC)
                large_amount,
                true,  // is_exact_in
                reasonable_price_limit,
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            // Get payment info from receipt
            let (pool_id, a_to_b, pay_amount) = pool::get_flash_swap_receipt_info(&receipt);
            
            // 🔍 SECURITY CHECK: Swap should complete with reasonable amounts
            let amount_a = pay_amount;
            let amount_b = coin::value(&coin_b_out);
            assert_eq(amount_a > 0, true);
            assert_eq(amount_b > 0, true);
            assert_eq(coin::value(&coin_a_out), 0); // Should be zero for a_to_b
            
            // 🔍 SECURITY CHECK: Price should not exceed limit
            let final_sqrt_price = pool::get_pool_sqrt_price(&pool);
            assert_eq(final_sqrt_price >= reasonable_price_limit, true);
            
            // 🔍 SECURITY CHECK: Price impact should be reasonable (max 15%)
            let price_impact_ratio = (initial_sqrt_price - final_sqrt_price) * 100 / initial_sqrt_price;
            assert_eq(price_impact_ratio <= 15, true);
            
            // Repay the flash swap
            let payment_coin = coin::mint_for_testing<BTC>((pay_amount as u64), test_scenario::ctx(scenario));
            pool::repay_flash_swap<BTC, USDC, FEE3000BPS>(
                &mut pool,
                payment_coin,
                coin::zero<USDC>(test_scenario::ctx(scenario)),
                receipt,
                &versioned
            );
            
            // Clean up coins
            coin::destroy_zero(coin_a_out);
            coin::burn_for_testing(coin_b_out);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::pool::ESqrtPriceOutOfBounds)]
    public fun test_price_bounds_protection() {
        // 🚨 SECURITY TEST: Verify out-of-bounds price limits are rejected
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_swap_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🚨 ATTACK: Try flash_swap with invalid price limit (should fail)
            let (coin_a_out, coin_b_out, receipt) = pool::flash_swap<BTC, USDC, FEE3000BPS>(
                &mut pool,
                USER1,
                true,  // a_to_b
                1000,
                true,  // is_exact_in
                79226673515401279992447579056,  // Price above MAX_SQRT_PRICE
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            // Should never reach here - clean up if somehow we do
            coin::destroy_zero(coin_a_out);
            coin::burn_for_testing(coin_b_out);
            // Cannot destructure FlashSwapReceipt outside pool module, repay to clean up
            pool::repay_flash_swap<BTC, USDC, FEE3000BPS>(
                &mut pool,
                coin::zero<BTC>(test_scenario::ctx(scenario)),
                coin::zero<USDC>(test_scenario::ctx(scenario)),
                receipt,
                &versioned
            );
            abort 999
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::pool::EInvalidSqrtPriceLimitDirection)]
    public fun test_price_direction_protection() {
        // 🚨 SECURITY TEST: Verify incorrect price direction is rejected
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_swap_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let current_price = pool::get_pool_sqrt_price(&pool);
            
            // 🚨 ATTACK: Try A->B swap with price limit higher than current (wrong direction)
            let (coin_a_out, coin_b_out, receipt) = pool::flash_swap<BTC, USDC, FEE3000BPS>(
                &mut pool,
                USER1,
                true,  // a_to_b (price should go down)
                1000,
                true,  // is_exact_in
                current_price + 1000000,  // Price limit higher than current (wrong direction)
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            // Should never reach here - clean up if somehow we do
            coin::destroy_zero(coin_a_out);
            coin::burn_for_testing(coin_b_out);
            // Cannot destructure FlashSwapReceipt outside pool module, repay to clean up
            pool::repay_flash_swap<BTC, USDC, FEE3000BPS>(
                &mut pool,
                coin::zero<BTC>(test_scenario::ctx(scenario)),
                coin::zero<USDC>(test_scenario::ctx(scenario)),
                receipt,
                &versioned
            );
            abort 999
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::pool::ESwapAmountSpecifiedZero)]
    public fun test_zero_amount_swap_protection() {
        // 🚨 SECURITY TEST: Verify zero amount swaps are rejected
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_swap_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // 🚨 ATTACK: Try zero amount flash swap (should fail)
            let (coin_a_out, coin_b_out, receipt) = pool::flash_swap<BTC, USDC, FEE3000BPS>(
                &mut pool,
                USER1,
                true,  // a_to_b
                0,     // zero amount - should trigger error
                true,  // is_exact_in
                4295048016,
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            // Should never reach here - clean up if somehow we do
            coin::destroy_zero(coin_a_out);
            coin::burn_for_testing(coin_b_out);
            // Cannot destructure FlashSwapReceipt outside pool module, repay to clean up
            pool::repay_flash_swap<BTC, USDC, FEE3000BPS>(
                &mut pool,
                coin::zero<BTC>(test_scenario::ctx(scenario)),
                coin::zero<USDC>(test_scenario::ctx(scenario)),
                receipt,
                &versioned
            );
            abort 999
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_fee_application() {
        // 🔍 SECURITY TEST: Verify fees are properly applied and calculated using swap_router
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_swap_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Record initial pool state for fee verification
            let initial_sqrt_price = pool::get_pool_sqrt_price(&pool);
            
            // Create input coins vector for swap_router
            let btc_coins = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(10000, test_scenario::ctx(scenario)));
            
            // Perform swap to generate fees using swap_router
            let (coin_usdc_out, coin_btc_left) = swap_router::swap_a_b_with_return_<BTC, USDC, FEE3000BPS>(
                &mut pool,
                btc_coins,
                10000,      // amount to swap
                5000,       // minimum output (50% of input as safety)
                4295048016, // min sqrt_price_limit
                true,       // is_exact_in
                USER1,      // recipient
                9999999999999, // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            let amount_a = 10000; // Input amount
            let amount_b = coin::value(&coin_usdc_out);
            let final_sqrt_price = pool::get_pool_sqrt_price(&pool);
            
            // 🔍 SECURITY CHECK: Fees should be generated and swap completed
            assert_eq(amount_a > 0, true);
            assert_eq(amount_b > 0, true);
            assert_eq(coin::value(&coin_btc_left), 0); // Should be zero for exact-in
            
            // 🔍 SECURITY CHECK: Price should change due to swap (indicating fees and impact)
            assert_eq(final_sqrt_price != initial_sqrt_price, true);
            
            // 🔍 SECURITY CHECK: Fee calculation should be reasonable (3000bps = 0.3%)
            // Since we can't directly access protocol fees, verify swap amounts are reasonable
            let output_ratio = amount_b * 1000 / amount_a; // Should be close to 1000 (1:1 price) minus fees
            assert_eq(output_ratio < 1000, true); // Output should be less due to fees
            assert_eq(output_ratio > 950, true); // But not too much less (reasonable fee)
            
            // Clean up coins
            coin::burn_for_testing(coin_usdc_out);
            coin::destroy_zero(coin_btc_left);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }
}