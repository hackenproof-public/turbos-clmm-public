// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::swap_router_partner_paths_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::test_utils::{assert_eq};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::partner::{Self, Partners, Partner, PartnerCap, PartnerAdminCap};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::swap_router;
    use turbos_clmm::tools_tests;
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::math_tick;
    use turbos_clmm::math_sqrt_price;
    use turbos_clmm::i32::{Self};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};

    const ADMIN: address = @0x100;
    const PLAYER: address = @0x101;
    const RECIPIENT: address = @0x102; // partner fee recipient
    const MAX_SQRT_PRICE_X64: u128 = 79226673515401279992447579055;
    const MIN_SQRT_PRICE_X64: u128 = 4295048016;

    fun setup_basic_pools(admin: address, player: address, scenario: &mut Scenario) {
        // Coins, factory, fees, clock, pool manager
        tools_tests::init_tests_coin(admin, player, player, 100000000, scenario);
        tools_tests::init_pool_factory(admin, scenario);
        tools_tests::init_fee_type(admin, scenario);

        test_scenario::next_tx(scenario, admin);
        { position_manager::init_for_testing(test_scenario::ctx(scenario)); };
        tools_tests::init_clock(admin, scenario);

        // Deploy BTC/USDC pool at price 1:1
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

        // Provide liquidity to BTC/USDC
        test_scenario::next_tx(scenario, player);
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
            position_manager::mint<BTC, USDC, FEE3000BPS>(
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
                player,
                1,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(pool_btc_usdc);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_immutable(fee_type);
        };
    }

    fun setup_partner_system(admin: address, scenario: &mut Scenario) {
        // Ensure factory exists
        test_scenario::next_tx(scenario, admin);
        { pool_factory::init_for_testing(test_scenario::ctx(scenario)); };

        // Enable partners via factory admin
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            pool_factory::init_partners(&admin_cap, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        // Create a partner active at current time
        test_scenario::next_tx(scenario, admin);
        {
            let partner_admin_cap = test_scenario::take_from_sender<PartnerAdminCap>(scenario);
            let partners = test_scenario::take_shared<Partners>(scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::set_for_testing(&mut clock, 1_500_000);
            partner::create_partner(
                &partner_admin_cap,
                &mut partners,
                std::string::utf8(b"RouterPartner"),
                500, // 5%
                1_000_000,
                2_000_000,
                RECIPIENT,
                &clock,
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(partners);
            test_scenario::return_to_sender(scenario, partner_admin_cap);
            clock::destroy_for_testing(clock);
        };
    }

    #[test]
    public fun test_swap_a_b_with_partner_exact_in() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pools(ADMIN, PLAYER, scenario);
        setup_partner_system(ADMIN, scenario);

        // Prepare partner, pool and inputs
        test_scenario::next_tx(scenario, PLAYER);
        {
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let shared_clock = test_scenario::take_shared<Clock>(scenario);
            let pool_btc_usdc = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let partner = test_scenario::take_shared<Partner>(scenario);

            // Pick one BTC coin from sender as input via ID list (avoids non-drop vectors)
            let btc_in = {
                let ids = test_scenario::ids_for_sender<Coin<BTC>>(scenario);
                let id = std::vector::pop_back(&mut ids);
                test_scenario::take_from_sender_by_id<Coin<BTC>>(scenario, id)
            };

            let deadline = clock::timestamp_ms(&shared_clock) + 10;
            let (btc_after, usdc_out) = swap_router::swap_a_b_with_partner<BTC, USDC, FEE3000BPS>(
                &mut pool_btc_usdc,
                &mut partner,
                btc_in,
                3,              // amount
                1,              // amount_threshold (min out)
                MIN_SQRT_PRICE_X64 + 1,
                true,           // exact in
                deadline,
                &shared_clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Output coin types are correct and some value transferred
            assert_eq(coin::value(&usdc_out) > 0, true);
            // Clean up output coins
            if (coin::value(&btc_after) == 0) { coin::destroy_zero(btc_after); } else { coin::burn_for_testing(btc_after); };
            if (coin::value(&usdc_out) == 0) { coin::destroy_zero(usdc_out); } else { coin::burn_for_testing(usdc_out); };

            test_scenario::return_shared(pool_btc_usdc);
            test_scenario::return_shared(partner);
            test_scenario::return_shared(shared_clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_swap_b_a_with_partner_exact_out() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pools(ADMIN, PLAYER, scenario);
        setup_partner_system(ADMIN, scenario);

        // Prepare partner, pool and inputs
        test_scenario::next_tx(scenario, PLAYER);
        {
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let shared_clock = test_scenario::take_shared<Clock>(scenario);
            let pool_btc_usdc = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let partner = test_scenario::take_shared<Partner>(scenario);

            // Pick one USDC coin from sender as input via ID list
            let usdc_in = {
                let ids = test_scenario::ids_for_sender<Coin<USDC>>(scenario);
                let id = std::vector::pop_back(&mut ids);
                test_scenario::take_from_sender_by_id<Coin<USDC>>(scenario, id)
            };

            let deadline = clock::timestamp_ms(&shared_clock) + 10;
            // exact out: want 2 BTC, cap max in at a large threshold
            let (btc_out, usdc_left) = swap_router::swap_b_a_with_partner<BTC, USDC, FEE3000BPS>(
                &mut pool_btc_usdc,
                &mut partner,
                usdc_in,
                2,              // amount (exact out)
                10_000_000,     // amount_threshold (max in)
                MAX_SQRT_PRICE_X64 - 1,
                false,          // exact out
                deadline,
                &shared_clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            assert_eq(coin::value(&btc_out), 2);
            // Clean up output BTC; return leftover USDC to sender
            if (coin::value(&btc_out) == 0) { coin::destroy_zero(btc_out); } else { coin::burn_for_testing(btc_out); };
            test_scenario::return_to_sender(scenario, usdc_left);

            test_scenario::return_shared(pool_btc_usdc);
            test_scenario::return_shared(partner);
            test_scenario::return_shared(shared_clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::swap_router::ETransactionTooOld)]
    public fun test_swap_a_b_with_partner_deadline_expired() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pools(ADMIN, PLAYER, scenario);
        setup_partner_system(ADMIN, scenario);

        test_scenario::next_tx(scenario, PLAYER);
        {
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let tmp_clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::set_for_testing(&mut tmp_clock, 1);
            let pool_btc_usdc = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let partner = test_scenario::take_shared<Partner>(scenario);

            let btc_in = {
                let ids = test_scenario::ids_for_sender<Coin<BTC>>(scenario);
                let id = std::vector::pop_back(&mut ids);
                test_scenario::take_from_sender_by_id<Coin<BTC>>(scenario, id)
            };

            let deadline = 0; // expired
            let (_btc_after, _usdc_out) = swap_router::swap_a_b_with_partner<BTC, USDC, FEE3000BPS>(
                &mut pool_btc_usdc,
                &mut partner,
                btc_in,
                1,
                1,
                MIN_SQRT_PRICE_X64 + 1,
                true,
                deadline,
                &tmp_clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            // Clean up if somehow not aborted
            if (coin::value(&_btc_after) == 0) { coin::destroy_zero(_btc_after); } else { coin::burn_for_testing(_btc_after); };
            if (coin::value(&_usdc_out) == 0) { coin::destroy_zero(_usdc_out); } else { coin::burn_for_testing(_usdc_out); };

            clock::destroy_for_testing(tmp_clock);
            test_scenario::return_shared(pool_btc_usdc);
            test_scenario::return_shared(partner);
            // no shared clock taken in this block
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::swap_router::EAmountOutBelowMinimum)]
    public fun test_swap_a_b_with_partner_threshold_too_high() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup_basic_pools(ADMIN, PLAYER, scenario);
        setup_partner_system(ADMIN, scenario);

        test_scenario::next_tx(scenario, PLAYER);
        {
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let pool_btc_usdc = test_scenario::take_shared<Pool<BTC, USDC, FEE3000BPS>>(scenario);
            let partner = test_scenario::take_shared<Partner>(scenario);

            let btc_in = {
                let ids = test_scenario::ids_for_sender<Coin<BTC>>(scenario);
                let id = std::vector::pop_back(&mut ids);
                test_scenario::take_from_sender_by_id<Coin<BTC>>(scenario, id)
            };

            let deadline = clock::timestamp_ms(&clock) + 10;
            let (_btc_after, _usdc_out) = swap_router::swap_a_b_with_partner<BTC, USDC, FEE3000BPS>(
                &mut pool_btc_usdc,
                &mut partner,
                btc_in,
                3,
                1_000_000_000, // unrealistically high min out
                MIN_SQRT_PRICE_X64 + 1,
                true,
                deadline,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );
            // Clean up if somehow not aborted
            if (coin::value(&_btc_after) == 0) { coin::destroy_zero(_btc_after); } else { coin::burn_for_testing(_btc_after); };
            if (coin::value(&_usdc_out) == 0) { coin::destroy_zero(_usdc_out); } else { coin::burn_for_testing(_usdc_out); };

            test_scenario::return_shared(pool_btc_usdc);
            test_scenario::return_shared(partner);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }
}
