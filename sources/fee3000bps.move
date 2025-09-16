// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::fee3000bps {
    use sui::transfer;
    use sui::tx_context::{TxContext};
    use turbos_clmm::fee::{Self};

    struct FEE3000BPS has drop {}
    
    fun init(witness: FEE3000BPS, ctx: &mut TxContext) {
        let fee = fee::create_fee(
            witness,
            3000,
            60,
            ctx
        );

        transfer::public_freeze_object(fee);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(FEE3000BPS{}, ctx);
    }

}