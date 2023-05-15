// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module nonfungible::factory {
    // Imports
    use sui::tx_context::{ Self, TxContext };
    use sui::clock::{ Clock };
    use sui::coin::{ Self, Coin };
    use sui::sui::SUI;
    use sui::balance;
    use sui::transfer;
    use sui::object::{ Self, ID };
    use nonfungible::random;
    use nonfungible::nft::{ Self, MintingTreasury, MinterCap, XYZNFT };
    use sui::event;
    use std::string::{ String, utf8 };
    use whitelist_package::whitelist::{ Self, WhitelistStorage };


    // Constants
    const EInsufficientBalance: u64 = 0;
    const ENotInWhitelist: u64 = 1;

    // Events
    struct UpgradeEvent<phantom T> has drop, copy {
        is_upgradable: bool,
        random_seed_string: String,
        old_nft_id: ID
    }

    public entry fun mint(
        minting_treasury: &mut MintingTreasury,
        clock: &Clock,
        fee: Coin<SUI>,
        ref_address: address,
        ctx: &mut TxContext
    ){
        // Mint NFT
        nft::mint_to_account(
            minting_treasury,
            clock,
            fee,
            ref_address,
            ctx
        );
    }

    public entry fun add_level_price_info<T>(
        cap: &MinterCap, 
        treasury: &mut MintingTreasury, 
        mint_price: u64, 
        level_name: vector<u8>,
        level_value: u64,
        next_level_name: vector<u8>,
        rarity_numerator: u64,
        rarity_denumerator: u64,
    ){
        nft::add_level_price_info<T>(cap, treasury, mint_price, level_name, level_value, next_level_name, rarity_numerator, rarity_denumerator);
    }

    public entry fun delete_level_price_info<T>(
        cap: &MinterCap, 
        treasury: &mut MintingTreasury, 
        level_name: vector<u8>
    ){
        nft::delete_level_price_info<T>(cap, treasury, level_name);
    }

    public entry fun edit_level_price_info<T>(
        cap: &MinterCap, 
        treasury: &mut MintingTreasury, 
        mint_price: u64, 
        level_name: vector<u8>,
        level_value: u64,
        next_level_name: vector<u8>,
        rarity_numerator: u64,
        rarity_denumerator: u64,
    ){
        nft::edit_level_price_info<T>(cap, treasury, mint_price, level_name, level_value, next_level_name, rarity_numerator, rarity_denumerator);
    }

    /// Transfer minter cap
    public entry fun transfer_minter_cap(
     cap: MinterCap, 
     minting_treasury: &mut MintingTreasury, 
     ctx: &mut TxContext
     ) {
        nft::transfer_minter_cap(cap, minting_treasury, ctx);
    }

    /// Set the max total nft available for minting
    public entry fun set_max_total_mints(
        cap: &MinterCap, 
        minting_treasury: &mut MintingTreasury,
        max_total: u64, 
        _ctx: &mut TxContext
    ){
        nft::set_max_total_mints(cap, minting_treasury, max_total);
    }

    public entry fun burn_cap(
       cap: MinterCap,
       _ctx: &mut TxContext
    ){
        nft::burn_cap(cap);
    }

    public entry fun burn(
        nft: XYZNFT,
        _ctx: &mut TxContext
    ){
        nft::burn(nft);
    }

    public entry fun set_due_time(
        cap: &MinterCap, 
        minting_treasury: &mut MintingTreasury,
        clock: &Clock,
        due_timestamp_ms: u64,
        _ctx: &mut TxContext
    ) {
        nft::set_due_time(cap, minting_treasury, clock, due_timestamp_ms);
    }

    public entry fun set_mint_ref_percent(
        cap: &MinterCap, 
        minting_treasury: &mut MintingTreasury,
        ref_percent: u64,
        _ctx: &mut TxContext
    ){
        nft::set_mint_ref_percent(cap, minting_treasury, ref_percent);
    }

    public entry fun upgrade_nft<TCurr, TNext>(
        nft: XYZNFT,
        clock: &Clock,
        minting_treasury: &mut MintingTreasury,
        paid: Coin<TNext>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        // Get level of nft
        let nft_next_level_name = nft::get_nft_next_level_name<TCurr>(&nft, minting_treasury);
        // get the next level price info
        let next_level_price_info = nft::get_level_price_info<TNext>(minting_treasury, nft_next_level_name);
        let next_level_mint_price = nft::get_level_mint_price<TNext>(&next_level_price_info);
        let beneficiary = nft::get_beneficiary(minting_treasury);
        assert!(
          coin::value(&paid) >= next_level_mint_price, 
          EInsufficientBalance
        );
        // Convert fee in sui to mutable balance
        let balance = coin::balance_mut<TNext>(&mut paid);
        // Calculate the remain amount
        let remain_amount = balance::value(balance) - next_level_mint_price;
        // Transfer next_level_mint_price amount of paid to beneficiary
        transfer::public_transfer<Coin<TNext>>(
            coin::take<TNext>(balance, next_level_mint_price, ctx),
            beneficiary
        );
        // Transfer changes of paid back to sender
        transfer::public_transfer(coin::take<TNext>(balance, remain_amount, ctx), sender);
        let uid = object::new(ctx);
        let seed = random::pseudo_random_num_generator(&uid, clock);
        let random = random::new(seed);
        // calculate the rarity fraction
        // random with rarity fraction between 0 and 1
        let is_upgradable = random::next_bool_with_p(&mut random, nft::get_level_info_probability<TNext>(&next_level_price_info));
        let old_nft_id = nft::get_nft_id(&nft);
        nft::update_nft_to_next_level(nft, nft_next_level_name, is_upgradable, ctx);
        event::emit( UpgradeEvent<XYZNFT> {
                is_upgradable,
                random_seed_string: utf8(seed),
                old_nft_id,
        });
        // delete unused id
        object::delete(uid);
        // Destroy zero paid balance
        coin::destroy_zero(paid);
    }
    public entry fun mint_with_whitelist(
        whitelist: &WhitelistStorage,
        treasury: &mut MintingTreasury,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(
            whitelist::is_whitelist(whitelist, tx_context::sender(ctx), ctx),
            ENotInWhitelist
        );
        nft::free_mint_to_account(treasury, clock, ctx);
    }
}
