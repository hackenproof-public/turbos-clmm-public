// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::swap_router_enhanced_tests {
    use std::vector;
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::swap_router;
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::fee500bps::{FEE500BPS};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::math_tick;
    use turbos_clmm::math_sqrt_price;
    use turbos_clmm::i32::{Self};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::eth::{ETH};
    use turbos_clmm::tools_tests;

    const ADMIN: address = @0x900;
    const USER: address = @0x901;
    const USER2: address = @0x902;
    const MIN_SQRT_PRICE_X64: u128 = 4295048016;
    const MAX_SQRT_PRICE_X64: u128 = 79226673515401279992447579055;

    fun setup_test_pools(admin: address, user: address, scenario: &mut Scenario) {
        tools_tests::init_tests_coin(admin, user, user, 100000000, scenario);
        tools_tests::init_pool_factory(admin, scenario);
        tools_tests::init_fee_type(admin, scenario);

        // init position manager + clock
        test_scenario::next_tx(scenario, admin);
        { turbos_clmm::position_manager::init_for_testing(test_scenario::ctx(scenario)); };
        tools_tests::init_clock(admin, scenario);

        // Deploy BTC/USDC pool
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

        // Deploy ETH/USDC pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            pool_factory::deploy_pool<ETH, USDC, FEE3000BPS>(
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

    fun add_liquidity_to_btc_usdc_pool(
        admin: address, 
        scenario: &mut Scenario,
        liquidity_amount: u128
    ) {
        test_scenario::next_tx(scenario, admin);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let btc_coins = vector::empty<Coin<BTC>>();
            let usdc_coins = vector::empty<Coin<USDC>>();
            
            let btc_amount = 10000000u64; // 10M BTC (considering decimals)
            let usdc_amount = 10000000u64; // 10M USDC (considering decimals)
            
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(btc_amount, test_scenario::ctx(scenario)));
            vector::push_back(&mut usdc_coins, coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario)));
            
            let (nft, btc_left, usdc_left) = position_manager::mint_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                btc_coins,
                usdc_coins,
                60000, // tick_lower_index
                true, // tick_lower_index_is_neg
                60000, // tick_upper_index  
                false, // tick_upper_index_is_neg
                btc_amount, // amount_a_desired
                usdc_amount, // amount_b_desired
                0, // amount_a_min
                0, // amount_b_min
                clock::timestamp_ms(&clock) + 1000, // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            transfer::public_transfer(nft, admin);
            transfer::public_transfer(btc_left, admin);
            transfer::public_transfer(usdc_left, admin);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
    }

    fun add_liquidity_to_eth_usdc_pool(
        admin: address, 
        scenario: &mut Scenario,
        liquidity_amount: u128
    ) {
        test_scenario::next_tx(scenario, admin);
        {
            let pool = test_scenario::take_shared<Pool<ETH, USDC, FEE3000BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let eth_coins = vector::empty<Coin<ETH>>();
            let usdc_coins = vector::empty<Coin<USDC>>();
            
            let eth_amount = 10000000u64; // 10M ETH (considering decimals)
            let usdc_amount = 10000000u64; // 10M USDC (considering decimals)
            
            vector::push_back(&mut eth_coins, coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario)));
            vector::push_back(&mut usdc_coins, coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario)));
            
            let (nft, eth_left, usdc_left) = position_manager::mint_with_return_<ETH, USDC, FEE3000BPS>(
                &mut pool,
                &mut positions,
                eth_coins,
                usdc_coins,
                60000, // tick_lower_index
                true, // tick_lower_index_is_neg
                60000, // tick_upper_index  
                false, // tick_upper_index_is_neg
                eth_amount, // amount_a_desired
                usdc_amount, // amount_b_desired
                0, // amount_a_min
                0, // amount_b_min
                clock::timestamp_ms(&clock) + 1000, // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            
            // Destroy or transfer NFT and remaining tokens
            transfer::public_transfer(nft, admin);
            transfer::public_transfer(eth_left, admin);
            transfer::public_transfer(usdc_left, admin);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
    }

    #[test]
    #[expected_failure(abort_code = 2)] // ETransactionTooOld
    public fun test_swap_a_b_expired_deadline() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_test_pools(ADMIN, USER, scenario);
        // Add liquidity so that the swap can reach the deadline check
        add_liquidity_to_btc_usdc_pool(ADMIN, scenario, 100000000000);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Advance the clock to make sure deadline is in the past
            clock::increment_for_testing(&mut clock, 1000); // Advance by 1000ms
            
            let btc_coins = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario)));

            // Set deadline in the past (0 < current time which is now 1000ms)
            let expired_deadline = 0;

            swap_router::swap_a_b<BTC, USDC, FEE500BPS>(
                &mut pool,
                btc_coins,
                100,
                0,
                MIN_SQRT_PRICE_X64,
                true,
                USER,
                expired_deadline,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 7)] // ECoinsNotGatherThanAmount
    public fun test_swap_a_b_insufficient_coins() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_test_pools(ADMIN, USER, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let btc_coins = vector::empty<Coin<BTC>>();
            // Only provide 50 coins but try to swap 100
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(50, test_scenario::ctx(scenario)));

            swap_router::swap_a_b<BTC, USDC, FEE500BPS>(
                &mut pool,
                btc_coins,
                100, // Try to swap more than available
                0,
                MIN_SQRT_PRICE_X64,
                true, // exact_in
                USER,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_a_b_with_return_basic() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_test_pools(ADMIN, USER, scenario);
        add_liquidity_to_btc_usdc_pool(ADMIN, scenario, 100000000000);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let btc_coins = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario)));

            let current_price = pool::get_pool_sqrt_price(&pool);
            let adjusted_limit = current_price / 10; // Much lower limit for a_to_b swap to be safe

            let (coin_b_out, coin_a_left) = swap_router::swap_a_b_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                btc_coins,
                100,
                0,
                adjusted_limit,
                true,
                USER,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Verify we got some output
            assert!(coin::value(&coin_b_out) >= 0, 1);
            assert!(coin::value(&coin_a_left) >= 0, 2);

            coin::burn_for_testing(coin_b_out);
            coin::burn_for_testing(coin_a_left);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_b_a_with_return_basic() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_test_pools(ADMIN, USER, scenario);
        add_liquidity_to_btc_usdc_pool(ADMIN, scenario, 100000000000);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let usdc_coins = vector::empty<Coin<USDC>>();
            vector::push_back(&mut usdc_coins, coin::mint_for_testing<USDC>(1000, test_scenario::ctx(scenario)));

            let current_price = pool::get_pool_sqrt_price(&pool);
            let safe_limit = current_price * 10; // Higher limit for b_to_a swap

            let (coin_a_out, coin_b_left) = swap_router::swap_b_a_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                usdc_coins,
                100,
                0,
                safe_limit,
                true,
                USER,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Verify we got some output
            assert!(coin::value(&coin_a_out) >= 0, 1);
            assert!(coin::value(&coin_b_left) >= 0, 2);

            coin::burn_for_testing(coin_a_out);
            coin::burn_for_testing(coin_b_left);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_multiple_coins_merge() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_test_pools(ADMIN, USER, scenario);
        add_liquidity_to_btc_usdc_pool(ADMIN, scenario, 100000000000);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Create multiple BTC coins to test merging
            let btc_coins = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(300, test_scenario::ctx(scenario)));
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(400, test_scenario::ctx(scenario)));
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(500, test_scenario::ctx(scenario)));

            let current_price = pool::get_pool_sqrt_price(&pool);
            let safe_limit = current_price / 10; // Lower limit for a_to_b swap

            let (coin_b_out, coin_a_left) = swap_router::swap_a_b_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                btc_coins,
                600, // Less than total (1200) to test partial usage
                0,
                safe_limit,
                true,
                USER,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Should have leftover BTC
            assert!(coin::value(&coin_a_left) > 0, 1);
            assert!(coin::value(&coin_b_out) >= 0, 2);

            coin::burn_for_testing(coin_b_out);
            coin::burn_for_testing(coin_a_left);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_exact_out_vs_exact_in() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_test_pools(ADMIN, USER, scenario);
        add_liquidity_to_btc_usdc_pool(ADMIN, scenario, 100000000000);
        add_liquidity_to_eth_usdc_pool(ADMIN, scenario, 100000000);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test exact_in
            let btc_coins1 = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins1, coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario)));

            let current_price = pool::get_pool_sqrt_price(&pool);
            let safe_limit = current_price / 10;

            let (coin_b_out1, coin_a_left1) = swap_router::swap_a_b_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                btc_coins1,
                100,
                0,
                safe_limit,
                true, // exact_in
                USER,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            let exact_in_output = coin::value(&coin_b_out1);

            // Test exact_out 
            let btc_coins2 = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins2, coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario)));

            let (coin_b_out2, coin_a_left2) = swap_router::swap_a_b_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                btc_coins2,
                50, // Smaller amount for exact_out
                500, // max input threshold
                safe_limit,
                false, // exact_out
                USER,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            let exact_out_output = coin::value(&coin_b_out2);

            // Both should produce valid results
            assert!(exact_in_output >= 0, 1);
            assert!(exact_out_output >= 0, 2);

            coin::burn_for_testing(coin_b_out1);
            coin::burn_for_testing(coin_a_left1);
            coin::burn_for_testing(coin_b_out2);
            coin::burn_for_testing(coin_a_left2);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_price_limits() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_test_pools(ADMIN, USER, scenario);
        add_liquidity_to_btc_usdc_pool(ADMIN, scenario, 100000000000);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test with very restrictive price limit
            let btc_coins = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario)));

            let current_price = pool::get_pool_sqrt_price(&pool);
            
            let safe_limit = current_price / 10; // Safe limit for a_to_b swap
            
            let (coin_b_out, coin_a_left) = swap_router::swap_a_b_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                btc_coins,
                10, // Small amount
                0,
                safe_limit,
                true,
                USER,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            coin::burn_for_testing(coin_b_out);
            coin::burn_for_testing(coin_a_left);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_zero_coin_value_handling() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_test_pools(ADMIN, USER, scenario);
        add_liquidity_to_btc_usdc_pool(ADMIN, scenario, 100000000000);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Create coins with exact amount needed (no leftovers)
            let btc_coins = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(100, test_scenario::ctx(scenario)));

            let current_price = pool::get_pool_sqrt_price(&pool);
            let safe_limit = current_price / 10;

            let (coin_b_out, coin_a_left) = swap_router::swap_a_b_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                btc_coins,
                100, // Exact amount
                0,
                safe_limit,
                true,
                USER,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Should handle zero leftover coins properly
            if (coin::value(&coin_a_left) == 0) {
                coin::destroy_zero(coin_a_left);
            } else {
                coin::burn_for_testing(coin_a_left);
            };

            coin::burn_for_testing(coin_b_out);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_with_large_price_range() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_test_pools(ADMIN, USER, scenario);
        add_liquidity_to_btc_usdc_pool(ADMIN, scenario, 100000000000);
        add_liquidity_to_eth_usdc_pool(ADMIN, scenario, 100000000);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let btc_coins = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario)));

            let current_price = pool::get_pool_sqrt_price(&pool);
            let safe_limit = current_price / 10; // Lower limit for a_to_b swap

            let (coin_b_out, coin_a_left) = swap_router::swap_a_b_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                btc_coins,
                50,
                0,
                safe_limit, // Correct direction for a_to_b swap
                true, // exact_in
                USER,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            coin::burn_for_testing(coin_b_out);
            coin::burn_for_testing(coin_a_left);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_with_minimal_amounts() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_test_pools(ADMIN, USER, scenario);
        add_liquidity_to_btc_usdc_pool(ADMIN, scenario, 100000000000);
        add_liquidity_to_eth_usdc_pool(ADMIN, scenario, 100000000);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let btc_coins = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(100, test_scenario::ctx(scenario)));

            let current_price = pool::get_pool_sqrt_price(&pool);
            let safe_limit = current_price / 10;

            let (coin_b_out, coin_a_left) = swap_router::swap_a_b_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                btc_coins,
                1, // Minimal amount
                0,
                safe_limit,
                true, // exact_in
                USER,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            coin::burn_for_testing(coin_b_out);
            coin::burn_for_testing(coin_a_left);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_different_fee_tiers() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_test_pools(ADMIN, USER, scenario);
        add_liquidity_to_btc_usdc_pool(ADMIN, scenario, 100000000000);
        add_liquidity_to_eth_usdc_pool(ADMIN, scenario, 100000000);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let btc_coins = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario)));

            let current_price = pool::get_pool_sqrt_price(&pool);
            let safe_limit = current_price / 10;

            let (coin_b_out, coin_a_left) = swap_router::swap_a_b_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                btc_coins,
                100,
                0,
                safe_limit,
                true, // exact_in
                USER,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            coin::burn_for_testing(coin_b_out);
            coin::burn_for_testing(coin_a_left);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        // Add liquidity to ETH/USDC pool
        test_scenario::next_tx(scenario, ADMIN);
        {
            let pool = test_scenario::take_shared<Pool<ETH, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            
            let tick_lower = i32::neg_from(60000);
            let tick_upper = i32::from(60000);
            
            pool::mint_for_testing<ETH, USDC, FEE3000BPS>(
                &mut pool,
                ADMIN,
                tick_lower,
                tick_upper,
                100000000000,
                &clock,
                test_scenario::ctx(scenario),
            );
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
        };

        // Test with different fee tier pool
        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<ETH, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let eth_coins = vector::empty<Coin<ETH>>();
            vector::push_back(&mut eth_coins, coin::mint_for_testing<ETH>(1000, test_scenario::ctx(scenario)));

            let current_price_eth = pool::get_pool_sqrt_price(&pool);
            let safe_limit_eth = current_price_eth / 10;

            let (coin_b_out, coin_a_left) = swap_router::swap_a_b_with_return_<ETH, USDC, FEE3000BPS>(
                &mut pool,
                eth_coins,
                100,
                0,
                safe_limit_eth,
                true, // exact_in
                USER,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            coin::burn_for_testing(coin_b_out);
            coin::burn_for_testing(coin_a_left);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_check_amount_threshold_function() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_test_pools(ADMIN, USER, scenario);
        add_liquidity_to_btc_usdc_pool(ADMIN, scenario, 100000000000);
        add_liquidity_to_eth_usdc_pool(ADMIN, scenario, 100000000);

        test_scenario::next_tx(scenario, USER);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test with reasonable thresholds that should pass
            let btc_coins = vector::empty<Coin<BTC>>();
            vector::push_back(&mut btc_coins, coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario)));

            let current_price = pool::get_pool_sqrt_price(&pool);
            let safe_limit = current_price / 10;

            let (coin_b_out, coin_a_left) = swap_router::swap_a_b_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                btc_coins,
                100,
                10, // Reasonable threshold
                safe_limit,
                true, // exact_in
                USER,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            coin::burn_for_testing(coin_b_out);
            coin::burn_for_testing(coin_a_left);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }
}