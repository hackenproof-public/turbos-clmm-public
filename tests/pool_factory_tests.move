// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::pool_factory_tests {
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig, AclConfig};
    use sui::test_utils::{assert_eq};
    use sui::coin::{Self, Coin};
    use sui::test_scenario::{Self, Scenario};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::trb::{TRB};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::tools_tests;
    use turbos_clmm::fee500bps::{FEE500BPS};
    use turbos_clmm::fee3000bps::{FEE3000BPS};
    use turbos_clmm::math_sqrt_price::{Self};
    use turbos_clmm::i32::{Self};
    use turbos_clmm::math_tick;
    use turbos_clmm::position_manager::{Self,Positions};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use std::string::{Self};
    use sui::clock::{Self, Clock};
    use sui::object::{Self};
    use sui::transfer::{Self};
    use std::vector::{Self};
    use std::option::{Self};

    public fun init_pools(
        admin: address,
        player: address,
        player2: address, 
        scenario: &mut Scenario,
    ) {
        tools_tests::init_tests_coin(
            admin,
            player,
            player2,
            10000,
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
            admin,
            scenario
        );

        //init BTCUSDC pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            //price=1 1btc = 1usdc
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
            test_scenario::return_shared(clock);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };

        //init BTCUSDC pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            //price=1 1btc = 1usdc
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
            test_scenario::return_shared(clock);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };

        //init USDCTRB pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            //price=0.01 1usdc = 0.01BTC
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 100);
            pool_factory::deploy_pool<USDC, TRB, FEE500BPS>(
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
    }

    #[test]
    #[expected_failure(abort_code = pool_factory::ERepeatedType)]
    public fun repeated_type_on_deploy_pool() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        tools_tests::init_tests_coin(
            admin,
            player,
            player2,
            10000,
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
            admin,
            scenario
        );
        //init BTCBTC pool
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            //price=1 1btc = 1usdc
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            pool_factory::deploy_pool<BTC, BTC, FEE500BPS>(
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
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_deploy_pool() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        init_pools(admin, player, player2, scenario);

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_deploy_pool_and_mint() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        tools_tests::init_tests_coin(
            admin,
            player,
            player2,
            100000,
            scenario
        );

        tools_tests::init_pool_factory(
            player,
            scenario
        );

        tools_tests::init_fee_type(
            player,
            scenario
        );

        //init pool position manager
        test_scenario::next_tx(scenario, player);
        {
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };
        
        tools_tests::init_clock(
            player,
            scenario
        );

        // init USDCBTC pool
        test_scenario::next_tx(scenario, player);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            //price=0.01 1usdc = 0.01BTC
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 100);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let btc = test_scenario::take_from_sender<Coin<BTC>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);

            pool_factory::deploy_pool_and_mint<BTC, USDC, FEE500BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
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
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };

        // init USDCTRB pool
        test_scenario::next_tx(scenario, player);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            //price=0.01 1usdc = 0.01TRB
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 100);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let usdc = test_scenario::take_from_sender<Coin<USDC>>(scenario);
            let trb = test_scenario::take_from_sender<Coin<TRB>>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let min_tick_index = math_tick::get_min_tick(10);
            let max_tick_index = math_tick::get_max_tick(10);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);

            pool_factory::deploy_pool_and_mint<TRB, USDC, FEE500BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                &mut positions,
                tools_tests::coin_to_vec(trb),
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
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_update_nft_metadata() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        init_pools(admin, player, player2, scenario);

        //init pool position manager
        test_scenario::next_tx(scenario, admin);
        {
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };

        //init BTCBTC pool
        test_scenario::next_tx(scenario, admin);
        {
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);

            pool_factory::update_nft_name_v2(
                &acl_config,
                &mut positions,
                string::utf8(b"name"),
                &versioned,
                test_scenario::ctx(scenario),
            );

            pool_factory::update_nft_description_v2(
                &acl_config,
                &mut positions,
                string::utf8(b"description"),
                &versioned,
                test_scenario::ctx(scenario),
            );

            pool_factory::update_nft_img_url_v2(
                &acl_config,
                &mut positions,
                string::utf8(b"imgurl"),
                &versioned,
                test_scenario::ctx(scenario),
            );
            //std::debug::print(&positions);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_update_pool_fee_protocol() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        init_pools(admin, player, player2, scenario);

        //init pool position manager
        test_scenario::next_tx(scenario, admin);
        {
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);

            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            pool_factory::update_pool_fee_protocol_v2(
                &acl_config,
                &mut pool,
                300000,
                &versioned,
                test_scenario::ctx(scenario),
            );
            test_scenario::return_shared(acl_config);

            assert_eq(pool::get_pool_fee_protocol(&pool), 300000);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_get_pool_id_function() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        init_pools(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, admin);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);

            // Test get_pool_id function
            let retrieved_pool_id = pool_factory::get_pool_id<BTC, USDC, FEE500BPS>(&mut pool_config);
            let actual_pool_id = object::id(&pool);
            
            assert_eq(retrieved_pool_id, option::some(actual_pool_id));

            test_scenario::return_shared(pool);
            test_scenario::return_shared(pool_config);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_acl_role_management() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        init_pools(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);

            // Test ACL functions
            let acl = pool_factory::acl(&acl_config);

            // Test get_members initially (should be empty or contain admin)
            let initial_members = pool_factory::get_members(&acl_config);

            // Test add_role (role 0 = CLMM_MANAGER)
            pool_factory::add_role(&admin_cap, &mut acl_config, player, 0, &versioned);

            // Test role checking function
            pool_factory::check_clmm_manager_role(&acl_config, player);

            // Test get_members after adding
            let members_after_add = pool_factory::get_members(&acl_config);
            assert!(vector::length(&members_after_add) >= vector::length(&initial_members), 107);

            // Test remove_role
            pool_factory::remove_role(&admin_cap, &mut acl_config, player, 0, &versioned);

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_protocol_fee_collection() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        init_pools(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, admin);
        {
            let pool = test_scenario::take_shared<Pool<BTC, USDC, FEE500BPS>>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);

            // Use v2 API: request amounts and return coins (should be zero for fresh pool)
            let (protocol_fee_a_v2, protocol_fee_b_v2) = pool_factory::collect_protocol_fee_with_return_v2<BTC, USDC, FEE500BPS>(
                &acl_config,
                &mut pool,
                0,
                0,
                admin,
                &versioned,
                test_scenario::ctx(scenario),
            );

            coin::burn_for_testing(protocol_fee_a_v2);
            coin::burn_for_testing(protocol_fee_b_v2);

            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_acl_role_checking_functions() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        init_pools(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);

            // Add different roles to different users
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                player,
                1, // role as u8
                &versioned,
            );

            pool_factory::add_role(&admin_cap, &mut acl_config, player2, 2, &versioned);

            // Test specific role checking functions
            pool_factory::check_reward_manager_role(&acl_config, player);
            pool_factory::check_claim_protocol_fee_manager_role(&acl_config, player2);

            // Test set_roles function (bit 3 => 8)
            pool_factory::set_roles(&admin_cap, &mut acl_config, player, 8, &versioned);

            // Now player should have pause_pool_manager role
            pool_factory::check_pause_pool_manager_role(&acl_config, player);

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_deploy_pool_and_mint_comprehensive() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        tools_tests::init_tests_coin(admin, player, player2, 10000, scenario);
        tools_tests::init_pool_factory(admin, scenario);
        tools_tests::init_fee_type(admin, scenario);
        tools_tests::init_clock(admin, scenario);

        // Init position manager
        test_scenario::next_tx(scenario, admin);
        {
            position_manager::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, player);
        {
            // Take required shared objects
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);

            // Deploy the TRB/USDC pool at tick 0 (price = 1)
            let sqrt_price = math_sqrt_price::encode_price_sqrt(1, 1);
            pool_factory::deploy_pool<TRB, USDC, FEE500BPS>(
                &mut pool_config,
                &fee_type,
                sqrt_price,
                &clock,
                &versioned,
                test_scenario::ctx(scenario),
            );

            // Return objects to scenario
            test_scenario::return_shared(pool_config);
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(positions);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
        };

        test_scenario::next_tx(scenario, player);
        {
            // Take required shared objects
            let pool = test_scenario::take_shared<Pool<TRB, USDC, FEE500BPS>>(scenario);
            let positions = test_scenario::take_shared<Positions>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            let coin_a = test_scenario::take_from_sender<Coin<TRB>>(scenario);
            let coin_b = test_scenario::take_from_sender<Coin<USDC>>(scenario);

            let (nft, left_a, left_b) = position_manager::mint_with_return_<TRB, USDC, FEE500BPS>(
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

            // Verify position NFT and info
            assert!(object::id_address(&nft) != @0x0, 108);
            let (tick_lower, tick_upper, liquidity) = position_manager::get_position_info(&positions, object::id_address(&nft));
            assert_eq(i32::as_u32(tick_lower), i32::as_u32(i32::neg_from(100)));
            assert_eq(i32::as_u32(tick_upper), i32::as_u32(i32::from(100)));
            assert!(liquidity > 0, 109);

            coin::burn_for_testing(left_a);
            coin::burn_for_testing(left_b);

            // Transfer the NFT to player since it's a newly created object
            transfer::public_transfer(nft, player);

            // Return objects to scenario
            test_scenario::return_shared(pool);
            test_scenario::return_shared(clock);
            test_scenario::return_shared(versioned);
            test_scenario::return_shared(positions);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_acl_member_management() {
        let admin = @0x0;
        let player = @0x1;
        let player2 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        init_pools(admin, player, player2, scenario);

        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);

            // Add a member with role
            // Assign a role to create the member (use role 0)
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            pool_factory::add_role(&admin_cap, &mut acl_config, player, 0, &versioned);

            // Get members and verify
            let members = pool_factory::get_members(&acl_config);
            let found_player = false;
            let i = 0;
            while (i < vector::length(&members)) {
                let member = vector::borrow(&members, i);
                if (turbos_clmm::acl::get_member_address(member) == player) {
                    found_player = true;
                    break
                };
                i = i + 1;
            };
            assert!(found_player, 110);

            // Remove member
            pool_factory::remove_member(&admin_cap, &mut acl_config, player, &versioned);

            // Verify member was removed
            let members_after_removal = pool_factory::get_members(&acl_config);
            let found_player_after = false;
            let j = 0;
            while (j < vector::length(&members_after_removal)) {
                let member = vector::borrow(&members_after_removal, j);
                if (turbos_clmm::acl::get_member_address(member) == player) {
                    found_player_after = true;
                    break
                };
                j = j + 1;
            };
            assert!(!found_player_after, 111);

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_pool_factory_initialization() {
        let admin = @0x0;
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        // Test init_for_testing
        pool_factory::init_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, admin);
        {
            // Initialize ACL config
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            pool_factory::init_acl_config(&admin_cap, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::next_tx(scenario, admin);
        {
            // Verify that the initialization created the necessary objects
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let acl_config = test_scenario::take_shared<AclConfig>(scenario);

            // Basic checks to ensure objects were created properly
            let acl = pool_factory::acl(&acl_config);

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(acl_config);
        };

        test_scenario::end(scenario_val);
    }
}
