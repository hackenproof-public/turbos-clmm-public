// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::swap_inner_tests {
    use sui::test_utils::{assert_eq};
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::feemock10000bps::{FEEMOCK10000BPS};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::tools_tests;
    use turbos_clmm::math_tick;
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::i32::{Self};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::math_sqrt_price::{Self};
    use sui::clock::{Clock};

    const MAX_SQRT_PRICE_X64: u128 = 79226673515401279992447579055;
    const MIN_SQRT_PRICE_X64: u128 = 4295048016;

    fun prepare_tests(
        admin: address,
        player: address,
        player2: address, 
        scenario: &mut Scenario,
    ) {
        tools_tests::init_tests_coin(
            admin,
            player,
            player2,
            2000000,
            scenario
        );

        tools_tests::init_pool_factory(
            admin,
            scenario
        );

        tools_tests::init_fee_type(
            admin,
            scenario
        );

        tools_tests::set_fee_protocol(
            admin,
            250000,
            scenario
        );

        tools_tests::init_clock(
            admin,
            scenario
        );

        //init BTCUSDC pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEEMOCK10000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            pool_factory::deploy_pool<BTC, USDC, FEEMOCK10000BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_config);
            test_scenario::return_immutable(fee_type);
        };

        //pool with 2^64 liquidity, swap exactly 1e+12 tokenA to tokenB at tick 0 (p = 1) with 1.00%/250000 fee
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEEMOCK10000BPS>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEEMOCK10000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(1);
            let max_tick_index = math_tick::get_max_tick(1);
            let clock = test_scenario::take_shared<Clock>(scenario);


            let (amount_a, amount_b) = pool::mint_for_testing(
                &mut pool,
                player,
                min_tick_index,
                max_tick_index,
                18446744073709551616,
                &clock,
                test_scenario::ctx(scenario),
            );
            let tick = tools_tests::get_pool_tick_index(&mut pool);
            assert_eq(i32::eq(tick, i32::neg_from(0)), true);
            assert_eq(amount_a, 18446744069414503600);
            assert_eq(amount_b, 18446744069414503600);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_immutable(fee_type);
        };
    }

    #[test]
    public fun test_swap_a_b_exact_in() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEEMOCK10000BPS>>(scenario);
            let (amount_a, amount_b) = pool::swap_for_testing(
                &mut pool,
                player,
                true,
                1000000000000, //amount_in 
                true,
                MIN_SQRT_PRICE_X64 + 1,
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 1000000000000);
            assert_eq(amount_b, 989999946868);
            assert_eq(tools_tests::get_pool_tick_index(&pool), i32::neg_from(1));
            assert_eq(tools_tests::get_pool_sqrt_price(&pool), 18446743083709604748);
            let (fee_growth_global_a, fee_growth_global_b) = tools_tests::get_pool_fee_growth_global(&pool);
            assert_eq(fee_growth_global_a, 7500000000);
            assert_eq(fee_growth_global_b, 0);
            let (protocol_fees_a, protocol_fees_b) = tools_tests::get_pool_protocol_fees(&pool);
            assert_eq(protocol_fees_a, 2500000000);
            assert_eq(protocol_fees_b, 0);
            // test 
            let min_tick_index = math_tick::get_min_tick(1);
            let max_tick_index = math_tick::get_max_tick(1);
            pool::burn_for_testing(&mut pool, player, min_tick_index, max_tick_index, 0, &clock, test_scenario::ctx(scenario));
            let (
                liquidity,
                fee_growth_inside_a,
                fee_growth_inside_b,
                tokens_owed_a,
                tokens_owed_b
            ) = pool::get_position_info(&pool, player, min_tick_index, max_tick_index);
            assert_eq(liquidity, 18446744073709551616);
            assert_eq(fee_growth_inside_a, 7500000000);
            assert_eq(fee_growth_inside_b, 0);
            assert_eq(tokens_owed_a, 7500000000);
            assert_eq(tokens_owed_b, 0);

            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_b_a_exact_in() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEEMOCK10000BPS>>(scenario);
            let (amount_a, amount_b) = pool::swap_for_testing(
                &mut pool,
                player,
                false,
                1000000000000, //amount_in 
                true,
                MAX_SQRT_PRICE_X64 - 1,
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 989999946868);
            assert_eq(amount_b, 1000000000000);
            assert_eq(tools_tests::get_pool_tick_index(&pool), i32::zero());
            assert_eq(tools_tests::get_pool_sqrt_price(&pool), 18446745063709551616);
            let (fee_growth_global_a, fee_growth_global_b) = tools_tests::get_pool_fee_growth_global(&pool);
            assert_eq(fee_growth_global_a, 0);
            assert_eq(fee_growth_global_b, 7500000000);
            let (protocol_fees_a, protocol_fees_b) = tools_tests::get_pool_protocol_fees(&pool);
            assert_eq(protocol_fees_a, 0);
            assert_eq(protocol_fees_b, 2500000000);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_a_b_exact_out() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEEMOCK10000BPS>>(scenario);
            let (amount_a, amount_b) = pool::swap_for_testing(
                &mut pool,
                player,
                true,
                1000000000000, //amount_in 
                false,
                MIN_SQRT_PRICE_X64 + 1,
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 1010101064860);
            assert_eq(amount_b, 1000000000000);
            assert_eq(tools_tests::get_pool_tick_index(&pool), i32::neg_from(1));
            assert_eq(tools_tests::get_pool_sqrt_price(&pool), 18446743073709551616);
            let (fee_growth_global_a, fee_growth_global_b) = tools_tests::get_pool_fee_growth_global(&pool);
            assert_eq(fee_growth_global_a, 7575757987);
            assert_eq(fee_growth_global_b, 0);
            let (protocol_fees_a, protocol_fees_b) = tools_tests::get_pool_protocol_fees(&pool);
            assert_eq(protocol_fees_a, 2525252662);
            assert_eq(protocol_fees_b, 0);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_b_a_exact_out() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEEMOCK10000BPS>>(scenario);
            let (amount_a, amount_b) = pool::swap_for_testing(
                &mut pool,
                player,
                false,
                1000000000000, //amount_in 
                false,
                MAX_SQRT_PRICE_X64 - 1,
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 1000000000000);
            assert_eq(amount_b, 1010101064860);
            assert_eq(tools_tests::get_pool_tick_index(&pool), i32::zero());
            assert_eq(tools_tests::get_pool_sqrt_price(&pool), 18446745073709605827);
            let (fee_growth_global_a, fee_growth_global_b) = tools_tests::get_pool_fee_growth_global(&pool);
            assert_eq(fee_growth_global_a, 0);
            assert_eq(fee_growth_global_b, 7575757987);
            let (protocol_fees_a, protocol_fees_b) = tools_tests::get_pool_protocol_fees(&pool);
            assert_eq(protocol_fees_a, 0);
            assert_eq(protocol_fees_b, 2525252662);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario_val);
    }
}