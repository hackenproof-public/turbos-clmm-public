// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::trb {
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self};
    use std::option;

    struct TRB has drop {}

    fun init(witness: TRB, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 9, b"TurbosTest", b"TRB", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(TRB{}, ctx);
    }
}