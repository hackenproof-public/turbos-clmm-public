// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::protocol_fee_tests {
     use sui::coin::{Coin};
    use sui::test_utils::{assert_eq};
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::feemock10000bps::{FEEMOCK10000BPS};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::pool_factory::{AclConfig};
    use turbos_clmm::tools_tests;
    use turbos_clmm::math_tick;
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::i32::{Self};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::math_sqrt_price::{Self};
    use sui::clock::{Clock};
    use turbos_clmm::position_manager::{Self, Positions};

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
            100000000,
            scenario
        );

         //init pool position manager
        test_scenario::next_tx(scenario, player);
        {
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };

        tools_tests::init_pool_factory(
            player,
            scenario
        );

        tools_tests::init_fee_type(
            player,
            scenario
        );

        tools_tests::set_fee_protocol(
            player,
            250000,
            scenario
        );

        tools_tests::init_clock(
            player,
            scenario
        );

        //init BTCUSDC pool
        test_scenario::next_tx(scenario, player);
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
            test_scenario::return_shared(pool_config);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };

        //pool with 2^64 liquidity, swap exactly 1e+12 tokenA to tokenB at tick 0 (p = 1) with 1.00%/250000 fee
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEEMOCK10000BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEEMOCK10000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(1);
            let max_tick_index = math_tick::get_max_tick(1);
            position_manager::mint<BTC, USDC, FEEMOCK10000BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(btc),
                tools_tests::coin_to_vec(usdc),
                i32::abs_u32(min_tick_index),
                i32::is_neg(min_tick_index),
                i32::abs_u32(max_tick_index),
                i32::is_neg(max_tick_index),
                10000000,
                10000000,
                0,
                0,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
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
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEEMOCK10000BPS>>(scenario);
            pool::swap_for_testing(
                &mut pool,
                player,
                true,
                1000000, //amount_in 
                true,
                MIN_SQRT_PRICE_X64 + 1,
                &clock,
                test_scenario::ctx(scenario),
            );
            let (protocol_fees_a, protocol_fees_b) = tools_tests::get_pool_protocol_fees(&pool);
            assert_eq(protocol_fees_a, 2497);
            assert_eq(protocol_fees_b, 0);

            pool::swap_for_testing(
                &mut pool,
                player,
                false,
                1000000, //amount_in 
                true,
                MAX_SQRT_PRICE_X64 - 1,
                &clock,
                test_scenario::ctx(scenario),
            );
            let (protocol_fees_a, protocol_fees_b) = tools_tests::get_pool_protocol_fees(&pool);
            assert_eq(protocol_fees_a, 2497);
            assert_eq(protocol_fees_b, 2498);

            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };

        let (trader_balance_a_before, trader_balance_b_before);
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEEMOCK10000BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            trader_balance_a_before = tools_tests::get_user_coin_balance<BTC>(scenario);
            trader_balance_b_before = tools_tests::get_user_coin_balance<USDC>(scenario);
            pool_factory::collect_protocol_fee_v2(
                &acl_config,
                &mut pool,
                100,
                200,
                player,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };

        test_scenario::next_tx(scenario, player);
        {
            let trader_balance_a_after = tools_tests::get_user_coin_balance<BTC>(scenario);
            let trader_balance_b_after = tools_tests::get_user_coin_balance<USDC>(scenario);
            assert_eq(trader_balance_a_after, trader_balance_a_before + 100);
            assert_eq(trader_balance_b_after, trader_balance_b_before + 200);
        };

        let (trader_balance_a_before, trader_balance_b_before);
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEEMOCK10000BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            trader_balance_a_before = tools_tests::get_user_coin_balance<BTC>(scenario);
            trader_balance_b_before = tools_tests::get_user_coin_balance<USDC>(scenario);
            pool_factory::collect_protocol_fee_v2(
                &acl_config,
                &mut pool,
                100000000,
                100000000,
                player,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };

        test_scenario::next_tx(scenario, player);
        {
            let trader_balance_a_after = tools_tests::get_user_coin_balance<BTC>(scenario);
            let trader_balance_b_after = tools_tests::get_user_coin_balance<USDC>(scenario);
            assert_eq(trader_balance_a_after, trader_balance_a_before + 2397);
            assert_eq(trader_balance_b_after, trader_balance_b_before + 2298);
        };

        test_scenario::end(scenario_val);
    }
}