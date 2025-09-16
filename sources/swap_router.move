// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::swap_router {
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use turbos_clmm::partner::{Self, Partner};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};

    const ETransactionTooOld: u64 = 2;
    const EAmountOutBelowMinimum: u64 = 4; 
    const EAmountInAboveMaximum: u64 = 5; 
    const ETwoStepSwapLackOfLiquidity: u64 = 6; 
    const ECoinsNotGatherThanAmount: u64 = 7; 
    
    public entry fun swap_a_b<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_b_out, coin_a_left) = swap_a_b_with_return_(
            pool,
            coins_a,
            amount,
            amount_threshold,
            sqrt_price_limit,
            is_exact_in,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );
        transfer::public_transfer(coin_b_out, recipient);

        if (coin::value(&coin_a_left) == 0) {
            coin::destroy_zero(coin_a_left);
        } else {
            transfer::public_transfer(
                coin_a_left,
                tx_context::sender(ctx)
            );
        };
    }

    public fun swap_a_b_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeB>, Coin<CoinTypeA>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionTooOld);
        let coin_a =pool::merge_coin(coins_a);
        if (is_exact_in) {
            assert!(coin::value(&coin_a) >= amount, ECoinsNotGatherThanAmount);
        };
        let (amount_a, amount_b) = pool::swap(
            pool,
            recipient,
            true,
            (amount as u128),
            is_exact_in,
            sqrt_price_limit,
            clock,
            ctx
        );
        let amount_a_64 = (amount_a as u64);
        let amount_b_64 = (amount_b as u64);
        check_amount_threshold(is_exact_in, true, amount_a_64, amount_b_64, amount_threshold);
        if (!is_exact_in) {
            assert!(coin::value(&coin_a) >= amount_a_64, ECoinsNotGatherThanAmount);
        };
        pool::swap_coin_a_b_with_return_(
            pool,
            coin_a,
            amount_a_64,
            amount_b_64,
            ctx
        )
    }

    public fun swap_with_partner<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        partner: &mut Partner,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        a_to_b: bool,
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionTooOld);
        let (coin_a_return, coin_b_return, receipt) = pool::flash_swap_partner(
            pool,
            partner,
            a_to_b,
            (amount as u128),
            is_exact_in,
            sqrt_price_limit,
            clock,
            versioned,
            ctx
        );

        let pay_amount = pool::flash_swap_pay_amount<CoinTypeA, CoinTypeB>(&receipt);
        let receive_amount = if (a_to_b) {
            coin::value(&coin_b_return)
        } else {
            coin::value(&coin_a_return)
        };
        if (is_exact_in) {
            assert!(pay_amount == amount, ECoinsNotGatherThanAmount);
            assert!(receive_amount >= amount_threshold, EAmountOutBelowMinimum);
        } else {
            assert!(receive_amount == amount, ECoinsNotGatherThanAmount);
            assert!(pay_amount <= amount_threshold, EAmountInAboveMaximum);
        };

        let (repay_coin_a, repay_coin_b) = if (a_to_b) {
            (
                coin::split<CoinTypeA>(&mut coin_a, pay_amount, ctx),
                coin::zero<CoinTypeB>(ctx)
            )
        } else {
            (
                coin::zero<CoinTypeA>(ctx),
                coin::split<CoinTypeB>(&mut coin_b, pay_amount, ctx)
            )
        };
        coin::join<CoinTypeB>(&mut coin_b, coin_b_return);
        coin::join<CoinTypeA>(&mut coin_a, coin_a_return);
        pool::repay_flash_swap_partner<CoinTypeA, CoinTypeB, FeeType>(pool, partner, repay_coin_a, repay_coin_b, receipt, versioned);
        (coin_a, coin_b)
    }

    public fun swap_a_b_with_partner<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        partner: &mut Partner,
        coin_a: Coin<CoinTypeA>,
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        swap_with_partner(
            pool,
            partner,
            coin_a,
            coin::zero(ctx),
            true,
            amount,
            amount_threshold,
            sqrt_price_limit,
            is_exact_in,
            deadline,
            clock,
            versioned,
            ctx,
        )
    }

    public fun swap_b_a_with_partner<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        partner: &mut Partner,
        coin_b: Coin<CoinTypeB>,
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        swap_with_partner(
            pool,
            partner,
            coin::zero(ctx),
            coin_b,
            false,
            amount,
            amount_threshold,
            sqrt_price_limit,
            is_exact_in,
            deadline,
            clock,
            versioned,
            ctx,
        )
    }

    public entry fun swap_b_a<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coins_b: vector<Coin<CoinTypeB>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_a_out, coin_b_left) = swap_b_a_with_return_(
            pool,
            coins_b,
            amount,
            amount_threshold,
            sqrt_price_limit,
            is_exact_in,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );
        transfer::public_transfer(coin_a_out, recipient);

        if (coin::value(&coin_b_left) == 0) {
            coin::destroy_zero(coin_b_left);
        } else {
            transfer::public_transfer(
                coin_b_left,
                tx_context::sender(ctx)
            );
        };
    }

    public fun swap_b_a_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        coins_b: vector<Coin<CoinTypeB>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionTooOld);
        let coin_b =pool::merge_coin(coins_b);
        if (is_exact_in) {
            assert!(coin::value(&coin_b) >= amount, ECoinsNotGatherThanAmount);
        };
        let (amount_a, amount_b) = pool::swap(
            pool,
            recipient,
            false,
            (amount as u128),
            is_exact_in,
            sqrt_price_limit,
            clock,
            ctx
        );
        let amount_a_64 = (amount_a as u64);
        let amount_b_64 = (amount_b as u64);
        check_amount_threshold(is_exact_in, false, amount_a_64, amount_b_64, amount_threshold);

        if (!is_exact_in) {
            assert!(coin::value(&coin_b) >= amount_b_64, ECoinsNotGatherThanAmount);
        };
        pool::swap_coin_b_a_with_return_(
            pool,
            coin_b,
            amount_b_64,
            amount_a_64,
            ctx
        )
    }

    fun check_amount_threshold(
        is_exact_in: bool,
        a_to_b: bool,
        amount_a: u64, 
        amount_b: u64, 
        amount_threshold: u64
    ) {
        if (is_exact_in) {
            if ((a_to_b && amount_threshold > amount_b)
                || (!a_to_b && amount_threshold > amount_a))
            {
                abort EAmountOutBelowMinimum
            }
        } else {
            if ((a_to_b && amount_threshold < amount_a)
                || (!a_to_b && amount_threshold < amount_b))
            {
                abort EAmountInAboveMaximum
            }
        }
    }

    // such as: pool a: BTC/USDC, pool b: USDC/ETH
    // if swap BTC to ETH,route is BTC -> USDC -> ETH,fee paid in BTC and USDC 
    // step one: swap BTC to USDC (a to b), step two: swap USDC to ETH (a to b)
    public entry fun swap_a_b_b_c<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_c_out, coin_a_left) = swap_a_b_b_c_with_return_(
            pool_a,
            pool_b,
            coins_a,
            amount,
            amount_threshold,
            sqrt_price_limit_one,
            sqrt_price_limit_two,
            is_exact_in,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );
        transfer::public_transfer(coin_c_out, recipient);

        if (coin::value(&coin_a_left) == 0) {
            coin::destroy_zero(coin_a_left);
        } else {
            transfer::public_transfer(
                coin_a_left,
                tx_context::sender(ctx)
            );
        };
    }

    public fun swap_a_b_b_c_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeC>, Coin<CoinTypeA>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionTooOld);
        let coin_a =pool::merge_coin(coins_a);
        if (is_exact_in) {
            assert!(coin::value(&coin_a) >= amount, ECoinsNotGatherThanAmount);
        };

        let (amount_a_64, amount_b_64, amount_c_64);

        let a_to_b_step_one = true;
        let a_to_b_step_two = true;
        if (is_exact_in) {
            let (step1_in, step1_out) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );

            let (step2_in, step2_out) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                step1_out,
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold <= amount_c_64, EAmountOutBelowMinimum);
        } else {
            let (step2_in, step2_out) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );

            let (step1_in, step1_out) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                step2_in,
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold >= amount_a_64, EAmountInAboveMaximum);
        };

        if (!is_exact_in) {
            assert!(coin::value(&coin_a) >= amount_a_64, ECoinsNotGatherThanAmount);
        };

        pool::swap_coin_a_b_b_c_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
            pool_a,
            pool_b,
            coin_a,
            amount_a_64,
            amount_b_64,
            amount_c_64,
            ctx
        )
    }

    // such as: pool a: BTC/USDC, pool b: ETH/USDC
    // if swap BTC to ETH, route is BTC -> USDC -> ETH,fee paid in BTC and USDC 
    // step one: swap BTC to USDC (a to b), step two: swap USDC to ETH (b to a)
    public entry fun swap_a_b_c_b<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_c_out, coin_a_left) = swap_a_b_c_b_with_return_(
            pool_a,
            pool_b,
            coins_a,
            amount,
            amount_threshold,
            sqrt_price_limit_one,
            sqrt_price_limit_two,
            is_exact_in,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );
        transfer::public_transfer(coin_c_out, recipient);

        if (coin::value(&coin_a_left) == 0) {
            coin::destroy_zero(coin_a_left);
        } else {
            transfer::public_transfer(
                coin_a_left,
                tx_context::sender(ctx)
            );
        };
    }

     public fun swap_a_b_c_b_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeA, CoinTypeB, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeC>, Coin<CoinTypeA>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionTooOld);
        let coin_a =pool::merge_coin(coins_a);
        if (is_exact_in) {
            assert!(coin::value(&coin_a) >= amount, ECoinsNotGatherThanAmount);
        };

        let (amount_a_64, amount_b_64, amount_c_64);

        let a_to_b_step_one = true;
        let a_to_b_step_two = false;
        if (is_exact_in) {
            let (step1_in, step1_out) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );

            let (step2_out, step2_in) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                step1_out,
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold <= amount_c_64, EAmountOutBelowMinimum);
        } else {
            //b for c, exact out
            let (step2_out, step2_in) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );
            
            //a for b, exact out
            let (step1_in, step1_out) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                step2_in,
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold >= amount_a_64, EAmountInAboveMaximum);
        };

        if (!is_exact_in) {
            assert!(coin::value(&coin_a) >= amount_a_64, ECoinsNotGatherThanAmount);
        };
        pool::swap_coin_a_b_c_b_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
            pool_a,
            pool_b,
            coin_a,
            amount_a_64,
            amount_b_64,
            amount_c_64,
            ctx,
        )
    }

    // such as: pool a: USDC/BTC, pool b: USDC/ETH
    // if swap BTC to ETH, route is BTC -> USDC -> ETH, fee paid in BTC and USDC 
    // step one: swap BTC to USDC (b to a), step two: swap USDC to ETH (a to b)
    public entry fun swap_b_a_b_c<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_c_out, coin_a_left) = swap_b_a_b_c_with_return_(
            pool_a,
            pool_b,
            coins_a,
            amount,
            amount_threshold,
            sqrt_price_limit_one,
            sqrt_price_limit_two,
            is_exact_in,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );
        transfer::public_transfer(coin_c_out, recipient);

        if (coin::value(&coin_a_left) == 0) {
            coin::destroy_zero(coin_a_left);
        } else {
            transfer::public_transfer(
                coin_a_left,
                tx_context::sender(ctx)
            );
        }
    }

    public fun swap_b_a_b_c_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeB, CoinTypeC, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeC>, Coin<CoinTypeA>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionTooOld);
        let coin_a =pool::merge_coin(coins_a);
        if (is_exact_in) {
            assert!(coin::value(&coin_a) >= amount, ECoinsNotGatherThanAmount);
        };
        let (amount_a_64, amount_b_64, amount_c_64);

        let a_to_b_step_one = false;
        let a_to_b_step_two = true;
        if (is_exact_in) {
            let (step1_out, step1_in) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );

            let (step2_in, step2_out) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                step1_out,
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold <= amount_c_64, EAmountOutBelowMinimum);
        } else {
            let (step2_in, step2_out) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );

            let (step1_out, step1_in) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                step2_in,
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold >= amount_a_64, EAmountInAboveMaximum);

        };

        if (!is_exact_in) {
            assert!(coin::value(&coin_a) >= amount_a_64, ECoinsNotGatherThanAmount);
        };
        pool::swap_coin_b_a_b_c_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
            pool_a,
            pool_b,
            coin_a,
            amount_a_64,
            amount_b_64,
            amount_c_64,
            ctx
        )
    }

    // such as: pool a: USDC/BTC, pool b: ETH/USDC
    // if swap BTC to ETH, route is BTC -> USDC -> ETH, fee paid in BTC and USDC 
    // step one: swap BTC to USDC (b to a), step two: swap USDC to ETH (b to a)
    public entry fun swap_b_a_c_b<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        let (coin_c_out, coin_a_left) = swap_b_a_c_b_with_return_(
            pool_a,
            pool_b,
            coins_a,
            amount,
            amount_threshold,
            sqrt_price_limit_one,
            sqrt_price_limit_two,
            is_exact_in,
            recipient,
            deadline,
            clock,
            versioned,
            ctx,
        );
        transfer::public_transfer(coin_c_out, recipient);

        if (coin::value(&coin_a_left) == 0) {
            coin::destroy_zero(coin_a_left);
        } else {
            transfer::public_transfer(
                coin_a_left,
                tx_context::sender(ctx)
            );
        }
    }

     public fun swap_b_a_c_b_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
        pool_a: &mut Pool<CoinTypeB, CoinTypeA, FeeTypeA>,
        pool_b: &mut Pool<CoinTypeC, CoinTypeB, FeeTypeB>,
        coins_a: vector<Coin<CoinTypeA>>, 
        amount: u64,
        amount_threshold: u64,
        sqrt_price_limit_one: u128,
        sqrt_price_limit_two: u128,
        is_exact_in: bool,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeC>, Coin<CoinTypeA>) {
        pool::check_version(versioned);
        assert!(clock::timestamp_ms(clock) <= deadline, ETransactionTooOld);
        let coin_a =pool::merge_coin(coins_a);
        if (is_exact_in) {
            assert!(coin::value(&coin_a) >= amount, ECoinsNotGatherThanAmount);
        };
        let (amount_a_64, amount_b_64, amount_c_64);

        let a_to_b_step_one = false;
        let a_to_b_step_two = false;
        if (is_exact_in) {
            let (step1_out, step1_in) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );

            //b for c
            let (step2_out, step2_in) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                step1_out,
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold <= amount_c_64, EAmountOutBelowMinimum);
        } else {
            let (step2_out, step2_in) = pool::swap(
                pool_b,
                recipient,
                a_to_b_step_two,
                (amount as u128),
                is_exact_in,
                sqrt_price_limit_two,
                clock,
                ctx
            );

            let (step1_out, step1_in) = pool::swap(
                pool_a,
                recipient,
                a_to_b_step_one,
                step2_in,
                is_exact_in,
                sqrt_price_limit_one,
                clock,
                ctx
            );
            assert!(step1_out == step2_in, ETwoStepSwapLackOfLiquidity);

            amount_a_64 = (step1_in as u64);
            amount_b_64 = (step1_out as u64);
            amount_c_64 = (step2_out as u64);
            assert!(amount_threshold >= amount_a_64, EAmountInAboveMaximum);
        };

        if (!is_exact_in) {
            assert!(coin::value(&coin_a) >= amount_a_64, ECoinsNotGatherThanAmount);
        };

        pool::swap_coin_b_a_c_b_with_return_<CoinTypeA, FeeTypeA, CoinTypeB, FeeTypeB, CoinTypeC>(
            pool_a,
            pool_b,
            coin_a,
            amount_a_64,
            amount_b_64,
            amount_c_64,
            ctx
        )
    }
}