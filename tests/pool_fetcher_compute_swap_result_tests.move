// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::pool_fetcher_compute_swap_result_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_fetcher;
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::math_tick;
    use turbos_clmm::math_sqrt_price;
    use turbos_clmm::i32::{Self};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::tools_tests;

    const ADMIN: address = @0x900;
    const USER: address = @0x901;
    const MIN_SQRT_PRICE_X64: u128 = 4295048016;
    const MAX_SQRT_PRICE_X64: u128 = 79226673515401279992447579055;

    fun setup_pool_with_liquidity(admin: address, user: address, scenario: &mut Scenario) {
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

        // Provide liquidity
        test_scenario::next_tx(scenario, user);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_btc_usdc = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(60);
            let max_tick_index = math_tick::get_max_tick(60);

            turbos_clmm::position_manager::mint<BTC, USDC, FEE3000BPS>(
                &mut pool_btc_usdc,
                &mut positions,
                tools_tests::coin_to_vec(btc),
                tools_tests::coin_to_vec(usdc),
                i32::abs_u32(min_tick_index),
                i32::is_neg(min_tick_index),
                i32::abs_u32(max_tick_index),
                i32::is_neg(max_tick_index),
                1_000_000,
                1_000_000,
                0,
                0,
                user,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool_btc_usdc);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
    }

    #[test]
    public fun test_compute_swap_result_exact_in() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_pool_with_liquidity(ADMIN, USER, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_btc_usdc = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);

            // Just ensure it executes without abort (fields are internal)
            let _state = pool_fetcher::compute_swap_result<BTC, USDC, FEE3000BPS>(
                &mut pool_btc_usdc,
                true,  // a_to_b
                3,
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
    public fun test_compute_swap_result_exact_out() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_pool_with_liquidity(ADMIN, USER, scenario);

        test_scenario::next_tx(scenario, USER);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_btc_usdc = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);

            let _state = pool_fetcher::compute_swap_result<BTC, USDC, FEE3000BPS>(
                &mut pool_btc_usdc,
                false,  // a_to_b? here compute B->A path via exact out
                2,
                false,  // amount_specified_is_input = false (exact out)
                MAX_SQRT_PRICE_X64 - 1,
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
}

