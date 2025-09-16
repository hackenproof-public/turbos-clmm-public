// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::partner_comprehensive_tests {
    use std::string::{Self};
    use sui::test_scenario::{Self};
    use sui::clock::{Self};
    use sui::balance::{Self};
    use sui::bag;
    use sui::coin::{Self};
    use turbos_clmm::partner::{Self, Partners, Partner, PartnerCap, PartnerAdminCap};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap};
    use turbos_clmm::usdc::{Self, USDC};
    use turbos_clmm::eth::{Self, ETH};

    const ADMIN: address = @0x123;
    const PARTNER_RECIPIENT: address = @0x456;
    const PARTNER_USER: address = @0x789;

    // Helper function to set up complete partner system
    fun setup_partner_system(
        scenario: &mut test_scenario::Scenario,
        partner_name: vector<u8>,
        ref_fee_rate: u64,
        start_time: u64,
        end_time: u64,
        recipient: address
    ) {
        // Initialize pool factory
        {
            let ctx = test_scenario::ctx(scenario);
            pool_factory::init_for_testing(ctx);
        };
        
        test_scenario::next_tx(scenario, ADMIN);
        
        // Initialize partners system
        {
            let pool_factory_admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            pool_factory::init_partners(&pool_factory_admin_cap, ctx);
            test_scenario::return_to_sender(scenario, pool_factory_admin_cap);
        };
        
        test_scenario::next_tx(scenario, ADMIN);
        
        // Create partner
        {
            let partner_admin_cap = test_scenario::take_from_sender<PartnerAdminCap>(scenario);
            let partners = test_scenario::take_shared<Partners>(scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::set_for_testing(&mut clock, 1500000); // Set current time
            
            partner::create_partner(
                &partner_admin_cap,
                &mut partners,
                string::utf8(partner_name),
                ref_fee_rate,
                start_time,
                end_time,
                recipient,
                &clock,
                test_scenario::ctx(scenario)
            );
            
            test_scenario::return_shared(partners);
            test_scenario::return_to_sender(scenario, partner_admin_cap);
            clock::destroy_for_testing(clock);
        };
    }

    #[test]
    public fun test_partner_system_initialization() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_partner_system(
            scenario,
            b"TestPartner",
            500, // 5%
            1000,
            2000,
            PARTNER_RECIPIENT
        );
        
        test_scenario::next_tx(scenario, PARTNER_RECIPIENT);
        
        // Verify partner was created
        assert!(test_scenario::has_most_recent_shared<Partner>(), 1);
        
        // Verify partner cap was transferred
        let partner_cap = test_scenario::take_from_sender<PartnerCap>(scenario);
        test_scenario::return_to_sender(scenario, partner_cap);
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_partner_properties() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_partner_system(
            scenario,
            b"PropertyTestPartner",
            750, // 7.5%
            1000,
            2000,
            PARTNER_RECIPIENT
        );
        
        test_scenario::next_tx(scenario, PARTNER_RECIPIENT);
        
        let partner = test_scenario::take_shared<Partner>(scenario);
        
        // Test getter functions
        assert!(partner::name(&partner) == string::utf8(b"PropertyTestPartner"), 2);
        assert!(partner::ref_fee_rate(&partner) == 750, 3);
        assert!(partner::start_time(&partner) == 1000, 4);
        assert!(partner::end_time(&partner) == 2000, 5);
        
        // Test current_ref_fee_rate with different times
        assert!(partner::current_ref_fee_rate(&partner, 500) == 0, 6); // Before start
        assert!(partner::current_ref_fee_rate(&partner, 1500) == 750, 7); // During active period
        assert!(partner::current_ref_fee_rate(&partner, 2500) == 0, 8); // After end
        
        // Test balances function returns empty bag
        let balances = partner::balances(&partner);
        assert!(bag::is_empty(balances), 9);
        
        test_scenario::return_shared(partner);
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_receive_and_claim_ref_fee() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        // Initialize USDC token
        {
            let ctx = test_scenario::ctx(scenario);
            usdc::init_for_testing(ctx);
        };
        
        setup_partner_system(
            scenario,
            b"FeeTestPartner",
            500,
            1000,
            2000,
            PARTNER_RECIPIENT
        );
        
        test_scenario::next_tx(scenario, PARTNER_RECIPIENT);
        
        let partner = test_scenario::take_shared<Partner>(scenario);
        let partner_cap = test_scenario::take_from_sender<PartnerCap>(scenario);
        
        // Add some referral fee
        let fee_balance = balance::create_for_testing<USDC>(1500);
        partner::receive_ref_fee(&mut partner, fee_balance);
        
        // Verify balances are no longer empty
        let balances = partner::balances(&partner);
        assert!(!bag::is_empty(balances), 10);
        
        // Claim the referral fee
        partner::claim_ref_fee<USDC>(&partner_cap, &mut partner, test_scenario::ctx(scenario));
        
        test_scenario::return_shared(partner);
        test_scenario::return_to_sender(scenario, partner_cap);
        
        // Verify coin was transferred
        test_scenario::next_tx(scenario, PARTNER_RECIPIENT);
        let claimed_coin = test_scenario::take_from_sender<coin::Coin<USDC>>(scenario);
        assert!(coin::value(&claimed_coin) == 1500, 11);
        test_scenario::return_to_sender(scenario, claimed_coin);
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_multiple_coin_types() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        // Initialize tokens
        {
            let ctx = test_scenario::ctx(scenario);
            usdc::init_for_testing(ctx);
            eth::init_for_testing(ctx);
        };
        
        setup_partner_system(
            scenario,
            b"MultiCoinPartner",
            300,
            1000,
            2000,
            PARTNER_RECIPIENT
        );
        
        test_scenario::next_tx(scenario, PARTNER_RECIPIENT);
        
        let partner = test_scenario::take_shared<Partner>(scenario);
        let partner_cap = test_scenario::take_from_sender<PartnerCap>(scenario);
        
        // Add referral fees for multiple coin types
        let usdc_fee = balance::create_for_testing<USDC>(1000);
        let eth_fee = balance::create_for_testing<ETH>(2000);
        
        partner::receive_ref_fee(&mut partner, usdc_fee);
        partner::receive_ref_fee(&mut partner, eth_fee);
        
        // Claim USDC
        partner::claim_ref_fee<USDC>(&partner_cap, &mut partner, test_scenario::ctx(scenario));
        
        test_scenario::return_shared(partner);
        test_scenario::return_to_sender(scenario, partner_cap);
        
        // Verify USDC was claimed
        test_scenario::next_tx(scenario, PARTNER_RECIPIENT);
        let usdc_coin = test_scenario::take_from_sender<coin::Coin<USDC>>(scenario);
        assert!(coin::value(&usdc_coin) == 1000, 12);
        test_scenario::return_to_sender(scenario, usdc_coin);
        
        // Claim ETH
        let partner = test_scenario::take_shared<Partner>(scenario);
        let partner_cap = test_scenario::take_from_sender<PartnerCap>(scenario);
        
        partner::claim_ref_fee<ETH>(&partner_cap, &mut partner, test_scenario::ctx(scenario));
        
        test_scenario::return_shared(partner);
        test_scenario::return_to_sender(scenario, partner_cap);
        
        // Verify ETH was claimed
        test_scenario::next_tx(scenario, PARTNER_RECIPIENT);
        let eth_coin = test_scenario::take_from_sender<coin::Coin<ETH>>(scenario);
        assert!(coin::value(&eth_coin) == 2000, 13);
        test_scenario::return_to_sender(scenario, eth_coin);
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_update_ref_fee_rate() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_partner_system(
            scenario,
            b"UpdateTestPartner",
            500,
            1000,
            2000,
            PARTNER_RECIPIENT
        );
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let partner_admin_cap = test_scenario::take_from_sender<PartnerAdminCap>(scenario);
        let partner = test_scenario::take_shared<Partner>(scenario);
        
        // Verify initial fee rate
        assert!(partner::ref_fee_rate(&partner) == 500, 14);
        
        // Update fee rate
        let new_fee_rate = 750;
        partner::update_ref_fee_rate(&partner_admin_cap, &mut partner, new_fee_rate, test_scenario::ctx(scenario));
        
        // Verify fee rate was updated
        assert!(partner::ref_fee_rate(&partner) == new_fee_rate, 15);
        
        test_scenario::return_shared(partner);
        test_scenario::return_to_sender(scenario, partner_admin_cap);
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_update_time_range() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        setup_partner_system(
            scenario,
            b"TimeUpdatePartner",
            400,
            1000,
            2000,
            PARTNER_RECIPIENT
        );
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let partner_admin_cap = test_scenario::take_from_sender<PartnerAdminCap>(scenario);
        let partner = test_scenario::take_shared<Partner>(scenario);
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1500000);
        
        // Verify initial time range
        assert!(partner::start_time(&partner) == 1000, 16);
        assert!(partner::end_time(&partner) == 2000, 17);
        
        // Update time range
        let new_start_time = 1200;
        let new_end_time = 2500;
        partner::update_time_range(&partner_admin_cap, &mut partner, new_start_time, new_end_time, &clock, test_scenario::ctx(scenario));
        
        // Verify time range was updated
        assert!(partner::start_time(&partner) == new_start_time, 18);
        assert!(partner::end_time(&partner) == new_end_time, 19);
        
        test_scenario::return_shared(partner);
        test_scenario::return_to_sender(scenario, partner_admin_cap);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::partner::EInvalidReferralFeeRate)]
    public fun test_invalid_ref_fee_rate() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        // Initialize pool factory and partners
        {
            let ctx = test_scenario::ctx(scenario);
            pool_factory::init_for_testing(ctx);
        };
        
        test_scenario::next_tx(scenario, ADMIN);
        
        {
            let pool_factory_admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            pool_factory::init_partners(&pool_factory_admin_cap, ctx);
            test_scenario::return_to_sender(scenario, pool_factory_admin_cap);
        };
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let partner_admin_cap = test_scenario::take_from_sender<PartnerAdminCap>(scenario);
        let partners = test_scenario::take_shared<Partners>(scenario);
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1500000);
        
        // Try to create partner with invalid fee rate (>= 10000)
        partner::create_partner(
            &partner_admin_cap,
            &mut partners,
            string::utf8(b"InvalidPartner"),
            10000, // Invalid: should be < 10000
            1000,
            2000,
            PARTNER_RECIPIENT,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(partners);
        test_scenario::return_to_sender(scenario, partner_admin_cap);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::partner::EInvalidTime)]
    public fun test_invalid_time_range() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        // Initialize system
        {
            let ctx = test_scenario::ctx(scenario);
            pool_factory::init_for_testing(ctx);
        };
        
        test_scenario::next_tx(scenario, ADMIN);
        
        {
            let pool_factory_admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            pool_factory::init_partners(&pool_factory_admin_cap, ctx);
            test_scenario::return_to_sender(scenario, pool_factory_admin_cap);
        };
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let partner_admin_cap = test_scenario::take_from_sender<PartnerAdminCap>(scenario);
        let partners = test_scenario::take_shared<Partners>(scenario);
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1500000);
        
        // Try to create partner with end_time <= start_time
        partner::create_partner(
            &partner_admin_cap,
            &mut partners,
            string::utf8(b"InvalidTimePartner"),
            500,
            2000, // start_time
            1500, // end_time < start_time (invalid)
            PARTNER_RECIPIENT,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(partners);
        test_scenario::return_to_sender(scenario, partner_admin_cap);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::partner::EPartnerNameEmpty)]
    public fun test_empty_partner_name() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        // Initialize system
        {
            let ctx = test_scenario::ctx(scenario);
            pool_factory::init_for_testing(ctx);
        };
        
        test_scenario::next_tx(scenario, ADMIN);
        
        {
            let pool_factory_admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            pool_factory::init_partners(&pool_factory_admin_cap, ctx);
            test_scenario::return_to_sender(scenario, pool_factory_admin_cap);
        };
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let partner_admin_cap = test_scenario::take_from_sender<PartnerAdminCap>(scenario);
        let partners = test_scenario::take_shared<Partners>(scenario);
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1500000);
        
        // Try to create partner with empty name
        partner::create_partner(
            &partner_admin_cap,
            &mut partners,
            string::utf8(b""), // Empty name
            500,
            1000,
            2000,
            PARTNER_RECIPIENT,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(partners);
        test_scenario::return_to_sender(scenario, partner_admin_cap);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::partner::EEmptyPartnerFee)]
    public fun test_claim_empty_fee() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        // Initialize USDC token
        {
            let ctx = test_scenario::ctx(scenario);
            usdc::init_for_testing(ctx);
        };
        
        setup_partner_system(
            scenario,
            b"EmptyFeePartner",
            500,
            1000,
            2000,
            PARTNER_RECIPIENT
        );
        
        test_scenario::next_tx(scenario, PARTNER_RECIPIENT);
        
        let partner = test_scenario::take_shared<Partner>(scenario);
        let partner_cap = test_scenario::take_from_sender<PartnerCap>(scenario);
        
        // Try to claim fee without adding any (should fail)
        partner::claim_ref_fee<USDC>(&partner_cap, &mut partner, test_scenario::ctx(scenario));
        
        test_scenario::return_shared(partner);
        test_scenario::return_to_sender(scenario, partner_cap);
        test_scenario::end(scenario_val);
    }
}