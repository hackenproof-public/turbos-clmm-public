// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::position_nft {
    use std::vector;
    use sui::transfer;
    use sui::url::{Self, Url};
    use std::string::{Self, utf8, String};
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::display;
    use sui::package;
    use sui::tx_context::{Self, TxContext};
    use std::type_name::{TypeName};

    friend turbos_clmm::position_manager;

    struct TurbosPositionNFT has key, store {
        id: UID,
        name: String,
        description: String,
        img_url: Url,
        pool_id: ID,
        position_id: ID,
        coin_type_a: TypeName,
        coin_type_b: TypeName,
        fee_type: TypeName,
    }

    struct POSITION_NFT has drop {}

    struct MintNFTEvent has copy, drop {
        object_id: ID,
        creator: address,
        name: String,
    }

    fun init(nft: POSITION_NFT, ctx: &mut TxContext) {
        let display_keys = vector::empty();
        vector::push_back(&mut display_keys, utf8(b"name"));
        vector::push_back(&mut display_keys, utf8(b"description"));
        vector::push_back(&mut display_keys, utf8(b"image_url"));
        vector::push_back(&mut display_keys, utf8(b"project_url"));
        vector::push_back(&mut display_keys, utf8(b"creator"));

        let display_values = vector::empty();
        vector::push_back(&mut display_values, utf8(b"{name}"));
        vector::push_back(&mut display_values, utf8(b"{description}"));
        vector::push_back(&mut display_values, utf8(b"{img_url}"));
        vector::push_back(&mut display_values, utf8(b"https://turbos.finance"));
        vector::push_back(&mut display_values, utf8(b"Turbos Team"));

        let publisher = package::claim(nft, ctx);
        let display = display::new<TurbosPositionNFT>(&publisher, ctx);

        display::add_multiple<TurbosPositionNFT>(&mut display, display_keys, display_values);
        display::update_version<TurbosPositionNFT>(&mut display);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
    }

    /// Create a new position_nft
    public(friend) fun mint(
        name: String,
        description: String,
        img_url: String,
        pool_id: ID,
        position_id: ID,
        coin_type_a: TypeName,
        coin_type_b: TypeName,
        fee_type: TypeName,
        ctx: &mut TxContext
    ): TurbosPositionNFT {
        let nft = TurbosPositionNFT {
            id: object::new(ctx),
            name: name,
            description: description,
            img_url: url::new_unsafe(string::to_ascii(img_url)),
            pool_id,
            position_id,
            coin_type_a,
            coin_type_b,
            fee_type,
        };
        let sender = tx_context::sender(ctx);
        // event::emit(MintNFTEvent {
        //     object_id: object::uid_to_inner(&nft.id),
        //     creator: sender,
        //     name: nft.name,
        // });

        nft
    }

    /// Permanently delete `nft`
    public(friend) fun burn(nft: TurbosPositionNFT) {
        let TurbosPositionNFT { 
            id, 
            name: _, 
            description: _, 
            img_url: _, 
            pool_id: _, 
            position_id: _,
            coin_type_a: _,
            coin_type_b: _,
            fee_type: _,
        } = nft;
        object::delete(id)
    }

    public fun pool_id(nft: &TurbosPositionNFT): ID {
        nft.pool_id
    }

    public fun position_id(nft: &TurbosPositionNFT): ID {
        nft.position_id
    }

}