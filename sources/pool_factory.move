// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

module turbos_clmm::pool_factory {
    use std::vector;
    use std::type_name::{Self, TypeName};
    use sui::event;
    use std::hash;
    use std::ascii;
    use sui::vec_map::{Self, VecMap};
    use sui::transfer;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Coin};
    use turbos_clmm::position_manager::{Self, Positions};
    use turbos_clmm::position_nft::{Self, TurbosPositionNFT};
    use turbos_clmm::fee::{Self, Fee};
    use sui::clock::{Clock};
    use turbos_clmm::pool::{Self, Pool, Versioned};
    use std::string::{Self, String};
    use sui::table::{Self, Table};
    use turbos_clmm::i32::{Self};
    use std::option::{Self, Option};
    use turbos_clmm::partner::{Self};
    use turbos_clmm::acl;
    
    const EFeeNotExists: u64 = 0;
    const EInvalidFee: u64 = 1;
    const EInvalidTicKSpacing: u64 = 2;
    const EFeeAlreadyExists: u64 = 3;
    const ERepeatedType: u64 = 4;
    const EPoolAlreadyExists: u64 = 5;
    const EInvalidClmmManagerRole: u64 = 6;
    const EInvalidRewardManagerRole: u64 = 7;
    const EInvalidClaimProtocolFeeRoleManager: u64 = 8;
    const EInvalidPausePoolManagerRole: u64 = 9;

    const ACL_CLMM_MANAGER: u8 = 0;
    const ACL_REWARD_MANAGER: u8 = 1;
    const ACL_CLAIM_PROTOCOL_FEE_MANAGER: u8 = 2;
    const ACL_PAUSE_POOL_MANAGER: u8 = 3;

    struct PoolFactoryAdminCap has key, store { id: UID }

    struct PoolSimpleInfo has copy, store {
        pool_id: ID,
        pool_key: ID,
        coin_type_a: TypeName,
        coin_type_b: TypeName,
        fee_type: TypeName,
        fee: u32,
        tick_spacing: u32,
    }

    struct PoolConfig has key, store {
        id: UID,
        fee_map: VecMap<String, ID>,
        fee_protocol: u32,
        pools: Table<ID, PoolSimpleInfo>,
    }

    struct AclConfig has key, store {
        id: UID,
        acl: acl::ACL,
    }

    struct PoolCreatedEvent has copy, drop {
        account: address,
        pool: ID,
        fee: u32,
        tick_spacing: u32,
        fee_protocol: u32,
        sqrt_price: u128,
    }

    struct FeeAmountEnabledEvent has copy, drop {
        fee: u32,
        tick_spacing: u32,
    }

    struct SetFeeProtocolEvent has copy, drop {
        fee_protocol: u32,
    }

    /// Emit when set roles
    struct SetRolesEvent has copy, drop {
        member: address,
        roles: u128,
    }

    /// Emit when add member a role
    struct AddRoleEvent has copy, drop {
        member: address,
        role: u8,
    }

    /// Emit when remove member a role
    struct RemoveRoleEvent has copy, drop {
        member: address,
        role: u8,
    }

    /// Emit remove member
    struct RemoveMemberEvent has copy, drop {
        member: address,
    }

    fun init(ctx: &mut TxContext) {
        init_(ctx);
    }

    fun init_(ctx: &mut TxContext) {
        let pool_config = PoolConfig {
            id: object::new(ctx), 
            fee_map: vec_map::empty(),
            fee_protocol: 0,
            pools: table::new(ctx),
        };

        transfer::share_object(pool_config);
        transfer::transfer(PoolFactoryAdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }

    public entry fun deploy_pool_and_mint<CoinTypeA, CoinTypeB, FeeType>(
        pool_config: &mut PoolConfig,
        feeType: &Fee<FeeType>,
        sqrt_price: u128,
        positions: &mut Positions,
        coins_a: vector<Coin<CoinTypeA>>,
        coins_b: vector<Coin<CoinTypeB>>,
        tick_lower_index: u32,
        tick_lower_index_is_neg: bool,
        tick_upper_index: u32,
        tick_upper_index_is_neg: bool,
        amount_a_desired: u64,
        amount_b_desired: u64,
        amount_a_min: u64,
        amount_b_min: u64,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);

        let coin_type_a = type_name::get<CoinTypeA>();
        let coin_type_b = type_name::get<CoinTypeB>();
        assert!(coin_type_a != coin_type_b, ERepeatedType);

        let fee_type = type_name::get<FeeType>();
        let fee_type_str = string::from_ascii(type_name::into_string(fee_type));
        assert!(vec_map::contains(&pool_config.fee_map, &fee_type_str), EFeeNotExists);

        let pool_key = pool_key<CoinTypeA, CoinTypeB, FeeType>(coin_type_a, coin_type_b, fee_type);
        assert!(!table::contains(&pool_config.pools, pool_key), EPoolAlreadyExists);

        let fee = fee::get_fee(feeType);
        let tick_spacing = fee::get_tick_spacing(feeType);

        let pool = pool::deploy_pool<CoinTypeA, CoinTypeB, FeeType>(
            fee,
            tick_spacing,
            sqrt_price,
            pool_config.fee_protocol,
            clock,
            ctx,
        );

        event::emit(PoolCreatedEvent {
            account: tx_context::sender(ctx),
            pool: object::id(&pool),
            fee: fee,
            tick_spacing: tick_spacing,
            fee_protocol: pool_config.fee_protocol,
            sqrt_price: sqrt_price,
        });

        position_manager::mint(
            &mut pool,
            positions,
            coins_a,
            coins_b,
            tick_lower_index,
            tick_lower_index_is_neg,
            tick_upper_index,
            tick_upper_index_is_neg,
            amount_a_desired,
            amount_b_desired,
            amount_a_min,
            amount_b_min,
            recipient,
            deadline,
            clock,
            versioned,
            ctx
        );

        table::add(&mut pool_config.pools, pool_key, PoolSimpleInfo {
            pool_id: object::id(&pool),
            pool_key: pool_key,
            coin_type_a: coin_type_a,
            coin_type_b: coin_type_b,
            fee_type: fee_type,
            fee: fee,
            tick_spacing: tick_spacing,
        });
        transfer::public_share_object(pool);

    }

    public fun deploy_pool_and_mint_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        pool_config: &mut PoolConfig,
        feeType: &Fee<FeeType>,
        sqrt_price: u128,
        positions: &mut Positions,
        coins_a: vector<Coin<CoinTypeA>>,
        coins_b: vector<Coin<CoinTypeB>>,
        tick_lower_index: u32,
        tick_lower_index_is_neg: bool,
        tick_upper_index: u32,
        tick_upper_index_is_neg: bool,
        amount_a_desired: u64,
        amount_b_desired: u64,
        amount_a_min: u64,
        amount_b_min: u64,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (TurbosPositionNFT, Coin<CoinTypeA>, Coin<CoinTypeB>, ID) {
        pool::check_version(versioned);

        let coin_type_a = type_name::get<CoinTypeA>();
        let coin_type_b = type_name::get<CoinTypeB>();
        assert!(coin_type_a != coin_type_b, ERepeatedType);

        let fee_type = type_name::get<FeeType>();
        let fee_type_str = string::from_ascii(type_name::into_string(fee_type));
        assert!(vec_map::contains(&pool_config.fee_map, &fee_type_str), EFeeNotExists);

        let pool_key = pool_key<CoinTypeA, CoinTypeB, FeeType>(coin_type_a, coin_type_b, fee_type);
        assert!(!table::contains(&pool_config.pools, pool_key), EPoolAlreadyExists);

        let fee = fee::get_fee(feeType);
        let tick_spacing = fee::get_tick_spacing(feeType);

        let pool = pool::deploy_pool<CoinTypeA, CoinTypeB, FeeType>(
            fee,
            tick_spacing,
            sqrt_price,
            pool_config.fee_protocol,
            clock,
            ctx,
        );

        event::emit(PoolCreatedEvent {
            account: tx_context::sender(ctx),
            pool: object::id(&pool),
            fee: fee,
            tick_spacing: tick_spacing,
            fee_protocol: pool_config.fee_protocol,
            sqrt_price: sqrt_price,
        });

        let (nft, coin_a_left, coin_b_left) = position_manager::mint_with_return_(
            &mut pool,
            positions,
            coins_a,
            coins_b,
            tick_lower_index,
            tick_lower_index_is_neg,
            tick_upper_index,
            tick_upper_index_is_neg,
            amount_a_desired,
            amount_b_desired,
            amount_a_min,
            amount_b_min,
            deadline,
            clock,
            versioned,
            ctx
        );

        let pool_id = object::id(&pool);
        table::add(&mut pool_config.pools, pool_key, PoolSimpleInfo {
            pool_id: pool_id,
            pool_key: pool_key,
            coin_type_a: coin_type_a,
            coin_type_b: coin_type_b,
            fee_type: fee_type,
            fee: fee,
            tick_spacing: tick_spacing,
        });
        transfer::public_share_object(pool);

        (nft, coin_a_left, coin_b_left, pool_id)
    }

    public entry fun deploy_pool<CoinTypeA, CoinTypeB, FeeType>(
        pool_config: &mut PoolConfig,
        feeType: &Fee<FeeType>,
        sqrt_price: u128,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);

        let coin_type_a = type_name::get<CoinTypeA>();
        let coin_type_b = type_name::get<CoinTypeB>();
        assert!(coin_type_a != coin_type_b, ERepeatedType);

        let fee_type = type_name::get<FeeType>();
        let fee_type_str = string::from_ascii(type_name::into_string(fee_type));
        assert!(vec_map::contains(&pool_config.fee_map, &fee_type_str), EFeeNotExists);

        let pool_key = pool_key<CoinTypeA, CoinTypeB, FeeType>(coin_type_a, coin_type_b, fee_type);
        assert!(!table::contains(&pool_config.pools, pool_key), EPoolAlreadyExists);

        let fee = fee::get_fee(feeType);
        let tick_spacing = fee::get_tick_spacing(feeType);

        let pool = pool::deploy_pool<CoinTypeA, CoinTypeB, FeeType>(
            fee,
            tick_spacing,
            sqrt_price,
            pool_config.fee_protocol,
            clock,
            ctx
        );
        table::add(&mut pool_config.pools, pool_key, PoolSimpleInfo {
            pool_id: object::id(&pool),
            pool_key: pool_key,
            coin_type_a: coin_type_a,
            coin_type_b: coin_type_b,
            fee_type: fee_type,
            fee: fee,
            tick_spacing: tick_spacing,
        });

        event::emit(PoolCreatedEvent {
            account: tx_context::sender(ctx),
            pool: object::id(&pool),
            fee: fee,
            tick_spacing: tick_spacing,
            fee_protocol: pool_config.fee_protocol,
            sqrt_price: sqrt_price,
        });
        transfer::public_share_object(pool);
    }

    public fun get_pool_id<CoinTypeA, CoinTypeB, FeeType>(
        pool_config: &mut PoolConfig,
    ): Option<ID> {
        let coin_type_a = type_name::get<CoinTypeA>();
        let coin_type_b = type_name::get<CoinTypeB>();
        let fee_type = type_name::get<FeeType>();
        let pool_key = pool_key<CoinTypeA, CoinTypeB, FeeType>(coin_type_a, coin_type_b, fee_type);
        if (table::contains(&pool_config.pools, pool_key)) {
            let pool_info = table::borrow(&pool_config.pools, pool_key);
            option::some(pool_info.pool_id)
        } else {
            option::none()
        }
    }

    fun pool_key<CoinTypeA, CoinTypeB, FeeType>(
        coin_type_a: TypeName,
        coin_type_b: TypeName,
        fee_type: TypeName,
    ): ID {
        let result = vector::empty<u8>();
        let coin_type_a_bytes = ascii::into_bytes(type_name::into_string(coin_type_a));
        let coin_type_b_bytes = ascii::into_bytes(type_name::into_string(coin_type_b));
        let (coin_type_a_bytes, coin_type_b_bytes) = if (!compare_types(&coin_type_a_bytes, &coin_type_b_bytes)) {
            (coin_type_a_bytes, coin_type_b_bytes)
        } else {
            (coin_type_b_bytes, coin_type_a_bytes)
        };
        vector::append(&mut result, coin_type_a_bytes);
        vector::append(&mut result, coin_type_b_bytes);
        vector::append(&mut result, ascii::into_bytes(type_name::into_string(fee_type)));

        object::id_from_bytes(hash::sha2_256(result))
    }

    fun compare_types(a: &vector<u8>, b: &vector<u8>): bool {
        let a_len = vector::length(a);
        let b_len = vector::length(b);

        let i = 0;
        while (i < a_len && i < b_len) {
            let a_val = *vector::borrow(a, i);
            let b_val = *vector::borrow(b, i);

            if (a_val < b_val) {
                return false
            } else if (a_val > b_val) {
                return true
            };

            i = i + 1;
        };

        if (a_len < b_len) {
            false
        } else {
            true
        }
    }

    public entry fun set_fee_tier<FeeType>(
        _: &PoolFactoryAdminCap,
        pool_config: &mut PoolConfig,
        feeType: &Fee<FeeType>,
        versioned: &Versioned,
    ) {
        abort(0)
    }

    public entry fun set_fee_tier_v2<FeeType>(
        acl_config: &AclConfig,
        pool_config: &mut PoolConfig,
        feeType: &Fee<FeeType>,
        versioned: &Versioned,
        ctx: &mut TxContext,
    ) {
        pool::check_version(versioned);
        check_clmm_manager_role(acl_config, tx_context::sender(ctx));

        let type = string::from_ascii(type_name::into_string(type_name::get<FeeType>()));
        assert!(!vec_map::contains(&pool_config.fee_map, &type), EFeeAlreadyExists);

        let fee = fee::get_fee(feeType);
        let tick_spacing = fee::get_tick_spacing(feeType);
        assert!(fee < 1000000, EInvalidFee);
        assert!(tick_spacing > 0 && tick_spacing < 16384, EInvalidTicKSpacing);

        vec_map::insert(&mut pool_config.fee_map, type, object::id(feeType));
        event::emit(FeeAmountEnabledEvent {fee: fee, tick_spacing: tick_spacing});
    }

    public entry fun set_fee_protocol(
        _: &PoolFactoryAdminCap,
        pool_config: &mut PoolConfig,
        fee_protocol: u32,
        versioned: &Versioned,
    ) {
        abort(0)
    }

    public entry fun set_fee_protocol_v2(
        acl_config: &AclConfig,
        pool_config: &mut PoolConfig,
        fee_protocol: u32,
        versioned: &Versioned,
        ctx: &mut TxContext,
    ) {
        pool::check_version(versioned);
        check_clmm_manager_role(acl_config, tx_context::sender(ctx));

        assert!(fee_protocol < 1000000, EInvalidFee);
        pool_config.fee_protocol = fee_protocol;
        event::emit(SetFeeProtocolEvent {fee_protocol: fee_protocol});
    }

    public entry fun update_pool_fee_protocol<CoinTypeA, CoinTypeB, FeeType>(
        _: &PoolFactoryAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        fee_protocol: u32,
        versioned: &Versioned,
        _ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun update_pool_fee_protocol_v2<CoinTypeA, CoinTypeB, FeeType>(
        acl_config: &AclConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        fee_protocol: u32,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        check_clmm_manager_role(acl_config, tx_context::sender(ctx));
        assert!(fee_protocol < 1000000, EInvalidFee);

        pool::update_pool_fee_protocol(pool, fee_protocol);
        event::emit(SetFeeProtocolEvent {fee_protocol: fee_protocol});
    }

    public entry fun collect_protocol_fee<CoinTypeA, CoinTypeB, FeeType>(
        _: &PoolFactoryAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        amount_a_requested: u64,
        amount_b_requested: u64,
        recipient: address,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun collect_protocol_fee_v2<CoinTypeA, CoinTypeB, FeeType>(
        acl_config: &AclConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        amount_a_requested: u64,
        amount_b_requested: u64,
        recipient: address,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        check_claim_protocol_fee_manager_role(acl_config, tx_context::sender(ctx));
        let (coin_a, coin_b) = pool::collect_protocol_fee_with_return_(
            pool,
            amount_a_requested,
            amount_b_requested,
            recipient,
            ctx
        );

        transfer::public_transfer(coin_a, recipient);
        transfer::public_transfer(coin_b, recipient);
    }

    public fun collect_protocol_fee_with_return_<CoinTypeA, CoinTypeB, FeeType>(
        _: &PoolFactoryAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        amount_a_requested: u64,
        amount_b_requested: u64,
        recipient: address,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        abort(0)
    }

    public fun collect_protocol_fee_with_return_v2<CoinTypeA, CoinTypeB, FeeType>(
        acl_config: &AclConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        amount_a_requested: u64,
        amount_b_requested: u64,
        recipient: address,
        versioned: &Versioned,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        pool::check_version(versioned);
        check_claim_protocol_fee_manager_role(acl_config, tx_context::sender(ctx));
        pool::collect_protocol_fee_with_return_(
            pool,
            amount_a_requested,
            amount_b_requested,
            recipient,
            ctx
        )
    }

    public entry fun toggle_pool_status<CoinTypeA, CoinTypeB, FeeType>(
        _: &PoolFactoryAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        versioned: &Versioned,
        ctx: &mut TxContext,
    ) {
        abort(0)
    }

    public entry fun toggle_pool_status_v2<CoinTypeA, CoinTypeB, FeeType>(
        acl_config: &AclConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        versioned: &Versioned,
        ctx: &mut TxContext,
    ) {
        pool::check_version(versioned);
        check_pause_pool_manager_role(acl_config, tx_context::sender(ctx));
        pool::toggle_pool_status(pool, ctx);
    }

    public entry fun update_nft_name(
        _: &PoolFactoryAdminCap,
        positions: &mut Positions,
        name: String,
        versioned: &Versioned,
        _ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun update_nft_name_v2(
        acl_config: &AclConfig,
        positions: &mut Positions,
        name: String,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        check_clmm_manager_role(acl_config, tx_context::sender(ctx));
        position_manager::update_nft_name(
            positions,
            name,
        );
    }

    public entry fun upgrade(
        _: &PoolFactoryAdminCap,
        versioned: &mut Versioned,
    ) {
        pool::upgrade(versioned)
    }

    public entry fun update_nft_description(
        _: &PoolFactoryAdminCap,
        positions: &mut Positions,
        nft_description: String,
        versioned: &Versioned,
        _ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun update_nft_description_v2(
        acl_config: &AclConfig,
        positions: &mut Positions,
        nft_description: String,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        check_clmm_manager_role(acl_config, tx_context::sender(ctx));
        position_manager::update_nft_description(
            positions,
            nft_description,
        );
    }

    public entry fun update_nft_img_url(
        _: &PoolFactoryAdminCap,
        positions: &mut Positions,
        nft_img_url: String,
        versioned: &Versioned,
        _ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun update_nft_img_url_v2(
        acl_config: &AclConfig,
        positions: &mut Positions,
        nft_img_url: String,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        pool::check_version(versioned);
        check_clmm_manager_role(acl_config, tx_context::sender(ctx));
        position_manager::update_nft_img_url(
            positions,
            nft_img_url,
        );
    }

    public entry fun migrate_position<CoinTypeA, CoinTypeB, FeeType>(
        _: &PoolFactoryAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        nfts: vector<address>,
        owned: address,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun decrease_liquidity_admin<CoinTypeA, CoinTypeB, FeeType>(
         _: &PoolFactoryAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        position_owner: address,
        tick_lower_index: u32,
        tick_lower_index_is_neg: bool,
        tick_upper_index: u32,
        tick_upper_index_is_neg: bool,
        user_address: address,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        abort(0)
    }
    /// deprecated
    public entry fun modify_tick_reward<CoinTypeA, CoinTypeB, FeeType>(
    	_: &PoolFactoryAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: u32,
    	tick_index_is_neg: bool,
    	clock: &Clock,
    	versioned: &Versioned,
        ctx: &mut TxContext,
    ) {
        abort(0)
    }

    public entry fun modify_tick<CoinTypeA, CoinTypeB, FeeType>(
        _: &PoolFactoryAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        tick_index: u32,
        tick_index_is_neg: bool,
        versioned: &Versioned,
    ) {
        abort(0)
    } 

    public entry fun modify_reward<CoinTypeA, CoinTypeB, FeeType>(
        _: &PoolFactoryAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        positions: &mut Positions,
        tick_lower_index: u32,
        tick_lower_index_is_neg: bool,
        tick_upper_index: u32,
        tick_upper_index_is_neg: bool,
        nfts: vector<address>,
        owners: vector<address>,
        versioned: &Versioned,
        _ctx: &mut TxContext,
    ) {
        abort(0)
    }

    //just for fix pool state, should remove on next version
    public entry fun fake_swap<CoinTypeA, CoinTypeB, FeeType>(
        _: &PoolFactoryAdminCap,
        pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
        recipient: address,
        a_to_b: bool,
        amount_specified: u128,
        is_exact_input: bool,
        sqrt_price_limit: u128,
        clock: &Clock,
        versioned: &Versioned,
        ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun init_partners(
        _: &PoolFactoryAdminCap,
        ctx: &mut TxContext
    ) {
        partner::init_partners(ctx)
    }

    /// acl
    public entry fun init_acl_config(
        _: &PoolFactoryAdminCap,
        ctx: &mut TxContext
    ) {
        let acl_config = AclConfig{
            id                : object::new(ctx), 
            acl               : acl::new(ctx), 
        };
        
        // Set all roles for the admin (transaction sender)
        let admin_address = tx_context::sender(ctx);
        let all_roles = (1u128 << ACL_CLMM_MANAGER) | 
                       (1u128 << ACL_REWARD_MANAGER) | 
                       (1u128 << ACL_CLAIM_PROTOCOL_FEE_MANAGER) | 
                       (1u128 << ACL_PAUSE_POOL_MANAGER);
        acl::set_roles(&mut acl_config.acl, admin_address, all_roles);
        
        transfer::share_object(acl_config);
    }

    public fun acl(config: &AclConfig): &acl::ACL {
        &config.acl
    }

    public fun add_role(
        _: &PoolFactoryAdminCap,
        config: &mut AclConfig,
        member: address,
        role: u8,
        versioned: &Versioned,
    ) {
        pool::check_version(versioned);
        acl::add_role(&mut config.acl, member, role);
        let add_role_event = AddRoleEvent{
            member : member, 
            role   : role,
        };
        event::emit<AddRoleEvent>(add_role_event);
    }

    public fun get_members(config: &AclConfig): vector<acl::Member> {
        acl::get_members(&config.acl)
    }

    public fun remove_member(
        _: &PoolFactoryAdminCap,
        config: &mut AclConfig,
        member: address,
        versioned: &Versioned,
    ) {
        pool::check_version(versioned);
        acl::remove_member(&mut config.acl, member);
        let remove_member_event = RemoveMemberEvent{member: member};
        event::emit<RemoveMemberEvent>(remove_member_event);
    }

    public fun remove_role(
        _: &PoolFactoryAdminCap,
        config: &mut AclConfig,
        member: address,
        role: u8,
        versioned: &Versioned,
    ) {
        pool::check_version(versioned);
        acl::remove_role(&mut config.acl, member, role);
        let remove_role_event = RemoveRoleEvent{
            member : member, 
            role   : role,
        };
        event::emit<RemoveRoleEvent>(remove_role_event);
    }

    public fun set_roles(
        _: &PoolFactoryAdminCap,
        config: &mut AclConfig,
        member: address,
        roles: u128,
        versioned: &Versioned,
    ) {
        pool::check_version(versioned);
        acl::set_roles(&mut config.acl, member, roles);
        let set_roles_event = SetRolesEvent{
            member : member, 
            roles  : roles,
        };
        event::emit<SetRolesEvent>(set_roles_event);
    }

    public fun check_clmm_manager_role(config: &AclConfig, member: address) {
        assert!(acl::has_role(&config.acl, member, ACL_CLMM_MANAGER), EInvalidClmmManagerRole);
    }

    public fun check_reward_manager_role(
        config: &AclConfig,
        member: address,
    ) {
        assert!(acl::has_role(&config.acl, member, ACL_REWARD_MANAGER), EInvalidRewardManagerRole);
    }

    public fun check_claim_protocol_fee_manager_role(
        config: &AclConfig,
        member: address,
    ) {
        assert!(acl::has_role(&config.acl, member, ACL_CLAIM_PROTOCOL_FEE_MANAGER), EInvalidClaimProtocolFeeRoleManager);
    }

    public fun check_pause_pool_manager_role(
        config: &AclConfig,
        member: address,
    ) {
        assert!(acl::has_role(&config.acl, member, ACL_PAUSE_POOL_MANAGER), EInvalidPausePoolManagerRole);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init_(ctx);
    }
}