// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::fee {

    use sui::object::{Self, UID};
    use sui::tx_context::{TxContext};

    const EBadWitness: u64 = 0;
    
    struct Fee<phantom T> has key, store {
        id: UID,
        fee: u32,
        tick_spacing: u32,
    }

    fun init(_ctx: &mut TxContext) {
    }

    public fun create_fee<T: drop>(
        witness: T,
        fee: u32,
        tick_spacing: u32,
        ctx: &mut TxContext
    ): Fee<T> {
        // Make sure there's only one instance of the type T
        assert!(sui::types::is_one_time_witness(&witness), EBadWitness);

        Fee {
            id: object::new(ctx),
            fee: fee,
            tick_spacing: tick_spacing,
        }
    }

    public fun get_fee<T>(self: &Fee<T>): u32 {
        self.fee
    }

    public fun get_tick_spacing<T>(self: &Fee<T>): u32 {
        self.tick_spacing
    }
}