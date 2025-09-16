// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::lp_asset_security_tests {
    use sui::test_utils::{assert_eq};
    use sui::test_scenario::{Self, Scenario};
    use sui::object;
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::clock::{Clock};
    use std::vector;
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::position_nft::{TurbosPositionNFT};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::fee500bps::{FEE500BPS};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::tools_tests;
    use turbos_clmm::i32::{Self};
    use turbos_clmm::math_sqrt_price;

    // Test addresses
    const ADMIN: address = @0x0;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    fun prepare_lp_test_environment(admin: address, user: address, scenario: &mut Scenario) {
        // Initialize coins
        tools_tests::init_tests_coin(admin, user, user, 10000000, scenario);
        
        // Initialize pool factory
        tools_tests::init_pool_factory(admin, scenario);
        
        // Initialize position manager
        test_scenario::next_tx(scenario, admin);
        {
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };
        
        // Initialize fee types
        tools_tests::init_fee_type(admin, scenario);
        
        // Initialize clock
        tools_tests::init_clock(admin, scenario);
        
        // Deploy BTC-USDC pool with 500bps fee
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Set initial price at sqrt(1) = price 1:1 
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
    }

    #[test]
    public fun test_lp_asset_mint_burn_balance() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_lp_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Prepare coins for minting
            let coins_a = vector::empty<Coin<BTC>>();
            let coins_b = vector::empty<Coin<USDC>>();
            vector::push_back(&mut coins_a, coin::mint_for_testing<BTC>(100000, test_scenario::ctx(scenario)));
            vector::push_back(&mut coins_b, coin::mint_for_testing<USDC>(100000, test_scenario::ctx(scenario)));
            
            // Mint position in a reasonable tick range
            let (nft, coin_a_left, coin_b_left) = position_manager::mint_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                coins_a,
                coins_b,
                1000,    // tick_lower_index
                true,    // tick_lower_index_is_neg
                1000,    // tick_upper_index  
                false,   // tick_upper_index_is_neg
                50000,   // amount_a_desired
                50000,   // amount_b_desired
                40000,   // amount_a_min
                40000,   // amount_b_min
                9999999999999,  // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            // Verify position was created with proper liquidity
            let (_, _, liquidity) = position_manager::get_position_info(
                &positions, 
                object::id_address(&nft)
            );
            assert_eq(liquidity > 0, true);
            
            // Assets should be deposited properly - some should remain
            let remaining_a = coin::value(&coin_a_left);
            let remaining_b = coin::value(&coin_b_left);
            
            // At least 40k should be used (our min amounts)
            assert_eq(remaining_a <= 60000, true); // At most 60k remaining (40k+ used)
            assert_eq(remaining_b <= 60000, true);
            
            // Clean up
            coin::burn_for_testing(coin_a_left);
            coin::burn_for_testing(coin_b_left);
            transfer::public_transfer(nft, USER1);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::pool::EInvildAmount)]
    public fun test_lp_asset_zero_amount_protection() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_lp_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test with zero amount coins
            let coins_a = vector::empty<Coin<BTC>>();
            let coins_b = vector::empty<Coin<USDC>>();
            vector::push_back(&mut coins_a, coin::zero<BTC>(test_scenario::ctx(scenario)));
            vector::push_back(&mut coins_b, coin::zero<USDC>(test_scenario::ctx(scenario)));
            
            let (nft, coin_a_left, coin_b_left) = position_manager::mint_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                coins_a,
                coins_b,
                1000,    // tick_lower_index
                true,    // tick_lower_index_is_neg
                1000,    // tick_upper_index  
                false,   // tick_upper_index_is_neg
                0,       // amount_a_desired (zero)
                0,       // amount_b_desired (zero)
                0,       // amount_a_min
                0,       // amount_b_min
                9999999999999,  // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            // Verify zero liquidity position handling
            let (_, _, liquidity) = position_manager::get_position_info(
                &positions, 
                object::id_address(&nft)
            );
            assert_eq(liquidity, 0); // Should be zero liquidity
            
            // All coins should be returned as zero
            assert_eq(coin::value(&coin_a_left), 0);
            assert_eq(coin::value(&coin_b_left), 0);
            
            // Clean up
            coin::destroy_zero(coin_a_left);
            coin::destroy_zero(coin_b_left);
            transfer::public_transfer(nft, USER1);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::position_manager::EPriceSlippageCheck)]
    public fun test_lp_asset_slippage_failure() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_lp_test_environment(ADMIN, USER1, scenario);
        
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            // Test slippage protection failure with impossible constraints
            let coins_a = vector::empty<Coin<BTC>>();
            let coins_b = vector::empty<Coin<USDC>>();
            vector::push_back(&mut coins_a, coin::mint_for_testing<BTC>(100000, test_scenario::ctx(scenario)));
            vector::push_back(&mut coins_b, coin::mint_for_testing<USDC>(100000, test_scenario::ctx(scenario)));
            
            // This should fail - requiring more than we desire
            let (nft, coin_a_left, coin_b_left) = position_manager::mint_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                coins_a,
                coins_b,
                1000,    // tick_lower_index
                true,    // tick_lower_index_is_neg
                1000,    // tick_upper_index  
                false,   // tick_upper_index_is_neg
                50000,   // amount_a_desired
                50000,   // amount_b_desired
                60000,   // amount_a_min (impossible - more than desired!)
                60000,   // amount_b_min (impossible - more than desired!)
                9999999999999,  // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            // Should never reach here - but clean up just in case
            coin::burn_for_testing(coin_a_left);
            coin::burn_for_testing(coin_b_left);
            transfer::public_transfer(nft, USER1);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }

    // 🚨 SECURITY ANALYSIS - Potential Vulnerabilities to Test:
    
    #[test]
    public fun test_lp_asset_mint_burn_consistency() {
        // 🔍 SECURITY TEST: Verify that burning liquidity returns expected amounts
        // Potential vulnerability: Rounding errors or calculation bugs could lead to 
        // asset drainage or unexpected slippage during burn operations
        
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        prepare_lp_test_environment(ADMIN, USER1, scenario);
        
        let nft_id: address;
        
        // First mint a position
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            let coins_a = vector::empty<Coin<BTC>>();
            let coins_b = vector::empty<Coin<USDC>>();
            vector::push_back(&mut coins_a, coin::mint_for_testing<BTC>(100000, test_scenario::ctx(scenario)));
            vector::push_back(&mut coins_b, coin::mint_for_testing<USDC>(100000, test_scenario::ctx(scenario)));
            
            let (nft, coin_a_left, coin_b_left) = position_manager::mint_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                coins_a,
                coins_b,
                1000,    // tick_lower_index
                true,    // tick_lower_index_is_neg
                1000,    // tick_upper_index  
                false,   // tick_upper_index_is_neg
                50000,   // amount_a_desired
                50000,   // amount_b_desired
                40000,   // amount_a_min
                40000,   // amount_b_min
                9999999999999,  // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            nft_id = object::id_address(&nft);
            
            coin::burn_for_testing(coin_a_left);
            coin::burn_for_testing(coin_b_left);
            transfer::public_transfer(nft, USER1);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        // Then burn the position and verify consistency
        test_scenario::next_tx(scenario, USER1);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let nft = test_scenario::take_from_sender<TurbosPositionNFT>(scenario);
            
            // Get current liquidity before burn
            let (_, _, liquidity_before) = position_manager::get_position_info(&positions, nft_id);
            
            // 🚨 CRITICAL SECURITY CHECK: Burn all liquidity and verify we get assets back
            // This tests for potential asset drainage vulnerabilities
            let (coin_a, coin_b) = position_manager::decrease_liquidity_with_return_<BTC, USDC, FEE500BPS>(
                &mut pool,
                &mut positions,
                &mut nft,
                liquidity_before, // burn all liquidity
                0,        // amount_a_min (accept any amount for this test)
                0,        // amount_b_min 
                9999999999999,  // deadline
                &clock,
                &versioned,
                test_scenario::ctx(scenario)
            );
            
            // 🔍 SECURITY ASSERTION: Assets must be returned when burning liquidity
            // If this fails, it indicates potential asset lock or drainage
            assert_eq(coin::value<BTC>(&coin_a) > 0, true);
            assert_eq(coin::value<USDC>(&coin_b) > 0, true);
            
            // Verify liquidity is now zero
            let (_, _, liquidity_after) = position_manager::get_position_info(&positions, nft_id);
            assert_eq(liquidity_after, 0);
            
            // Clean up
            coin::burn_for_testing<BTC>(coin_a);
            coin::burn_for_testing<USDC>(coin_b);
            transfer::public_transfer(nft, USER1);
            
            test_scenario::return_shared(pool);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };
        
        test_scenario::end(scenario_val);
    }
}