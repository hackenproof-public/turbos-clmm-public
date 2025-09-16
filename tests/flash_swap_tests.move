// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::flash_swap_tests {
    use sui::test_utils::{assert_eq};
    use sui::coin::{Self, Coin};
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
    use turbos_clmm::position_manager_tests;
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::math_sqrt_price::{Self};
    use sui::clock::{Clock};
    use sui::transfer;

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
    public fun test_flash_swap_a_b_exact_in() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, player);
        {
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);

            let (coin_a, coin_b, flash_swap_receipt) = pool::flash_swap(
                &mut pool_a,
                player,
                true,
                3, //amount_in 
                true,
                MIN_SQRT_PRICE_X64 + 1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            let (_, _, pay_amount) = pool::get_flash_swap_receipt_info<BTC, USDC>(&flash_swap_receipt);
            assert_eq(coin::value(&coin_a), 0);
            assert_eq(coin::value(&coin_b), 1);
            assert_eq(pay_amount, 3);

            //repay coin a
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let coin_a_repay = coin::split(&mut btc, pay_amount, test_scenario::ctx(scenario));

            pool::repay_flash_swap(
                &mut pool_a,
                coin_a_repay,
                coin::zero<USDC>(test_scenario::ctx(scenario)),
                flash_swap_receipt,
                &versioned,
            );
            transfer::public_transfer(coin_b, player);

            coin::destroy_zero(coin_a);
            test_scenario::return_to_sender(scenario, btc);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_flash_swap_a_b_exact_out() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);

            let (coin_a, coin_b, flash_swap_receipt) = pool::flash_swap(
                &mut pool_a,
                player,
                true,
                3, //amount_in 
                false,
                MIN_SQRT_PRICE_X64 + 1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            let (_, _, pay_amount) = pool::get_flash_swap_receipt_info<BTC, USDC>(&flash_swap_receipt);
            assert_eq(coin::value(&coin_a), 0);
            assert_eq(coin::value(&coin_b), 3);
            assert_eq(pay_amount, 4);

            //repay coin a
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let coin_a_repay = coin::split(&mut btc, pay_amount, test_scenario::ctx(scenario));

            pool::repay_flash_swap(
                &mut pool_a,
                coin_a_repay,
                coin::zero<USDC>(test_scenario::ctx(scenario)),
                flash_swap_receipt,
                &versioned,
            );
            transfer::public_transfer(coin_b, player);

            coin::destroy_zero(coin_a);
            test_scenario::return_to_sender(scenario, btc);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_flash_swap_b_a_exact_in() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);

            let (coin_a, coin_b, flash_swap_receipt) = pool::flash_swap(
                &mut pool_a,
                player,
                false,
                3, //amount_in usdc
                true,
                MAX_SQRT_PRICE_X64 - 1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            let (_, _, pay_amount) = pool::get_flash_swap_receipt_info<BTC, USDC>(&flash_swap_receipt);
            assert_eq(coin::value(&coin_a), 1);
            assert_eq(coin::value(&coin_b), 0);
            assert_eq(pay_amount, 3);

            //repay coin b
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let coin_b_repay = coin::split(&mut usdc, pay_amount, test_scenario::ctx(scenario));

            pool::repay_flash_swap(
                &mut pool_a,
                coin::zero<BTC>(test_scenario::ctx(scenario)),
                coin_b_repay,
                flash_swap_receipt,
                &versioned,
            );
            transfer::public_transfer(coin_a, player);

            coin::destroy_zero(coin_b);
            test_scenario::return_to_sender(scenario, usdc);

            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
        };

        test_scenario::end(scenario_val);
    }

     #[test]
    public fun test_flash_swap_b_a_exact_out() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        position_manager_tests::init_pool_manager(admin, scenario);

        prepare_tests(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, player);
        {
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let pool_a = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);

            let (coin_a, coin_b, flash_swap_receipt) = pool::flash_swap(
                &mut pool_a,
                player,
                false,
                300, //amount_out btc
                false,
                MAX_SQRT_PRICE_X64 - 1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            let (_, _, pay_amount) = pool::get_flash_swap_receipt_info<BTC, USDC>(&flash_swap_receipt);
            assert_eq(coin::value(&coin_a), 300);
            assert_eq(coin::value(&coin_b), 0);
            assert_eq(pay_amount, 301);

            //repay coin b
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let coin_b_repay = coin::split(&mut usdc, pay_amount, test_scenario::ctx(scenario));

            pool::repay_flash_swap(
                &mut pool_a,
                coin::zero<BTC>(test_scenario::ctx(scenario)),
                coin_b_repay,
                flash_swap_receipt,
                &versioned,
            );
            transfer::public_transfer(coin_a, player);

            coin::destroy_zero(coin_b);
            test_scenario::return_to_sender(scenario, usdc);

            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(pool_a);
        };

        test_scenario::end(scenario_val);
    }
}