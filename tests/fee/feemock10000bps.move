// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::feemock10000bps {
    use sui::transfer;
    use sui::tx_context::{TxContext};
    use turbos_clmm::fee::{Self};

    struct FEEMOCK10000BPS has drop {}
    
    fun init(witness: FEEMOCK10000BPS, ctx: &mut TxContext) {
        let fee = fee::create_fee(
            witness,
            10000,
            1,
            ctx
        );

        transfer::public_freeze_object(fee);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(FEEMOCK10000BPS{}, ctx);
    }

}