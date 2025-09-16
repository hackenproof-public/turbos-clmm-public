module turbos_clmm::partner {
	use std::type_name;
	use sui::event;
	use sui::transfer;
	use sui::object::{Self, UID, ID};
    use sui::vec_map::{Self};
    use std::string::{Self, String};
    use sui::bag::{Self};
    use sui::balance::{Self};
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
	use sui::coin::{Self, Coin};

    const EPartnerAlreadyExists: u64 = 1;
    const EInvalidReferralFeeRate: u64 = 2;
    const EPartnerNameEmpty: u64 = 3;
    const EInvalidTime: u64 = 4;
    const EInvalidPartner: u64 = 5;
    const EEmptyPartnerFee: u64 = 6;

    friend turbos_clmm::pool_factory;

	struct PartnerAdminCap has key, store { 
		id: UID
	}

    struct Partners has key {
        id: UID,
        partners: vec_map::VecMap<String, ID>,
    }

    struct PartnerCap has store, key {
        id: UID,
        name: String,
        partner_id: ID,
    }

    struct Partner has store, key {
        id: UID,
        name: String,
        ref_fee_rate: u64,
        start_time: u64,
        end_time: u64,
        balances: bag::Bag,
    }

    struct InitPartnerEvent has copy, drop {
        partners_id: ID,
    }

    struct CreatePartnerEvent has copy, drop {
        recipient: address,
        partner_id: ID,
        partner_cap_id: ID,
        ref_fee_rate: u64,
        name: String,
        start_time: u64,
        end_time: u64,
    }

    struct UpdateRefFeeRateEvent has copy, drop {
        partner_id: ID,
        old_fee_rate: u64,
        new_fee_rate: u64,
    }

    struct UpdateTimeRangeEvent has copy, drop {
        partner_id: ID,
        start_time: u64,
        end_time: u64,
    }

    struct ReceiveRefFeeEvent has copy, drop {
        partner_id: ID,
        amount: u64,
        type_name: String,
    }

    struct ClaimRefFeeEvent has copy, drop {
        partner_id: ID,
        amount: u64,
        type_name: String,
    }


    fun init(_ctx: &mut TxContext) {
    }

    public(friend) fun init_partners(ctx: &mut TxContext) {
        let partners = Partners{
            id       : object::new(ctx),
            partners : vec_map::empty<String, ID>(),
        };
		let partners_id = object::id<Partners>(&partners);
        transfer::transfer(PartnerAdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
        transfer::share_object<Partners>(partners);
        let event = InitPartnerEvent{partners_id};
        event::emit<InitPartnerEvent>(event);
    }

    public fun claim_ref_fee<CoinType>(partner_cap: &PartnerCap, partner: &mut Partner, ctx: &mut TxContext) {
        assert!(partner_cap.partner_id == object::id<Partner>(partner), EInvalidPartner);
        let coin_name = string::from_ascii(type_name::into_string(type_name::get<CoinType>()));
        assert!(bag::contains<String>(&partner.balances, coin_name), EEmptyPartnerFee);
		let balance = bag::remove<String, balance::Balance<CoinType>>(&mut partner.balances, coin_name);
		let amount = balance::value<CoinType>(&balance);
        transfer::public_transfer<Coin<CoinType>>(coin::from_balance<CoinType>(balance, ctx), tx_context::sender(ctx));
        let event = ClaimRefFeeEvent{
            partner_id : object::id<Partner>(partner),
            amount,
            type_name  : coin_name,
        };
        event::emit<ClaimRefFeeEvent>(event);
    }

    public fun create_partner(
		_admin_cap: &PartnerAdminCap, 
		partners: &mut Partners, 
		name: String, 
		ref_fee_rate: u64, 
		start_time: u64, 
		end_time: u64, 
		recipient: address, 
		clock: &Clock, 
		ctx: &mut TxContext
	) {
        assert!(end_time > start_time, EInvalidTime);
        assert!(end_time >= clock::timestamp_ms(clock) / 1000, EInvalidTime);
        assert!(ref_fee_rate < 10000, EInvalidReferralFeeRate);
        assert!(!string::is_empty(&name), EPartnerNameEmpty);
        assert!(!vec_map::contains<String, ID>(&partners.partners, &name), EPartnerAlreadyExists);
        let partner = Partner{
            id           : object::new(ctx),
            name         : name,
            ref_fee_rate : ref_fee_rate,
            start_time   : start_time,
            end_time     : end_time,
            balances     : bag::new(ctx),
        };
		let partner_id = object::id<Partner>(&partner);

        let partner_cap = PartnerCap{
            id         : object::new(ctx),
            name       : name,
            partner_id : partner_id,
        };
		let partner_cap_id = object::id<PartnerCap>(&partner_cap);
        vec_map::insert<String, ID>(&mut partners.partners, name, partner_id);
        transfer::share_object<Partner>(partner);
        transfer::transfer<PartnerCap>(partner_cap, recipient);
        let event = CreatePartnerEvent{
            recipient      : recipient,
            partner_id     : partner_id,
            partner_cap_id : partner_cap_id,
            ref_fee_rate   : ref_fee_rate,
            name           : name,
            start_time     : start_time,
            end_time       : end_time,
        };
        event::emit<CreatePartnerEvent>(event);
    }
		
    public fun balances(partner: &Partner) : &bag::Bag {
        &partner.balances
    }

    public fun current_ref_fee_rate(partner: &Partner, current_time: u64) : u64 {
        if (partner.start_time > current_time || partner.end_time <= current_time) {
            return 0
        };
        partner.ref_fee_rate
    }

    public fun end_time(partner: &Partner) : u64 {
        partner.end_time
    }

    public fun name(partner: &Partner) : String {
        partner.name
    }

    public fun receive_ref_fee<CoinType>(partner: &mut Partner, fee: balance::Balance<CoinType>) {
        let coin_name = string::from_ascii(type_name::into_string(type_name::get<CoinType>()));
		let fee_amount = balance::value<CoinType>(&fee);
        if (bag::contains<String>(&partner.balances, coin_name)) {
            balance::join<CoinType>(bag::borrow_mut<String, balance::Balance<CoinType>>(&mut partner.balances, coin_name), fee);
        } else {
            bag::add<String, balance::Balance<CoinType>>(&mut partner.balances, coin_name, fee);
        };
        let event = ReceiveRefFeeEvent{
            partner_id : object::id<Partner>(partner),
            amount     : fee_amount,
            type_name  : coin_name,
        };
        event::emit<ReceiveRefFeeEvent>(event);
    }

    public fun ref_fee_rate(partner: &Partner) : u64 {
        partner.ref_fee_rate
    }

    public fun start_time(partner: &Partner) : u64 {
        partner.start_time
    }

    public fun update_ref_fee_rate(
		_admin_cap: &PartnerAdminCap, 
		partner: &mut Partner, 
		new_fee_rate: u64, 
		_ctx: &TxContext
	) {
        assert!(new_fee_rate < 10000, EInvalidReferralFeeRate);
        let old_fee_rate = partner.ref_fee_rate;
        partner.ref_fee_rate = new_fee_rate;
        let event = UpdateRefFeeRateEvent{
            partner_id   : object::id<Partner>(partner),
            old_fee_rate : old_fee_rate,
            new_fee_rate : new_fee_rate,
        };
        event::emit<UpdateRefFeeRateEvent>(event);
    }

    public fun update_time_range(
		_admin_cap: &PartnerAdminCap, 
		partner: &mut Partner, 
		start_time: u64, 
		end_time: u64, 
		clock: &Clock, 
		_ctx: &mut TxContext
	) {
        assert!(end_time > start_time, EInvalidTime);
        assert!(end_time > clock::timestamp_ms(clock) / 1000, EInvalidTime);
        partner.start_time = start_time;
        partner.end_time = end_time;
        let event = UpdateTimeRangeEvent{
            partner_id : object::id<Partner>(partner),
            start_time : start_time,
            end_time   : end_time,
        };
        event::emit<UpdateTimeRangeEvent>(event);
    }
}