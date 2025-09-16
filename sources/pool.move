// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::pool {
    use std::vector;
    use std::type_name::{Self, TypeName};
    use sui::pay;
    use sui::event;
    use sui::transfer;
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as dof;
    use sui::dynamic_field as df;
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use turbos_clmm::math_tick;
    use turbos_clmm::math_swap;
    use turbos_clmm::string_tools;
    use turbos_clmm::i32::{Self, I32};
    use turbos_clmm::i128::{Self, I128};
    use turbos_clmm::math_liquidity;
    use turbos_clmm::math_sqrt_price;
    use turbos_clmm::math_u64;
    use turbos_clmm::full_math_u128;
    use turbos_clmm::math_u128;
    use turbos_clmm::math_bit;
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use turbos_clmm::partner::{Self, Partner};

    friend turbos_clmm::position_manager;
    friend turbos_clmm::pool_factory;
    friend turbos_clmm::swap_router;
    friend turbos_clmm::reward_manager;
    friend turbos_clmm::pool_fetcher;

    const VERSION: u64 = 18;

    const TickNotFound: u64 = 0;
    const EInvildAmount: u64 = 1;
    const EInvildMintReturnAmount: u64 = 3;
    const EInvildTick: u64 = 5;
    const EForPokesZeroPosition: u64 = 6;
    const ESwapAmountSpecifiedZero: u64 = 7;
    const EPoolLocked: u64 = 8;
    const EPoolOverflow: u64 = 11;
    const EInvildTickIndex: u64 = 12;
    const EInvalidRewardIndex: u64 = 13;
    const EInvalidRewardVault: u64 = 14;
    const EInvalidTimestamp: u64 = 15;
    const EInvalidRemoveRewardAmount: u64 = 16;
    const EInvalidRewardManager: u64 = 17;
    const EInsufficientBalanceRewardVault: u64 = 18;
    const ESqrtPriceOutOfBounds: u64 = 19;
    const EInvalidSqrtPriceLimitDirection: u64 = 20;
    const EInvildCoins: u64 = 21;
    const ENotUpgrade: u64 = 22;
    const EWrongVersion: u64 = 23;
    const ERepayWrongPool: u64 = 24;
    const ERepayWrongAmount: u64 = 25;
    const EInsufficientLiquidity: u64 = 26;
    const ERepayWrongPartner: u64 = 27;

    const MAX_TICK_INDEX: u32 = 443636;
    const Q64: u128 = 0x10000000000000000;
    const RESOLUTION_Q64: u8 = 64;
    const MIN_SQRT_PRICE: u128 = 4295048016;
    const MAX_SQRT_PRICE: u128 = 79226673515401279992447579055;
    const NUM_REWARDS: u64 = 3;

    struct Versioned has key, store {
        id: UID,
        version: u64,
    }

    struct Tick has key, store {
        id: UID,
        liquidity_gross: u128,
        liquidity_net: I128,
        fee_growth_outside_a: u128,
        fee_growth_outside_b: u128,
        reward_growths_outside: vector<u128>,
        initialized: bool,
    }

    struct TickInfo has copy, drop {
        id: ID,
        tick_index: I32,
        liquidity_gross: u128,
        liquidity_net: I128,
        fee_growth_outside_a: u128,
        fee_growth_outside_b: u128,
        reward_growths_outside: vector<u128>,
        initialized: bool,
    }

    struct PositionRewardInfo has store {
        reward_growth_inside: u128,
        amount_owed: u64,
    }

    struct Position has key, store {
        id: UID,
        // the amount of liquidity owned by this position
        liquidity: u128,
        // fee growth per unit of liquidity as of the last update to liquidity or fees owed
        fee_growth_inside_a: u128,
        fee_growth_inside_b: u128,
        // the fees owed to the position owner in token0/token1
        tokens_owed_a: u64,
        tokens_owed_b: u64,
        reward_infos: vector<PositionRewardInfo>,
    }

    struct PoolRewardVault<phantom RewardCoin> has key, store {
        id: UID,
        coin: Balance<RewardCoin>,
    }
    
    struct PoolRewardInfo has key, store {
        id: UID,
        vault: address,
        vault_coin_type: String,
        emissions_per_second: u128,
        growth_global: u128,
        manager: address,
    }

    struct Pool<phantom CoinTypeA, phantom CoinTypeB, phantom FeeType> has key, store {
        id: UID,
        coin_a: Balance<CoinTypeA>,
        coin_b: Balance<CoinTypeB>,
        protocol_fees_a: u64,
        protocol_fees_b: u64,
        sqrt_price: u128,
        tick_current_index: I32,
        tick_spacing: u32,
        max_liquidity_per_tick: u128,
        fee: u32,
        fee_protocol: u32,
        unlocked: bool,
        fee_growth_global_a: u128,
        fee_growth_global_b: u128,
        liquidity: u128,
        tick_map: Table<I32, u256>,
        deploy_time_ms: u64,
        reward_infos: vector<PoolRewardInfo>,
        reward_last_updated_time_ms: u64,
    }

    struct ComputeSwapState has copy, drop {
        amount_a: u128,
        amount_b: u128, 
        amount_specified_remaining: u128,
        amount_calculated: u128,
        sqrt_price: u128,
        tick_current_index: I32,
        fee_growth_global: u128,
        protocol_fee: u128,
        liquidity: u128,
        fee_amount: u128,
    }

    struct ComputeSwapStateV2 has copy, drop {
        amount_a: u128,
        amount_b: u128, 
        amount_specified_remaining: u128,
        amount_calculated: u128,
        sqrt_price: u128,
        tick_current_index: I32,
        fee_growth_global: u128,
        protocol_fee: u128,
        liquidity: u128,
        fee_amount: u128,
        partner_fee_amount: u128,
    }

    struct FlashSwapReceipt<phantom CoinTypeA, phantom CoinTypeB> {
        pool_id: ID,
        a_to_b: bool,
        pay_amount: u64,
    }

    struct FlashSwapReceiptPartner<phantom CoinTypeA, phantom CoinTypeB> {
        pool_id: ID,
        a_to_b: bool,
        pay_amount: u64,
        partner_id: ID,
        partner_fee_amount: u64,
    }

    struct SwapEvent has copy, drop {
        pool: ID,
        recipient: address,
        amount_a: u64,
        amount_b: u64,
        liquidity: u128,
        tick_current_index: I32,
        tick_pre_index: I32,
        sqrt_price: u128,
        protocol_fee: u64,
        fee_amount: u64,
        a_to_b: bool,
        is_exact_in: bool,
    }

    struct MintEvent has copy, drop {
        pool: ID,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount_a: u64,
        amount_b: u64,
        liquidity_delta: u128,
    }

    struct BurnEvent has copy, drop {
        pool: ID,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount_a: u64,
        amount_b: u64,
        liquidity_delta: u128,
    }

    struct TogglePoolStatusEvent has copy, drop {
        pool: ID,
        status: bool,
    }

    struct UpdatePoolFeeProtocolEvent has copy, drop {
        pool: ID,
        fee_protocol: u32,
    }

    struct CollectEvent has copy, drop {
        pool: ID,
        recipient: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount_a: u64,
        amount_b: u64,
    }

    struct CollectProtocolFeeEvent has copy, drop {
        pool: ID,
        recipient: address,
        amount_a: u64,
        amount_b: u64,
    }

    struct CollectRewardEvent has copy, drop {
        pool: ID,
        recipient: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount: u64,
        vault: ID,
        reward_index: u64,
    }

    struct CollectEventV2 has copy, drop {
        pool: ID,
        owner: address,
        recipient: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount_a: u64,
        amount_b: u64,
    }

    struct CollectRewardEventV2 has copy, drop {
        pool: ID,
        recipient: address,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount: u64,
        vault: ID,
        reward_type: TypeName,
        reward_index: u64,
    }

    struct InitRewardEvent has copy, drop {
        pool: ID,
        reward_index: u64,
        reward_vault: address,
        reward_manager: address,
    }

    struct UpdateRewardManagerEvent has copy, drop {
        pool: ID,
        reward_index: u64,
        reward_manager: address,
    }

    struct UpdateRewardEmissionsEvent has copy, drop {
        pool: ID,
        reward_index: u64,
        reward_vault: address,
        reward_manager: address,
        reward_emissions_per_second: u128,
    }

    struct AddRewardEvent has copy, drop {
        pool: ID,
        reward_index: u64,
        reward_vault: address,
        reward_manager: address,
        amount: u64,
    }

    struct RemoveRewardEvent has copy, drop {
        pool: ID,
        reward_index: u64,
        reward_vault: address,
        reward_manager: address,
        amount: u64,
        recipient: address,
    }

    struct UpgradeEvent has copy, drop {
        old_version: u64,
        new_version: u64,
    }

    struct MigratePositionEvent has copy, drop {
        pool: ID,
        old_key: String, 
        new_key: String,
    }

    struct ModifyTickRewardEvent has copy, drop {
        pool: ID,
        old_reward: u128, 
        new_reward: u128,
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(Versioned {
            id: object::new(ctx),
            version: VERSION,
        });
    }

    public(friend) fun upgrade(
        versioned: &mut Versioned,
    ) {
        let old_version = versioned.version;
        assert!(old_version < VERSION, ENotUpgrade);
        versioned.version = VERSION;

        event::emit(UpgradeEvent {
            old_version: old_version,
            new_version: VERSION,
        })
    }

    public fun version(versioned: &Versioned): u64 {
        versioned.version
    }

    public fun check_version(versioned: &Versioned) {
        assert!(VERSION >= versioned.version, EWrongVersion);
    }

    public(friend) fun deploy_pool<CoinTypeA, CoinTypeB, FeeType>(
        fee: u32,
        tick_spacing: u32,
        sqrt_price: u128,
        fee_protocol: u32,
        clock: &Clock,
        ctx: &mut TxContext
    ) :Pool<CoinTypeA, CoinTypeB, FeeType> {
        let tick_current_index = math_tick::tick_index_from_sqrt_price(sqrt_price);
        let max_liquidity_per_tick = math_tick::max_liquidity_per_tick(tick_spacing);

        Pool {
            id: object::new(ctx), 
            coin_a: balance::zero<CoinTypeA>(),
            coin_b: balance::zero<CoinTypeB>(),
            protocol_fees_a: 0,
            protocol_fees_b: 0,
            sqrt_price: sqrt_price,
            tick_current_index: tick_current_index,
            tick_spacing: tick_spacing,
            max_liquidity_per_tick: max_liquidity_per_tick,
            fee: fee,
            fee_protocol: fee_protocol,
            unlocked: true,
            fee_growth_global_a: 0,
            fee_growth_global_b: 0,
            liquidity: 0,
            tick_map: table::new(ctx),
            deploy_time_ms: clock::timestamp_ms(clock),
            reward_infos: vector::empty(),
            reward_last_updated_time_ms: 0,
        }
    }

    public(friend) fun mint<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: u128,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, u64) {
        assert!(pool.unlocked, EPoolLocked);
        assert!(liquidity_delta > 0, EInvildAmount);

        try_init_position(
            pool,
            owner,
            tick_lower_index,
            tick_upper_index,
            ctx
        );

        let (amount_a, amount_b) = modify_position(
            pool,
            owner,
            tick_lower_index,
            tick_upper_index,
            i128::from(liquidity_delta),
            clock,
            ctx
        );

        assert!(!i128::is_neg(amount_a) && !i128::is_neg(amount_b), EInvildMintReturnAmount);
        let (amount_a_u64, amount_b_u64) = ((i128::abs_u128(amount_a) as u64), (i128::abs_u128(amount_b) as u64));

        event::emit(MintEvent {
            pool: object::id(pool),
            owner: owner,
            tick_lower_index: tick_lower_index,
            tick_upper_index: tick_upper_index,
            amount_a: amount_a_u64,
            amount_b: amount_b_u64,
            liquidity_delta: liquidity_delta,
        });

        (amount_a_u64, amount_b_u64)
    }

    public(friend) fun burn<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: u128,
        clock: &Clock,
        ctx: &mut TxContext
    ): (u64, u64) {
        assert!(pool.unlocked, EPoolLocked);
        let (amount_a, amount_b) = modify_position(
            pool,
            owner,
            tick_lower_index,
            tick_upper_index,
            i128::neg_from(liquidity_delta),
            clock,
            ctx
        );

        let (amount_a_u64, amount_b_u64) = ((i128::abs_u128(amount_a) as u64), (i128::abs_u128(amount_b) as u64));

        // if (amount_a_u64 > 0 || amount_b_u64 > 0) {
        //     let position = get_position_mut(pool, owner, tick_lower_index, tick_upper_index);
        //     position.tokens_owed_a = position.tokens_owed_a + amount_a_u64;
        //     position.tokens_owed_b = position.tokens_owed_b + amount_b_u64;
        // };

        event::emit(BurnEvent {
            pool: object::id(pool),
            owner: owner,
            tick_lower_index: tick_lower_index,
            tick_upper_index: tick_upper_index,
            amount_a: amount_a_u64,
            amount_b: amount_b_u64,
            liquidity_delta: liquidity_delta,
        });

        (amount_a_u64, amount_b_u64)
    }

    public(friend) fun swap<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        recipient: address,
        a_to_b: bool,
        amount_specified: u128,
        amount_specified_is_input: bool,
        sqrt_price_limit: u128,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u128, u128) {
        let state = compute_swap_result(
            pool,
            recipient,
            a_to_b,
            amount_specified,
            amount_specified_is_input,
            sqrt_price_limit,
            false,
            0,
            clock,
            ctx
        );
        
        (state.amount_a, state.amount_b)
    }

    public fun flash_swap<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        recipient: address,
        a_to_b: bool,
        amount_specified: u128,
        amount_specified_is_input: bool,
        sqrt_price_limit: u128,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext,
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>, FlashSwapReceipt<CoinTypeA, CoinTypeB>) {
        check_version(versioned);
        assert!(pool.unlocked, EPoolLocked);
        let state = compute_swap_result(
            pool,
            recipient,
            a_to_b,
            amount_specified,
            amount_specified_is_input,
            sqrt_price_limit,
            false,
            0,
            clock,
            ctx
        );

        let (coin_a_output, coin_b_output, pay_amount) = if (a_to_b) {
            let balance_b_output = balance::split(&mut pool.coin_b, (state.amount_b as u64));
            (coin::zero<CoinTypeA>(ctx), coin::from_balance(balance_b_output, ctx), (state.amount_a as u64))
        } else {
            let balance_a_output = balance::split(&mut pool.coin_a, (state.amount_a as u64));
            (coin::from_balance(balance_a_output, ctx), coin::zero<CoinTypeB>(ctx), (state.amount_b as u64))
        };
        
        (
            coin_a_output, 
            coin_b_output,
            FlashSwapReceipt<CoinTypeA, CoinTypeB> {
                pool_id: object::id(pool),
                a_to_b: a_to_b,
                pay_amount: pay_amount,
            }
        )
    }

    public fun flash_swap_partner<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        partner: &Partner,
        a_to_b: bool,
        amount_specified: u128,
        amount_specified_is_input: bool,
        sqrt_price_limit: u128,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext,
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>, FlashSwapReceiptPartner<CoinTypeA, CoinTypeB>) {
        check_version(versioned);
        assert!(pool.unlocked, EPoolLocked);
        let state = compute_swap_result(
            pool,
            @0x0,
            a_to_b,
            amount_specified,
            amount_specified_is_input,
            sqrt_price_limit,
            false,
            partner::current_ref_fee_rate(partner, clock::timestamp_ms(clock) / 1000),
            clock,
            ctx
        );

        let (coin_a_output, coin_b_output, pay_amount) = if (a_to_b) {
            let balance_b_output = balance::split(&mut pool.coin_b, (state.amount_b as u64));
            (coin::zero<CoinTypeA>(ctx), coin::from_balance(balance_b_output, ctx), (state.amount_a as u64))
        } else {
            let balance_a_output = balance::split(&mut pool.coin_a, (state.amount_a as u64));
            (coin::from_balance(balance_a_output, ctx), coin::zero<CoinTypeB>(ctx), (state.amount_b as u64))
        };
        
        (
            coin_a_output, 
            coin_b_output,
            FlashSwapReceiptPartner<CoinTypeA, CoinTypeB> {
                pool_id: object::id(pool),
                a_to_b: a_to_b,
                pay_amount: pay_amount,
                partner_id: object::id(partner),
                partner_fee_amount: (state.partner_fee_amount as u64)
            }
        )
    }

    public fun repay_flash_swap<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        receipt: FlashSwapReceipt<CoinTypeA, CoinTypeB>,
        versioned: &Versioned
    ) {
        check_version(versioned);
        let FlashSwapReceipt { pool_id, a_to_b, pay_amount } = receipt;
        assert!(pool.unlocked, EPoolLocked);
        assert!(pool_id == object::id(pool), ERepayWrongPool);
        let coin_a_balance = coin::into_balance(coin_a);
        let coin_b_balance = coin::into_balance(coin_b);
        if (a_to_b) {
            assert!(balance::value(&coin_a_balance) == pay_amount, ERepayWrongAmount);
            balance::join(&mut pool.coin_a, coin_a_balance);
            balance::destroy_zero(coin_b_balance);
        } else {
            assert!(balance::value(&coin_b_balance) == pay_amount, ERepayWrongAmount);
            balance::join(&mut pool.coin_b, coin_b_balance);
            balance::destroy_zero(coin_a_balance);
        }
    }

    public fun repay_flash_swap_partner<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        partner: &mut Partner,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        receipt: FlashSwapReceiptPartner<CoinTypeA, CoinTypeB>,
        versioned: &Versioned,
    ) {
        check_version(versioned);
        let FlashSwapReceiptPartner { pool_id, a_to_b, pay_amount, partner_id, partner_fee_amount } = receipt;
        assert!(pool.unlocked, EPoolLocked);
        assert!(pool_id == object::id(pool), ERepayWrongPool);
        assert!(partner_id == object::id(partner), ERepayWrongPartner);
        let coin_a_balance = coin::into_balance(coin_a);
        let coin_b_balance = coin::into_balance(coin_b);
        if (a_to_b) {
            assert!(balance::value(&coin_a_balance) == pay_amount, ERepayWrongAmount);
            if (partner_fee_amount > 0) {
                partner::receive_ref_fee(partner, balance::split<CoinTypeA>(&mut coin_a_balance, partner_fee_amount));
            };
            balance::join(&mut pool.coin_a, coin_a_balance);
            balance::destroy_zero(coin_b_balance);
        } else {
            assert!(balance::value(&coin_b_balance) == pay_amount, ERepayWrongAmount);
            if (partner_fee_amount > 0) {
                partner::receive_ref_fee(partner, balance::split<CoinTypeB>(&mut coin_b_balance, partner_fee_amount));
            };
            balance::join(&mut pool.coin_b, coin_b_balance);
            balance::destroy_zero(coin_a_balance);
        }
    }

    public fun flash_swap_pay_amount<CoinTypeA, CoinTypeB>(swap_receipt: &FlashSwapReceiptPartner<CoinTypeA, CoinTypeB>): u64 {
        swap_receipt.pay_amount
    }

    public(friend) fun compute_swap_result<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        recipient: address,
        a_to_b: bool,
        amount_specified: u128,
        amount_specified_is_input: bool,
        sqrt_price_limit: u128,
        dry_run: bool,
        partner_ref_fee_rate: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): ComputeSwapStateV2 {
        assert!(pool.unlocked, EPoolLocked);
        assert!(amount_specified != 0, ESwapAmountSpecifiedZero);
        if (sqrt_price_limit < MIN_SQRT_PRICE || sqrt_price_limit > MAX_SQRT_PRICE) abort ESqrtPriceOutOfBounds;
        if (a_to_b && sqrt_price_limit > pool.sqrt_price || !a_to_b && sqrt_price_limit < pool.sqrt_price) abort EInvalidSqrtPriceLimitDirection;

        //reword
        let reward_growths = next_pool_reward_infos(pool, clock::timestamp_ms(clock));
        let tick_pre_index = pool.tick_current_index;

        //state
        let state = ComputeSwapStateV2 {
            amount_a: 0,
            amount_b: 0,
            amount_specified_remaining: amount_specified,
            amount_calculated: 0,
            sqrt_price: pool.sqrt_price,
            tick_current_index: pool.tick_current_index,
            fee_growth_global: if (a_to_b) pool.fee_growth_global_a else pool.fee_growth_global_b,
            protocol_fee: 0,
            liquidity: pool.liquidity,
            fee_amount: 0,
            partner_fee_amount: 0,
        };

        while (state.amount_specified_remaining > 0 && state.sqrt_price !=sqrt_price_limit) {
            let step_sqrt_price_start = state.sqrt_price;
            let (step_tick_next_index, step_initialized) = next_initialized_tick_within_one_word(
                pool,
                state.tick_current_index,
                a_to_b
            );

            if (i32::lt(step_tick_next_index, i32::neg_from(MAX_TICK_INDEX))) {
                step_tick_next_index = i32::neg_from(MAX_TICK_INDEX);
            } else if (i32::gt(step_tick_next_index, i32::from(MAX_TICK_INDEX))) {
                step_tick_next_index = i32::from(MAX_TICK_INDEX);
            };

            let step_sqrt_price_next = math_tick::sqrt_price_from_tick_index(step_tick_next_index);
            // compute values to swap to the target tick, price limit, or point where input/output amount is exhausted
            let step_sqrt_price;
            let step_amount_in;
            let step_amount_out;
            let step_fee_amount;
            let limit = if (a_to_b) step_sqrt_price_next < sqrt_price_limit else step_sqrt_price_next > sqrt_price_limit;
            let target = if (limit) sqrt_price_limit else step_sqrt_price_next;
            (step_sqrt_price, step_amount_in, step_amount_out, step_fee_amount) = math_swap::compute_swap(
                state.sqrt_price,
                target,
                state.liquidity,
                state.amount_specified_remaining,
                amount_specified_is_input,
                pool.fee
            );
            state.sqrt_price = step_sqrt_price;

            if (amount_specified_is_input) {
                state.amount_specified_remaining = state.amount_specified_remaining - step_amount_in - step_fee_amount;
                state.amount_calculated = state.amount_calculated + step_amount_out;
            } else {
                state.amount_specified_remaining = state.amount_specified_remaining - step_amount_out;
                state.amount_calculated = state.amount_calculated + step_amount_in + step_fee_amount;
            };

            state.fee_amount = state.fee_amount + step_fee_amount;
            if (pool.fee_protocol > 0) {
                let delta = step_fee_amount * (pool.fee_protocol as u128) / 1000000;
                step_fee_amount = step_fee_amount - delta;
                state.protocol_fee = math_u128::wrapping_add(state.protocol_fee, delta);
            };

            if (state.liquidity > 0) {
                let fee_growth_global_delta = full_math_u128::mul_div_floor(step_fee_amount, Q64, state.liquidity);
                state.fee_growth_global = math_u128::wrapping_add(state.fee_growth_global, fee_growth_global_delta);
            };

            if (state.sqrt_price == step_sqrt_price_next) {
                if (step_initialized) {
                    let (fee_growth_global_a, fee_growth_global_b) = (pool.fee_growth_global_a, pool.fee_growth_global_b);
                    let liquidity_net = cross_tick(
                        pool,
                        step_tick_next_index,
                        if(a_to_b) state.fee_growth_global else fee_growth_global_a,
                        if(a_to_b) fee_growth_global_b else state.fee_growth_global,
                        &reward_growths,
                        dry_run,
                        ctx
                    );
                    // if we're moving leftward, we interpret liquidity_net as the opposite sign
                    // safe because liquidity_net cannot be type(int128).min
                    if (a_to_b) {
                        liquidity_net = i128::neg(liquidity_net);
                    };

                    state.liquidity = math_liquidity::add_delta(state.liquidity, liquidity_net);
                };
                state.tick_current_index = if (a_to_b) i32::sub(step_tick_next_index, i32::from(1)) else step_tick_next_index;
            } else if (state.sqrt_price != step_sqrt_price_start) {
                state.tick_current_index = math_tick::tick_index_from_sqrt_price(state.sqrt_price);
            };
            if (state.liquidity == 0) {
                break
            };
        };

        if (!dry_run) {
            assert!(state.liquidity > 0, EInsufficientLiquidity);
            if (!i32::eq(state.tick_current_index, pool.tick_current_index)) {
                pool.sqrt_price = state.sqrt_price;
                pool.tick_current_index = state.tick_current_index;
            } else {
                pool.sqrt_price = state.sqrt_price;
            };

            if (pool.liquidity != state.liquidity) pool.liquidity = state.liquidity;
       
            if (partner_ref_fee_rate > 0) {
                state.partner_fee_amount = full_math_u128::mul_div_floor(state.protocol_fee, (partner_ref_fee_rate as u128), 10000);
            };
            if (a_to_b) {
                pool.fee_growth_global_a = state.fee_growth_global;
                if (state.protocol_fee > 0) {
                    pool.protocol_fees_a = pool.protocol_fees_a + (state.protocol_fee as u64) - (state.partner_fee_amount as u64);
                };
            } else {
                pool.fee_growth_global_b = state.fee_growth_global;
                if (state.protocol_fee > 0) {
                    pool.protocol_fees_b = pool.protocol_fees_b + (state.protocol_fee as u64) - (state.partner_fee_amount as u64);
                };
            };
        };

        let (amount_a, amount_b) = if (a_to_b == amount_specified_is_input) {
            (amount_specified - state.amount_specified_remaining, state.amount_calculated)
        } else {
            (state.amount_calculated, amount_specified - state.amount_specified_remaining)
        };
        state.amount_a = amount_a;
        state.amount_b = amount_b;

        event::emit(SwapEvent {
            pool: object::id(pool),
            recipient: recipient,
            amount_a: (state.amount_a as u64),
            amount_b: (state.amount_b as u64),
            liquidity: state.liquidity,
            tick_current_index: state.tick_current_index,
            tick_pre_index: tick_pre_index,
            sqrt_price: state.sqrt_price,
            protocol_fee: (state.protocol_fee as u64),
            fee_amount: (state.fee_amount as u64),
            a_to_b: a_to_b,
            is_exact_in: amount_specified_is_input,
        });

        state
    }

    public(friend) fun convert_state_v2_to_v1(state: &ComputeSwapStateV2): ComputeSwapState {
        ComputeSwapState {
            amount_a: state.amount_a,
            amount_b: state.amount_b,
            amount_specified_remaining: state.amount_specified_remaining,
            amount_calculated: state.amount_calculated,
            sqrt_price: state.sqrt_price,
            tick_current_index: state.tick_current_index,
            fee_growth_global: state.fee_growth_global,
            protocol_fee: state.protocol_fee,
            liquidity: state.liquidity,
            fee_amount: state.fee_amount,
        }
    }

    public(friend) fun toggle_pool_status<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        _ctx: &mut TxContext,
    ) {
        pool.unlocked = !pool.unlocked;

        event::emit(TogglePoolStatusEvent {
            pool: object::id(pool),
            status: pool.unlocked,
        });
    }

    ///deprecated
    public(friend) fun collect<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        recipient: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount_a_requested: u64,
        amount_b_requested: u64,
        ctx: &mut TxContext
    ): (u64, u64) {
        abort(0)
    }

     public(friend) fun collect_v2<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        recipient: address,
        position_owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount_a_requested: u64,
        amount_b_requested: u64,
        _ctx: &mut TxContext
    ): (u64, u64) {
        let position = get_position_mut(pool, position_owner, tick_lower_index, tick_upper_index);

        let amount_a = if (amount_a_requested > position.tokens_owed_a) position.tokens_owed_a else amount_a_requested;
        let amount_b = if (amount_b_requested > position.tokens_owed_b) position.tokens_owed_b else amount_b_requested;

        if (amount_a > 0) {
            position.tokens_owed_a = position.tokens_owed_a - amount_a;
        };
        if (amount_b > 0) {
            position.tokens_owed_b = position.tokens_owed_b - amount_b;
        };

        event::emit(CollectEventV2 {
            pool: object::id(pool),
            owner: position_owner,
            recipient: recipient,
            tick_lower_index: tick_lower_index,
            tick_upper_index: tick_upper_index,
            amount_a: amount_a,
            amount_b: amount_b,
        });

        (amount_a, amount_b)
    }

    ///deprecated
    public(friend) fun collect_protocol_fee<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        amount_a_requested: u64,
        amount_b_requested: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public(friend) fun collect_protocol_fee_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        amount_a_requested: u64,
        amount_b_requested: u64,
        recipient: address,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        let amount_a = if (amount_a_requested > pool.protocol_fees_a) pool.protocol_fees_a else amount_a_requested;
        let amount_b = if (amount_b_requested > pool.protocol_fees_b) pool.protocol_fees_b else amount_b_requested;

        if (amount_a > 0) {
            pool.protocol_fees_a = pool.protocol_fees_a - amount_a;
        };
        if (amount_b > 0) {
            pool.protocol_fees_b = pool.protocol_fees_b - amount_b;
        };
  
        let (coin_a, coin_b) = split_out_and_return_(
            pool,
            amount_a,
            amount_b,
            ctx
        );

        event::emit(CollectProtocolFeeEvent {
            pool: object::id(pool),
            recipient: recipient,
            amount_a: amount_a,
            amount_b: amount_b,
        });

        (coin_a, coin_b)
    }

    public(friend) fun update_pool_fee_protocol<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        fee_protocol: u32,
    ) {
        pool.fee_protocol = fee_protocol;
        event::emit(UpdatePoolFeeProtocolEvent {
            pool: object::id(pool),
            fee_protocol: fee_protocol
        });
    }

    public(friend) fun init_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
        manager: address,
        ctx: &mut TxContext
    ): PoolRewardVault<RewardCoin> {
        assert!(reward_index < NUM_REWARDS, EInvalidRewardIndex);
        assert!(reward_index == vector::length(&pool.reward_infos), EInvalidRewardIndex);

        let vault = PoolRewardVault {
            id: object::new(ctx),
            coin: balance::zero<RewardCoin>(),
        };
        vector::insert(&mut pool.reward_infos, PoolRewardInfo {
            id: object::new(ctx), 
            vault: object::id_address(&vault),
            vault_coin_type: string::from_ascii(type_name::into_string(type_name::get<RewardCoin>())),
            emissions_per_second: 0,
            growth_global: 0,
            manager: manager,
        }, reward_index);

        event::emit(InitRewardEvent {
            pool: object::id(pool),
            reward_index: reward_index,
            reward_vault: object::id_address(&vault),
            reward_manager: manager,
        });
        
        vault
    }

    public(friend) fun reset_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
        ctx: &mut TxContext
    ) {
        assert!(reward_index < NUM_REWARDS, EInvalidRewardIndex);

        let reward_info = vector::borrow_mut(&mut pool.reward_infos, reward_index);
        reward_info.growth_global = 0;
        reward_info.emissions_per_second = 0;
    }

    public(friend) fun update_reward_manager<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
        new_manager: address,
        _ctx: &mut TxContext
    ) {
        assert!(reward_index < NUM_REWARDS, EInvalidRewardIndex);
        assert!(reward_index < vector::length(&pool.reward_infos), EInvalidRewardIndex);

        let reward_info = vector::borrow_mut(&mut pool.reward_infos, reward_index);
        reward_info.manager = new_manager;

        event::emit(UpdateRewardManagerEvent {
            pool: object::id(pool),
            reward_index: reward_index,
            reward_manager: new_manager,
        })
    }

    public(friend) fun update_reward_emissions<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
        emissions_per_second: u128,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        next_pool_reward_infos(pool, clock::timestamp_ms(clock));
        let pool_id = object::id(pool);
        assert!(reward_index < vector::length(&pool.reward_infos),EInvalidRewardIndex);
        let reward_info = vector::borrow_mut(&mut pool.reward_infos, reward_index);

        reward_info.emissions_per_second = emissions_per_second << RESOLUTION_Q64;

        event::emit(UpdateRewardEmissionsEvent {
            pool: pool_id,
            reward_index: reward_index,
            reward_vault: reward_info.vault,
            reward_manager: reward_info.manager,
            reward_emissions_per_second: emissions_per_second,
        });
    }

    public(friend) fun add_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        vault: &mut  PoolRewardVault<RewardCoin>,
        reward_index: u64,
        coin: Coin<RewardCoin>,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(reward_index < vector::length(&pool.reward_infos),EInvalidRewardIndex);
        next_pool_reward_infos(pool, clock::timestamp_ms(clock));
        let reward_info = vector::borrow(&pool.reward_infos, reward_index);
        assert!(reward_info.vault == object::id_address(vault), EInvalidRewardVault);
        
        let coin_in = coin::split(&mut coin, amount, ctx);
        balance::join(&mut vault.coin, coin::into_balance(coin_in));

        if (coin::value(&coin) == 0) {
            coin::destroy_zero(coin);
        } else {
            transfer::public_transfer(
                coin,
                tx_context::sender(ctx)
            );
        };

        event::emit(AddRewardEvent {
            pool: object::id(pool),
            reward_index: reward_index,
            reward_vault: reward_info.vault,
            reward_manager: reward_info.manager,
            amount: amount,
        });
    }

    public(friend) fun remove_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        vault: &mut  PoolRewardVault<RewardCoin>,
        reward_index: u64,
        amount: u64,
        recipient: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(reward_index < vector::length(&pool.reward_infos),EInvalidRewardIndex);
        next_pool_reward_infos(pool, clock::timestamp_ms(clock));
        let reward_info = vector::borrow(&pool.reward_infos, reward_index);
        assert!(reward_info.vault == object::id_address(vault), EInvalidRewardVault);
        assert!(amount <= balance::value(&vault.coin), EInvalidRemoveRewardAmount);

        let amount_out_balance = balance::split(&mut vault.coin, amount);
        let amount_out_coin = coin::from_balance(amount_out_balance, ctx);
        transfer::public_transfer(amount_out_coin, recipient);

        event::emit(RemoveRewardEvent {
            pool: object::id(pool),
            reward_index: reward_index,
            reward_vault: reward_info.vault,
            reward_manager: reward_info.manager,
            amount: amount,
            recipient: recipient,
        });
    }

    /// deprecated
    public(friend) fun collect_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        vault: &mut  PoolRewardVault<RewardCoin>,
        recipient: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount: u64,
        reward_index: u64,
        ctx: &mut TxContext
    ): u64 {
        abort(0)
    }

    /// deprecated
    public(friend) fun collect_reward_v2<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        vault: &mut  PoolRewardVault<RewardCoin>,
        recipient: address,
        position_owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount: u64,
        reward_index: u64,
        ctx: &mut TxContext
    ): u64 {
        abort(0)
    }

    public(friend) fun collect_reward_with_return_<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        vault: &mut  PoolRewardVault<RewardCoin>,
        recipient: address,
        position_owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount: u64,
        reward_index: u64,
        ctx: &mut TxContext
    ): Coin<RewardCoin> {
        let pool_reward_info = vector::borrow(&pool.reward_infos, reward_index);
        assert!(pool_reward_info.vault == object::id_address(vault), EInvalidRewardVault);
        let position = get_position_mut(pool, position_owner, tick_lower_index, tick_upper_index);
        assert!(reward_index < vector::length(&position.reward_infos),EInvalidRewardIndex);
        let reward_info = vector::borrow_mut(&mut position.reward_infos, reward_index);

        let amount = if (amount > reward_info.amount_owed) reward_info.amount_owed else amount;

        if (amount > 0) {
            reward_info.amount_owed = reward_info.amount_owed - amount;
        };

        assert!(amount <= balance::value(&vault.coin), EInsufficientBalanceRewardVault);
        let amount_out_balance = balance::split(&mut vault.coin, amount);
        let amount_out_coin = coin::from_balance(amount_out_balance, ctx);

        event::emit(CollectRewardEventV2 {
            pool: object::id(pool),
            recipient: recipient,
            owner: position_owner,
            tick_lower_index: tick_lower_index,
            tick_upper_index: tick_upper_index,
            amount: amount,
            vault: object::id(vault),
            reward_type: type_name::get<RewardCoin>(),
            reward_index: reward_index,
        });

        amount_out_coin
    }

    // returns [growth_global]
    fun next_pool_reward_infos<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        next_time_ms: u64,
    ) :vector<u128> {
        let curr_time_ms = pool.reward_last_updated_time_ms;
        assert!(next_time_ms >= curr_time_ms, EInvalidTimestamp);

        let growth_global_vector = vector::empty<u128>();
        // Calculate new global reward growth
        let time_delta = (next_time_ms - curr_time_ms) / 1000;
        let len = vector::length(&pool.reward_infos);
        let i = 0;
        
        while (i < len) {
            let reward_info = vector::borrow_mut(&mut pool.reward_infos, i);
            if (pool.liquidity == 0 || time_delta == 0) {
                vector::insert(&mut growth_global_vector, reward_info.growth_global, i);
            } else {
                // Calculate the new reward growth delta.
                let reward_growth_delta = full_math_u128::mul_div_floor(
                    (time_delta as u128),
                    reward_info.emissions_per_second,
                    pool.liquidity,
                );

                let curr_growth_global = reward_info.growth_global;
                reward_info.growth_global = math_u128::wrapping_add(curr_growth_global, reward_growth_delta);
                vector::insert(&mut growth_global_vector, reward_info.growth_global, i);
            };

            i = i + 1;
        };

        let i = vector::length(&growth_global_vector);
        while (i < NUM_REWARDS) {
            vector::push_back(&mut growth_global_vector, 0);
            i = i + 1;
        };

        pool.reward_last_updated_time_ms = next_time_ms;

        growth_global_vector
    }

    public fun next_initialized_tick_within_one_word<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_current_index: I32,
        lte: bool
    ): (I32, bool) {
        assert!(i32::gte(tick_current_index, i32::neg_from(MAX_TICK_INDEX)), EInvildTick);
        assert!(i32::lte(tick_current_index, i32::from(MAX_TICK_INDEX)), EInvildTick);

        let compressed = i32::div(tick_current_index, i32::from(pool.tick_spacing));

        // round towards negative infinity
        if (
            i32::lt(tick_current_index, i32::zero()) && 
            !i32::eq(i32::mod_euclidean(tick_current_index, pool.tick_spacing), i32::zero())
        ) {
             compressed = i32::sub(compressed, i32::from(1));
        };
        let next: I32;
        let initialized: bool;
        if (lte) {
            let (word_pos, bit_pos) = position_tick(compressed);
            try_init_tick_word(pool, word_pos);
            let word = get_tick_word(pool, word_pos);
            // all the 1s at or to the right of the current bit_pos
            let mask: u256 = (1 << bit_pos) - 1 + (1 << bit_pos);
            let masked: u256 = word & mask;

            // if there are no initialized ticks to the right of or at the current tick, return rightmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = if (initialized) {
                i32::mul(
                    i32::sub(compressed, i32::from((bit_pos - math_bit::most_significant_bit(masked) as u32))), 
                    i32::from(pool.tick_spacing)
                )
            } else { 
                i32::mul(
                    i32::sub(compressed, i32::from((bit_pos as u32))),
                    i32::from(pool.tick_spacing)
                )
            };
        } else {
            // start from the word of the next tick, since the current tick state doesn't matter
            let (word_pos, bit_pos) = position_tick(i32::add(compressed, i32::from(1)));
            try_init_tick_word(pool, word_pos);
            let word = get_tick_word(pool, word_pos);
            // all the 1s at or to the left of the bit_pos
            // like ~((1 << bit_pos) - 1)
            let mask: u256 = ((1 << bit_pos) - 1) ^ 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
            let masked = word & mask;

            // if there are no initialized ticks to the left of the current tick, return leftmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = if (initialized) {
                i32::mul(
                    i32::add(
                        i32::add(compressed, i32::from(1)),
                        i32::sub(i32::from((math_bit::least_significant_bit(masked) as u32)), i32::from((bit_pos as u32)))
                    ), 
                    i32::from(pool.tick_spacing)
                )
            } else { 
                i32::mul(
                    i32::add(
                        i32::add(compressed, i32::from(1)),
                        i32::from(((255 - bit_pos) as u32))
                    ),
                    i32::from(pool.tick_spacing)
                )
            };
        };

        (next, initialized)
    }

    public fun position_tick(tick: I32): (I32, u8) {
        let word_pos = i32::shr(tick, 8);
        let bit_pos = (i32::abs_u32(i32::mod_euclidean(tick, 256)) as u8);

        (word_pos, bit_pos)
    }

    fun try_init_tick_word<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        word_pos: I32
    ) {
        if (!table::contains(&pool.tick_map, word_pos)) {
            table::add(&mut pool.tick_map, word_pos, 0u256);
        };
    }

    fun get_tick_word<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        word_pos: I32
    ): u256 {
        *table::borrow(& pool.tick_map, word_pos)
    }

    fun get_tick_word_mut<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        word_pos: I32
    ): &mut u256 {
        table::borrow_mut(&mut pool.tick_map, word_pos)
    }

    /// @return amount_a the amount of token0 owed to the pool, negative if the pool should pay the recipient
    /// @return amount_b the amount of token1 owed to the pool, negative if the pool should pay the recipient
    fun modify_position<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: I128,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (I128, I128){
        check_ticks(tick_lower_index, tick_upper_index);

        update_position(
            pool,
            owner,
            tick_lower_index,
            tick_upper_index,
            liquidity_delta,
            clock,
            ctx,
        );
        let amount_a = i128::zero();
        let amount_b = i128::zero();

        if (!i128::eq(liquidity_delta, i128::zero())) {
            if (i32::lt(pool.tick_current_index, tick_lower_index)) {
                // current tick is below the passed range; liquidity can only become in range by crossing from left to
                // right, when we'll need _more_ token0 (it's becoming more valuable) so user must provide it
                amount_a = math_sqrt_price::get_amount_a_delta(
                    math_tick::sqrt_price_from_tick_index(tick_lower_index),
                    math_tick::sqrt_price_from_tick_index(tick_upper_index),
                    liquidity_delta
                );
            } else if (i32::lt(pool.tick_current_index, tick_upper_index)) {
                amount_a = math_sqrt_price::get_amount_a_delta(
                    pool.sqrt_price,
                    math_tick::sqrt_price_from_tick_index(tick_upper_index),
                    liquidity_delta
                );
                amount_b = math_sqrt_price::get_amount_b_delta(
                    math_tick::sqrt_price_from_tick_index(tick_lower_index),
                    pool.sqrt_price,
                    liquidity_delta
                );
                pool.liquidity = math_liquidity::add_delta(pool.liquidity, liquidity_delta);
            } else {
                // current tick is above the passed range; liquidity can only become in range by crossing from right to
                // left, when we'll need _more_ token1 (it's becoming more valuable) so user must provide it
                amount_b = math_sqrt_price::get_amount_b_delta(
                    math_tick::sqrt_price_from_tick_index(tick_lower_index),
                    math_tick::sqrt_price_from_tick_index(tick_upper_index),
                    liquidity_delta
                );
            };
        };

        (amount_a, amount_b)
    }

    fun try_init_position<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        ctx: &mut TxContext
    ) {
        let key = get_position_key_fix(pool, owner, tick_lower_index, tick_upper_index);
        if (!dof::exists_(&pool.id, key)) {
            let reward_infos = vector::empty<PositionRewardInfo>();
            let i = 0;
            while (i < NUM_REWARDS) {
                vector::push_back(&mut reward_infos, PositionRewardInfo {
                    reward_growth_inside: 0,
                    amount_owed: 0,
                });
                i = i + 1;
            };
            dof::add(&mut pool.id, key, Position {
                id: object::new(ctx),
                liquidity: 0,
                fee_growth_inside_a: 0,
                fee_growth_inside_b: 0,
                tokens_owed_a: 0,
                tokens_owed_b: 0,
                reward_infos: reward_infos,
            });
        }
    }

    fun update_position<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: I128,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let tick_current_index = pool.tick_current_index;

        // if we need to update the ticks, do it
        let flipped_lower = false;
        let flipped_upper = false;
        let reward_growths = next_pool_reward_infos(pool, clock::timestamp_ms(clock));
        if (!i128::eq(liquidity_delta, i128::zero())) {
            flipped_lower = update_tick(
                pool,
                tick_lower_index,
                tick_current_index,
                liquidity_delta,
                false,
                reward_growths,
                ctx,
            );
            flipped_upper = update_tick(
                pool,
                tick_upper_index,
                tick_current_index,
                liquidity_delta,
                true,
                reward_growths,
                ctx,
            );

            if (flipped_lower) {
                flip_tick(pool, tick_lower_index, ctx);
            };
            if (flipped_upper) {
                flip_tick(pool, tick_upper_index, ctx);
            };
        };

        let (fee_growth_inside_a, fee_growth_inside_b) = next_fee_growth_inside(
            pool,
            tick_lower_index,
            tick_upper_index,
            tick_current_index,
            ctx
        );

        let reward_growths_inside = next_reward_growths_inside(
            pool,
            tick_lower_index,
            tick_upper_index,
            tick_current_index,
            ctx
        );

        let key = get_position_key_fix(pool, owner, tick_lower_index, tick_upper_index);
        update_position_metadata(
            pool, 
            key,
            liquidity_delta, 
            fee_growth_inside_a, 
            fee_growth_inside_b, 
            reward_growths_inside,
            ctx
        );

        // clear any tick data that is no longer needed
        if (i128::is_neg(liquidity_delta)) {
            if (flipped_lower) {
                clear_tick(pool, tick_lower_index, ctx);
            };
            if (flipped_upper) {
                clear_tick(pool, tick_upper_index, ctx);
            };
        };
    }

    fun check_ticks(
        tick_lower_index: I32,
        tick_upper_index: I32
    ) {
        assert!(i32::lt(tick_lower_index, tick_upper_index), EInvildTick);
        assert!(i32::gte(tick_lower_index, i32::neg_from(MAX_TICK_INDEX)), EInvildTick);
        assert!(i32::lte(tick_upper_index, i32::from(MAX_TICK_INDEX)), EInvildTick);
    }

    fun update_tick<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: I32,
        tick_current_index: I32,
        liquidity_delta: I128,
        is_upper: bool,
        reward_infos: vector<u128>,
        ctx: &mut TxContext,
    ): bool {
        let tick;
        let fee_growth_global_a = pool.fee_growth_global_a;
        let fee_growth_global_b = pool.fee_growth_global_b;
        let max_liquidity_per_tick = pool.max_liquidity_per_tick;
        if (!df::exists_(&pool.id, tick_index)) {
            tick = init_tick(pool, tick_index, ctx);
        } else {
            tick = df::borrow_mut<I32, Tick>(&mut pool.id, tick_index);
        };

        let liquidity_gross_before = tick.liquidity_gross;
        let liquidity_gross_after = math_liquidity::add_delta(liquidity_gross_before, liquidity_delta);

        assert!(liquidity_gross_after <= max_liquidity_per_tick, EPoolOverflow);

        let flipped = (liquidity_gross_after == 0) != (liquidity_gross_before == 0);

        if (liquidity_gross_before == 0) {
            // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
            if (i32::lte(tick_index, tick_current_index)) {
                tick.fee_growth_outside_a = fee_growth_global_a;
                tick.fee_growth_outside_b = fee_growth_global_b;
                tick.reward_growths_outside = reward_infos;
            };
            tick.initialized = true;
        };

        tick.liquidity_gross = liquidity_gross_after;

        // when the lower (upper) tick is crossed left to right (right to left), liquidity must be added (removed)
        tick.liquidity_net = if (is_upper) {
            i128::sub(tick.liquidity_net, liquidity_delta)
        } else {
            i128::add(tick.liquidity_net, liquidity_delta)
        };

        flipped
    }

    public fun get_tick<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        index: I32
    ): &Tick {
        assert!(df::exists_(&pool.id, index), TickNotFound);
        let tick = df::borrow<I32, Tick>(&pool.id, index);

        tick
    }

    fun init_tick<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        index: I32,
        ctx: &mut TxContext,
    ): &mut Tick {
        let reward_growths_outside = vector::empty<u128>();
        let i = 0;
        while (i < NUM_REWARDS) {
            vector::push_back(&mut reward_growths_outside, 0);
            i = i + 1;
        };
        df::add(&mut pool.id, index, Tick {
            id: object::new(ctx),
            liquidity_gross: 0,
            liquidity_net: i128::zero(),
            fee_growth_outside_a: 0,
            fee_growth_outside_b: 0,
            reward_growths_outside: reward_growths_outside,
            initialized: false,
        });

        df::borrow_mut<I32, Tick>(&mut pool.id, index)
    }

    fun cross_tick<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: I32,
        fee_growth_global_a: u128,
        fee_growth_global_b: u128,
        reward_growth_global: &vector<u128>,
        dry_run: bool,
        ctx: &mut TxContext,
    ): I128 {
        let tick;
        if (!df::exists_(&pool.id, tick_index)) {
            tick = init_tick(pool, tick_index, ctx);
        } else {
            tick = df::borrow_mut<I32, Tick>(&mut pool.id, tick_index);
        };

        if (!dry_run) {
            tick.fee_growth_outside_a = math_u128::wrapping_sub(fee_growth_global_a, tick.fee_growth_outside_a);
            tick.fee_growth_outside_b = math_u128::wrapping_sub(fee_growth_global_b, tick.fee_growth_outside_b);

            let i = 0;
            let len = vector::length(reward_growth_global);
            while (i < len) {
                let reward_new = vector::borrow(reward_growth_global, i);
                let reward = vector::borrow_mut(&mut tick.reward_growths_outside, i);
                *reward = math_u128::wrapping_sub(*reward_new, *reward);
                i = i + 1;
            };
        };

        tick.liquidity_net
    }

    fun clear_tick<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: I32,
        _ctx: &mut TxContext,
    ) {
        let tick = df::borrow_mut<I32, Tick>(&mut pool.id, tick_index);
        tick.liquidity_gross = 0;
        tick.liquidity_net = i128::zero();
        tick.fee_growth_outside_a = 0;
        tick.fee_growth_outside_b = 0;
        tick.initialized = false;
    }

    fun flip_tick<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: I32,
        _ctx: &mut TxContext,
    ) {
        // ensure that the tick is spaced
        assert!(i32::eq(i32::mod_euclidean(tick_index, pool.tick_spacing), i32::zero()), EInvildTickIndex);
        let next = i32::div(tick_index, i32::from(pool.tick_spacing));
        let (word_pos, bit_pos) = position_tick(next);
        let mask: u256 = 1u256 << bit_pos;
        try_init_tick_word(pool, word_pos);
        let word = get_tick_word_mut(pool, word_pos);
        *word = *word^mask;
    }

    fun next_fee_growth_inside<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_lower_index: I32,
        tick_upper_index: I32,
        tick_current_index: I32,
        _ctx: &mut TxContext,
    ): (u128, u128) {
        let tick_lower = get_tick(pool, tick_lower_index);
        let tick_upper = get_tick(pool, tick_upper_index);
        // calculate fee growth below
        let fee_growth_below_a;
        let fee_growth_below_b;
        if (!tick_lower.initialized) {
            fee_growth_below_a = pool.fee_growth_global_a;
            fee_growth_below_b = pool.fee_growth_global_b;
        } else if (i32::gte(tick_current_index, tick_lower_index)) {
            fee_growth_below_a = tick_lower.fee_growth_outside_a;
            fee_growth_below_b = tick_lower.fee_growth_outside_b;
        } else {
            fee_growth_below_a = math_u128::wrapping_sub(pool.fee_growth_global_a, tick_lower.fee_growth_outside_a);
            fee_growth_below_b = math_u128::wrapping_sub(pool.fee_growth_global_b, tick_lower.fee_growth_outside_b);
        };

        // calculate fee growth above
        let fee_growth_above_a;
        let fee_growth_above_b;
        if (!tick_upper.initialized) {
            fee_growth_above_a = 0;
            fee_growth_above_b = 0;
        } else if (i32::lt(tick_current_index, tick_upper_index)) {
            fee_growth_above_a = tick_upper.fee_growth_outside_a;
            fee_growth_above_b = tick_upper.fee_growth_outside_b;
        } else {
            fee_growth_above_a = math_u128::wrapping_sub(pool.fee_growth_global_a, tick_upper.fee_growth_outside_a);
            fee_growth_above_b = math_u128::wrapping_sub(pool.fee_growth_global_b, tick_upper.fee_growth_outside_b);
        };

        let fee_growth_inside_a = math_u128::wrapping_sub(
            math_u128::wrapping_sub(pool.fee_growth_global_a, fee_growth_below_a), fee_growth_above_a
        );
        let fee_growth_inside_b = math_u128::wrapping_sub(
            math_u128::wrapping_sub(pool.fee_growth_global_b, fee_growth_below_b), fee_growth_above_b
        );

        (fee_growth_inside_a, fee_growth_inside_b)
    }

    fun next_reward_growths_inside<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_lower_index: I32,
        tick_upper_index: I32,
        tick_current_index: I32,
        _ctx: &mut TxContext,
    ): vector<u128> {
        let reward_growths_inside = vector::empty();
        let tick_lower = get_tick(pool, tick_lower_index);
        let tick_upper = get_tick(pool, tick_upper_index);

        let i = 0;
        let len = vector::length(&pool.reward_infos);
        while (i < len) {
            let reward_info = vector::borrow(&pool.reward_infos, i);
            let reward_growths_outside_lower = *vector::borrow(&tick_lower.reward_growths_outside, i);
            let reward_growths_outside_upper = *vector::borrow(&tick_upper.reward_growths_outside, i);

            // calculate reword growth below
            let reward_growth_below;
            if (!tick_lower.initialized) {
                reward_growth_below = reward_info.growth_global;
            } else if (i32::gte(tick_current_index, tick_lower_index)) {
                reward_growth_below = reward_growths_outside_lower;
            } else {
                reward_growth_below = math_u128::wrapping_sub(reward_info.growth_global, reward_growths_outside_lower);
            };

            // calculate reword growth above
            let reward_growth_above;
            if (!tick_upper.initialized) {
                reward_growth_above = 0;
            } else if (i32::lt(tick_current_index, tick_upper_index)) {
                reward_growth_above = reward_growths_outside_upper;
            } else {
                reward_growth_above = math_u128::wrapping_sub(reward_info.growth_global, reward_growths_outside_upper);
            };

            vector::insert(
                &mut reward_growths_inside,
                math_u128::wrapping_sub(
                    math_u128::wrapping_sub(reward_info.growth_global, reward_growth_below), 
                    reward_growth_above
                ),
                i
            );
            i = i + 1;
        };

        reward_growths_inside
    }

    fun update_position_metadata<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        position_key: String,
        liquidity_delta: I128,
        fee_growth_inside_a: u128,
        fee_growth_inside_b: u128,
        reward_growths_inside: vector<u128>,
        _ctx: &mut TxContext,
    ) {
        let reward_infos_len = vector::length(&pool.reward_infos);
        let position = get_position_mut_by_key(pool, position_key);

        let liquidity_next;
        if (i128::eq(liquidity_delta, i128::zero())) {
            assert!(position.liquidity > 0, EForPokesZeroPosition); // disallow pokes for 0 liquidity positions
            liquidity_next = position.liquidity;
        } else {
            liquidity_next = math_liquidity::add_delta(position.liquidity, liquidity_delta);
        };

        // calculate accumulated fees
        let growth_delta_a = math_u128::wrapping_sub(fee_growth_inside_a, position.fee_growth_inside_a);
        let tokens_owed_a = (full_math_u128::mul_div_floor(growth_delta_a, position.liquidity, Q64) as u64);

        let growth_delta_b = math_u128::wrapping_sub(fee_growth_inside_b, position.fee_growth_inside_b);
        let tokens_owed_b = (full_math_u128::mul_div_floor(growth_delta_b, position.liquidity, Q64) as u64);

        position.fee_growth_inside_a = fee_growth_inside_a;
        position.fee_growth_inside_b = fee_growth_inside_b;
        if (tokens_owed_a > 0 || tokens_owed_b > 0) {
            // overflow is acceptable, have to withdraw before you hit type(uint128).max fees
            position.tokens_owed_a = math_u64::wrapping_add(position.tokens_owed_a, tokens_owed_a);
            position.tokens_owed_b = math_u64::wrapping_add(position.tokens_owed_b, tokens_owed_b);
        };

        let i = 0;
        while (i < reward_infos_len) {
            let reward_growth_inside = *vector::borrow(&reward_growths_inside, i);
            let curr_reward_info = vector::borrow_mut(&mut position.reward_infos, i);

            let reward_growth_delta = math_u128::wrapping_sub(reward_growth_inside, curr_reward_info.reward_growth_inside); 
            let amount_owed_delta = (full_math_u128::mul_div_floor(reward_growth_delta, position.liquidity, Q64) as u64);
            curr_reward_info.reward_growth_inside = reward_growth_inside;
            curr_reward_info.amount_owed = math_u64::wrapping_add(curr_reward_info.amount_owed, amount_owed_delta);

            i = i + 1;
        };

        // update the position
        if (!i128::eq(liquidity_delta, i128::zero())) {
            position.liquidity = liquidity_next;
        };
    }

    public fun get_position<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): &Position {
        let key = get_position_key_fix(pool, owner, tick_lower_index, tick_upper_index);
        get_position_by_key(pool, key)
    }

    public fun check_position_exists<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): bool {
        let key = get_position_key_fix(pool, owner, tick_lower_index, tick_upper_index);
        return dof::exists_(&pool.id, key)
    }

    public fun check_position_exists_old<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): bool {
        let key = get_position_key_old(owner, tick_lower_index, tick_upper_index);
        return dof::exists_(&pool.id, key)
    }

    fun get_position_mut<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): &mut Position {
        let key = get_position_key_fix(pool, owner, tick_lower_index, tick_upper_index);
        get_position_mut_by_key(pool, key)
    }

    fun get_position_by_key<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        key: String
    ): &Position {
        dof::borrow<String, Position>(&pool.id, key)
    }

    fun get_position_mut_by_key<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        key: String
    ): &mut Position {
        dof::borrow_mut<String, Position>(&mut pool.id, key)
    }

    public(friend) fun fetch_ticks<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        start_index: I32,
        limit: u64,
    ): (vector<TickInfo>, Option<I32>) {
        assert!(i32::gte(start_index, i32::neg_from(MAX_TICK_INDEX)), EInvildTick);
        assert!(i32::lte(start_index, i32::from(MAX_TICK_INDEX)), EInvildTick);

        let tick_end_index = i32::from_u32(MAX_TICK_INDEX);
        //let tick_spacing = pool.tick_spacing;
        //start_index = i32::mul(i32::from(tick_spacing), i32::div(start_index, i32::from(tick_spacing)));

        let ticks = vector::empty<TickInfo>();
        let current_tick = start_index;
        let i = 0;
        while (i32::lt(current_tick, tick_end_index) && i < limit) {
            let (next_tick, initialized) = next_initialized_tick_within_one_word(pool, current_tick, false);

            if (initialized) {
                let tick_ref = df::borrow<I32, Tick>(&pool.id, next_tick);
                vector::push_back(&mut ticks, TickInfo {
                    id: object::id(tick_ref),
                    tick_index: next_tick,
                    liquidity_gross: tick_ref.liquidity_gross,
                    liquidity_net: tick_ref.liquidity_net,
                    fee_growth_outside_a: tick_ref.fee_growth_outside_a,
                    fee_growth_outside_b: tick_ref.fee_growth_outside_b,
                    reward_growths_outside: tick_ref.reward_growths_outside,
                    initialized: tick_ref.initialized,
                });
            };
            i = i + 1;
            current_tick = next_tick;
        };
        if (i32::lt(current_tick, tick_end_index) && i >= limit) {
            (ticks, option::some(current_tick))
        } else {
            (ticks, option::none())
        }
    }

    public fun get_position_key_fix<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): String {
        let old_key =  string_tools::get_position_key_old(
            owner, 
            i32::abs_u32(tick_lower_index),
            i32::is_neg(tick_lower_index),
            i32::abs_u32(tick_upper_index),
            i32::is_neg(tick_upper_index)
        );
        if (dof::exists_(&pool.id, old_key)) {
            return old_key
        };
        return string_tools::get_position_key(
            owner, 
            i32::abs_u32(tick_lower_index),
            i32::is_neg(tick_lower_index),
            i32::abs_u32(tick_upper_index),
            i32::is_neg(tick_upper_index)
        )
    }

    public fun get_position_key(
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): String {
        string_tools::get_position_key(
            owner, 
            i32::abs_u32(tick_lower_index),
            i32::is_neg(tick_lower_index),
            i32::abs_u32(tick_upper_index),
            i32::is_neg(tick_upper_index)
        )
    }

    public fun get_position_key_old(
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): String {
        string_tools::get_position_key_old(
            owner, 
            i32::abs_u32(tick_lower_index),
            i32::is_neg(tick_lower_index),
            i32::abs_u32(tick_upper_index),
            i32::is_neg(tick_upper_index)
        )
    }

    public fun get_pool_fee<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): u32 {
        pool.fee
    }

    public fun get_pool_unlocked<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): bool {
        pool.unlocked
    }

    public fun get_pool_sqrt_price<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): u128 {
        pool.sqrt_price
    }

    public fun get_pool_tick_spacing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): u32 {
        pool.tick_spacing
    }

    public fun get_pool_current_index<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): I32 {
        pool.tick_current_index
    }

    public fun get_pool_liquidity<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): u128 {
        pool.liquidity
    }

    public fun get_tick_liquidity_gross(
        tick: &Tick,
    ): u128 {
        tick.liquidity_gross
    }

    public fun get_tick_liquidity_net(
        tick: &Tick,
    ): I128 {
        tick.liquidity_net
    }

    public fun get_tick_initialized(
        tick: &Tick,
    ): bool {
        tick.initialized
    }

    public fun get_tick_fee_growth_outside(
        tick: &Tick,
    ): (u128, u128) {
        (tick.fee_growth_outside_a, tick.fee_growth_outside_b)
    }

    public fun get_tick_reward_growths_outside(
        tick: &Tick,
    ): vector<u128> {
        tick.reward_growths_outside
    }

    public fun get_pool_fee_growth_global<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): (u128, u128) {
        (pool.fee_growth_global_a, pool.fee_growth_global_b)
    }

    public fun get_pool_reward_last_updated_time_ms<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): u64 {
        pool.reward_last_updated_time_ms
    }
    
    public fun get_position_fee_growth_inside_a<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        key: String
    ): u128 {
        let position = get_position_by_key(pool, key);
        position.fee_growth_inside_a
    }

    public fun get_position_base_info<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        key: String
    ): (u128, u128, u128, u64, u64, &vector<PositionRewardInfo>) {
        let position = get_position_by_key(pool, key);
        (
            position.liquidity,
            position.fee_growth_inside_a,
            position.fee_growth_inside_b,
            position.tokens_owed_a,
            position.tokens_owed_b,
            &position.reward_infos
        )
    }

    public fun get_position_reward_infos<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        key: String
    ): &vector<PositionRewardInfo> {
        let position = get_position_by_key(pool, key);

        &position.reward_infos
    }

    public fun get_position_reward_info(
        reward_info: &PositionRewardInfo
    ): (u128, u64) {
        (reward_info.reward_growth_inside, reward_info.amount_owed)
    }

    public fun get_position_fee_growth_inside_b<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        key: String
    ): u128 {
        let position = get_position_by_key(pool, key);
        position.fee_growth_inside_b
    }

    public fun get_flash_swap_receipt_info<CoinTypeA, CoinTypeB>(
        flash_swap_receipt: &FlashSwapReceipt<CoinTypeA, CoinTypeB>
    ): (ID, bool, u64) {
        (flash_swap_receipt.pool_id, flash_swap_receipt.a_to_b, flash_swap_receipt.pay_amount)
    }

    public(friend) fun merge_coin<CoinType>(
        coins: vector<Coin<CoinType>>, 
    ): Coin<CoinType> {
        assert!(vector::length(&coins) > 0, EInvildCoins);
        let self = vector::pop_back(&mut coins);
        pay::join_vec(&mut self, coins);
        
        self
    }

    public(friend) fun transfer_in<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coin_a: Coin<CoinTypeA>, 
        coin_b: Coin<CoinTypeB>, 
    ) {
        balance::join(&mut pool.coin_a, coin::into_balance(coin_a));
        balance::join(&mut pool.coin_b, coin::into_balance(coin_b));
    }

    /// deprecated
    public(friend) fun transfer_out<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        amount_a: u64, 
        amount_b: u64, 
        recipient: address,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public(friend) fun split_out_and_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        amount_a: u64, 
        amount_b: u64, 
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        let amount_out_balance_a = balance::split(&mut pool.coin_a, amount_a);
        let amount_out_coin_a = coin::from_balance(amount_out_balance_a, ctx);

        let amount_out_balance_b = balance::split(&mut pool.coin_b, amount_b);
        let amount_out_coin_b = coin::from_balance(amount_out_balance_b, ctx);
        
        (amount_out_coin_a, amount_out_coin_b)
    }

    /// deprecated
    public(friend) fun split_and_transfer<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>, 
        coin_a: Coin<CoinTypeA>, 
        amount_a: u64,
        coin_b: Coin<CoinTypeB>, 
        amount_b: u64,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public(friend) fun split_and_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>, 
        coin_a: Coin<CoinTypeA>, 
        amount_a: u64,
        coin_b: Coin<CoinTypeB>, 
        amount_b: u64,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        let left_a = coin::split(&mut coin_a, amount_a, ctx);

        let left_b = coin::split(&mut coin_b, amount_b, ctx);

        transfer_in(pool, left_a, left_b);

        (coin_a, coin_b)
    }

    /// deprecated
    public(friend) fun swap_coin_a_b<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>, 
        coin_a: Coin<CoinTypeA>, 
        amount_in: u64,
        amount_out: u64, 
        recipient: address,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public(friend) fun swap_coin_a_b_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>, 
        coin_a: Coin<CoinTypeA>, 
        amount_in: u64,
        amount_out: u64, 
        ctx: &mut TxContext
    ): (Coin<CoinTypeB>, Coin<CoinTypeA>) {
        //transfer a in pool_a
        let coin_in = coin::split(&mut coin_a, amount_in, ctx);
        balance::join(&mut pool.coin_a, coin::into_balance(coin_in));

        let out_balance = balance::split(&mut pool.coin_b, amount_out);
        let out_coin = coin::from_balance(out_balance, ctx);

        (out_coin, coin_a)
    }

    /// deprecated
    public(friend) fun swap_coin_b_a<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>, 
        coin_b: Coin<CoinTypeB>, 
        amount_in: u64,
        amount_out: u64, 
        recipient: address,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public(friend) fun swap_coin_b_a_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>, 
        coin_b: Coin<CoinTypeB>, 
        amount_in: u64,
        amount_out: u64, 
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        //transfer a in pool_a
        let coin_in = coin::split(&mut coin_b, amount_in, ctx);
        balance::join(&mut pool.coin_b, coin::into_balance(coin_in));

        let out_balance = balance::split(&mut pool.coin_a, amount_out);
        let out_coin = coin::from_balance(out_balance, ctx);

        (out_coin, coin_b)
    }

    /// deprecated
    public(friend) fun swap_coin_a_b_b_c<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
        coin_a: Coin<CoinTypeA>, 
        amount_in: u64,
        amount_mid: u64,
        amount_out: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

     /// swap: a=>c, pool_a: (a,b), pool_b:(b,c)
    public(friend) fun swap_coin_a_b_b_c_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
        coin_a: Coin<CoinTypeA>, 
        amount_in: u64,
        amount_mid: u64,
        amount_out: u64,
        ctx: &mut TxContext
    ): (Coin<CoinTypeC>, Coin<CoinTypeA>) {
        //transfer a in pool_a
        let coin_in = coin::split(&mut coin_a, amount_in, ctx);
        balance::join(&mut pool_a.coin_a, coin::into_balance(coin_in));

        //transer b from pool_a to pool_b
        let balance_mid = balance::split(&mut pool_a.coin_b, amount_mid);
        let coin_mid = coin::from_balance(balance_mid, ctx);
        balance::join(&mut pool_b.coin_a, coin::into_balance(coin_mid));

        let balance_out = balance::split(&mut pool_b.coin_b, amount_out);
        let coin_out = coin::from_balance(balance_out, ctx);

        (coin_out, coin_a)
    }

    /// deprecated
    public(friend) fun swap_coin_a_b_c_b<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
        coin_a: Coin<CoinTypeA>, 
        amount_in: u64,
        amount_mid: u64,
        amount_out: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    /// swap: a=>c, pool_a: (a,b), pool_b:(c,b)
    public(friend) fun swap_coin_a_b_c_b_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
        coin_a: Coin<CoinTypeA>, 
        amount_in: u64,
        amount_mid: u64,
        amount_out: u64,
        ctx: &mut TxContext
    ): (Coin<CoinTypeC>, Coin<CoinTypeA>) {
        //transfer a in pool_a
        let coin_in = coin::split(&mut coin_a, amount_in, ctx);
        balance::join(&mut pool_a.coin_a, coin::into_balance(coin_in));

        //transer b from pool_a to pool_b
        let balance_mid = balance::split(&mut pool_a.coin_b, amount_mid);
        let coin_mid = coin::from_balance(balance_mid, ctx);
        balance::join(&mut pool_b.coin_b, coin::into_balance(coin_mid));

        let balance_out = balance::split(&mut pool_b.coin_a, amount_out);
        let coin_out = coin::from_balance(balance_out, ctx);

        (coin_out, coin_a)
    }

     /// deprecated
    public(friend) fun swap_coin_b_a_b_c<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
        coin_a: Coin<CoinTypeA>, 
        amount_in: u64,
        amount_mid: u64,
        amount_out: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
       abort(0)
    }

    /// swap: a=>c, pool_a: (b,a), pool_b:(b,c)
    public(friend) fun swap_coin_b_a_b_c_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
        coin_a: Coin<CoinTypeA>, 
        amount_in: u64,
        amount_mid: u64,
        amount_out: u64,
        ctx: &mut TxContext
    ): (Coin<CoinTypeC>, Coin<CoinTypeA>) {
        //transfer a in pool_a
        let coin_in = coin::split(&mut coin_a, amount_in, ctx);
        balance::join(&mut pool_a.coin_b, coin::into_balance(coin_in));

        //transer b from pool_a to pool_b
        let balance_mid = balance::split(&mut pool_a.coin_a, amount_mid);
        let coin_mid = coin::from_balance(balance_mid, ctx);
        balance::join(&mut pool_b.coin_a, coin::into_balance(coin_mid));

        let balance_out = balance::split(&mut pool_b.coin_b, amount_out);
        let coin_out = coin::from_balance(balance_out, ctx);
        
        (coin_out, coin_a)
    }

     /// deprecated
    public(friend) fun swap_coin_b_a_c_b<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
        coin_a: Coin<CoinTypeA>, 
        amount_in: u64,
        amount_mid: u64,
        amount_out: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    /// swap: a=>c, pool_a: (b,a), pool_b:(c,b)
    public(friend) fun swap_coin_b_a_c_b_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
        coin_a: Coin<CoinTypeA>, 
        amount_in: u64,
        amount_mid: u64,
        amount_out: u64,
        ctx: &mut TxContext
    ): (Coin<CoinTypeC>, Coin<CoinTypeA>) {
        //transfer a in pool_a
        let coin_in = coin::split(&mut coin_a, amount_in, ctx);
        balance::join(&mut pool_a.coin_b, coin::into_balance(coin_in));

        //transer b from pool_a to pool_b
        let balance_mid = balance::split(&mut pool_a.coin_a, amount_mid);
        let coin_mid = coin::from_balance(balance_mid, ctx);
        balance::join(&mut pool_b.coin_b, coin::into_balance(coin_mid));

        let balance_out = balance::split(&mut pool_b.coin_a, amount_out);
        let coin_out = coin::from_balance(balance_out, ctx);

        (coin_out, coin_a)
    }

    public fun get_pool_balance<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>, 
    ): (u64, u64) {
        (
            balance::value<CoinTypeA>(&pool.coin_a),
            balance::value<CoinTypeB>(&pool.coin_b),
        )
    }

    public(friend) fun migrate_position<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>, 
        old_key: String, 
        new_key: String,
        ctx: &mut TxContext
    ) {
        let old_position = get_position_by_key(pool, old_key);
        let reward_infos = vector::empty<PositionRewardInfo>();
        let reward_infos_old = &old_position.reward_infos;
        let i = 0;
        while (i < NUM_REWARDS) {
            let reward_info_old = vector::borrow<PositionRewardInfo>(reward_infos_old, i);
            vector::push_back(&mut reward_infos, PositionRewardInfo {
                reward_growth_inside: reward_info_old.reward_growth_inside,
                amount_owed: reward_info_old.amount_owed,
            });
            i = i + 1;
        };
        save_position(pool, new_key, Position {
            id: object::new(ctx),
            liquidity: old_position.liquidity,
            fee_growth_inside_a: old_position.fee_growth_inside_a,
            fee_growth_inside_b: old_position.fee_growth_inside_b,
            tokens_owed_a: old_position.tokens_owed_a,
            tokens_owed_b: old_position.tokens_owed_b,
            reward_infos: reward_infos,
        });
        clean_position(pool, old_key);

        event::emit(MigratePositionEvent {
            pool: object::id(pool),
            old_key: old_key,
            new_key: new_key,
        });
    }

    public(friend) fun modify_tick_reward<CoinTypeA, CoinTypeB, FeeType>(
        _pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        _tick_lower_index: I32,
        _tick_upper_index: I32,
    ) {
        abort(0)
    }

    public(friend) fun modify_tick<CoinTypeA, CoinTypeB, FeeType>(
        _pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        _tick_index: I32,
    ) {
        abort(0)
    }

    public(friend) fun modify_position_reward_inside<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_lower_index: I32,
        tick_upper_index: I32,
        owner: address,
        tick_reward_index: u64,
        value: u128,
    ) {
        let position = get_position_mut(pool, owner, tick_lower_index, tick_upper_index);
        let reward_infos = &mut position.reward_infos;
        let reward_info = vector::borrow_mut(reward_infos, tick_reward_index);
        reward_info.reward_growth_inside = value;
    }

    fun save_position<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        key: String,
        position: Position,
    ) {
        dof::add(&mut pool.id, key, position)
    }

    fun clean_position<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        key: String,
    ) {
        let position = get_position_mut_by_key(pool, key);
        let reward_infos = &mut position.reward_infos;
        let i = 0;
        while (i < NUM_REWARDS) {
            let reward_info = vector::borrow_mut<PositionRewardInfo>(reward_infos, i);
            reward_info.reward_growth_inside = 0;
            reward_info.amount_owed = 0;
            i = i + 1;
        };
        position.liquidity = 0;
        position.fee_growth_inside_a = 0;
        position.fee_growth_inside_b = 0;
        position.tokens_owed_a = 0;
        position.tokens_owed_b = 0;
    }

    #[test_only]
    public fun get_pool_tick_current_index<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
    ): I32 {
        pool.tick_current_index
    }

    #[test_only]
    public fun get_tick_info_tick_index(tick_info: &TickInfo): I32 {
        tick_info.tick_index
    }

    #[test_only]
    public fun get_tick_info_liquidity_gross(tick_info: &TickInfo): u128 {
        tick_info.liquidity_gross
    }

    #[test_only]
    public fun get_tick_info_liquidity_net(tick_info: &TickInfo): I128 {
        tick_info.liquidity_net
    }

    #[test_only]
    public fun get_pool_info<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>, 
    ): (u64, u64, u64, u64, u128, I32, u32, u128, u32, u32, u128, u128, u128) {
        (
            balance::value<CoinTypeA>(&pool.coin_a),
            balance::value<CoinTypeB>(&pool.coin_b),
            pool.protocol_fees_a,
            pool.protocol_fees_b,
            pool.sqrt_price,
            pool.tick_current_index,
            pool.tick_spacing,
            pool.max_liquidity_per_tick,
            pool.fee,
            pool.fee_protocol,
            pool.fee_growth_global_a,
            pool.fee_growth_global_b,
            pool.liquidity
        )
    }

    #[test_only]
    public fun get_pool_fee_protocol<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>, 
    ): u32 {
        pool.fee_protocol
    }

    #[test_only]
    public fun get_tick_info<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: I32,
    ): (u128, I128, u128, u128, bool) {
        if (!df::exists_(&pool.id, tick_index)) return (0, i128::zero(), 0, 0, false);

        let tick = get_tick(pool, tick_index);
        (
            tick.liquidity_gross,
            tick.liquidity_net,
            tick.fee_growth_outside_a,
            tick.fee_growth_outside_b,
            tick.initialized
        )
    }

    #[test_only]
    public fun get_position_info<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
    ): (u128, u128, u128, u64, u64) {
        let position = get_position(pool, owner, tick_lower_index, tick_upper_index);
        (
            position.liquidity,
            position.fee_growth_inside_a,
            position.fee_growth_inside_b,
            position.tokens_owed_a,
            position.tokens_owed_b
        )
    }

    #[test_only]
    public fun tick_is_initialized<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: I32
    ): bool {
        let (next_index, initialized) = next_initialized_tick_within_one_word(
            pool,
            tick_index,
            true
        );
        if (i32::eq(next_index, tick_index)) initialized else false
    }

    #[test_only]
    public fun next_initialized_tick_within_one_word_for_testing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_current_index: I32,
        lte: bool
    ): (I32, bool) {
        next_initialized_tick_within_one_word(pool, tick_current_index, lte)
    }

    #[test_only]
    public fun flip_tick_for_testing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: I32,
        ctx: &mut TxContext,
    ) {
        flip_tick(pool, tick_index, ctx)
    }

    #[test_only]
    public fun collect_for_testing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        recipient: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        amount_a_requested: u64,
        amount_b_requested: u64,
        ctx: &mut TxContext
    ): (u64, u64) {
        collect_v2(
            pool, 
            recipient,
            recipient,
            tick_lower_index, 
            tick_upper_index, 
            amount_a_requested, 
            amount_b_requested, 
        ctx)
    }

    #[test_only]
    public fun mint_for_testing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: u128,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, u64) {
        mint(
            pool,
            owner,
            tick_lower_index,
            tick_upper_index,
            liquidity_delta,
            clock,
            ctx
        )
    }

    #[test_only]
    public fun burn_for_testing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        owner: address,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity_delta: u128,
        clock: &Clock,
        ctx: &mut TxContext
    ): (u64, u64) {
        burn(
            pool,
            owner,
            tick_lower_index,
            tick_upper_index,
            liquidity_delta,
            clock,
            ctx
        )
    }

    #[test_only]
    public fun swap_for_testing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        recipient: address,
        a_to_b: bool,
        amount_specified: u128,
        is_exact_input: bool,
        sqrt_price_limit: u128,
        clock: &Clock,
        ctx: &mut TxContext
    ): (u128, u128) {
        swap(
            pool,
            recipient,
            a_to_b,
            amount_specified,
            is_exact_input,
            sqrt_price_limit,
            clock,
            ctx
        )
    }

    #[test_only]
    public fun get_reward_info<CoinTypeA, CoinTypeB, FeeType>(
        pool: &Pool<CoinTypeA, CoinTypeB, FeeType>,
        reward_index: u64,
    ): (address, u128, u128, address) {
        let reward_info = vector::borrow(&pool.reward_infos, reward_index);
        (reward_info.vault, reward_info.emissions_per_second, reward_info.growth_global, reward_info.manager)
    }

    #[test_only]
    public fun get_reward_vault<RewardCoin>(
        vault: &PoolRewardVault<RewardCoin>,
    ): &Balance<RewardCoin> {
       &vault.coin
    }

    #[test_only]
    public fun next_pool_reward_infos_for_testing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        clock: &Clock,
    ) :vector<u128> {
        next_pool_reward_infos(pool, clock::timestamp_ms(clock))
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}