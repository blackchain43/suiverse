// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module nonfungible::nft{
   use sui::object::{Self, UID, ID};
   use sui::tx_context::{Self, TxContext, sender};
   use sui::balance::{Self, Balance};
   use sui::event;
   use sui::transfer;
   use sui::package;
   use sui::display;
   use sui::sui::SUI;
   use sui::coin::{Self, Coin};
   use sui::url::{Self, Url};
   use std::string::{utf8, String};

   const EInsufficientBalance: u64 = 0;

   /// Type that marks the capability to mint new S6kTestNFT's.
   struct MinterCap has key { id: UID }

    /// Event marking when a S6kTestNFT has been minted
   struct MintNFTEvent has copy, drop {
        // The Object ID of the NFT
        object_id: ID,
        // The creator of the NFT
        creator: address,
        // The name of the NFT
        name: String,
    }

   // ======= Types =======
   struct NFT has drop {}

   /// An example NFT that can be minted by anybody
   struct S6kTestNFT has key, store {
        id: UID,
        /// Name for the token
        name: String,
        /// Description of the token
        description: String,
        /// URL for the token
        image_url: Url,
        /// creator of the token
        creator: address,
    }

   struct MintingTreasury has key {
        id: UID,
        mintingfee: u64,
        balance: Balance<SUI>
    }
   
   fun init(otw: NFT, ctx: &mut TxContext) {
      // Claim the `Publisher` for the package!
      let publisher = package::claim(otw, ctx);

      let nft_keys = vector[
            utf8(b"name"),
            utf8(b"link"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];

      let nft_values = vector[
            utf8(b"{name}"),
            utf8(b"https://s6k.finance"),
            utf8(b"{image_url}"),
            utf8(b"{description}"),
            utf8(b"https://s6k.finance"),
            utf8(b"{creator}"),
        ];

      let nft_display = display::new_with_fields<S6kTestNFT>(
            &publisher, nft_keys, nft_values, ctx
        );
      display::update_version(&mut nft_display);

      transfer::transfer(MinterCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));

      transfer::share_object(MintingTreasury {
            id: object::new(ctx),
            mintingfee: 5000000,
            balance: balance::zero<SUI>(),
        });

      transfer::public_transfer(nft_display, sender(ctx));

      transfer::public_transfer(publisher, sender(ctx));
   }
   
   /// Private function that creates and returns a new S6kTestNFT
   fun mint(
      name: vector<u8>, 
      description: vector<u8>, 
      url: vector<u8>, 
      ctx: &mut TxContext
   ): S6kTestNFT {

      let sender = tx_context::sender(ctx);

      let nft = S6kTestNFT {
         id: object::new(ctx),
         name: utf8(name),
         description: utf8(description),
         image_url: url::new_unsafe_from_bytes(url),
         creator: sender,
      };
      
      event::emit(MintNFTEvent {
         object_id: object::uid_to_inner(&nft.id),
         creator: sender,
         name: nft.name,
      });
      nft
   }

   /// Paid public mint to an account
   public entry fun mint_to_account(
        mintingtreasury: &mut MintingTreasury,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        fee: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(coin::value(&fee) >= mintingtreasury.mintingfee, EInsufficientBalance);
        let balance = coin::balance_mut<SUI>(&mut fee);
        let remain_amount = balance::value(balance) - mintingtreasury.mintingfee;
        // add a payment to the minting treasury balance
        balance::join(&mut mintingtreasury.balance, balance::split(balance, mintingtreasury.mintingfee));
        
        let remain = coin::take<SUI>(balance, remain_amount, ctx);
        transfer::public_transfer<Coin<SUI>>(remain, sender(ctx));

        //mint the NFT and transfer to sender
        let nft = mint(name, description, url, ctx);
        transfer::transfer(nft, tx_context::sender(ctx));
        coin::destroy_zero(fee);
   }

   /// Privileged mint a S6kTestNFT to an account 
   public entry fun owner_mint_to_account(
      _: &MinterCap,
      name: vector<u8>,
      description: vector<u8>,
      url: vector<u8>,
      receipient: address,
      ctx: &mut TxContext
    ) {
      let nft = mint(name, description, url, ctx);
      transfer::transfer(nft, receipient);
   }
   /// Withdraw SUI in MintingTreasury
   public entry fun collect_profits(
        _: &MinterCap,
        mintingtreasury: &mut MintingTreasury,
        ctx: &mut TxContext
    ) {
      let amount = balance::value(&mintingtreasury.balance);
      let profits = coin::take(&mut mintingtreasury.balance, amount, ctx);

      transfer::public_transfer(profits, tx_context::sender(ctx))
    }

   /// Update the `description` of `nft` to `new_description`
   public entry fun update_description(
        nft: &mut S6kTestNFT,
        new_description: vector<u8>,
   
        _: &mut TxContext
   ) {
        nft.description = utf8(new_description)
   }

   /// Permanently delete `nft`
   public entry fun burn(nft: S6kTestNFT, _: &mut TxContext) {
        let S6kTestNFT { id, name: _, description: _, image_url: _, creator: _} = nft;
        object::delete(id)
   }

   /// Permanently delete `minterCap`
   public entry fun burn_cap(cap: MinterCap, _: &mut TxContext) {
        let MinterCap { id } = cap;
        object::delete(id)
   }

   /// Get the NFT's `name`
   public fun name(nft: &S6kTestNFT): &String {
        &nft.name
    }

   /// Get the NFT's `description`
   public fun description(nft: &S6kTestNFT): &String {
        &nft.description    
    }

   /// Get the NFT's `url`
   public fun image_url(nft: &S6kTestNFT): &Url {
        &nft.image_url
   }

   /// Get the NFT's `creator`
   public fun creator(nft: &S6kTestNFT): &address {
        &nft.creator
   }

   #[test_only] 
   public fun init_for_testing(otw: NFT, ctx: &mut TxContext) { init(otw, ctx) } 
}