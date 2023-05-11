// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module governance::factory {
    use nonfungible::nft::{ Self, MintingTreasury, MinterCap, S6kTestNFT };
    use sui::tx_context::{ TxContext };
    use sui::clock::{ Clock };
    use sui::coin::{Coin};
    use sui::sui::SUI;

    public entry fun mint(
        minting_treasury: &mut MintingTreasury,
        clock: &Clock,
        fee: Coin<SUI>,
        ctx: &mut TxContext
    ){
        // Mint NFT
        nft::mint_to_account(
            minting_treasury,
            clock,
            fee,
            ctx
        );
    }

    public entry fun add_level_price_info(
        cap: &MinterCap, 
        treasury: &mut MintingTreasury, 
        mint_price: u64, 
        level_name: vector<u8>
    ){
        nft::add_level_price_info(cap, treasury, mint_price, level_name);
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
        nft: S6kTestNFT,
        _ctx: &mut TxContext
    ){
        nft::burn(nft);
    }

    public entry fun set_due_time(
        cap: &MinterCap, 
        minting_treasury: &mut MintingTreasury,
        clock: &Clock,
        due_timestamp_ms: u64
    ) {
        nft::set_due_time(cap, minting_treasury, clock, due_timestamp_ms);
    }
}
