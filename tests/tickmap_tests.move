// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::tickmap_tests {
    use sui::test_scenario::{Self};
    use turbos_clmm::pool_factory_tests;
    use turbos_clmm::pool::{Self, Pool};
    use turbos_clmm::i32::{Self, I32};
    use turbos_clmm::position_manager_tests;
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::fee500bps::{FEE500BPS};
    use sui::test_utils::{assert_eq};
    use std::vector;
    use sui::tx_context::{TxContext};
    use turbos_clmm::math_tick;

    public fun init_tick<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        ticks: &mut vector<I32>,
        ctx: &mut TxContext
    ){
        while (!vector::is_empty(ticks)) {
            pool::flip_tick_for_testing(
                pool,
                vector::pop_back(ticks), 
                ctx,
            );
        };
    }

    #[test]
    public fun test_position() {
        let (word_pos, bit_pos) = pool::position_tick(i32::neg_from(257));
        assert_eq(i32::eq(word_pos, i32::neg_from(2)), true);
        assert_eq(bit_pos == 255, true);

        (word_pos, bit_pos) = pool::position_tick(i32::from(780));
        assert_eq(i32::eq(word_pos, i32::from(3)), true);
        assert_eq(bit_pos == 12, true);

        (word_pos, bit_pos) = pool::position_tick(i32::from(256));
        assert_eq(i32::eq(word_pos, i32::from(1)), true);
        assert_eq(bit_pos == 0, true);
    }

    #[test]
    public fun test_flip_tick_for_testing() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        pool_factory_tests::init_pools(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let is_initialized = pool::tick_is_initialized(
                &mut pool,
                i32::from(10)
            );
            assert_eq(is_initialized, false);

            pool::flip_tick_for_testing(
                &mut pool,
                i32::from(10), 
                test_scenario::ctx(scenario),
            );
            let is_initialized_1 = pool::tick_is_initialized(
                &mut pool,
                i32::from(10)
            );
            assert_eq(is_initialized_1, true);

            //flip back
            pool::flip_tick_for_testing(
                &mut pool,
                i32::from(10), 
                test_scenario::ctx(scenario),
            );
            let is_initialized_2 = pool::tick_is_initialized(
                &mut pool,
                i32::from(10)
            );
            assert_eq(is_initialized_2, false);

            test_scenario::return_shared(pool);
        };

        //flips only the specified tick
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);

            //right
            pool::flip_tick_for_testing(&mut pool, i32::from(100), test_scenario::ctx(scenario));
            assert_eq(pool::tick_is_initialized(&mut pool, i32::from(100)), true);
            assert_eq(pool::tick_is_initialized(&mut pool, i32::from(110)), false);
            assert_eq(pool::tick_is_initialized(&mut pool, i32::from(120)), false);
            assert_eq(pool::tick_is_initialized(&mut pool, i32::from(130)), false);
            assert_eq(pool::tick_is_initialized(&mut pool, i32::from(90)), false);

            //left
            pool::flip_tick_for_testing(&mut pool, i32::neg_from(100), test_scenario::ctx(scenario));
            assert_eq(pool::tick_is_initialized(&mut pool, i32::neg_from(100)), true);
            assert_eq(pool::tick_is_initialized(&mut pool, i32::neg_from(110)), false);
            assert_eq(pool::tick_is_initialized(&mut pool, i32::neg_from(120)), false);
            assert_eq(pool::tick_is_initialized(&mut pool, i32::neg_from(130)), false);
            assert_eq(pool::tick_is_initialized(&mut pool, i32::from(90)), false);

            //skip words
            pool::flip_tick_for_testing(&mut pool, i32::from(2560), test_scenario::ctx(scenario));
            assert_eq(pool::tick_is_initialized(&mut pool, i32::from(2560)), true);
            assert_eq(pool::tick_is_initialized(&mut pool, i32::from(2570)), false);
            assert_eq(pool::tick_is_initialized(&mut pool, i32::from(2580)), false);
            assert_eq(pool::tick_is_initialized(&mut pool, i32::from(2550)), false);
            
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_next_initialized_tick_within_one_word_for_testing_left() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        pool_factory_tests::init_pools(admin, player, player2, scenario);

        //is_initialized
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);

            let ticks = vector::empty<I32>();
            vector::push_back(&mut ticks, i32::neg_from(2000));
            vector::push_back(&mut ticks, i32::neg_from(550));
            vector::push_back(&mut ticks, i32::neg_from(40));
            vector::push_back(&mut ticks, i32::from(700));
            vector::push_back(&mut ticks, i32::from(780));
            vector::push_back(&mut ticks, i32::from(840));
            vector::push_back(&mut ticks, i32::from(1390));
            vector::push_back(&mut ticks, i32::from(2400));
            vector::push_back(&mut ticks, i32::from(5350));

            init_tick(
                &mut pool,
                &mut ticks,
                test_scenario::ctx(scenario),
            );

            //lte = true, to the left
            let (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(780),
                true
            );
            assert_eq(i32::eq(next, i32::from(780)), true);
            assert_eq(initialized, true);

            //returns tick directly to the left of input tick if not initialized
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(790),
                true
            );
            assert_eq(i32::eq(next, i32::from(780)), true);
            assert_eq(initialized, true);

            //will not exceed the word boundary
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(2580),
                true
            );
            assert_eq(i32::eq(next, i32::from(2560)), true);
            assert_eq(initialized, false);

            //at the word boundary
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(2560),
                true
            );
            assert_eq(i32::eq(next, i32::from(2560)), true);
            assert_eq(initialized, false);

            //word boundary less 1 (next initialized tick in next word)
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(720),
                true
            );
            assert_eq(i32::eq(next, i32::from(700)), true);
            assert_eq(initialized, true);

            //word boundary
            let (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::neg_from(2570),
                true
            );
            assert_eq(i32::eq(next, i32::neg_from(5120)), true);
            assert_eq(initialized, false);

            // eintire empty word
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(10230),
                true
            );
            assert_eq(i32::eq(next, i32::from(7680)), true);
            assert_eq(initialized, false);

            //halfway through empty word
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(9000),
                true
            );
            assert_eq(i32::eq(next, i32::from(7680)), true);
            assert_eq(initialized, false);

            //boundary is initialized
            pool::flip_tick_for_testing(
                &mut pool,
                i32::from(3290),
                test_scenario::ctx(scenario),
            );
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(4560),
                true
            );
            assert_eq(i32::eq(next, i32::from(3290)), true);
            assert_eq(initialized, true);

            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_next_initialized_tick_within_one_word_for_testing_right() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        pool_factory_tests::init_pools(admin, player, player2, scenario);

        //is_initialized
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);

            let ticks = vector::empty<I32>();
            vector::push_back(&mut ticks, i32::neg_from(2000));
            vector::push_back(&mut ticks, i32::neg_from(550));
            vector::push_back(&mut ticks, i32::neg_from(40));
            vector::push_back(&mut ticks, i32::from(700));
            vector::push_back(&mut ticks, i32::from(780));
            vector::push_back(&mut ticks, i32::from(840));
            vector::push_back(&mut ticks, i32::from(1390));
            vector::push_back(&mut ticks, i32::from(2400));
            vector::push_back(&mut ticks, i32::from(5350));

            init_tick(
                &mut pool,
                &mut ticks,
                test_scenario::ctx(scenario),
            );

            //lte = false, to the right
            //returns tick to right if at initialized tick
            let (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(780),
                false
            );
            assert_eq(initialized, true);
            assert_eq(i32::eq(next, i32::from(840)), true);

            //returns tick to right if at initialized tick
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::neg_from(550),
                false
            );
            assert_eq(initialized, true);
            assert_eq(i32::eq(next, i32::neg_from(40)), true);

            //returns the tick directly to the right
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(770),
                false
            );
            assert_eq(initialized, true);
            assert_eq(i32::eq(next, i32::from(780)), true);	

            //returns the tick directly to the right
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::neg_from(560),
                false
            );
            assert_eq(initialized, true);
            assert_eq(i32::eq(next, i32::neg_from(550)), true);	

            //returns the next words initialized tick if on the right boundary
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(2550),
                false
            );
            assert_eq(i32::eq(next, i32::from(5110)), true);	
            assert_eq(initialized, false);

            //returns the next words initialized tick if on the right boundary
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::neg_from(2570),
                false
            );
            assert_eq(initialized, true);
            assert_eq(i32::eq(next, i32::neg_from(2000)), true);

            //does not exceed boundary
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(5080),
                false
            );
            assert_eq(initialized, false);
            assert_eq(i32::eq(next, i32::from(5110)), true);

            //skips entire word
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(2550),
                false
            );
            assert_eq(initialized, false);
            assert_eq(i32::eq(next, i32::from(5110)), true);

            //skips half word
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(3830),
                false
            );
            assert_eq(initialized, false);
            assert_eq(i32::eq(next, i32::from(5110)), true);

            //returns the next initialized tick from the next word
            pool::flip_tick_for_testing(
                &mut pool,
                i32::from(3400),
                test_scenario::ctx(scenario),
            );
            (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::from(3280),
                false
            );
            assert_eq(initialized, true);
            assert_eq(i32::eq(next, i32::from(3400)), true);

            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_next_initialized_tick_within_min_max() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        pool_factory_tests::init_pools(admin, player, player2, scenario);

        //is_initialized
        test_scenario::next_tx(scenario, player);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);

            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);
            let ticks = vector::empty<I32>();
            vector::push_back(&mut ticks, min_tick_index);
            vector::push_back(&mut ticks, max_tick_index);

            init_tick(
                &mut pool,
                &mut ticks,
                test_scenario::ctx(scenario),
            );

            let (next, initialized) = pool::next_initialized_tick_within_one_word_for_testing(
                &mut pool,
                i32::neg_from(1),
                true
            );
            assert_eq(initialized, false);
            assert_eq(i32::eq(next, i32::neg_from(2560)), true);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario_val);
    }
}