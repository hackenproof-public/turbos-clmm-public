// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

/// Coin<TURBOS> is the token of turbos.finance
/// It has 9 decimals
module turbos_token::turbos {
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self};
    use std::option;
    use sui::url::{Self};

    struct TURBOS has drop {}

    fun init(witness: TURBOS, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness, 
            9, 
            b"TURBOS",  // symbols
            b"Turbos",  // name
            b"Turbos Finance Token", // description
            option::some(url::new_unsafe_from_bytes(b"https://ipfs.io/ipfs/QmbfGQugNb5Te96jVmR21kiKNcmD4k1ntXgyKbFTXioihQ?filename=turbostoken.svg")), 
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    public entry fun transfer(c: coin::Coin<TURBOS>, recipient: address) {
        transfer::public_transfer(c, recipient)
    }
}
