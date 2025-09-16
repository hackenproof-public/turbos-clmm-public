// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::position_manager {
    use std::vector;
    use std::type_name::{Self};
    use sui::transfer;
    use sui::event;
    use std::string::{Self, String};
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as dof;
    use sui::coin::{Self, Coin};
    use sui::table::{Self, Table};
    use turbos_clmm::i32::{Self, I32};
    use turbos_clmm::math_liquidity;
    use turbos_clmm::math_tick;
    use turbos_clmm::pool::{Self, Pool, PositionRewardInfo as PositionRewardInfoInPool, PoolRewardVault, Versioned};
    use turbos_clmm::position_nft::{Self, TurbosPositionNFT};
    use sui::clock::{Self, Clock};
    use sui::url::{Self, Url};
    use std::type_name::{TypeName};
    
    friend turbos_clmm::pool_factory;

    const ENoCoins: u64 = 4;
    const EPriceSlippageCheck: u64 = 5;
    const EPositionNotCleared: u64 = 6;
    const EInvildMintAmount: u64 = 7;
    const ETransactionTooOld: u64 = 8;
    const EInsufficientLiquidity: u64 = 9;
    const EInvalidRewardIndex: u64 = 10;
    const EPositionNotExists: u64 = 11;
    const EPositionAlreadyExists: u64 = 12;
    const EPositionMigrateFail: u64 = 14;
    const EInvalidPool: u64 = 15;
    const EInvalidBurnTickRange: u64 = 16;

    const TICK_SIZE: u32 = 443636;
    
    struct TurbosPositionBurnNFT has store, key {
        id: UID,
        name: String,
        description: String,
        img_url: Url,
        position_nft: TurbosPositionNFT,
        position_id: ID,
        pool_id: ID,
        coin_type_a: TypeName,
        coin_type_b: TypeName,
        fee_type: TypeName,
    }

    struct PositionRewardInfo has store {
        reward_growth_inside: u128,
        amount_owed: u64,
    }

    struct Position has key, store {
        id: UID,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity: u128,
        fee_growth_inside_a: u128,
        fee_growth_inside_b: u128,
        tokens_owed_a: u64,
        tokens_owed_b: u64,
        reward_infos: vector<PositionRewardInfo>,
    }

    struct Positions has key, store {
        id: UID,
        nft_minted: u64,
        user_position: Table<address, ID>,
        nft_name: String,
        nft_description: String,
        nft_img_url: String,
    }

    struct IncreaseLiquidityEvent has copy, drop {
        pool: ID,
        amount_a: u64,
        amount_b: u64,
        liquidity: u128,
    }

    struct DecreaseLiquidityEvent has copy, drop {
        pool: ID,
        amount_a: u64,
        amount_b: u64,
        liquidity: u128,
    }

    struct CollectEvent has copy, drop {
        pool: ID,
        amount_a: u64,
        amount_b: u64,
        recipient: address,
    }

    struct CollectRewardEvent has copy, drop {
        pool: ID,
        amount: u64,
        vault: ID,
        reward_index: u64,
        recipient: address,
    }

    struct BurnPositionEvent has copy, drop {
        nft_address: address,
        position_id: ID,
        pool_id: ID,
        burn_nft_address: address,
    }

    struct MintNftEvent has copy, drop {
        nft_address: address,
        position_id: ID,
        pool_id: ID,
    }

    struct BurnNftEvent has copy, drop {
        nft_address: address,
        position_id: ID,
        pool_id: ID,
    }

    fun init(ctx: &mut TxContext) {
        init_(ctx);
    }

    fun init_(ctx: &mut TxContext) {
        transfer::share_object(Positions {
            id: object::new(ctx),
            nft_minted: 0,
            user_position: table::new(ctx),
            nft_name: string::utf8(b"Turbos Position's NFT"),
            nft_description: string::utf8(b"An NFT created by Turbos CLMM"),
            nft_img_url: string::utf8(b"https://ipfs.io/ipfs/QmTxRsWbrLG6mkjg375wW77Lfzm38qsUQjRBj3b2K3t8q1?filename=Turbos_nft.png"),
        });
    }

    public entry fun mint<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        coins_a: vector<Coin<CoinTypeA>>, 
        coins_b: vector<Coin<CoinTypeB>>, 
        tick_lower_index: u32,
        tick_lower_index_is_neg: bool,
        tick_upper_index: u32,
        tick_upper_index_is_neg: bool,
        amount_a_desired: u64,
        amount_b_desired: u64,
        amount_a_min: u64,
        amount_b_min: u64,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (nft, coin_a_left, coin_b_left) = mint_with_return_(
            pool,
            positions,
            coins_a,
            coins_b,
            tick_lower_index,
            tick_lower_index_is_neg,
            tick_upper_index,
            tick_upper_index_is_neg,
            amount_a_desired,
            amount_b_desired,
            amount_a_min,
            amount_b_min,
            deadline,
            clock,
            versioned,
            ctx,
        );
        if (coin::value(&coin_a_left) == 0) {
            coin::destroy_zero(coin_a_left);
        } else {
            transfer::public_transfer(
                coin_a_left,
                tx_context::sender(ctx)
            );
        };

        if (coin::value(&coin_b_left) == 0) {
            coin::destroy_zero(coin_b_left);
        } else {
            transfer::public_transfer(
                coin_b_left,
                tx_context::sender(ctx)
            );
        };
        transfer::public_transfer(nft, recipient)
    }

    public fun mint_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        coins_a: vector<Coin<CoinTypeA>>, 
        coins_b: vector<Coin<CoinTypeB>>, 
        tick_lower_index: u32,
        tick_lower_index_is_neg: bool,
        tick_upper_index: u32,
        tick_upper_index_is_neg: bool,
        amount_a_desired: u64,
        amount_b_desired: u64,
        amount_a_min: u64,
        amount_b_min: u64,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (TurbosPositionNFT, Coin<CoinTypeA>, Coin<CoinTypeB>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionTooOld);
        assert!(vector::length(&coins_a) > 0, ENoCoins);
        assert!(vector::length(&coins_b) > 0, ENoCoins);
        let tick_lower_index_i32 = i32::from_u32_neg(tick_lower_index, tick_lower_index_is_neg);
        let tick_upper_index_i32 = i32::from_u32_neg(tick_upper_index, tick_upper_index_is_neg);
        let position_id = object::new(ctx);
        let position_inner_id = object::uid_to_inner(&position_id);

        let nft = mint_nft_with_return_<CoinTypeA, CoinTypeB, FeeType>(
            object::id(pool), 
            position_inner_id, 
            positions, 
            ctx,
        );
        let nft_address = object::id_address(&nft);
        let position_key = pool::get_position_key_fix(pool, nft_address, tick_lower_index_i32, tick_upper_index_i32);

        let (liquidity_delta, amount_a, amount_b, coin_a_left, coin_b_left) = add_liquidity_with_return_(
            pool,
            pool::merge_coin<CoinTypeA>(coins_a),
            pool::merge_coin<CoinTypeB>(coins_b),
            nft_address,
            tick_lower_index_i32,
            tick_upper_index_i32,
            amount_a_desired,
            amount_b_desired,
            clock,
            ctx,
        );
        assert!(amount_a >= amount_a_min && amount_b >= amount_b_min, EPriceSlippageCheck);

        let position_m = Position {
            id: position_id,
            tick_lower_index: tick_lower_index_i32,
            tick_upper_index: tick_upper_index_i32,
            liquidity: liquidity_delta,
            fee_growth_inside_a: 0,
            fee_growth_inside_b: 0,
            tokens_owed_a: 0,
            tokens_owed_b: 0,
            reward_infos: vector::empty<PositionRewardInfo>(),
        };
        copy_position(pool, position_key, &mut position_m);
        dof::add<address, Position>(&mut positions.id, nft_address, position_m);
        insert_user_position(positions, position_inner_id, nft_address);

        event::emit(IncreaseLiquidityEvent {
            pool: object::id(pool),
            amount_a: amount_a,
            amount_b: amount_b,
            liquidity: liquidity_delta,
        });

        (nft, coin_a_left, coin_b_left)
    }

    public entry fun burn<CoinTypeA, CoinTypeB, FeeType>(
        positions: &mut Positions,
        nft: TurbosPositionNFT,
        versioned: &Versioned,
        _ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let nft_address = object::id_address(&nft);
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);
        let position_id = object::id(position);
        let pool_id = position_nft::pool_id(&nft);
        assert!(position.liquidity == 0 && position.tokens_owed_a == 0 && position.tokens_owed_b == 0, EPositionNotCleared);
        
        let i = 0;
        let len = vector::length(&position.reward_infos);
        while (i < len) {
            let reward_info = vector::borrow(&position.reward_infos, i);
            assert!(reward_info.amount_owed == 0, EPositionNotCleared);
            i = i + 1;
        };

        delete_user_position(positions, nft_address);
        burn_nft(nft);
    }

    fun add_liquidity<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        recipient: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount_a_desired: u64,
        amount_b_desired: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u128, u64, u64) {
        abort(0)
    }

    fun add_liquidity_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        recipient: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount_a_desired: u64,
        amount_b_desired: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u128, u64, u64, Coin<CoinTypeA>, Coin<CoinTypeB>) {
        let sqrt_price_a = math_tick::sqrt_price_from_tick_index(tick_lower_index);
        let sqrt_price_b = math_tick::sqrt_price_from_tick_index(tick_upper_index);
        let sqrt_price = pool::get_pool_sqrt_price(pool);

        let liquidity_delta = math_liquidity::get_liquidity_for_amounts(
            sqrt_price,
            sqrt_price_a,
            sqrt_price_b,
            (amount_a_desired as u128),
            (amount_b_desired as u128)
        );

        let (amount_a, amount_b) = pool::mint(
            pool,
            recipient,
            tick_lower_index,
            tick_upper_index,
            liquidity_delta,
            clock,
            ctx,
        );

        let (balance_a_before, balance_b_before) = pool::get_pool_balance(pool);
        let (coin_a_left, coin_b_left) = pool::split_and_return_(
            pool,
            coin_a,
            amount_a,
            coin_b,
            amount_b,
            ctx,
        );
        let (balance_a_current, balance_b_current) = pool::get_pool_balance(pool);

        assert!(balance_a_before + amount_a <= balance_a_current, EInvildMintAmount);
        assert!(balance_b_before + amount_b <= balance_b_current, EInvildMintAmount);

        (liquidity_delta, amount_a, amount_b, coin_a_left, coin_b_left)
    }

    public entry fun increase_liquidity<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        coins_a: vector<Coin<CoinTypeA>>, 
        coins_b: vector<Coin<CoinTypeB>>, 
        nft: &mut TurbosPositionNFT,
        amount_a_desired: u64,
        amount_b_desired: u64,
        amount_a_min: u64,
        amount_b_min: u64,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_a_left, coin_b_left) = increase_liquidity_with_return_(
            pool,
            positions,
            coins_a,
            coins_b,
            nft,
            amount_a_desired,
            amount_b_desired,
            amount_a_min,
            amount_b_min,
            deadline,
            clock,
            versioned,
            ctx,
        );
        if (coin::value(&coin_a_left) == 0) {
            coin::destroy_zero(coin_a_left);
        } else {
            transfer::public_transfer(
                coin_a_left,
                tx_context::sender(ctx)
            );
        };

        if (coin::value(&coin_b_left) == 0) {
            coin::destroy_zero(coin_b_left);
        } else {
            transfer::public_transfer(
                coin_b_left,
                tx_context::sender(ctx)
            );
        };
    }

     public fun increase_liquidity_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        coins_a: vector<Coin<CoinTypeA>>, 
        coins_b: vector<Coin<CoinTypeB>>, 
        nft: &mut TurbosPositionNFT,
        amount_a_desired: u64,
        amount_b_desired: u64,
        amount_a_min: u64,
        amount_b_min: u64,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        pool::check_version(versioned);
        assert!(object::id(pool) == position_nft::pool_id(nft), EInvalidPool);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionTooOld);
        assert!(vector::length(&coins_a) > 0, ENoCoins);
        assert!(vector::length(&coins_b) > 0, ENoCoins);
        let nft_address = object::id_address(nft);
        let sender = tx_context::sender(ctx);
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);

        //new position key is (nft_address, tick_lower_index, tick_upper_index)
        //old position key is (owner, tick_lower_index, tick_upper_index)
        let position_owner;
        if (pool::check_position_exists(pool, nft_address, position.tick_lower_index, position.tick_upper_index)) {
            position_owner = nft_address;
        } else {
            position_owner = sender;
        };

        let (liquidity_delta, amount_a, amount_b, coin_a_left, coin_b_left) = add_liquidity_with_return_(
            pool,
            pool::merge_coin<CoinTypeA>(coins_a),
            pool::merge_coin<CoinTypeB>(coins_b),
            position_owner,
            position.tick_lower_index,
            position.tick_upper_index,
            amount_a_desired,
            amount_b_desired,
            clock,
            ctx,
        );
        assert!(amount_a >= amount_a_min && amount_b >= amount_b_min, EPriceSlippageCheck);

        let position_key =  pool::get_position_key_fix(pool, position_owner, position.tick_lower_index, position.tick_upper_index);
        copy_position(pool, position_key, position);

        event::emit(IncreaseLiquidityEvent {
            pool: object::id(pool),
            amount_a: amount_a,
            amount_b: amount_b,
            liquidity: liquidity_delta,
        });

        (coin_a_left, coin_b_left)
    }

    public entry fun decrease_liquidity<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        nft: &mut TurbosPositionNFT,
        liquidity: u128,
        amount_a_min: u64,
        amount_b_min: u64,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_a, coin_b) = decrease_liquidity_with_return_(
            pool,
            positions,
            nft,
            liquidity,
            amount_a_min,
            amount_b_min,
            deadline,
            clock,
            versioned,
            ctx,
        );
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(coin_a, sender);
        transfer::public_transfer(coin_b, sender);

    }

    public fun decrease_liquidity_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        nft: &mut TurbosPositionNFT,
        liquidity: u128,
        amount_a_min: u64,
        amount_b_min: u64,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        pool::check_version(versioned);
        assert!(object::id(pool) == position_nft::pool_id(nft), EInvalidPool);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionTooOld);
        let nft_address = object::id_address(nft);
        let sender = tx_context::sender(ctx);
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);
        assert!(position.liquidity >= liquidity, EInsufficientLiquidity);

        let position_owner;
        if (pool::check_position_exists(pool, nft_address, position.tick_lower_index, position.tick_upper_index)) {
            position_owner = nft_address;
        } else {
            position_owner = sender;
        };

        let (amount_a, amount_b) = pool::burn(
            pool,
            position_owner,
            position.tick_lower_index,
            position.tick_upper_index,
            liquidity,
            clock,
            ctx,
        );

        assert!(amount_a >= amount_a_min && amount_b >= amount_b_min, EPriceSlippageCheck);

        let position_key =  pool::get_position_key_fix(pool, position_owner, position.tick_lower_index, position.tick_upper_index);
        copy_position(pool, position_key, position);

        let (coin_a, coin_b) = pool::split_out_and_return_(
            pool,
            amount_a,
            amount_b,
            ctx
        );

        event::emit(DecreaseLiquidityEvent {
            pool: object::id(pool),
            amount_a: amount_a,
            amount_b: amount_b,
            liquidity: liquidity,
        });

        (coin_a, coin_b)
    }

    public entry fun collect<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        nft: &mut TurbosPositionNFT,
        amount_a_max: u64,
        amount_b_max: u64,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_a, coin_b) = collect_with_return_(
            pool,
            positions,
            nft,
            amount_a_max,
            amount_b_max,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );

        transfer::public_transfer(coin_a, recipient);
        transfer::public_transfer(coin_b, recipient);
    }

    public fun collect_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        nft: &mut TurbosPositionNFT,
        amount_a_max: u64,
        amount_b_max: u64,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        pool::check_version(versioned);
        assert!(object::id(pool) == position_nft::pool_id(nft), EInvalidPool);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionTooOld);
        let nft_address = object::id_address(nft);
        let sender = tx_context::sender(ctx);
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);
        let position_owner;
        if (pool::check_position_exists(pool, nft_address, position.tick_lower_index, position.tick_upper_index)) {
            position_owner = nft_address;
        } else {
            position_owner = sender;
        };
        if (position.liquidity > 0) {
            pool::burn(
                pool,
                position_owner,
                position.tick_lower_index,
                position.tick_upper_index,
                0,
                clock,
                ctx,
            );
            let position_key = pool::get_position_key_fix(pool, position_owner, position.tick_lower_index, position.tick_upper_index);
            copy_position(pool, position_key, position);
        };
        let (tokens_owed_a, tokens_owed_b) = (position.tokens_owed_a, position.tokens_owed_b);

        let (amount_a_collect, amount_b_collect) =
        (
            if (amount_a_max > tokens_owed_a) tokens_owed_a else amount_a_max,
            if (amount_b_max > tokens_owed_b) tokens_owed_b else amount_b_max
        );

        let (amount_a, amount_b) = pool::collect_v2(
            pool,
            recipient,
            position_owner,
            position.tick_lower_index,
            position.tick_upper_index,
            amount_a_collect,
            amount_b_collect,
            ctx,
        );

        let (coin_a, coin_b) = pool::split_out_and_return_(
            pool,
            amount_a,
            amount_b,
            ctx
        );

        position.tokens_owed_a = position.tokens_owed_a - amount_a_collect;
        position.tokens_owed_b = position.tokens_owed_b - amount_b_collect;

        // event::emit(CollectEvent {
        //     pool: object::id(pool),
        //     amount_a: amount_a,
        //     amount_b: amount_b,
        //     recipient: recipient,
        // });

        (coin_a, coin_b)
    }

    public entry fun collect_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        nft: &mut TurbosPositionNFT,
        vault: &mut PoolRewardVault<RewardCoin>,
        reward_index: u64,
        amount_max: u64,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let coin_reward = collect_reward_with_return_(
            pool,
            positions,
            nft,
            vault,
            reward_index,
            amount_max,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );

        transfer::public_transfer(coin_reward, recipient);
    }

    public fun collect_reward_with_return_<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        nft: &mut TurbosPositionNFT,
        vault: &mut PoolRewardVault<RewardCoin>,
        reward_index: u64,
        amount_max: u64,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): Coin<RewardCoin> {
        pool::check_version(versioned);
        assert!(object::id(pool) == position_nft::pool_id(nft), EInvalidPool);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionTooOld);
        let nft_address = object::id_address(nft);
        let sender = tx_context::sender(ctx);
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);
        let position_owner;
        if (pool::check_position_exists(pool, nft_address, position.tick_lower_index, position.tick_upper_index)) {
            position_owner = nft_address;
        } else {
            position_owner = sender;
        };
        if (position.liquidity > 0) {
            pool::burn(
                pool,
                position_owner,
                position.tick_lower_index,
                position.tick_upper_index,
                0,
                clock,
                ctx,
            );
            let position_key =  pool::get_position_key_fix(pool, position_owner, position.tick_lower_index, position.tick_upper_index);
            copy_position(pool, position_key, position);
        };

        assert!(reward_index < vector::length(&position.reward_infos),EInvalidRewardIndex);
        let reward_info = vector::borrow_mut(&mut position.reward_infos, reward_index);
        let amount_collect = if (amount_max > reward_info.amount_owed) reward_info.amount_owed else amount_max;

        let coin_reward = pool::collect_reward_with_return_(
            pool,
            vault,
            recipient,
            position_owner,
            position.tick_lower_index,
            position.tick_upper_index,
            amount_collect,
            reward_index,
            ctx,
        );
        let amount = coin::value(&coin_reward);

        reward_info.amount_owed = reward_info.amount_owed - amount_collect;

        // event::emit(CollectRewardEvent {
        //     pool: object::id(pool),
        //     amount: amount,
        //     vault: object::id(vault),
        //     reward_index: reward_index,
        //     recipient: recipient,
        // });
        
        coin_reward
    }

    public fun burn_position_nft_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        nft: TurbosPositionNFT, 
        versioned: &Versioned,
        ctx: &mut TxContext
    ): TurbosPositionBurnNFT {
        pool::check_version(versioned);
        let pool_id = position_nft::pool_id(&nft);
        assert!(object::id(pool) == position_nft::pool_id(&nft), EInvalidPool);
        let nft_address = object::id_address(&nft);
        let position_inner = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);
        let tick_spacing = pool::get_pool_tick_spacing(pool);
        let mod = i32::from(TICK_SIZE % tick_spacing);

        //check full range
        assert!(i32::eq(i32::sub(position_inner.tick_lower_index, mod), i32::neg_from(TICK_SIZE)), EInvalidBurnTickRange);
        assert!(i32::eq(i32::add(position_inner.tick_upper_index, mod), i32::from(TICK_SIZE)), EInvalidBurnTickRange);
        
        let position_id = position_nft::position_id(&nft);
        let burn_nft = TurbosPositionBurnNFT{
            id: object::new(ctx), 
            name: string::utf8(b"Proof of Turbos Position Burn"), 
            description: string::utf8(b"Proof of Turbos Position Burn"), 
            img_url: url::new_unsafe(string::to_ascii(string::utf8(b"https://app.turbos.finance/icon/turbos-position-burn-nft.png"))), 
            position_nft: nft,
            position_id: position_id,
            pool_id: pool_id,
            coin_type_a: type_name::get<CoinTypeA>(),
            coin_type_b: type_name::get<CoinTypeB>(),
            fee_type: type_name::get<FeeType>(),
        };
        
        event::emit(BurnPositionEvent {
            nft_address: nft_address,
            position_id: position_id,
            pool_id: pool_id,
            burn_nft_address: object::id_address(&burn_nft),
        });
        burn_nft
    }

    public fun burn_nft_collect_reward_with_return_<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        burn_nft: &mut TurbosPositionBurnNFT,
        vault: &mut PoolRewardVault<RewardCoin>,
        reward_index: u64,
        amount_max: u64,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): Coin<RewardCoin> {
        pool::check_version(versioned);
        collect_reward_with_return_(
            pool,
            positions,
            &mut burn_nft.position_nft,
            vault,
            reward_index,
            amount_max,
            @0x0,
            deadline,
            clock,
            versioned,
            ctx,
        )
    }

    public fun burn_nft_collect_fee_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        burn_nft: &mut TurbosPositionBurnNFT,
        amount_a_max: u64,
        amount_b_max: u64,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        collect_with_return_(
            pool,
            positions,
            &mut burn_nft.position_nft,
            amount_a_max,
            amount_b_max,
            @0x0,
            deadline,
            clock,
            versioned,
            ctx,
        )
    }

    public(friend) fun decrease_liquidity_admin<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        position_owner: address,
        liquidity: u128,
        tick_lower_index: u32,
        tick_lower_index_is_neg: bool,
        tick_upper_index: u32,
        tick_upper_index_is_neg: bool,
        user_address: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public(friend) fun migrate_position<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        nfts: vector<address>,
        owned: address,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public(friend) fun modify_position_reward_inside(
        positions: &mut Positions,
        nft_address: address,
        tick_reward_index: u64,
        vaule: u128,
    ) {
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);
        let reward_infos = &mut position.reward_infos;
        let reward_info = vector::borrow_mut(reward_infos, tick_reward_index);
        reward_info.reward_growth_inside = vaule;
        reward_info.amount_owed = 0;
    }

    fun get_position_tick_info(
        positions: &mut Positions,
        nft_address: address
    ): (I32, I32) {
        let position = dof::borrow<address, Position>(&positions.id, nft_address);
        (
            position.tick_lower_index,
            position.tick_upper_index,
        )
    }

    fun copy_position_with_address<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        key: String,
        nft_address: address
    ) {
        let base_position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);
        copy_position(pool, key, base_position);
    }

    fun clean_position(
        positions: &mut Positions,
        tick_lower_index: I32,
        tick_upper_index: I32,
        nft_address: address,
    ) {
        let position = dof::borrow_mut<address, Position>(&mut positions.id, nft_address);
        assert!(
            i32::eq(position.tick_lower_index, tick_lower_index) &&
            i32::eq(position.tick_upper_index, tick_upper_index), 
            EPositionMigrateFail
        );
        position.liquidity = 0;
        position.tick_lower_index = i32::zero();
        position.tick_upper_index = i32::zero();
        position.fee_growth_inside_a = 0;
        position.fee_growth_inside_b = 0;
        position.tokens_owed_a = 0;
        position.tokens_owed_b = 0;

        let len = vector::length(&position.reward_infos);
        let i = 0;
        while (i < len) {
            let reward_info = vector::borrow_mut(&mut position.reward_infos, i);
            reward_info.reward_growth_inside = 0;
            reward_info.amount_owed = 0;
            i = i + 1;
        };
        
        if (table::contains(&positions.user_position, nft_address)) {
            table::remove(&mut positions.user_position, nft_address);
        }
    }

    fun get_mut_position(
        positions: &mut Positions,
        nft_address: address,
    ): &mut Position {
        dof::borrow_mut<address, Position>(&mut positions.id, nft_address)
    }

    public fun get_position_info(
        positions: &Positions,
        nft_address: address,
    ): (I32, I32, u128) {
        let position = dof::borrow<address, Position>(&positions.id, nft_address);
        (position.tick_lower_index, position.tick_upper_index, position.liquidity)
    }

    public(friend) fun update_nft_name(
        positions: &mut Positions,
        nft_name: String,
    ) {
        positions.nft_name = nft_name;
    }

    public(friend) fun update_nft_description(
        positions: &mut Positions,
        nft_description: String,
    ) {
        positions.nft_description = nft_description;
    }

    public(friend) fun update_nft_img_url(
        positions: &mut Positions,
        nft_img_url: String,
    ) {
        positions.nft_img_url = nft_img_url;
    }

    fun mint_nft<CoinTypeA, CoinTypeB, FeeType>(
        pool_id: ID,
        position_id: ID,
        positions: &mut Positions,
        recipient: address,
        ctx: &mut TxContext
    ): address {
        let nft = mint_nft_with_return_<CoinTypeA, CoinTypeB, FeeType>(
            pool_id,
            position_id,
            positions,
            ctx,
        );
        let nft_address = object::id_address(&nft);
        transfer::public_transfer(nft, recipient);

        nft_address
    }

    fun mint_nft_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool_id: ID,
        position_id: ID,
        positions: &mut Positions,
        ctx: &mut TxContext
    ): TurbosPositionNFT {
        let nft = position_nft::mint(
            positions.nft_name,
            positions.nft_description,
            positions.nft_img_url,
            pool_id,
            position_id,
            type_name::get<CoinTypeA>(),
            type_name::get<CoinTypeB>(),
            type_name::get<FeeType>(),
            ctx,
        );
        positions.nft_minted = positions.nft_minted + 1;

        event::emit(MintNftEvent {
            nft_address: object::id_address(&nft),
            position_id: position_id,
            pool_id: pool_id,
        });

        nft
    }

    fun burn_nft(
        nft: TurbosPositionNFT
    ) {
        let nft_address = object::id_address(&nft);
        let position_id = position_nft::position_id(&nft);
        let pool_id = position_nft::pool_id(&nft);

        position_nft::burn(nft);

        event::emit(BurnNftEvent {
            nft_address: nft_address,
            position_id: position_id,
            pool_id: pool_id,
        });
    }

    public entry fun burn_nft_directly(
        nft: TurbosPositionNFT
    ) {
        burn_nft(nft);
    }

    fun insert_user_position(
        positions: &mut Positions, 
        position_id: ID, 
        nft_address: address
    ) {
        if (!table::contains(&positions.user_position, nft_address)) {
            table::add(&mut positions.user_position, nft_address, position_id);
        }
    }

    fun delete_user_position(
        positions: &mut Positions, 
        nft_address: address
    ) {
        if (table::contains(&positions.user_position, nft_address)) {
            table::remove(&mut positions.user_position, nft_address);
        }
    }

    fun copy_position<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        key: String,
        position: &mut Position
    ) {
        let (
            liquidity,
            fee_growth_inside_a,
            fee_growth_inside_b,
            tokens_owed_a,
            tokens_owed_b,
            reward_infos,
        ) = pool::get_position_base_info(pool, key);
        position.liquidity = liquidity;
        position.fee_growth_inside_a = fee_growth_inside_a;
        position.fee_growth_inside_b = fee_growth_inside_b;
        position.tokens_owed_a = tokens_owed_a;
        position.tokens_owed_b = tokens_owed_b;
        copy_reward_info(reward_infos, &mut position.reward_infos);
    }

    fun copy_reward_info(
        reward_infos: &vector<PositionRewardInfoInPool>,
        reward_infos_m: &mut vector<PositionRewardInfo>
    ) {
        let len = vector::length(reward_infos);
        let i = 0;
        while (i < len) {
            let reward_info = vector::borrow(reward_infos, i);
            let (reward_growth_inside, amount_owed) = pool::get_position_reward_info(reward_info);
            try_init_reward_infos(reward_infos_m, i);
            let reward_info_m = vector::borrow_mut(reward_infos_m, i);
            reward_info_m.reward_growth_inside = reward_growth_inside;
            reward_info_m.amount_owed = amount_owed;
            i = i + 1;
        };
    }

    fun try_init_reward_infos(
        reward_infos: &mut vector<PositionRewardInfo>,
        index: u64,
    ) {
        let len = vector::length(reward_infos);
        if (index == len) {
            vector::push_back(reward_infos, PositionRewardInfo {
                reward_growth_inside: 0,
                amount_owed: 0,
            });
        }
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init_(ctx);
    }

    #[test_only]
    public fun get_nft_minted(positions: & Positions,): u64 {
        positions.nft_minted
    }
}