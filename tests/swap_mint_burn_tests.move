// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::swap_mint_burn_tests {
    use sui::test_utils::{assert_eq};
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::tools_tests;
    use turbos_clmm::math_tick;
    use turbos_clmm::math_u128;
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::i32::{Self};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
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
            let sqrt_price = 5833372668713515884;// 0.1
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
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_immutable(fee_type);
        };

        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(60);
            let max_tick_index = math_tick::get_max_tick(60);
            let clock = test_scenario::take_shared<Clock>(scenario);

            let (amount_a, amount_b) = pool::mint_for_testing(
                &mut pool,
                player,
                min_tick_index,
                max_tick_index,
                3161,
                &clock,
                test_scenario::ctx(scenario),
            );

            let tick = pool::get_pool_tick_current_index(&mut pool);
            assert_eq(i32::eq(tick, i32::neg_from(23028)), true);
            assert_eq(amount_a, 9996);
            assert_eq(amount_b, 1000);

            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
            test_scenario::return_immutable(fee_type);
        };
    }

    #[test]
    public fun test_token_a_only_above_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);

        //token_a only
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let (amount_a, amount_b) = pool::mint_for_testing(
                &mut pool,
                player,
                i32::neg_from(22980),
                i32::from(0),
                10000,
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 21549);
            assert_eq(amount_b, 0);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_max_tick_and_max_l_above_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);
        
        //max tick & max liquidity
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let max_tick_index = math_tick::get_max_tick(60);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let (amount_a, amount_b) = pool::mint_for_testing(
                &mut pool,
                player,
                i32::sub(max_tick_index, i32::from(60)),
                max_tick_index,
                math_u128::pow(2, 64) - 1, // liquidity must less than u64 max
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 12940025);
            assert_eq(amount_b, 0);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_works_for_max_tick_above_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let max_tick_index = math_tick::get_max_tick(60);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let (amount_a, amount_b) = pool::mint_for_testing(
                &mut pool,
                player,
                i32::neg_from(22980),
                max_tick_index,
                10000,
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 31549);
            assert_eq(amount_b, 0);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_removing_works_above_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let (amount_a, amount_b) = pool::mint_for_testing(
                &mut pool,
                player,
                i32::neg_from(240),
                i32::zero(),
                10000,
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 121);
            assert_eq(amount_b, 0);

            (amount_a, amount_b) = pool::burn_for_testing(
                &mut pool,
                player,
                i32::neg_from(240),
                i32::zero(),
                10000,
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 120);
            assert_eq(amount_b, 0);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_add_liquidity_to_liquidity_gross_above_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let tick_lower_index = i32::neg_from(240);
            let clock = test_scenario::take_shared<Clock>(scenario);
            pool::mint_for_testing(
                &mut pool,
                player,
                tick_lower_index,
                i32::zero(),
                100,
                &clock,
                test_scenario::ctx(scenario),
            );
            let (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, tick_lower_index);
            assert_eq(liquidity_gross, 100);
            (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::zero());
            assert_eq(liquidity_gross, 100);
            (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::from(60));
            assert_eq(liquidity_gross, 0);
            (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::from(120));
            assert_eq(liquidity_gross, 0);

            pool::mint_for_testing(
                &mut pool,
                player,
                tick_lower_index,
                i32::from(60),
                150,
                &clock,
                test_scenario::ctx(scenario),
            );
            (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::neg_from(240));
            assert_eq(liquidity_gross, 250);
            (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::zero());
            assert_eq(liquidity_gross, 100);
            (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::from(60));
            assert_eq(liquidity_gross, 150);
            (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::from(120));
            assert_eq(liquidity_gross, 0);

            pool::mint_for_testing(
                &mut pool,
                player,
                i32::zero(),
                i32::from(120),
                60,
                &clock,
                test_scenario::ctx(scenario),
            );
            (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::neg_from(240));
            assert_eq(liquidity_gross, 250);
            (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::zero());
            assert_eq(liquidity_gross, 160);
            (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::from(60));
            assert_eq(liquidity_gross, 150);
            (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::from(120));
            assert_eq(liquidity_gross, 60);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_remove_liquidity_from_liquidity_gross_above_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let tick_lower_index = i32::neg_from(240);
            let clock = test_scenario::take_shared<Clock>(scenario);
            pool::mint_for_testing(
                &mut pool,
                player,
                tick_lower_index,
                i32::zero(),
                100,
                &clock,
                test_scenario::ctx(scenario),
            );
            pool::mint_for_testing(
                &mut pool,
                player,
                tick_lower_index,
                i32::zero(),
                40,
                &clock,
                test_scenario::ctx(scenario),
            );
            pool::burn_for_testing(
                &mut pool,
                player,
                i32::neg_from(240),
                i32::zero(),
                90,
                &clock,
                test_scenario::ctx(scenario),
            );
            let (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, tick_lower_index);
            assert_eq(liquidity_gross, 50);
            (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::zero());
            assert_eq(liquidity_gross, 50);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_clear_ticks_above_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let tick_lower_index = i32::neg_from(240);
            let clock = test_scenario::take_shared<Clock>(scenario);
            pool::mint_for_testing(
                &mut pool,
                player,
                tick_lower_index,
                i32::zero(),
                100,
                &clock,
                test_scenario::ctx(scenario),
            );
            pool::burn_for_testing(
                &mut pool,
                player,
                i32::neg_from(240),
                i32::zero(),
                100,
                &clock,
                test_scenario::ctx(scenario),
            );
            let (liquidity_gross,_,fee_growth_outside_a,fee_growth_outside_b,_) = pool::get_tick_info(&pool, tick_lower_index);
            assert_eq(liquidity_gross, 0);
            assert_eq(fee_growth_outside_a, 0);
            assert_eq(fee_growth_outside_b, 0);

            (liquidity_gross,_,fee_growth_outside_a,fee_growth_outside_b,_) = pool::get_tick_info(&pool, i32::zero());
            assert_eq(liquidity_gross, 0);
            assert_eq(fee_growth_outside_a, 0);
            assert_eq(fee_growth_outside_b, 0);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_clear_ticks_only_not_used_above_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let tick_lower_index = i32::neg_from(240);
            let clock = test_scenario::take_shared<Clock>(scenario);
            pool::mint_for_testing(
                &mut pool,
                player,
                tick_lower_index,
                i32::zero(),
                100,
                &clock,
                test_scenario::ctx(scenario),
            );
            pool::mint_for_testing(
                &mut pool,
                player,
                i32::neg_from(60),
                i32::zero(),
                250,
                &clock,
                test_scenario::ctx(scenario),
            );
            pool::burn_for_testing(
                &mut pool,
                player,
                i32::neg_from(240),
                i32::zero(),
                100,
                &clock,
                test_scenario::ctx(scenario),
            );
            let (liquidity_gross,_,fee_growth_outside_a,fee_growth_outside_b,_) = pool::get_tick_info(&pool, tick_lower_index);
            assert_eq(liquidity_gross, 0);
            assert_eq(fee_growth_outside_a, 0);
            assert_eq(fee_growth_outside_b, 0);

            (liquidity_gross,_,fee_growth_outside_a,fee_growth_outside_b,_) = pool::get_tick_info(&pool, i32::neg_from(60));
            assert_eq(liquidity_gross, 250);
            assert_eq(fee_growth_outside_a, 0);
            assert_eq(fee_growth_outside_b, 0);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_token_a_only_including_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);

        //token_a only
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(60);
            let max_tick_index = math_tick::get_max_tick(60);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let (amount_a, amount_b) = pool::mint_for_testing(
                &mut pool,
                player,
                i32::add(min_tick_index, i32::from(60)),
                i32::sub(max_tick_index, i32::from(60)),
                100,
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 317);
            assert_eq(amount_b, 32);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_initializes_lower_tick_including_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);

        //token_a only
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(60);
            let max_tick_index = math_tick::get_max_tick(60);
            let clock = test_scenario::take_shared<Clock>(scenario);
            pool::mint_for_testing(
                &mut pool,
                player,
                i32::add(min_tick_index, i32::from(60)),
                i32::sub(max_tick_index, i32::from(60)),
                100,
                &clock,
                test_scenario::ctx(scenario),
            );
            let (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::add(min_tick_index, i32::from(60)));
            assert_eq(liquidity_gross, 100);
            let (liquidity_gross,_,_,_,_) = pool::get_tick_info(&pool, i32::sub(max_tick_index, i32::from(60)));
            assert_eq(liquidity_gross, 100);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_works_for_min_max_tick_including_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);

        //token_a only
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(60);
            let max_tick_index = math_tick::get_max_tick(60);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let (amount_a, amount_b) = pool::mint_for_testing(
                &mut pool,
                player,
                min_tick_index,
                max_tick_index,
                10000,
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 31623);
            assert_eq(amount_b, 3162);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_removing_works_including_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);

        //token_a only
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(60);
            let max_tick_index = math_tick::get_max_tick(60);
            let clock = test_scenario::take_shared<Clock>(scenario);
            pool::mint_for_testing(
                &mut pool,
                player,
                i32::add(min_tick_index, i32::from(60)),
                i32::sub(max_tick_index, i32::from(60)),
                100,
                &clock,
                test_scenario::ctx(scenario),
            );
            pool::burn_for_testing(
                &mut pool,
                player,
                i32::add(min_tick_index, i32::from(60)),
                i32::sub(max_tick_index, i32::from(60)),
                100,
                &clock,
                test_scenario::ctx(scenario),
            );
            let (amount_a, amount_b) = pool::collect_for_testing(
                &mut pool,
                player,
                i32::add(min_tick_index, i32::from(60)),
                i32::sub(max_tick_index, i32::from(60)),
                0xffffffffffffffff,
                0xffffffffffffffff,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 0);
            assert_eq(amount_b, 0);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_token_a_only_below_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);

        //token_a only
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let (amount_a, amount_b) = pool::mint_for_testing(
                &mut pool,
                player,
                i32::neg_from(46080),
                i32::neg_from(23040),
                10000,
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 0);
            assert_eq(amount_b, 2162);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_max_tick_and_max_l_below_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);
        
        //max tick & max liquidity
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(60);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let (amount_a, amount_b) = pool::mint_for_testing(
                &mut pool,
                player,
                min_tick_index,
                i32::add(min_tick_index, i32::from(60)),
                math_u128::pow(2, 64) - 1, // liquidity must less than u64 max
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 0);
            assert_eq(amount_b, 12940024);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_works_for_min_max_tick_below_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);

        //token_a only
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(60);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let (amount_a, amount_b) = pool::mint_for_testing(
                &mut pool,
                player,
                min_tick_index,
                i32::neg_from(23040),
                10000,
                &clock,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 0);
            assert_eq(amount_b, 3160);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_removing_works_below_current() {
        let (admin, player, player2)  = (@0x0, @0x1, @0x2);
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        prepare_tests(admin, player, player2, scenario);

        //token_a only
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            pool::mint_for_testing(
                &mut pool,
                player,
                i32::neg_from(46080),
                i32::neg_from(46020),
                10000,
                &clock,
                test_scenario::ctx(scenario),
            );
            pool::burn_for_testing(
                &mut pool,
                player,
                i32::neg_from(46080),
                i32::neg_from(46020),
                10000,
                &clock,
                test_scenario::ctx(scenario),
            );
            let (amount_a, amount_b) = pool::collect_for_testing(
                &mut pool,
                player,
                i32::neg_from(46080),
                i32::neg_from(46020),
                0xffffffffffffffff,
                0xffffffffffffffff,
                test_scenario::ctx(scenario),
            );
            assert_eq(amount_a, 0);
            assert_eq(amount_b, 0);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }
}