// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::pool_fetcher {
    use std::vector;
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Clock};
    use turbos_clmm::pool::{Self, Pool, ComputeSwapState, Versioned, TickInfo};
    use turbos_clmm::i32::{Self, I32};
    use sui::event;
    use std::option::{Option};

    struct FetchTicksResultEvent has copy, drop {
        ticks: vector<TickInfo>,
        next_cursor: Option<I32>,
    }

    public entry fun compute_swap_result<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        a_to_b: bool,
        amount_specified: u128,
        amount_specified_is_input: bool,
        sqrt_price_limit: u128,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext,
    ): ComputeSwapState {
        pool::check_version(versioned);
        let state = pool::compute_swap_result(
            pool,
            tx_context::sender(ctx),
            a_to_b,
            amount_specified,
            amount_specified_is_input,
            sqrt_price_limit,
            true,
            0,
            clock,
            ctx,
        );
        pool::convert_state_v2_to_v1(&state)
    }

    public entry fun fetch_ticks<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        start: vector<u32>,
        start_index_is_neg: bool,
        limit: u64,
        versioned: &Versioned,
    ) {
        pool::check_version(versioned);
        let start_index= if (vector::is_empty(&start)) {
            i32::neg_from(443636)
        } else {
            i32::from_u32_neg(*vector::borrow(&start, 0), start_index_is_neg)
        };
        let (ticks, next_cursor) = pool::fetch_ticks(pool, start_index, limit);
        event::emit(FetchTicksResultEvent { ticks: ticks, next_cursor });
    }

    #[test_only]
    public fun fetch_ticks_for_testing<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        start: vector<u32>,
        start_index_is_neg: bool,
        limit: u64,
        versioned: &Versioned,
    ): (vector<TickInfo>, Option<I32>) {
        pool::check_version(versioned);
        let start_index= if (vector::is_empty(&start)) {
            i32::neg_from(443636)
        } else {
            i32::from_u32_neg(*vector::borrow(&start, 0), start_index_is_neg)
        };
        pool::fetch_ticks(pool, start_index, limit)
    }
}