// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::position_manager_tests {
    use sui::coin::{Self, Coin};
    use sui::object;
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::pool_factory_tests;
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::trb::{TRB};
    use turbos_clmm::fee500bps::{FEE500BPS};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::tools_tests;
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::position_nft::{TurbosPositionNFT};
    use turbos_clmm::i32::{Self};
    use turbos_clmm::math_tick;
    use turbos_clmm::math_liquidity;
    use sui::test_utils::{assert_eq};
    use turbos_clmm::fee::{Fee};
    use sui::clock::{Self, Clock};
    use sui::transfer::{Self};
    use std::u64;

    public fun init_pool_manager(
        admin: address,
        scenario: &mut Scenario,
    ) {
        tools_tests::init_clock(
            admin,
            scenario
        );

        //init pool position manager
        test_scenario::next_tx(scenario, admin);
        {
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };
    }

    #[test]
    //#[expected_failure(abort_code = position_manager::EPositionNotCleared)]
    public fun test_mint() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        pool_factory_tests::init_pools(admin, player, player2, scenario);

        init_pool_manager(admin, scenario);

        //test BTCUSDC pool, 1BTC = 1USDC
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);
            position_manager::mint<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(btc),
                tools_tests::coin_to_vec(usdc),
                i32::abs_u32(min_tick_index),
                i32::is_neg(min_tick_index),
                i32::abs_u32(max_tick_index),
                i32::is_neg(max_tick_index),
                1000,
                1000,
                0,
                0,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            assert_eq(position_manager::get_nft_minted(&positions), 1);
            let (
                coin_a,
                coin_b,
                _,
                _,
                sqrt_price,
                tick_current_index,
                tick_spacing,
                _,
                fee,
                fee_protocol,
                fee_growth_global_a,
                fee_growth_global_b,
                liquidity,
            ) = pool::get_pool_info<BTC, USDC, FEE500BPS>(&pool);
            assert_eq(coin_a, 1000);
            assert_eq(coin_b, 1000);
            assert_eq(sqrt_price, 18446744073709551616);
            assert_eq(i32::eq(tick_current_index, i32::from(0)), true);
            assert_eq(tick_spacing, 10);
            assert_eq(fee, 500);
            assert_eq(fee_protocol, 0);
            assert_eq(fee_growth_global_a, 0);
            assert_eq(fee_growth_global_b, 0);
            assert_eq(liquidity, 1000);

            let sqrt_price_a = math_tick::sqrt_price_from_tick_index(min_tick_index);
            let sqrt_price_b = math_tick::sqrt_price_from_tick_index(max_tick_index);
            let (amount_a, amount_b) = math_liquidity::get_amount_for_liquidity(
                sqrt_price,
                sqrt_price_a,
                sqrt_price_b,
                liquidity
            );
            assert_eq(amount_a, 999);
            assert_eq(amount_b, 999);

            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        //check users coin
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let amount_btc = coin::value(&btc);
            let amount_usdc = coin::value(&usdc);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);
            assert_eq(amount_btc, 9000);
            assert_eq(amount_usdc, 9000);
        
            //get pool position info
            let (
                liquidity,
                fee_growth_inside_a,
                fee_growth_inside_b,
                tokens_owed_a,
                tokens_owed_b
            ) = pool::get_position_info<BTC, USDC, FEE500BPS>(&pool, object::id_address(&nft), min_tick_index, max_tick_index);
            assert_eq(liquidity, 1000);
            assert_eq(fee_growth_inside_a, 0);
            assert_eq(fee_growth_inside_b, 0);
            assert_eq(tokens_owed_a, 0);
            assert_eq(tokens_owed_b, 0);

            test_scenario::return_to_sender(scenario, nft);
            test_scenario::return_to_sender(scenario, btc);
            test_scenario::return_to_sender(scenario, usdc);
            test_scenario::return_shared(pool);
        };

   
        // increase position liquidity
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);

            position_manager::increase_liquidity(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(btc),
                tools_tests::coin_to_vec(usdc),
                &mut nft,
                100,
                100,
                0,
                0,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            let (
                liquidity,
                fee_growth_inside_a,
                fee_growth_inside_b,
                tokens_owed_a,
                tokens_owed_b
            ) = pool::get_position_info<BTC, USDC, FEE500BPS>(&pool, object::id_address(&nft), min_tick_index, max_tick_index);
            assert_eq(liquidity, 1100);
            assert_eq(fee_growth_inside_a, 0);
            assert_eq(fee_growth_inside_b, 0);
            assert_eq(tokens_owed_a, 0);
            assert_eq(tokens_owed_b, 0);

            test_scenario::return_immutable(fee_type);
            test_scenario::return_to_sender(scenario, nft);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        //check users coin
        test_scenario::next_tx(scenario, player);
        {
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let amount_btc = coin::value(&btc);
            let amount_usdc = coin::value(&usdc);
            assert_eq(amount_btc, 8900);
            assert_eq(amount_usdc, 8900);

            test_scenario::return_to_sender(scenario, btc);
            test_scenario::return_to_sender(scenario, usdc);
        };

        //decrease position liquidity
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);

            position_manager::decrease_liquidity(
                &mut pool,
                &mut positions,
                &mut nft,
                100,
                0,
                0,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            let (
                liquidity,
                fee_growth_inside_a,
                fee_growth_inside_b,
                tokens_owed_a,
                tokens_owed_b
            ) = pool::get_position_info<BTC, USDC, FEE500BPS>(&pool, object::id_address(&nft), min_tick_index, max_tick_index);
            assert_eq(liquidity, 1000);
            assert_eq(fee_growth_inside_a, 0);
            assert_eq(fee_growth_inside_b, 0);
            assert_eq(tokens_owed_a, 0);
            assert_eq(tokens_owed_b, 0);

            let (
                coin_a,
                coin_b,
                _,
                _,
                sqrt_price,
                tick_current_index,
                tick_spacing,
                _,
                fee,
                fee_protocol,
                fee_growth_global_a,
                fee_growth_global_b,
                liquidity,
            ) = pool::get_pool_info<BTC, USDC, FEE500BPS>(&pool);
            assert_eq(coin_a, 1001);
            assert_eq(coin_b, 1001);
            assert_eq(sqrt_price, 18446744073709551616);
            assert_eq(i32::eq(tick_current_index, i32::from(0)), true);
            assert_eq(tick_spacing, 10);
            assert_eq(fee, 500);
            assert_eq(fee_protocol, 0);
            assert_eq(fee_growth_global_a, 0);
            assert_eq(fee_growth_global_b, 0);
            assert_eq(liquidity, 1000);

            test_scenario::return_immutable(fee_type);
            test_scenario::return_to_sender(scenario, nft);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        //check users coin
        test_scenario::next_tx(scenario, player);
        {
            let amount_btc = tools_tests::get_user_coin_balance<BTC>(scenario);
            let amount_usdc = tools_tests::get_user_coin_balance<USDC>(scenario);
            assert_eq(amount_btc, 8999);
            assert_eq(amount_usdc, 8900 + 99);
        };

        // collect position
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);

            position_manager::collect(
                &mut pool,
                &mut positions,
                &mut nft,
                900,
                90,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            let (
                liquidity,
                fee_growth_inside_a,
                fee_growth_inside_b,
                tokens_owed_a,
                tokens_owed_b
            ) = pool::get_position_info<BTC, USDC, FEE500BPS>(&pool, object::id_address(&nft), min_tick_index, max_tick_index);
            assert_eq(liquidity, 1000);
            assert_eq(fee_growth_inside_a, 0);
            assert_eq(fee_growth_inside_b, 0);
            assert_eq(tokens_owed_a, 0);
            assert_eq(tokens_owed_b, 0);

            let (
                coin_a,
                coin_b,
                _,
                _,
                sqrt_price,
                tick_current_index,
                tick_spacing,
                _,
                fee,
                fee_protocol,
                fee_growth_global_a,
                fee_growth_global_b,
                liquidity,
            ) = pool::get_pool_info<BTC, USDC, FEE500BPS>(&pool);
            assert_eq(coin_a, 1001);
            assert_eq(coin_b, 1001);
            assert_eq(sqrt_price, 18446744073709551616);
            assert_eq(i32::eq(tick_current_index, i32::from(0)), true);
            assert_eq(tick_spacing, 10);
            assert_eq(fee, 500);
            assert_eq(fee_protocol, 0);
            assert_eq(fee_growth_global_a, 0);
            assert_eq(fee_growth_global_b, 0);
            assert_eq(liquidity, 1000);

            test_scenario::return_immutable(fee_type);
            test_scenario::return_to_sender(scenario, nft);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        //check users coin
        test_scenario::next_tx(scenario, player);
        {
            let amount_btc = tools_tests::get_user_coin_balance<BTC>(scenario);
            let amount_usdc = tools_tests::get_user_coin_balance<USDC>(scenario);
            assert_eq(amount_btc, 8999);
            assert_eq(amount_usdc, 8999);
        };


        //test USDCBTC pool, 1USDC = 0.01BTC
        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<USDC, TRB, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);
            position_manager::mint<USDC, TRB, FEE500BPS>(
                &mut pool,
                &mut positions,
                tools_tests::get_user_coin_vec<USDC>(scenario),
                tools_tests::get_user_coin_vec<TRB>(scenario),
                i32::abs_u32(min_tick_index),
                i32::is_neg(min_tick_index),
                i32::abs_u32(max_tick_index),
                i32::is_neg(max_tick_index),
                1000,
                1000,
                0,
                0,
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            assert_eq(position_manager::get_nft_minted(&positions), 2);
            let (
                coin_a,
                coin_b,
                _,
                _,
                sqrt_price,
                tick_current_index,
                tick_spacing,
                _,
                fee,
                fee_protocol,
                fee_growth_global_a,
                fee_growth_global_b,
                liquidity,
            ) = pool::get_pool_info<USDC, TRB, FEE500BPS>(&pool);
            assert_eq(coin_a, 1000);
            assert_eq(coin_b, 10);
            assert_eq(sqrt_price, 1844674407370955161);
            assert_eq(i32::eq(tick_current_index, i32::neg_from(46055)), true);
            assert_eq(tick_spacing, 10);
            assert_eq(fee, 500);
            assert_eq(fee_protocol, 0);
            assert_eq(fee_growth_global_a, 0);
            assert_eq(fee_growth_global_b, 0);

            let sqrt_price_a = math_tick::sqrt_price_from_tick_index(min_tick_index);
            let sqrt_price_b = math_tick::sqrt_price_from_tick_index(max_tick_index);
            let (amount_a, amount_b) = math_liquidity::get_amount_for_liquidity(
                sqrt_price,
                sqrt_price_a,
                sqrt_price_b,
                liquidity
            );
            assert_eq(amount_a, 999);
            assert_eq(amount_b, 9);



            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        //check users coin
        test_scenario::next_tx(scenario, player);
        {
            let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
            let trb = test_scenario::take_from_sender<Coin<TRB>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let amount_trb = coin::value(&trb);
            let amount_usdc = coin::value(&usdc);
            assert_eq(amount_trb, 9990);
            assert_eq(amount_usdc, 7999);

            test_scenario::return_to_sender(scenario, nft);
            test_scenario::return_to_sender(scenario, trb);
            test_scenario::return_to_sender(scenario, usdc);
        };

        // decrease  all
        // test_scenario::next_tx(scenario, player);
        // {
        //     let clock = test_scenario::take_shared<Clock>(scenario);
        //     let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
        //     let positions = test_scenario::take_shared<Positions>(scenario);
        //     let nft_id = tools_tests::get_user_nft_id(object::id(&pool),scenario);
        //     let nft = test_scenario::take_from_sender_by_id<TurbosPositionNFT>(scenario, nft_id);
        //     let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
        //     let min_tick_index = math_tick::get_min_tick(10);
        //     let max_tick_index = math_tick::get_max_tick(10);

        //     position_manager::decrease_liquidity(
        //         &mut pool,
        //         &mut positions,
        //         &mut nft,
        //         1000,
        //         0,
        //         0,
        //         1,
        //         &clock,
        //         test_scenario::ctx(scenario),
        //     );
        //     let (
        //         liquidity,
        //         fee_growth_inside_a,
        //         fee_growth_inside_b,
        //         tokens_owed_a,
        //         tokens_owed_b
        //     ) = pool::get_position_info<BTC, USDC, FEE500BPS>(&pool, player, min_tick_index, max_tick_index);
        //     assert_eq(liquidity, 0);
        //     assert_eq(fee_growth_inside_a, 0);
        //     assert_eq(fee_growth_inside_b, 0);
        //     assert_eq(tokens_owed_a, 0);
        //     assert_eq(tokens_owed_b, 0);

        //     let (
        // 	    coin_a,
        // 	    coin_b,
        // 	    _,
        // 	    _,
        // 	    sqrt_price,
        // 	    tick_current_index,
        // 	    tick_spacing,
        // 	    _,
        //         fee,
        //         fee_protocol,
        //         fee_growth_global_a,
        //         fee_growth_global_b,
        //         liquidity,
        //     ) = pool::get_pool_info<BTC, USDC, FEE500BPS>(&pool);
        //     assert_eq(coin_a, 2);
        //     assert_eq(coin_b, 2);
        //     assert_eq(sqrt_price, 18446744073709551616);
        //     assert_eq(i32::eq(tick_current_index, i32::from(0)), true);
        //     assert_eq(tick_spacing, 10);
        //     assert_eq(fee, 500);
        //     assert_eq(fee_protocol, 0);
        //     assert_eq(fee_growth_global_a, 0);
        //     assert_eq(fee_growth_global_b, 0);
        //     assert_eq(liquidity, 0);

        //     test_scenario::return_immutable(fee_type);
        //     test_scenario::return_to_sender(scenario, nft);
        //     test_scenario::return_shared(pool);
        //     test_scenario::return_shared(positions);
        //     test_scenario::return_shared(clock);
        // };
   
        // collect all
        // test_scenario::next_tx(scenario, player);
        // {
        //     let clock = test_scenario::take_shared<Clock>(scenario);
        //     let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
        //     let positions = test_scenario::take_shared<Positions>(scenario);
        //     let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
        //     let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
        //     let min_tick_index = math_tick::get_min_tick(10);
        //     let max_tick_index = math_tick::get_max_tick(10);

        //     position_manager::collect(
        //         &mut pool,
        //         &mut positions,
        //         &mut nft,
        //         999,
        //         1008,
        //         player,
        //         1,
        //         &clock,
        //         test_scenario::ctx(scenario),
        //     );
        //     let (
        //         liquidity,
        //         fee_growth_inside_a,
        //         fee_growth_inside_b,
        //         tokens_owed_a,
        //         tokens_owed_b
        //     ) = pool::get_position_info<BTC, USDC, FEE500BPS>(&pool, player, min_tick_index, max_tick_index);
        //     assert_eq(liquidity, 0);
        //     assert_eq(fee_growth_inside_a, 0);
        //     assert_eq(fee_growth_inside_b, 0);
        //     assert_eq(tokens_owed_a, 0);
        //     assert_eq(tokens_owed_b, 0);

        //     let (
        // 	    coin_a,
        // 	    coin_b,
        // 	    _,
        // 	    _,
        // 	    sqrt_price,
        // 	    tick_current_index,
        // 	    tick_spacing,
        // 	    _,
        //         fee,
        //         fee_protocol,
        //         fee_growth_global_a,
        //         fee_growth_global_b,
        //         liquidity,
        //     ) = pool::get_pool_info<BTC, USDC, FEE500BPS>(&pool);
        //     assert_eq(coin_a, 2);
        //     assert_eq(coin_b, 2);
        //     assert_eq(sqrt_price, 18446744073709551616);
        //     assert_eq(i32::eq(tick_current_index, i32::from(0)), true);
        //     assert_eq(tick_spacing, 10);
        //     assert_eq(fee, 500);
        //     assert_eq(fee_protocol, 0);
        //     assert_eq(fee_growth_global_a, 0);
        //     assert_eq(fee_growth_global_b, 0);
        //     assert_eq(liquidity, 0);

        //     test_scenario::return_immutable(fee_type);
        //     test_scenario::return_to_sender(scenario, nft);
        //     test_scenario::return_shared(pool);
        //     test_scenario::return_shared(positions);
        //     test_scenario::return_shared(clock);
        // };

        //burn
        // test_scenario::next_tx(scenario, player);
        // {
        //     let positions = test_scenario::take_shared<Positions>(scenario);
        //     let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);

        //     position_manager::burn<BTC, USDC, FEE500BPS>(
        //         &mut positions,
        //         nft,
        //         test_scenario::ctx(scenario),
        //     );
            
        //     test_scenario::return_shared(positions);
        // };
   
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_position_info_getters() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        pool_factory_tests::init_pools(admin, player, player2, scenario);
        init_pool_manager(admin, scenario);

        // Create position first
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);

            let coin_a = coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario));
            let coin_b = coin::mint_for_testing<USDC>(1000, test_scenario::ctx(scenario));

            let (nft, left_a, left_b) = position_manager::mint_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(coin_a),
                tools_tests::coin_to_vec(coin_b),
                i32::abs_u32(i32::neg_from(100)),
                i32::is_neg(i32::neg_from(100)),
                i32::abs_u32(i32::from(100)),
                i32::is_neg(i32::from(100)),
                500,
                500,
                0,
                0,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Test get_position_info
            let nft_address = object::id_address(&nft);
            let (tick_lower, tick_upper, liquidity) =
                position_manager::get_position_info(&positions, nft_address);
                
            assert_eq(i32::as_u32(tick_lower), i32::as_u32(i32::neg_from(100)));
            assert_eq(i32::as_u32(tick_upper), i32::as_u32(i32::from(100)));
            assert!(liquidity > 0, 100);

            // Test get_nft_minted
            let nft_count = position_manager::get_nft_minted(&positions);
            assert_eq(nft_count, 1);

            coin::burn_for_testing(left_a);
            coin::burn_for_testing(left_b);
            
            // Transfer the NFT to player since it's a newly created object
            transfer::public_transfer(nft, player);
            
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_increase_liquidity_edge_cases() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        pool_factory_tests::init_pools(admin, player, player2, scenario);
        init_pool_manager(admin, scenario);

        // Create position first
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);

            let coin_a = coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario));
            let coin_b = coin::mint_for_testing<USDC>(1000, test_scenario::ctx(scenario));

            let (nft, left_a, left_b) = position_manager::mint_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(coin_a),
                tools_tests::coin_to_vec(coin_b),
                i32::abs_u32(i32::neg_from(100)),
                i32::is_neg(i32::neg_from(100)),
                i32::abs_u32(i32::from(100)),
                i32::is_neg(i32::from(100)),
                500,
                500,
                0,
                0,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            coin::burn_for_testing(left_a);
            coin::burn_for_testing(left_b);

            // Test increase liquidity with very small amounts
            let small_coin_a = coin::mint_for_testing<BTC>(1, test_scenario::ctx(scenario));
            let small_coin_b = coin::mint_for_testing<USDC>(1, test_scenario::ctx(scenario));

            let (left_a_small, left_b_small) = position_manager::increase_liquidity_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(small_coin_a),
                tools_tests::coin_to_vec(small_coin_b),
                &mut nft,
                1,
                1,
                0,
                0,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            coin::burn_for_testing(left_a_small);
            coin::burn_for_testing(left_b_small);

            // Transfer the NFT to player since it's a newly created object
            transfer::public_transfer(nft, player);

            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_decrease_liquidity_partial() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        pool_factory_tests::init_pools(admin, player, player2, scenario);
        init_pool_manager(admin, scenario);

        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);

            let coin_a = coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario));
            let coin_b = coin::mint_for_testing<USDC>(1000, test_scenario::ctx(scenario));

            let (nft, left_a, left_b) = position_manager::mint_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(coin_a),
                tools_tests::coin_to_vec(coin_b),
                i32::abs_u32(i32::neg_from(100)),
                i32::is_neg(i32::neg_from(100)),
                i32::abs_u32(i32::from(100)),
                i32::is_neg(i32::from(100)),
                500,
                500,
                0,
                0,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            coin::burn_for_testing(left_a);
            coin::burn_for_testing(left_b);

            // Get initial liquidity
            let (_, _, initial_liquidity) = position_manager::get_position_info(&positions, object::id_address(&nft));

            // Decrease liquidity partially (50%)
            let liquidity_to_remove = initial_liquidity / 2;

            let (removed_a, removed_b) = position_manager::decrease_liquidity_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                &mut nft,
                liquidity_to_remove,
                0, // amount_a_min
                0, // amount_b_min
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Verify liquidity was decreased
            let (_, _, remaining_liquidity) = position_manager::get_position_info(&positions, object::id_address(&nft));
            assert!(remaining_liquidity < initial_liquidity, 101);
            assert!(remaining_liquidity > 0, 102);

            assert!(coin::value(&removed_a) > 0, 103);
            assert!(coin::value(&removed_b) > 0, 104);

            coin::burn_for_testing(removed_a);
            coin::burn_for_testing(removed_b);

            // Transfer the NFT to player since it's a newly created object
            transfer::public_transfer(nft, player);

            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_collect_fees_empty_position() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        pool_factory_tests::init_pools(admin, player, player2, scenario);
        init_pool_manager(admin, scenario);

        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);

            let coin_a = coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario));
            let coin_b = coin::mint_for_testing<USDC>(1000, test_scenario::ctx(scenario));

            let (nft, left_a, left_b) = position_manager::mint_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(coin_a),
                tools_tests::coin_to_vec(coin_b),
                i32::abs_u32(i32::neg_from(100)),
                i32::is_neg(i32::neg_from(100)),
                i32::abs_u32(i32::from(100)),
                i32::is_neg(i32::from(100)),
                500,
                500,
                0,
                0,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            coin::burn_for_testing(left_a);
            coin::burn_for_testing(left_b);

            // Try to collect fees from a fresh position (should be zero or very small)
            let (fee_a, fee_b) = position_manager::collect_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                &mut nft,
                18446744073709551615, // amount_a_max (u64::MAX)
                18446744073709551615, // amount_b_max (u64::MAX)
                @0x0, // recipient
                clock::timestamp_ms(&clock) + 1000, // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Fresh position should have minimal or zero fees
            coin::burn_for_testing(fee_a);
            coin::burn_for_testing(fee_b);

            // Transfer the NFT to player since it's a newly created object
            transfer::public_transfer(nft, player);

            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_burn_position_nft_flow() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        pool_factory_tests::init_pools(admin, player, player2, scenario);
        init_pool_manager(admin, scenario);

        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);

            let coin_a = coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario));
            let coin_b = coin::mint_for_testing<USDC>(1000, test_scenario::ctx(scenario));

            // Use full range ticks for burn test (TICK_SIZE = 443636, tick_spacing = 10)
            // Full range: tick_lower = -(TICK_SIZE - TICK_SIZE % tick_spacing), tick_upper = TICK_SIZE - TICK_SIZE % tick_spacing
            let tick_spacing = 10;
            let tick_size = 443636;
            let mod_val = tick_size % tick_spacing; // 443636 % 10 = 6
            let full_range_tick = tick_size - mod_val; // 443636 - 6 = 443630

            let (nft, left_a, left_b) = position_manager::mint_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(coin_a),
                tools_tests::coin_to_vec(coin_b),
                full_range_tick,
                true, // is_neg for tick_lower
                full_range_tick,
                false, // is_neg for tick_upper
                500,
                500,
                0,
                0,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            coin::burn_for_testing(left_a);
            coin::burn_for_testing(left_b);

            // First decrease all liquidity
            let (_, _, liquidity) = position_manager::get_position_info(&positions, object::id_address(&nft));

            if (liquidity > 0) {
                let (removed_a, removed_b) = position_manager::decrease_liquidity_with_return_<BTC, USDC, FEE500BPS>(
                    &mut pool,
                    &mut positions,
                    &mut nft,
                    liquidity,
                    0, // amount_a_min
                    0, // amount_b_min
                    clock::timestamp_ms(&clock) + 1000,
                    &clock,
                    &versioned,
                    test_scenario::ctx(scenario),
                );

                coin::burn_for_testing(removed_a);
                coin::burn_for_testing(removed_b);
            };

            // Now burn the position NFT
            let burn_nft = position_manager::burn_position_nft_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                nft,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Test burn_nft_collect_fee_with_return_
            let (final_fee_a, final_fee_b) = position_manager::burn_nft_collect_fee_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                &mut burn_nft,
                18446744073709551615, // u64::MAX
                18446744073709551615, // u64::MAX
                clock::timestamp_ms(&clock) + 1000, // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            coin::burn_for_testing(final_fee_a);
            coin::burn_for_testing(final_fee_b);

            // Transfer the burn_nft to player since it's a newly created object
            transfer::public_transfer(burn_nft, player);

            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test] 
    public fun test_multiple_positions_different_ranges() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        pool_factory_tests::init_pools(admin, player, player2, scenario);
        init_pool_manager(admin, scenario);

        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);

            // Create first position
            let coin_a1 = coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario));
            let coin_b1 = coin::mint_for_testing<USDC>(1000, test_scenario::ctx(scenario));

            let (nft1, left_a1, left_b1) = position_manager::mint_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(coin_a1),
                tools_tests::coin_to_vec(coin_b1),
                i32::abs_u32(i32::neg_from(100)),
                i32::is_neg(i32::neg_from(100)),
                i32::abs_u32(i32::from(100)),
                i32::is_neg(i32::from(100)),
                500,
                500,
                0,
                0,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Create second position with different range
            let coin_a2 = coin::mint_for_testing<BTC>(1000, test_scenario::ctx(scenario));
            let coin_b2 = coin::mint_for_testing<USDC>(1000, test_scenario::ctx(scenario));

            let (nft2, left_a2, left_b2) = position_manager::mint_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                tools_tests::coin_to_vec(coin_a2),
                tools_tests::coin_to_vec(coin_b2),
                i32::abs_u32(i32::neg_from(200)),
                i32::is_neg(i32::neg_from(200)),
                i32::abs_u32(i32::from(200)),
                i32::is_neg(i32::from(200)),
                500,
                500,
                0,
                0,
                clock::timestamp_ms(&clock) + 1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Verify different tick ranges
            let (tick_lower1, tick_upper1, _) = position_manager::get_position_info(&positions, object::id_address(&nft1));
            let (tick_lower2, tick_upper2, _) = position_manager::get_position_info(&positions, object::id_address(&nft2));

            assert!(i32::as_u32(tick_lower1) != i32::as_u32(tick_lower2), 105);
            assert!(i32::as_u32(tick_upper1) != i32::as_u32(tick_upper2), 106);

            // Verify NFT count
            let nft_count = position_manager::get_nft_minted(&positions);
            assert_eq(nft_count, 2);

            coin::burn_for_testing(left_a1);
            coin::burn_for_testing(left_b1);
            coin::burn_for_testing(left_a2);
            coin::burn_for_testing(left_b2);

            // Transfer the NFTs to player since they're newly created objects
            transfer::public_transfer(nft1, player);
            transfer::public_transfer(nft2, player);

            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }
}