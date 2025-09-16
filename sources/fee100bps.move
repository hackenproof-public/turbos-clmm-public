// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::fee100bps {
    use sui::transfer;
    use sui::tx_context::{TxContext};
    use turbos_clmm::fee::{Self};

    struct FEE100BPS has drop {}
    
    fun init(witness: FEE100BPS, ctx: &mut TxContext) {
        let fee = fee::create_fee(
            witness,
            100,
            2,
            ctx
        );

        transfer::public_freeze_object(fee);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(FEE100BPS{}, ctx);
    }
}