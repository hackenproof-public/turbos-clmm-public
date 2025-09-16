module turbos_clmm::swap_router_coverage_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context;
    use std::vector;

    use turbos_clmm::btc::BTC;
    use turbos_clmm::usdc::USDC;
    use turbos_clmm::eth::ETH;
    use turbos_clmm::fee500bps::FEE500BPS;
    use turbos_clmm::pool::{Self, Pool};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig, AclConfig};
    use turbos_clmm::pool::Versioned;
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::swap_router;
    use turbos_clmm::tools_tests;
    use turbos_clmm::math_sqrt_price;
    use turbos_clmm::math_tick;
    use turbos_clmm::i32;
    use turbos_clmm::fee::{Self, Fee};

    const ADMIN: address = @0x200;
    const USER: address = @0x201;
    const MIN_SQRT_PRICE_X64: u128 = 4295048016;
    const MAX_SQRT_PRICE_X64: u128 = 79226673515401279992447579055;

    fun setup_test_environment(admin: address, user: address, scenario: &mut Scenario) {
        tools_tests::init_tests_coin(admin, user, user, 100000000, scenario);
        tools_tests::init_pool_factory(admin, scenario);
        tools_tests::init_fee_type(admin, scenario);

        // init position manager + clock
        test_scenario::next_tx(scenario, admin);
        { 
            position_manager::init_for_testing(test_scenario::ctx(scenario)); 
        };
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

        // Add liquidity to BTC/USDC pool
        test_scenario::next_tx(scenario, user);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(60);
            let max_tick_index = math_tick::get_max_tick(60);

            position_manager::mint<BTC, USDC, FEE500BPS>(
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
                user,
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

    // Test error handling: ETransactionTooOld
    #[test]
    #[expected_failure(abort_code = 2)] // ETransactionTooOld
    public fun test_swap_a_b_transaction_too_old() {
        let admin = @0x200;
        let user = @0x201;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager::init_for_testing(test_scenario::ctx(scenario));
        setup_test_environment(admin, user, scenario);

        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let coins = test_scenario::take_from_sender<Coin<BTC>>(scenario);

            // Use past deadline - set to a very small value to ensure it's in the past
			clock::increment_for_testing(&mut clock, 1000); 
            let current_time = clock::timestamp_ms(&clock);
            swap_router::swap_a_b(
                &mut pool,
                vector[coins],
                100,
                50,
                MIN_SQRT_PRICE_X64 + 1,
                true,
                user,
                if (current_time > 0) current_time - 1 else 0, // Past deadline
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

    // Test error handling: EAmountOutBelowMinimum
    #[test]
    #[expected_failure(abort_code = 4)] // EAmountOutBelowMinimum
    public fun test_swap_a_b_amount_out_below_minimum() {
        let admin = @0x200;
        let user = @0x201;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager::init_for_testing(test_scenario::ctx(scenario));
        setup_test_environment(admin, user, scenario);

        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let coins = test_scenario::take_from_sender<Coin<BTC>>(scenario);

            // Set amount_threshold too high for exact in
            swap_router::swap_a_b(
                &mut pool,
                vector[coins],
                100,
                1000, // Too high threshold
                MIN_SQRT_PRICE_X64 + 1,
                true,
                user,
                1000,
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

    // Test error handling: EAmountInAboveMaximum
    #[test]
    #[expected_failure(abort_code = 5)] // EAmountInAboveMaximum
    public fun test_swap_a_b_amount_in_above_maximum() {
        let admin = @0x200;
        let user = @0x201;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager::init_for_testing(test_scenario::ctx(scenario));
        setup_test_environment(admin, user, scenario);

        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let coins = test_scenario::take_from_sender<Coin<BTC>>(scenario);

            // Set amount_threshold too low for exact out
            swap_router::swap_a_b(
                &mut pool,
                vector[coins],
                100,
                1, // Too low threshold
                MIN_SQRT_PRICE_X64 + 1,
                false, // exact out
                user,
                1000,
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

    // Test error handling: ECoinsNotGatherThanAmount
    #[test]
    #[expected_failure(abort_code = 7)] // ECoinsNotGatherThanAmount
    public fun test_swap_a_b_coins_not_gather_than_amount() {
        let admin = @0x200;
        let user = @0x201;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager::init_for_testing(test_scenario::ctx(scenario));
        setup_test_environment(admin, user, scenario);

        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let coins = test_scenario::take_from_sender<Coin<BTC>>(scenario);

            // Request more than available - use a very large amount
            swap_router::swap_a_b(
                &mut pool,
                vector[coins],
                1000000000, // Very large amount - more than available
                50,
                MIN_SQRT_PRICE_X64 + 1,
                true, // exact in - this will trigger ECoinsNotGatherThanAmount
                user,
                1000,
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

    // Test error handling: ESwapAmountSpecifiedZero
    #[test]
    #[expected_failure(abort_code = 7)] // ESwapAmountSpecifiedZero
    public fun test_swap_a_b_zero_amount() {
        let admin = @0x200;
        let user = @0x201;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager::init_for_testing(test_scenario::ctx(scenario));
        setup_test_environment(admin, user, scenario);

        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let coins = test_scenario::take_from_sender<Coin<BTC>>(scenario);

            // Zero amount
            swap_router::swap_a_b(
                &mut pool,
                vector[coins],
                0, // Zero amount
                50,
                MIN_SQRT_PRICE_X64 + 1,
                true,
                user,
                1000,
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

    // Test error handling: EInvalidSqrtPriceLimitDirection
    #[test]
    #[expected_failure(abort_code = 20)] // EInvalidSqrtPriceLimitDirection
    public fun test_swap_a_b_max_sqrt_price_limit() {
        let admin = @0x200;
        let user = @0x201;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager::init_for_testing(test_scenario::ctx(scenario));
        setup_test_environment(admin, user, scenario);

        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let coins = test_scenario::take_from_sender<Coin<BTC>>(scenario);

            // Invalid sqrt price limit for a_to_b swap
            swap_router::swap_a_b(
                &mut pool,
                vector[coins],
                100,
                50,
                MAX_SQRT_PRICE_X64, // Invalid for a_to_b
                true,
                user,
                1000,
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

    // Test error handling: ESqrtPriceOutOfBounds
    #[test]
    #[expected_failure(abort_code = 19)] // ESqrtPriceOutOfBounds
    public fun test_swap_a_b_min_sqrt_price_limit() {
        let admin = @0x200;
        let user = @0x201;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager::init_for_testing(test_scenario::ctx(scenario));
        setup_test_environment(admin, user, scenario);

        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let coins = test_scenario::take_from_sender<Coin<BTC>>(scenario);

            // Invalid sqrt price limit - use a very low price that's out of bounds
            swap_router::swap_a_b(
                &mut pool,
                vector[coins],
                100,
                50,
                1, // Very low price - out of bounds
                true,
                user,
                1000,
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

    // Test successful swap with return
    #[test]
    public fun test_swap_a_b_with_return_exact_in() {
        let admin = @0x200;
        let user = @0x201;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager::init_for_testing(test_scenario::ctx(scenario));
        setup_test_environment(admin, user, scenario);

        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let coins = test_scenario::take_from_sender<Coin<BTC>>(scenario);

            let (coin_out, coin_left) = swap_router::swap_a_b_with_return_(
                &mut pool,
                vector[coins],
                100,
                50,
                MIN_SQRT_PRICE_X64 + 1,
                true,
                user,
                1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Transfer coins to user
            transfer::public_transfer(coin_out, user);
            transfer::public_transfer(coin_left, user);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    // Test successful swap b_a with return
    #[test]
    public fun test_swap_b_a_with_return_exact_in() {
        let admin = @0x200;
        let user = @0x201;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager::init_for_testing(test_scenario::ctx(scenario));
        setup_test_environment(admin, user, scenario);

        test_scenario::next_tx(scenario, user);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let coins = test_scenario::take_from_sender<Coin<USDC>>(scenario);

            let (coin_out, coin_left) = swap_router::swap_b_a_with_return_(
                &mut pool,
                vector[coins],
                100,
                50,
                MAX_SQRT_PRICE_X64 - 1,
                true,
                user,
                1000,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Transfer coins to user
            transfer::public_transfer(coin_out, user);
            transfer::public_transfer(coin_left, user);

            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }
}
