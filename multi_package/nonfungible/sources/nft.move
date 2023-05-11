// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module nonfungible::nft{
   use std::string::{Self, utf8, String};
   use std::vector;
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
   use sui::clock::{Self, Clock};
   use sui::dynamic_field as field;

   const U64_MAX: u64 = 18446744073709551615;
   const MIN_OF_MAX_TOTAL_MINTS: u64 = 1;
   const TOKEN_NAME_PREFIX: vector<u8> = b"WorryPepe NFT #";
   const TOKEN_URL: vector<u8> = b"https://img-08.stickers.cloud/packs/787053f4-0bd6-45f0-9a58-715b54913177/webp/ce810738-214d-4b3b-ab2f-aead08c5f7f8.webp";
   const TOKEN_DESCRIPTION: vector<u8>  = b"$WPEPE The biggest airdrop on SUI mainnet";
   const EInsufficientBalance: u64 = 0;
   const EMintEventEnd: u64 = 1;
   const ELevelPriceInfoNotSet: u64 = 2;
   const EMaxTotalMintIsReached: u64 = 3;
   const EInvalidMaxTotalMint: u64 = 4;
   const EUserAlreadyMinted: u64 = 5;
   const EDueTimeNotValid: u64 = 6;
   const EMaxTotalMintNotGtCurrentMint: u64 = 7;

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

   struct LevelPriceInfo has store, copy, drop {
     level_name: vector<u8>,
   }
   struct UserInfo has store {
     is_mint: bool

     }

   /// An example NFT that can be minted by anybody
   struct S6kTestNFT has key, store {
        id: UID,
        /// Name for the token
        name: String,
        /// Description of the token
        description: String,
        /// URL for the token
        image_url: Url,
        /// Creator of the token
        creator: address,
        /// Level of the NFT
        level: String,
    }
    
    struct MintingTreasury has store, key {
          id: UID,
          current_mint: u64,
          max_total: u64,
          due_time: u64,
          beneficiary: address,
          balance: Balance<SUI>
     }

    
   
   fun init(otw: NFT, ctx: &mut TxContext) {
      // Claim the `Publisher` for the package!
     let publisher = package::claim(otw, ctx);

     let sender = tx_context::sender(ctx);

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
     let minting_treasury = MintingTreasury {
            id: object::new(ctx),
            balance: balance::zero<SUI>(),
            beneficiary: sender,
            current_mint: 0,
            max_total: U64_MAX,
            due_time: 0,
     };

     display::update_version(&mut nft_display);

     transfer::transfer(MinterCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));

      transfer::share_object(minting_treasury);

      transfer::public_transfer(nft_display, sender);

      transfer::public_transfer(publisher, sender);
   }
   
   /// Private function that creates and returns a new S6kTestNFT
   fun mint(
      name: String, 
      description: String, 
      url: Url,
      level: String, 
      ctx: &mut TxContext
   ): S6kTestNFT {

      let sender = tx_context::sender(ctx);

      let nft = S6kTestNFT {
         id: object::new(ctx),
         name: name,
         description: description,
         image_url: url,
         creator: sender,
         level: level,
      };
      
      event::emit(MintNFTEvent {
         object_id: object::uid_to_inner(&nft.id),
         creator: sender,
         name: nft.name,
      });
      nft
   }

   public fun add_level_price_info(
     _:&MinterCap, 
     treasury: &mut MintingTreasury, 
     mint_price: u64, 
     level_name: vector<u8>
     ) {
          field::add(&mut treasury.id, LevelPriceInfo { level_name },  mint_price);
     }

   /// Paid public mint to an account
   public fun mint_to_account(
        minting_treasury: &mut MintingTreasury,
        clock: &Clock,
        fee: Coin<SUI>,
        ctx: &mut TxContext
    ) {
     // Check if not exceed due_time
     assert!(
          clock::timestamp_ms(clock) <= minting_treasury.due_time, 
          EMintEventEnd
     );
     // Check if level_one price info exists
     assert!(
          field::exists_with_type<LevelPriceInfo, u64>(
               &minting_treasury.id, 
               LevelPriceInfo{ level_name : b"level_one" }
          ), 
          ELevelPriceInfoNotSet
     );
     // Check if max_total is reached
     assert!(
         minting_treasury.max_total > minting_treasury.current_mint,
         EMaxTotalMintIsReached
     );
     // Take the mint_fee of level_one price info
     let level_one_mint_fee = *field::borrow(&minting_treasury.id, LevelPriceInfo{ level_name : b"level_one" });
     // Check if fee is sufficient
     assert!(
          coin::value(&fee) >= level_one_mint_fee, 
          EInsufficientBalance
     );
     let sender = sender(ctx);
     // Check for the existence the dynamic field for user info, if not then create with is_mint: false else assert
     if(!field::exists_with_type<address, UserInfo>(&minting_treasury.id, sender)){
          field::add<address, UserInfo>(
               &mut minting_treasury.id, 
               sender, 
               UserInfo {is_mint: false}
          );
     };
     let user_info = field::borrow_mut<address, UserInfo>(&mut minting_treasury.id, sender); 
     assert!(!user_info.is_mint, EUserAlreadyMinted);
     // Convert fee in sui to mutable balance
     let balance = coin::balance_mut<SUI>(&mut fee);
     // Calculate the remain amount
     let remain_amount = balance::value(balance) - level_one_mint_fee;
     // Add a payment to the minting treasury balance
     balance::join(&mut minting_treasury.balance, balance::split(balance, level_one_mint_fee));
     // Convert the remain balance into coin object
     let remain = coin::take<SUI>(balance, remain_amount, ctx);
     // Transfer the changes to the sender
     transfer::public_transfer<Coin<SUI>>(remain, sender);
     // Mint the NFT
     let token_name = utf8(TOKEN_NAME_PREFIX);
     let token_id = u64_to_str(minting_treasury.current_mint + 1);
     string::append(&mut token_name, token_id);
     let nft = mint(
          token_name, 
          utf8(TOKEN_DESCRIPTION), 
          url::new_unsafe_from_bytes(TOKEN_URL), 
          utf8(b"level_one"), 
          ctx
     );
     // Transfer the NFT to sender
     transfer::transfer(nft, sender);
     // Increase the current_mint to 1
     minting_treasury.current_mint = minting_treasury.current_mint + 1;
     user_info.is_mint = true;
     // Destroy zero fee balance
     coin::destroy_zero(fee);
   }

   /// Privileged mint a S6kTestNFT to an account 
   public fun owner_mint_to_account(
      _: &MinterCap,
      name: vector<u8>,
      description: vector<u8>,
      url: vector<u8>,
      receipient: address,
      level: vector<u8>,
      ctx: &mut TxContext
    ) {
      let nft = mint(
          utf8(name), 
          utf8(description), 
          url::new_unsafe_from_bytes(url), 
          utf8(level), 
          ctx
     );
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
   public fun update_description(
        nft: &mut S6kTestNFT,
        new_description: vector<u8>,
   
        _: &mut TxContext
   ) {
        nft.description = utf8(new_description)
   }

   /// Permanently delete `nft`
   public fun burn(nft: S6kTestNFT) {
        let S6kTestNFT { id, name: _, description: _, image_url: _, creator: _, level: _} = nft;
        object::delete(id)
   }

   /// Permanently delete `minterCap`
   public fun burn_cap(cap: MinterCap) {
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

   /// Transfer minter cap
   public fun transfer_minter_cap(
     cap: MinterCap, 
     minting_treasury: &mut MintingTreasury, 
     ctx: &mut TxContext
     ) {
     let sender = tx_context::sender(ctx);
     transfer::transfer(cap, sender);
     minting_treasury.beneficiary = sender;
   }

   /// Set the max total nft available for minting
   public fun set_max_total_mints(
     _: &MinterCap, 
     minting_treasury: &mut MintingTreasury, 
     max_total: u64
     ) {
     if(minting_treasury.current_mint != 0){
          assert!(max_total > minting_treasury.current_mint, EMaxTotalMintNotGtCurrentMint);
     } else {
          assert!(max_total > MIN_OF_MAX_TOTAL_MINTS, EInvalidMaxTotalMint);
     };
     
     minting_treasury.max_total = max_total;
   }

   public fun set_due_time(
     _: &MinterCap, 
     minting_treasury: &mut MintingTreasury,
     clock: &Clock, 
     due_timestamp_ms: u64
   ){
     assert!(
          due_timestamp_ms > clock::timestamp_ms(clock), EDueTimeNotValid
     );
     minting_treasury.due_time = due_timestamp_ms;
   }
   fun u64_to_str(value: u64): String {
     let buffer = vector::empty<u8>();
     while( value / 10 > 0){
          vector::push_back(&mut buffer, ((48 + value % 10) as u8));
          value = value / 10;
     };
     vector::push_back(&mut buffer, ((value + 48) as u8));
     vector::reverse<u8>(&mut buffer);
     utf8(buffer)
   }
   #[test_only] 
   public fun init_for_testing(ctx: &mut TxContext) { init(NFT{}, ctx) } 
}