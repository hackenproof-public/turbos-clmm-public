// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::tools_tests {
    use sui::coin::{Coin};
    use std::vector;
    use sui::object::{Self, ID};
    use sui::test_scenario::{Self, Scenario};
    use sui::transfer;
    use turbos_clmm::btc::{Self, BTC};
    use turbos_clmm::usdc::{Self, USDC};
    use turbos_clmm::eth::{Self, ETH};
    use turbos_clmm::trb::{Self, TRB};
    use turbos_clmm::sui::{Self, SUI};
    use sui::coin::{Self, TreasuryCap};
    use turbos_clmm::fee500bps::{Self, FEE500BPS};
    use turbos_clmm::fee3000bps::{Self, FEE3000BPS};
    use turbos_clmm::fee10000bps::{Self, FEE10000BPS};
    use turbos_clmm::feemock10000bps::{Self, FEEMOCK10000BPS};
    use turbos_clmm::fee::{Fee};
    use turbos_clmm::pool_factory::{Self, PoolFactoryAdminCap, PoolConfig};
    use turbos_clmm::i32::{I32};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::position_nft::{Self, TurbosPositionNFT};
    use std::option::{Self, Option};
    use sui::clock::{Self};

    const MAX_TICK_INDEX: u32 = 443636;

    public fun coin_to_vec<T>(coin: Coin<T>): vector<Coin<T>> {
        let self = vector::empty<Coin<T>>();
        vector::push_back(&mut self, coin);
        self
    }

    public fun init_pool_factory(
        admin: address,
        scenario: &mut Scenario,
    ){
        test_scenario::next_tx(scenario, admin);
        {
            pool_factory::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            pool::init_for_testing(test_scenario::ctx(scenario));
        };
    }

    public fun init_clock(
        admin: address,
        scenario: &mut Scenario,
    ) {
        // init clock
        test_scenario::next_tx(scenario, admin);
        {
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            clock::share_for_testing(clock);
        };
    }

    public fun init_tests_coin(
        admin: address,
        player: address,
        _player2: address, 
        init_amount: u64,
        scenario: &mut Scenario,
    ) {
        // create btc coin
        test_scenario::next_tx(scenario, admin);
        {
            btc::init_for_testing(test_scenario::ctx(scenario));
        };

        // create usdc coin
        test_scenario::next_tx(scenario, admin);
        {
            usdc::init_for_testing(test_scenario::ctx(scenario));
        };

        // create eth coin
        test_scenario::next_tx(scenario, admin);
        {
            eth::init_for_testing(test_scenario::ctx(scenario));
        };

        // create sui coin
        test_scenario::next_tx(scenario, admin);
        {
            sui::init_for_testing(test_scenario::ctx(scenario));
        };

        // create trb coin
        test_scenario::next_tx(scenario, admin);
        {
            trb::init_for_testing(test_scenario::ctx(scenario));
        };

        // mint btc to player
        test_scenario::next_tx(scenario, admin);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<BTC>>(scenario);
            let coins = coin::mint(&mut treasury_cap, init_amount, test_scenario::ctx(scenario));
            transfer::public_transfer(coins, copy player);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

        // mint usdc to player
        test_scenario::next_tx(scenario, admin);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<USDC>>(scenario);
            let coins = coin::mint(&mut treasury_cap, init_amount, test_scenario::ctx(scenario));
            transfer::public_transfer(coins, copy player);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

        // mint eth to player
        test_scenario::next_tx(scenario, admin);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<ETH>>(scenario);
            let coins = coin::mint(&mut treasury_cap, init_amount, test_scenario::ctx(scenario));
            transfer::public_transfer(coins, copy player);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

         // mint sui to player
        test_scenario::next_tx(scenario, admin);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<SUI>>(scenario);
            let coins = coin::mint(&mut treasury_cap, init_amount, test_scenario::ctx(scenario));
            transfer::public_transfer(coins, copy player);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

         // mint trb to player
        test_scenario::next_tx(scenario, admin);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<TRB>>(scenario);
            let coins = coin::mint(&mut treasury_cap, init_amount, test_scenario::ctx(scenario));
            transfer::public_transfer(coins, copy player);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };
    }

    public fun init_fee_type(
        admin: address,
        scenario: &mut Scenario,
    ) {
        // Initialize ACL config first if not exists
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            pool_factory::init_acl_config(
                &admin_cap,
                test_scenario::ctx(scenario)
            );
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        // Set up CLMM manager role for admin
        test_scenario::next_tx(scenario, admin);
        {
            let admin_cap = test_scenario::take_from_sender<PoolFactoryAdminCap>(scenario);
            let acl_config = test_scenario::take_shared<turbos_clmm::pool_factory::AclConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                admin,
                0, // ACL_CLMM_MANAGER
                &versioned
            );
            
            // Add claim protocol fee manager role
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                admin,
                2, // ACL_CLAIM_PROTOCOL_FEE_MANAGER
                &versioned
            );
            
            // Add reward manager role
            pool_factory::add_role(
                &admin_cap,
                &mut acl_config,
                admin,
                1, // ACL_REWARD_MANAGER
                &versioned
            );
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(versioned);
        };

        //init fee type
        test_scenario::next_tx(scenario, admin);
        {
            fee500bps::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let fee_type = test_scenario::take_immutable<Fee<FEE500BPS>>(scenario);
            let acl_config = test_scenario::take_shared<turbos_clmm::pool_factory::AclConfig>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            pool_factory::set_fee_tier_v2<FEE500BPS>(
                &acl_config,
                &mut pool_config,
                &fee_type,
                &versioned,
                test_scenario::ctx(scenario)
            );
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(versioned);
        };

        test_scenario::next_tx(scenario, admin);
        {
            fee3000bps::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let fee_type = test_scenario::take_immutable<Fee<FEE3000BPS>>(scenario);
            let acl_config = test_scenario::take_shared<turbos_clmm::pool_factory::AclConfig>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            pool_factory::set_fee_tier_v2<FEE3000BPS>(
                &acl_config,
                &mut pool_config,
                &fee_type,
                &versioned,
                test_scenario::ctx(scenario)
            );
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(versioned);
        };

        test_scenario::next_tx(scenario, admin);
        {
            fee10000bps::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let fee_type = test_scenario::take_immutable<Fee<FEE10000BPS>>(scenario);
            let acl_config = test_scenario::take_shared<turbos_clmm::pool_factory::AclConfig>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            pool_factory::set_fee_tier_v2<FEE10000BPS>(
                &acl_config,
                &mut pool_config,
                &fee_type,
                &versioned,
                test_scenario::ctx(scenario)
            );
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(versioned);
        };

        test_scenario::next_tx(scenario, admin);
        {
            feemock10000bps::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let fee_type = test_scenario::take_immutable<Fee<FEEMOCK10000BPS>>(scenario);
            let acl_config = test_scenario::take_shared<turbos_clmm::pool_factory::AclConfig>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            pool_factory::set_fee_tier_v2<FEEMOCK10000BPS>(
                &acl_config,
                &mut pool_config,
                &fee_type,
                &versioned,
                test_scenario::ctx(scenario)
            );
            test_scenario::return_immutable(fee_type);
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(versioned);
        };

    }

    public fun set_fee_protocol(
        admin: address,
        fee_protocol: u32,
        scenario: &mut Scenario,
    ) {
        test_scenario::next_tx(scenario, admin);
        {
            let acl_config = test_scenario::take_shared<turbos_clmm::pool_factory::AclConfig>(scenario);
            let pool_config = test_scenario::take_shared<PoolConfig>(scenario);
            let versioned = test_scenario::take_shared<Versioned>(scenario);
            pool_factory::set_fee_protocol_v2(
                &acl_config,
                &mut pool_config,
                fee_protocol,
                &versioned,
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(acl_config);
            test_scenario::return_shared(pool_config);
            test_scenario::return_shared(versioned);
        };
    }

     public fun get_user_coin_balance<T>(
        scenario: &mut Scenario,
    ): u64 {
        let coin_ids = test_scenario::ids_for_sender<Coin<T>>(scenario);
        let trader_balance_a = 0;
        while (!vector::is_empty(&coin_ids)) {
            let coin = test_scenario::take_from_sender_by_id<Coin<T>>(scenario, vector::pop_back(&mut coin_ids));
            trader_balance_a = trader_balance_a + coin::value(&coin);
            test_scenario::return_to_sender(scenario, coin);
        };

        trader_balance_a
    }

    public fun get_user_coin_vec<T>(
        scenario: &mut Scenario,
    ): vector<Coin<T>> {
        let coin_ids = test_scenario::ids_for_sender<Coin<T>>(scenario);
        let coins = vector::empty<Coin<T>>();
        while (!vector::is_empty(&coin_ids)) {
            let coin = test_scenario::take_from_sender_by_id<Coin<T>>(scenario, vector::pop_back(&mut coin_ids));
            vector::push_back(&mut coins, coin);
        };

        coins
    }

    public fun get_user_coin<T>(
        scenario: &mut Scenario,
    ): (vector<Coin<T>>, u64) {
        let coin_ids = test_scenario::ids_for_sender<Coin<T>>(scenario);
        let coins = vector::empty<Coin<T>>();
        let trader_balance_a = 0;
        while (!vector::is_empty(&coin_ids)) {
            let coin = test_scenario::take_from_sender_by_id<Coin<T>>(scenario, vector::pop_back(&mut coin_ids));
            trader_balance_a = trader_balance_a + coin::value(&coin);
            vector::push_back(&mut coins, coin);
        };

        (coins, trader_balance_a)
    }

    public fun get_pool_tick_index<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): I32 {
        let (_,_,_,_,_,tick_current_index,_,_,_,_,_,_,_,) = pool::get_pool_info(pool);

        tick_current_index
    }
    
    public fun get_pool_sqrt_price<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): u128 {
        let (_,_,_,_,sqrt_price,_,_,_,_,_,_,_,_,) = pool::get_pool_info(pool);

        sqrt_price
    }

    public fun get_pool_fee_growth_global<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): (u128, u128) {
        let (_,_,_,_,_,_,_,_,_,_,fee_growth_global_a,fee_growth_global_b,_,) = pool::get_pool_info(pool);

        (fee_growth_global_a, fee_growth_global_b)
    }

    public fun get_pool_protocol_fees<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): (u64, u64) {
        let (_,_,protocol_fees_a,protocol_fees_b,_,_,_,_,_,_,_,_,_,) = pool::get_pool_info(pool);

        (protocol_fees_a, protocol_fees_b)
    }

    public fun get_user_nft_id(
        pool_id: ID,
        scenario: &mut Scenario,
    ): ID {
        let nft_id: Option<ID> = option::none();
        let nft_ids = test_scenario::ids_for_sender<TurbosPositionNFT>(scenario);

        while (!vector::is_empty(&nft_ids)) {
            let current_nft = test_scenario::take_from_sender_by_id<TurbosPositionNFT>(scenario, vector::pop_back(&mut nft_ids));
            if (position_nft::pool_id(&current_nft) == pool_id) {
                nft_id = option::some(object::id(&current_nft));
                test_scenario::return_to_sender(scenario, current_nft);
                break
            };
            test_scenario::return_to_sender(scenario, current_nft);
        };
        option::extract<ID>(&mut nft_id)
    }

}