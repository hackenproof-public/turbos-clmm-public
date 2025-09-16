// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

/// Coin<USDC> is the mock token used to test in Turbos.
/// It has 9 decimals
module turbos_token::usdc {
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self};
    use std::option;

    struct USDC has drop {}

    fun init(witness: USDC, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 9, b"TurbosTestUsdc", b"USDC", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(USDC{}, ctx);
    }
}
