// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::swap_router_tests {
    use sui::test_utils::{assert_eq};
    use sui::coin::{Coin};
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::eth::{ETH};
    use turbos_clmm::sui::{SUI};
    use turbos_clmm::trb::{TRB};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::tools_tests;
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::i32::{Self};
    use turbos_clmm::math_tick;
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::swap_router;
    use turbos_clmm::position_manager_tests;
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
            100000000,
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
            100000,
            scenario
        );

        tools_tests::init_clock(
            player,
            scenario
        );

        //init BTCUSDC pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            //price=1, 1btc = 1usdc
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
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool_config);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };

        //init ETHUSDC pool
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
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool_config);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };

        //init USDCSUI pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);

            //price=1, 1sui = 1usdc
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            pool_factory::deploy_pool<USDC, SUI, FEE3000BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(clock);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };

        //init USDCTRB pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            pool_factory::deploy_pool<USDC, TRB, FEE3000BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(clock);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };

        //add liquidity
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(60);
            let max_tick_index = math_tick::get_max_tick(60);

            //btc
            position_manager::mint<BTC, USDC, FEE3000BPS>(
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

            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        //add liquidity
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<USDC, SUI, FEE3000BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let sui = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(60);
            let max_tick_index = math_tick::get_max_tick(60);

            position_manager::mint<USDC, SUI, FEE3000BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(usdc),
                tools_tests::coin_to_vec(sui),
                i32::abs_u32(min_tick_index),
                i32::is_neg(min_tick_index),
                i32::abs_u32(max_tick_index),
                i32::is_neg(max_tick_index),
                1000000,
                1000000,
                0,
                0,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        //add liquidity
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<ETH, USDC, FEE3000BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let eth = test_scenario::take_from_sender<Coin<ETH>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(60);
            let max_tick_index = math_tick::get_max_tick(60);

            position_manager::mint<ETH, USDC, FEE3000BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(eth),
                tools_tests::coin_to_vec(usdc),
                i32::abs_u32(min_tick_index),
                i32::is_neg(min_tick_index),
                i32::abs_u32(max_tick_index),
                i32::is_neg(max_tick_index),
                1000000,
                1000000,
                0,
                0,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        //add liquidity
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<USDC, TRB, FEE3000BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let trb = test_scenario::take_from_sender<Coin<TRB>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(60);
            let max_tick_index = math_tick::get_max_tick(60);

            position_manager::mint<USDC, TRB, FEE3000BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(usdc),
                tools_tests::coin_to_vec(trb),
                i32::abs_u32(min_tick_index),
                i32::is_neg(min_tick_index),
                i32::abs_u32(max_tick_index),
                i32::is_neg(max_tick_index),
                1000000,
                1000000,
                0,
                0,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
    }

    #[test]
    public fun test_swap_a_b_exact_in() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        let (balance_a_before, balance_b_before);
        let (trader_balance_a_before, trader_balance_b_before);
        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            //pool balance before
            (balance_a_before, balance_b_before) = pool::get_pool_balance(&mut pool_a);

            //get trader balance before
            let coins;
            (coins, trader_balance_a_before) = tools_tests::get_user_coin<BTC>(scenario);
            trader_balance_b_before = tools_tests::get_user_coin_balance<USDC>(scenario);

            swap_router::swap_a_b(
                &mut pool_a,
                coins,
                3, //amount_in 
                1, //amount_threshold
                MIN_SQRT_PRICE_X64 + 1,
                true,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
        };

        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let (balance_a_after, balance_b_after) = pool::get_pool_balance(&mut pool_a);
            let trader_balance_a_after = tools_tests::get_user_coin_balance<BTC>(scenario);
            let trader_balance_b_after = tools_tests::get_user_coin_balance<USDC>(scenario);

            assert_eq(balance_a_after - balance_a_before, 3);
            assert_eq(balance_b_before - balance_b_after, 1);
            assert_eq(trader_balance_a_before - trader_balance_a_after, 3);
            assert_eq(trader_balance_b_after - trader_balance_b_before, 1);

            test_scenario::return_shared(pool_a);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_a_b_exact_out() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        let (balance_a_before, balance_b_before);
        let (trader_balance_a_before, trader_balance_b_before);
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);

            //pool balance before
            (balance_a_before, balance_b_before) = pool::get_pool_balance(&mut pool_a);

            //get trader balance before
            let coins;
            (coins, trader_balance_a_before) = tools_tests::get_user_coin<BTC>(scenario);
            trader_balance_b_before = tools_tests::get_user_coin_balance<USDC>(scenario);

            swap_router::swap_a_b(
                &mut pool_a,
                coins,
                3, //amount_in 
                10, //amount_threshold
                MIN_SQRT_PRICE_X64 + 1,
                false,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
        };

        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let (balance_a_after, balance_b_after) = pool::get_pool_balance(&pool_a);
            let trader_balance_a_after = tools_tests::get_user_coin_balance<BTC>(scenario);
            let trader_balance_b_after = tools_tests::get_user_coin_balance<USDC>(scenario);

            assert_eq(balance_a_after - balance_a_before, 4);
            assert_eq(balance_b_before - balance_b_after, 3);
            assert_eq(trader_balance_a_before - trader_balance_a_after, 4);
            assert_eq(trader_balance_b_after - trader_balance_b_before, 3);

            test_scenario::return_shared(pool_a);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_b_a() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        let (balance_a_before, balance_b_before);
        let (trader_balance_a_before, trader_balance_b_before);
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);

            //pool balance before
            (balance_a_before, balance_b_before) = pool::get_pool_balance(&mut pool_a);

            //get trader balance before
            let coins;
            (coins, trader_balance_b_before) = tools_tests::get_user_coin<USDC>(scenario);
            trader_balance_a_before = tools_tests::get_user_coin_balance<BTC>(scenario);

            swap_router::swap_b_a(
                &mut pool_a,
                coins,
                3, //amount_in 
                1, //amount_threshold
                MAX_SQRT_PRICE_X64 - 1,
                true,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
        };

        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let (balance_a_after, balance_b_after) = pool::get_pool_balance(&mut pool_a);
            let trader_balance_a_after = tools_tests::get_user_coin_balance<BTC>(scenario);
            let trader_balance_b_after = tools_tests::get_user_coin_balance<USDC>(scenario);

            assert_eq(balance_a_before - balance_a_after, 1);
            assert_eq(balance_b_after - balance_b_before, 3);
            assert_eq(trader_balance_a_after - trader_balance_a_before, 1);
            assert_eq(trader_balance_b_before - trader_balance_b_after, 3);

            test_scenario::return_shared(pool_a);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_a_b_b_c_exact_in() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        let (pool_a_balance_a_before, pool_a_balance_b_before);
        let (pool_b_balance_a_before, pool_b_balance_b_before);
        let (trader_balance_a_before, trader_balance_c_before);
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<USDC, SUI, FEE3000BPS>>(scenario);

            //pool balance before
            (pool_a_balance_a_before, pool_a_balance_b_before) = pool::get_pool_balance(&mut pool_a);
            (pool_b_balance_a_before, pool_b_balance_b_before) = pool::get_pool_balance(&mut pool_b);

            //get trader balance before
            let coins_a;
            (coins_a, trader_balance_a_before) = tools_tests::get_user_coin<BTC>(scenario);
            trader_balance_c_before = tools_tests::get_user_coin_balance<SUI>(scenario);

            swap_router::swap_a_b_b_c(
                &mut pool_a,
                &mut pool_b,
                coins_a,
                30, //amount_in 
                26, //amount_threshold
                MIN_SQRT_PRICE_X64 + 1,
                MIN_SQRT_PRICE_X64 + 1,
                true,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<USDC, SUI, FEE3000BPS>>(scenario);
            let (pool_a_balance_a_after, pool_a_balance_b_after) = pool::get_pool_balance(&mut pool_a);
            let (pool_b_balance_a_after, pool_b_balance_b_after) = pool::get_pool_balance(&mut pool_b);
            let trader_balance_a_after = tools_tests::get_user_coin_balance<BTC>(scenario);
            let trader_balance_c_after = tools_tests::get_user_coin_balance<SUI>(scenario);

            assert_eq(pool_a_balance_a_after - pool_a_balance_a_before, 30);
            assert_eq(pool_a_balance_b_before - pool_a_balance_b_after, 28);

            assert_eq(pool_b_balance_a_after - pool_b_balance_a_before, 28);
            assert_eq(pool_b_balance_b_before - pool_b_balance_b_after, 26);

            assert_eq(trader_balance_a_before - trader_balance_a_after, 30);
            assert_eq(trader_balance_c_after - trader_balance_c_before, 26);

            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_a_b_b_c_exact_out() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        let (pool_a_balance_a_before, pool_a_balance_b_before);
        let (pool_b_balance_a_before, pool_b_balance_b_before);
        let (trader_balance_a_before, trader_balance_c_before);
        let (pool_a_protocol_fee_a_before, pool_a_protocol_fee_a_after);
        let (pool_b_protocol_fee_a_before, pool_b_protocol_fee_a_after);
        let (pool_a_protocol_fee_b_before, pool_a_protocol_fee_b_after);
        let (pool_b_protocol_fee_b_before, pool_b_protocol_fee_b_after);
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<USDC, SUI, FEE3000BPS>>(scenario);

            //pool balance before
            (pool_a_balance_a_before, pool_a_balance_b_before) = pool::get_pool_balance(&mut pool_a);
            (pool_b_balance_a_before, pool_b_balance_b_before) = pool::get_pool_balance(&mut pool_b);
            (_, _, pool_a_protocol_fee_a_before, pool_a_protocol_fee_b_before, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_a);
            (_, _, pool_b_protocol_fee_a_before, pool_b_protocol_fee_b_before, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_b);

            //get trader balance before
            let coins_a;
            (coins_a, trader_balance_a_before) = tools_tests::get_user_coin<BTC>(scenario);
            trader_balance_c_before = tools_tests::get_user_coin_balance<SUI>(scenario);

            swap_router::swap_a_b_b_c(
                &mut pool_a,
                &mut pool_b,
                coins_a,
                10000, //amount out
                10174, //amount_threshold
                MIN_SQRT_PRICE_X64 + 1,
                MIN_SQRT_PRICE_X64 + 1,
                false,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<USDC, SUI, FEE3000BPS>>(scenario);
            let (pool_a_balance_a_after, pool_a_balance_b_after) = pool::get_pool_balance(&mut pool_a);
            let (pool_b_balance_a_after, pool_b_balance_b_after) = pool::get_pool_balance(&mut pool_b);
            let trader_balance_a_after = tools_tests::get_user_coin_balance<BTC>(scenario);
            let trader_balance_c_after = tools_tests::get_user_coin_balance<SUI>(scenario);
            (_, _, pool_a_protocol_fee_a_after, pool_a_protocol_fee_b_after, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_a);
            (_, _, pool_b_protocol_fee_a_after, pool_b_protocol_fee_b_after, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_b);

            assert_eq(pool_a_balance_a_after - pool_a_balance_a_before, 10174);
            assert_eq(pool_a_balance_b_before - pool_a_balance_b_after, 10132);

            assert_eq(pool_b_balance_a_after - pool_b_balance_a_before, 10132);
            assert_eq(pool_b_balance_b_before - pool_b_balance_b_after, 10000);

            assert_eq(trader_balance_a_before - trader_balance_a_after, 10174);
            assert_eq(trader_balance_c_after - trader_balance_c_before, 10000);

            // Fees are not paid using correspond B token
            assert_eq(pool_a_protocol_fee_b_after, pool_a_protocol_fee_b_before);
            assert_eq(pool_b_protocol_fee_b_after, pool_b_protocol_fee_b_before);
            // Fees are paid using corresponding A token
            assert!(pool_a_protocol_fee_a_after > pool_a_protocol_fee_a_before, 0);
            assert!(pool_b_protocol_fee_a_after > pool_b_protocol_fee_a_before, 1);

            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_a_b_c_b_exact_in() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        let (pool_a_balance_a_before, pool_a_balance_b_before);
        let (pool_b_balance_a_before, pool_b_balance_b_before);
        let (trader_balance_a_before, trader_balance_b_before);
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<ETH, USDC, FEE3000BPS>>(scenario);

            //pool balance before
            (pool_a_balance_a_before, pool_a_balance_b_before) = pool::get_pool_balance(&mut pool_a);
            (pool_b_balance_a_before, pool_b_balance_b_before) = pool::get_pool_balance(&mut pool_b);

            //get trader balance before
            let coins_a;
            (coins_a, trader_balance_a_before) = tools_tests::get_user_coin<BTC>(scenario);
            trader_balance_b_before = tools_tests::get_user_coin_balance<ETH>(scenario);

            swap_router::swap_a_b_c_b(
                &mut pool_a,
                &mut pool_b,
                coins_a,
                30, //amount_in 
                26, //amount_threshold
                MIN_SQRT_PRICE_X64 + 1,
                MAX_SQRT_PRICE_X64 - 1,
                true,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<ETH, USDC, FEE3000BPS>>(scenario);
            let (pool_a_balance_a_after, pool_a_balance_b_after) = pool::get_pool_balance(&mut pool_a);
            let (pool_b_balance_a_after, pool_b_balance_b_after) = pool::get_pool_balance(&mut pool_b);
            let trader_balance_a_after = tools_tests::get_user_coin_balance<BTC>(scenario);
            let trader_balance_b_after = tools_tests::get_user_coin_balance<ETH>(scenario);

            assert_eq(pool_a_balance_a_after - pool_a_balance_a_before, 30);
            assert_eq(pool_a_balance_b_before - pool_a_balance_b_after, 28);

            assert_eq(pool_b_balance_b_after - pool_b_balance_b_before, 28);
            assert_eq(pool_b_balance_a_before - pool_b_balance_a_after, 26);

            assert_eq(trader_balance_a_before - trader_balance_a_after, 30);
            assert_eq(trader_balance_b_after - trader_balance_b_before, 26);

            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_a_b_c_b_exact_out() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        let (pool_a_protocol_fee_a_before, pool_a_protocol_fee_a_after);
        let (pool_b_protocol_fee_a_before, pool_b_protocol_fee_a_after);
        let (pool_a_protocol_fee_b_before, pool_a_protocol_fee_b_after);
        let (pool_b_protocol_fee_b_before, pool_b_protocol_fee_b_after);
        let (pool_a_balance_a_before, pool_a_balance_b_before);
        let (pool_b_balance_a_before, pool_b_balance_b_before);
        let (trader_balance_a_before, trader_balance_b_before);
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<ETH, USDC, FEE3000BPS>>(scenario);

            //pool balance before
            (pool_a_balance_a_before, pool_a_balance_b_before) = pool::get_pool_balance(&mut pool_a);
            (pool_b_balance_a_before, pool_b_balance_b_before) = pool::get_pool_balance(&mut pool_b);
            (_, _, pool_a_protocol_fee_a_before, pool_a_protocol_fee_b_before, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_a);
            (_, _, pool_b_protocol_fee_a_before, pool_b_protocol_fee_b_before, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_b);

            //get trader balance before
            let coins_a;
            (coins_a, trader_balance_a_before) = tools_tests::get_user_coin<BTC>(scenario);
            trader_balance_b_before = tools_tests::get_user_coin_balance<ETH>(scenario);

            swap_router::swap_a_b_c_b(
                &mut pool_a,
                &mut pool_b,
                coins_a,
                10000, //amount_in 
                10173, //amount_threshold
                MIN_SQRT_PRICE_X64 + 1,
                MAX_SQRT_PRICE_X64 - 1,
                false,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<ETH, USDC, FEE3000BPS>>(scenario);
            let (pool_a_balance_a_after, pool_a_balance_b_after) = pool::get_pool_balance(&mut pool_a);
            let (pool_b_balance_a_after, pool_b_balance_b_after) = pool::get_pool_balance(&mut pool_b);
            let trader_balance_a_after = tools_tests::get_user_coin_balance<BTC>(scenario);
            let trader_balance_b_after = tools_tests::get_user_coin_balance<ETH>(scenario);
            (_, _, pool_a_protocol_fee_a_after, pool_a_protocol_fee_b_after, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_a);
            (_, _, pool_b_protocol_fee_a_after, pool_b_protocol_fee_b_after, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_b);

            assert_eq(pool_a_balance_a_after - pool_a_balance_a_before, 10173);
            assert_eq(pool_a_balance_b_before - pool_a_balance_b_after, 10131);

            assert_eq(pool_b_balance_b_after - pool_b_balance_b_before, 10131);
            assert_eq(pool_b_balance_a_before - pool_b_balance_a_after, 10000);

            assert_eq(trader_balance_a_before - trader_balance_a_after, 10173);
            assert_eq(trader_balance_b_after - trader_balance_b_before, 10000);

            // Fees are paid using correspond A token in pool a
            assert!(pool_a_protocol_fee_a_after > pool_a_protocol_fee_a_before, 0);
            assert_eq(pool_a_protocol_fee_b_after, pool_a_protocol_fee_b_before);

            // Fees are paid using corresponding B token in pool b
            assert!(pool_b_protocol_fee_b_after > pool_b_protocol_fee_b_before, 1);
            assert_eq(pool_b_protocol_fee_a_after, pool_b_protocol_fee_a_before);

            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_b_a_b_c_exact_in() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        let (pool_a_balance_a_before, pool_a_balance_b_before);
        let (pool_b_balance_a_before, pool_b_balance_b_before);
        let (trader_balance_a_before, trader_balance_b_before);
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_a = test_scenario::take_shared<Pool<USDC, TRB, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<USDC, SUI, FEE3000BPS>>(scenario);

            //pool balance before
            (pool_a_balance_a_before, pool_a_balance_b_before) = pool::get_pool_balance(&mut pool_a);
            (pool_b_balance_a_before, pool_b_balance_b_before) = pool::get_pool_balance(&mut pool_b);

            //get trader balance before
            let coins_a;
            (coins_a, trader_balance_a_before) = tools_tests::get_user_coin<TRB>(scenario);
            trader_balance_b_before = tools_tests::get_user_coin_balance<SUI>(scenario);

            swap_router::swap_b_a_b_c(
                &mut pool_a,
                &mut pool_b,
                coins_a,
                30, //amount_in 
                26, //amount_threshold
                MAX_SQRT_PRICE_X64 - 1,
                MIN_SQRT_PRICE_X64 + 1,
                true,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<USDC, TRB, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<USDC, SUI, FEE3000BPS>>(scenario);
            let (pool_a_balance_a_after, pool_a_balance_b_after) = pool::get_pool_balance(&mut pool_a);
            let (pool_b_balance_a_after, pool_b_balance_b_after) = pool::get_pool_balance(&mut pool_b);
            let trader_balance_a_after = tools_tests::get_user_coin_balance<TRB>(scenario);
            let trader_balance_b_after = tools_tests::get_user_coin_balance<SUI>(scenario);

            assert_eq(pool_a_balance_a_before - pool_a_balance_a_after, 28);
            assert_eq(pool_a_balance_b_after - pool_a_balance_b_before, 30);

            assert_eq(pool_b_balance_a_after - pool_b_balance_a_before, 28);
            assert_eq(pool_b_balance_b_before - pool_b_balance_b_after, 26);

            assert_eq(trader_balance_a_before - trader_balance_a_after, 30);
            assert_eq(trader_balance_b_after - trader_balance_b_before, 26);

            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_b_a_b_c_exact_out() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        let (pool_a_protocol_fee_a_before, pool_a_protocol_fee_a_after);
        let (pool_b_protocol_fee_a_before, pool_b_protocol_fee_a_after);
        let (pool_a_protocol_fee_b_before, pool_a_protocol_fee_b_after);
        let (pool_b_protocol_fee_b_before, pool_b_protocol_fee_b_after);
        let (pool_a_balance_a_before, pool_a_balance_b_before);
        let (pool_b_balance_a_before, pool_b_balance_b_before);
        let (trader_balance_a_before, trader_balance_b_before);
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_a = test_scenario::take_shared<Pool<USDC, TRB, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<USDC, SUI, FEE3000BPS>>(scenario);

            //pool balance before
            (pool_a_balance_a_before, pool_a_balance_b_before) = pool::get_pool_balance(&mut pool_a);
            (pool_b_balance_a_before, pool_b_balance_b_before) = pool::get_pool_balance(&mut pool_b);
            (_, _, pool_a_protocol_fee_a_before, pool_a_protocol_fee_b_before, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_a);
            (_, _, pool_b_protocol_fee_a_before, pool_b_protocol_fee_b_before, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_b);

            //get trader balance before
            let coins_a;
            (coins_a, trader_balance_a_before) = tools_tests::get_user_coin<TRB>(scenario);
            trader_balance_b_before = tools_tests::get_user_coin_balance<SUI>(scenario);

            swap_router::swap_b_a_b_c(
                &mut pool_a,
                &mut pool_b,
                coins_a,
                10000, //amount_in 
                10267, //amount_threshold
                MAX_SQRT_PRICE_X64 - 1,
                MIN_SQRT_PRICE_X64 + 1,
                false,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<USDC, TRB, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<USDC, SUI, FEE3000BPS>>(scenario);
            let (pool_a_balance_a_after, pool_a_balance_b_after) = pool::get_pool_balance(&mut pool_a);
            let (pool_b_balance_a_after, pool_b_balance_b_after) = pool::get_pool_balance(&mut pool_b);
            let trader_balance_a_after = tools_tests::get_user_coin_balance<TRB>(scenario);
            let trader_balance_b_after = tools_tests::get_user_coin_balance<SUI>(scenario);
            (_, _, pool_a_protocol_fee_a_after, pool_a_protocol_fee_b_after, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_a);
            (_, _, pool_b_protocol_fee_a_after, pool_b_protocol_fee_b_after, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_b);

            assert_eq(pool_a_balance_a_before - pool_a_balance_a_after, 10132);
            assert_eq(pool_a_balance_b_after - pool_a_balance_b_before, 10267);

            assert_eq(pool_b_balance_a_after - pool_b_balance_a_before, 10132);
            assert_eq(pool_b_balance_b_before - pool_b_balance_b_after, 10000);

            assert_eq(trader_balance_a_before - trader_balance_a_after, 10267);
            assert_eq(trader_balance_b_after - trader_balance_b_before, 10000);

            // Fees are paid using correspond B token in pool a
            assert!(pool_a_protocol_fee_b_after > pool_a_protocol_fee_b_before, 0);
            assert_eq(pool_a_protocol_fee_a_after, pool_a_protocol_fee_a_before);

            // Fees are paid using corresponding A token in pool b
            assert!(pool_b_protocol_fee_a_after > pool_b_protocol_fee_a_before, 1);
            assert_eq(pool_b_protocol_fee_b_after, pool_b_protocol_fee_b_before);

            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_b_a_c_b_exact_in() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        let (pool_a_balance_a_before, pool_a_balance_b_before);
        let (pool_b_balance_a_before, pool_b_balance_b_before);
        let (trader_balance_a_before, trader_balance_b_before);
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_a = test_scenario::take_shared<Pool<USDC, TRB, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<ETH, USDC, FEE3000BPS>>(scenario);

            //pool balance before
            (pool_a_balance_a_before, pool_a_balance_b_before) = pool::get_pool_balance(&mut pool_a);
            (pool_b_balance_a_before, pool_b_balance_b_before) = pool::get_pool_balance(&mut pool_b);

            //get trader balance before
            let coins_a;
            (coins_a, trader_balance_a_before) = tools_tests::get_user_coin<TRB>(scenario);
            trader_balance_b_before = tools_tests::get_user_coin_balance<ETH>(scenario);

            swap_router::swap_b_a_c_b(
                &mut pool_a,
                &mut pool_b,
                coins_a,
                30, //amount_in 
                26, //amount_threshold
                MAX_SQRT_PRICE_X64 - 1,
                MAX_SQRT_PRICE_X64 - 1,
                true,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<USDC, TRB, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<ETH, USDC, FEE3000BPS>>(scenario);
            let (pool_a_balance_a_after, pool_a_balance_b_after) = pool::get_pool_balance(&mut pool_a);
            let (pool_b_balance_a_after, pool_b_balance_b_after) = pool::get_pool_balance(&mut pool_b);
            let trader_balance_a_after = tools_tests::get_user_coin_balance<TRB>(scenario);
            let trader_balance_b_after = tools_tests::get_user_coin_balance<ETH>(scenario);

            assert_eq(pool_a_balance_a_before - pool_a_balance_a_after, 28);
            assert_eq(pool_a_balance_b_after - pool_a_balance_b_before, 30);

            assert_eq(pool_b_balance_a_before - pool_b_balance_a_after, 26);
            assert_eq(pool_b_balance_b_after - pool_b_balance_b_before, 28);

            assert_eq(trader_balance_a_before - trader_balance_a_after, 30);
            assert_eq(trader_balance_b_after - trader_balance_b_before, 26);

            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::end(scenario_val);
    }

     #[test]
    public fun test_swap_b_a_c_b_exact_out() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        let (pool_a_protocol_fee_a_before, pool_a_protocol_fee_a_after);
        let (pool_b_protocol_fee_a_before, pool_b_protocol_fee_a_after);
        let (pool_a_protocol_fee_b_before, pool_a_protocol_fee_b_after);
        let (pool_b_protocol_fee_b_before, pool_b_protocol_fee_b_after);
        let (pool_a_balance_a_before, pool_a_balance_b_before);
        let (pool_b_balance_a_before, pool_b_balance_b_before);
        let (trader_balance_a_before, trader_balance_b_before);
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_a = test_scenario::take_shared<Pool<USDC, TRB, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<ETH, USDC, FEE3000BPS>>(scenario);

            //pool balance before
            (pool_a_balance_a_before, pool_a_balance_b_before) = pool::get_pool_balance(&mut pool_a);
            (pool_b_balance_a_before, pool_b_balance_b_before) = pool::get_pool_balance(&mut pool_b);
            (_, _, pool_a_protocol_fee_a_before, pool_a_protocol_fee_b_before, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_a);
            (_, _, pool_b_protocol_fee_a_before, pool_b_protocol_fee_b_before, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_b);

            //get trader balance before
            let coins_a;
            (coins_a, trader_balance_a_before) = tools_tests::get_user_coin<TRB>(scenario);
            trader_balance_b_before = tools_tests::get_user_coin_balance<ETH>(scenario);

            swap_router::swap_b_a_c_b(
                &mut pool_a,
                &mut pool_b,
                coins_a,
                10000, //amount_in 
                10266, //amount_threshold
                MAX_SQRT_PRICE_X64 - 1,
                MAX_SQRT_PRICE_X64 - 1,
                false,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<USDC, TRB, FEE3000BPS>>(scenario);
            let pool_b = test_scenario::take_shared<Pool<ETH, USDC, FEE3000BPS>>(scenario);
            let (pool_a_balance_a_after, pool_a_balance_b_after) = pool::get_pool_balance(&mut pool_a);
            let (pool_b_balance_a_after, pool_b_balance_b_after) = pool::get_pool_balance(&mut pool_b);
            let trader_balance_a_after = tools_tests::get_user_coin_balance<TRB>(scenario);
            let trader_balance_b_after = tools_tests::get_user_coin_balance<ETH>(scenario);
            (_, _, pool_a_protocol_fee_a_after, pool_a_protocol_fee_b_after, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_a);
            (_, _, pool_b_protocol_fee_a_after, pool_b_protocol_fee_b_after, _, _,_, _, _, _, _, _, _) = pool::get_pool_info(&pool_b);

            assert_eq(pool_a_balance_a_before - pool_a_balance_a_after, 10131);
            assert_eq(pool_a_balance_b_after - pool_a_balance_b_before, 10266);

            assert_eq(pool_b_balance_a_before - pool_b_balance_a_after, 10000);
            assert_eq(pool_b_balance_b_after - pool_b_balance_b_before, 10131);

            assert_eq(trader_balance_a_before - trader_balance_a_after, 10266);
            assert_eq(trader_balance_b_after - trader_balance_b_before, 10000);

            // Fees are paid using correspond B token in pool a
            assert!(pool_a_protocol_fee_b_after > pool_a_protocol_fee_b_before, 0);
            assert_eq(pool_a_protocol_fee_a_after, pool_a_protocol_fee_a_before);

            // Fees are paid using corresponding B token in pool b
            assert!(pool_b_protocol_fee_b_after > pool_b_protocol_fee_b_before, 1);
            assert_eq(pool_b_protocol_fee_a_after, pool_b_protocol_fee_a_before);

            test_scenario::return_shared(pool_a);
            test_scenario::return_shared(pool_b);
        };

        test_scenario::end(scenario_val);
    }
}