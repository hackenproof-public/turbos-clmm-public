// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::fee2500bps {
    use sui::transfer;
    use sui::tx_context::{TxContext};
    use turbos_clmm::fee::{Self};

    struct FEE2500BPS has drop {}
    
    fun init(witness: FEE2500BPS, ctx: &mut TxContext) {
        let fee = fee::create_fee(
            witness,
            2500,
            50,
            ctx
        );

        transfer::public_freeze_object(fee);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(FEE2500BPS{}, ctx);
    }

}