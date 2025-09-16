// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::fee_types_comprehensive_tests {
    use sui::test_scenario::{Self};
    use turbos_clmm::fee::{Self, Fee};
    use turbos_clmm::fee100bps::{Self, FEE100BPS};
    use turbos_clmm::fee500bps::{Self, FEE500BPS};
    use turbos_clmm::fee1000bps::{Self, FEE1000BPS};
    use turbos_clmm::fee2000bps::{Self, FEE2000BPS};
    use turbos_clmm::fee2500bps::{Self, FEE2500BPS};
    use turbos_clmm::fee3000bps::{Self, FEE3000BPS};
    use turbos_clmm::fee10000bps::{Self, FEE10000BPS};
    use turbos_clmm::fee20000bps::{Self, FEE20000BPS};

    const ADMIN: address = @0x123;

    #[test]
    public fun test_fee100bps_initialization() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        let ctx = test_scenario::ctx(scenario);
        fee100bps::init_for_testing(ctx);
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let fee_obj = test_scenario::take_immutable<Fee<FEE100BPS>>(scenario);
        assert!(fee::get_fee(&fee_obj) == 100, 1);
        assert!(fee::get_tick_spacing(&fee_obj) == 2, 2);
        
        test_scenario::return_immutable(fee_obj);
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fee500bps_initialization() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        let ctx = test_scenario::ctx(scenario);
        fee500bps::init_for_testing(ctx);
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let fee_obj = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
        assert!(fee::get_fee(&fee_obj) == 500, 3);
        assert!(fee::get_tick_spacing(&fee_obj) == 10, 4);
        
        test_scenario::return_immutable(fee_obj);
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fee1000bps_initialization() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        let ctx = test_scenario::ctx(scenario);
        fee1000bps::init_for_testing(ctx);
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let fee_obj = test_scenario::take_immutable<Fee<FEE1000BPS>>(scenario);
        assert!(fee::get_fee(&fee_obj) == 1000, 5);
        assert!(fee::get_tick_spacing(&fee_obj) == 20, 6);
        
        test_scenario::return_immutable(fee_obj);
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fee2000bps_initialization() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        let ctx = test_scenario::ctx(scenario);
        fee2000bps::init_for_testing(ctx);
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let fee_obj = test_scenario::take_immutable<Fee<FEE2000BPS>>(scenario);
        assert!(fee::get_fee(&fee_obj) == 2000, 7);
        assert!(fee::get_tick_spacing(&fee_obj) == 40, 8);
        
        test_scenario::return_immutable(fee_obj);
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fee2500bps_initialization() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        let ctx = test_scenario::ctx(scenario);
        fee2500bps::init_for_testing(ctx);
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let fee_obj = test_scenario::take_immutable<Fee<FEE2500BPS>>(scenario);
        assert!(fee::get_fee(&fee_obj) == 2500, 9);
        assert!(fee::get_tick_spacing(&fee_obj) == 50, 10);
        
        test_scenario::return_immutable(fee_obj);
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fee3000bps_initialization() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        let ctx = test_scenario::ctx(scenario);
        fee3000bps::init_for_testing(ctx);
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let fee_obj = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
        assert!(fee::get_fee(&fee_obj) == 3000, 11);
        assert!(fee::get_tick_spacing(&fee_obj) == 60, 12);
        
        test_scenario::return_immutable(fee_obj);
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fee10000bps_initialization() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        let ctx = test_scenario::ctx(scenario);
        fee10000bps::init_for_testing(ctx);
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let fee_obj = test_scenario::take_immutable<Fee<FEE10000BPS>>(scenario);
        assert!(fee::get_fee(&fee_obj) == 10000, 13);
        assert!(fee::get_tick_spacing(&fee_obj) == 200, 14);
        
        test_scenario::return_immutable(fee_obj);
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fee20000bps_initialization() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        let ctx = test_scenario::ctx(scenario);
        fee20000bps::init_for_testing(ctx);
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let fee_obj = test_scenario::take_immutable<Fee<FEE20000BPS>>(scenario);
        assert!(fee::get_fee(&fee_obj) == 20000, 15);
        assert!(fee::get_tick_spacing(&fee_obj) == 220, 16);
        
        test_scenario::return_immutable(fee_obj);
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fee_tiers_ordering() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        let ctx = test_scenario::ctx(scenario);
        
        // Initialize all fee types
        fee100bps::init_for_testing(ctx);
        fee500bps::init_for_testing(ctx);
        fee1000bps::init_for_testing(ctx);
        fee2000bps::init_for_testing(ctx);
        fee2500bps::init_for_testing(ctx);
        fee3000bps::init_for_testing(ctx);
        fee10000bps::init_for_testing(ctx);
        fee20000bps::init_for_testing(ctx);
        
        test_scenario::next_tx(scenario, ADMIN);
        
        // Verify fee ordering: lower fees should have tighter tick spacing
        let fee100 = test_scenario::take_immutable<Fee<FEE100BPS>>(scenario);
        let fee500 = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
        let fee1000 = test_scenario::take_immutable<Fee<FEE1000BPS>>(scenario);
        let fee2000 = test_scenario::take_immutable<Fee<FEE2000BPS>>(scenario);
        let fee2500 = test_scenario::take_immutable<Fee<FEE2500BPS>>(scenario);
        let fee3000 = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
        let fee10000 = test_scenario::take_immutable<Fee<FEE10000BPS>>(scenario);
        let fee20000 = test_scenario::take_immutable<Fee<FEE20000BPS>>(scenario);
        
        // Verify fees are in ascending order
        assert!(fee::get_fee(&fee100) < fee::get_fee(&fee500), 17);
        assert!(fee::get_fee(&fee500) < fee::get_fee(&fee1000), 18);
        assert!(fee::get_fee(&fee1000) < fee::get_fee(&fee2000), 19);
        assert!(fee::get_fee(&fee2000) < fee::get_fee(&fee2500), 20);
        assert!(fee::get_fee(&fee2500) < fee::get_fee(&fee3000), 21);
        assert!(fee::get_fee(&fee3000) < fee::get_fee(&fee10000), 22);
        assert!(fee::get_fee(&fee10000) < fee::get_fee(&fee20000), 23);
        
        // Verify tick spacing increases with fee (generally)
        assert!(fee::get_tick_spacing(&fee100) <= fee::get_tick_spacing(&fee500), 24);
        assert!(fee::get_tick_spacing(&fee500) <= fee::get_tick_spacing(&fee1000), 25);
        assert!(fee::get_tick_spacing(&fee1000) <= fee::get_tick_spacing(&fee2000), 26);
        assert!(fee::get_tick_spacing(&fee2000) <= fee::get_tick_spacing(&fee2500), 27);
        assert!(fee::get_tick_spacing(&fee2500) <= fee::get_tick_spacing(&fee3000), 28);
        assert!(fee::get_tick_spacing(&fee3000) <= fee::get_tick_spacing(&fee10000), 29);
        assert!(fee::get_tick_spacing(&fee10000) <= fee::get_tick_spacing(&fee20000), 30);
        
        test_scenario::return_immutable(fee100);
        test_scenario::return_immutable(fee500);
        test_scenario::return_immutable(fee1000);
        test_scenario::return_immutable(fee2000);
        test_scenario::return_immutable(fee2500);
        test_scenario::return_immutable(fee3000);
        test_scenario::return_immutable(fee10000);
        test_scenario::return_immutable(fee20000);
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fee_bps_to_percentage() {
        // Test that fee basis points correspond to correct percentages
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        let ctx = test_scenario::ctx(scenario);
        fee100bps::init_for_testing(ctx);
        fee500bps::init_for_testing(ctx);
        fee3000bps::init_for_testing(ctx);
        fee10000bps::init_for_testing(ctx);
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let fee100 = test_scenario::take_immutable<Fee<FEE100BPS>>(scenario);
        let fee500 = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
        let fee3000 = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
        let fee10000 = test_scenario::take_immutable<Fee<FEE10000BPS>>(scenario);
        
        // 100 bps = 1%, 500 bps = 5%, 3000 bps = 30%, 10000 bps = 100%
        assert!(fee::get_fee(&fee100) == 100, 31); // 1%
        assert!(fee::get_fee(&fee500) == 500, 32); // 5%  
        assert!(fee::get_fee(&fee3000) == 3000, 33); // 30%
        assert!(fee::get_fee(&fee10000) == 10000, 34); // 100%
        
        test_scenario::return_immutable(fee100);
        test_scenario::return_immutable(fee500);
        test_scenario::return_immutable(fee3000);
        test_scenario::return_immutable(fee10000);
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_tick_spacing_constraints() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        let ctx = test_scenario::ctx(scenario);
        
        // Initialize all fee types
        fee100bps::init_for_testing(ctx);
        fee500bps::init_for_testing(ctx);
        fee1000bps::init_for_testing(ctx);
        fee2000bps::init_for_testing(ctx);
        fee2500bps::init_for_testing(ctx);
        fee3000bps::init_for_testing(ctx);
        fee10000bps::init_for_testing(ctx);
        fee20000bps::init_for_testing(ctx);
        
        test_scenario::next_tx(scenario, ADMIN);
        
        let fee100 = test_scenario::take_immutable<Fee<FEE100BPS>>(scenario);
        let fee500 = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
        let fee1000 = test_scenario::take_immutable<Fee<FEE1000BPS>>(scenario);
        let fee2000 = test_scenario::take_immutable<Fee<FEE2000BPS>>(scenario);
        let fee2500 = test_scenario::take_immutable<Fee<FEE2500BPS>>(scenario);
        let fee3000 = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
        let fee10000 = test_scenario::take_immutable<Fee<FEE10000BPS>>(scenario);
        let fee20000 = test_scenario::take_immutable<Fee<FEE20000BPS>>(scenario);
        
        // Verify all tick spacings are positive and reasonable
        assert!(fee::get_tick_spacing(&fee100) > 0, 35);
        assert!(fee::get_tick_spacing(&fee500) > 0, 36);
        assert!(fee::get_tick_spacing(&fee1000) > 0, 37);
        assert!(fee::get_tick_spacing(&fee2000) > 0, 38);
        assert!(fee::get_tick_spacing(&fee2500) > 0, 39);
        assert!(fee::get_tick_spacing(&fee3000) > 0, 40);
        assert!(fee::get_tick_spacing(&fee10000) > 0, 41);
        assert!(fee::get_tick_spacing(&fee20000) > 0, 42);
        
        // Verify tick spacings are reasonable (not too large)
        assert!(fee::get_tick_spacing(&fee100) <= 10000, 43);
        assert!(fee::get_tick_spacing(&fee500) <= 10000, 44);
        assert!(fee::get_tick_spacing(&fee1000) <= 10000, 45);
        assert!(fee::get_tick_spacing(&fee2000) <= 10000, 46);
        assert!(fee::get_tick_spacing(&fee2500) <= 10000, 47);
        assert!(fee::get_tick_spacing(&fee3000) <= 10000, 48);
        assert!(fee::get_tick_spacing(&fee10000) <= 10000, 49);
        assert!(fee::get_tick_spacing(&fee20000) <= 10000, 50);
        
        test_scenario::return_immutable(fee100);
        test_scenario::return_immutable(fee500);
        test_scenario::return_immutable(fee1000);
        test_scenario::return_immutable(fee2000);
        test_scenario::return_immutable(fee2500);
        test_scenario::return_immutable(fee3000);
        test_scenario::return_immutable(fee10000);
        test_scenario::return_immutable(fee20000);
        
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_fee_objects_are_immutable() {
        // This test verifies that fee objects are frozen/immutable after creation
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        let ctx = test_scenario::ctx(scenario);
        fee100bps::init_for_testing(ctx);
        
        test_scenario::next_tx(scenario, ADMIN);
        
        // If we can take_immutable, it means the object was properly frozen
        let fee_obj = test_scenario::take_immutable<Fee<FEE100BPS>>(scenario);
        
        // Verify the fee object has expected values
        assert!(fee::get_fee(&fee_obj) == 100, 51);
        assert!(fee::get_tick_spacing(&fee_obj) == 2, 52);
        
        test_scenario::return_immutable(fee_obj);
        test_scenario::end(scenario_val);
    }
}