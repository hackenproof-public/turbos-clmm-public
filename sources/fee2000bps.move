// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::fee2000bps {
    use sui::transfer;
    use sui::tx_context::{TxContext};
    use turbos_clmm::fee::{Self};

    struct FEE2000BPS has drop {}
    
    fun init(witness: FEE2000BPS, ctx: &mut TxContext) {
        let fee = fee::create_fee(
            witness,
            2000,
            40,
            ctx
        );

        transfer::public_freeze_object(fee);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(FEE2000BPS{}, ctx);
    }

}