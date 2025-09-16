// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::reward_manager {
    use sui::object::{Self, UID};
    use sui::transfer;
    use turbos_clmm::pool::{Self, Pool, PoolRewardVault, Versioned};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Coin};
    use sui::clock::{Clock};
    use turbos_clmm::pool_factory::{Self, AclConfig};

    struct RewardManagerAdminCap has key, store { id: UID }

    fun init(ctx: &mut TxContext) {
        init_(ctx);
    }

    fun init_(ctx: &mut TxContext) {
        transfer::transfer(RewardManagerAdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }

    public entry fun init_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        _: &RewardManagerAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
        manager: address,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun init_reward_v2<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        acl_config: &AclConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
        manager: address,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        pool_factory::check_reward_manager_role(acl_config, tx_context::sender(ctx));
        let vault = pool::init_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
            pool,
            reward_index,
            manager,
            ctx,
        );
        transfer::public_share_object(vault);
    }

    public entry fun reset_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        _: &RewardManagerAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun reset_reward_v2<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        acl_config: &AclConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        pool_factory::check_reward_manager_role(acl_config, tx_context::sender(ctx));
        pool::reset_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
            pool,
            reward_index,
            ctx,
        );
    }

    public entry fun update_reward_manager<CoinTypeA, CoinTypeB, FeeType>(
        _: &RewardManagerAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
        new_manager: address,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun add_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        vault: &mut  PoolRewardVault<RewardCoin>,
        reward_index: u64,
        coins: vector<Coin<RewardCoin>>,
        amount: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun add_reward_v2<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        acl_config: &AclConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        vault: &mut  PoolRewardVault<RewardCoin>,
        reward_index: u64,
        coins: vector<Coin<RewardCoin>>,
        amount: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        pool_factory::check_reward_manager_role(acl_config, tx_context::sender(ctx));
        pool::add_reward(
            pool,
            vault,
            reward_index,
            pool::merge_coin<RewardCoin>(coins),
            amount,
            clock,
            ctx,
        );
    }

    public entry fun remove_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        vault: &mut  PoolRewardVault<RewardCoin>,
        reward_index: u64,
        amount: u64,
        recipient: address,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun remove_reward_v2<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        acl_config: &AclConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        vault: &mut  PoolRewardVault<RewardCoin>,
        reward_index: u64,
        amount: u64,
        recipient: address,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        pool_factory::check_reward_manager_role(acl_config, tx_context::sender(ctx));
        pool::remove_reward(
            pool,
            vault,
            reward_index,
            amount,
            recipient,
            clock,
            ctx,
        );
    }

    // update reward emissions per second
    // will check manager address
    public entry fun update_reward_emissions<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
        emissions_per_second: u128,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun update_reward_emissions_v2<CoinTypeA, CoinTypeB, FeeType>(
        acl_config: &AclConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
        emissions_per_second: u128,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        pool_factory::check_reward_manager_role(acl_config, tx_context::sender(ctx));
        pool::update_reward_emissions(
            pool,
            reward_index,
            emissions_per_second,
            clock,
            ctx,
        );
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init_(ctx);
    }
}