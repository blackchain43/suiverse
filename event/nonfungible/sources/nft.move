// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module nonfungible::nft{
   use std::string::{Self, utf8, String, bytes};
   use std::vector;
   use std::fixed_point32::{ FixedPoint32, create_from_rational, multiply_u64 };
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
  
   friend nonfungible::factory;

   const U64_MAX: u64 = 18446744073709551615;
   const MIN_OF_MAX_TOTAL_MINTS: u64 = 1;
   const TOKEN_NAME_PREFIX: vector<u8> = b"XWorry NFT #";
   const TOKEN_URL: vector<u8> = b"https://img-08.stickers.cloud/packs/787053f4-0bd6-45f0-9a58-715b54913177/webp/ce810738-214d-4b3b-ab2f-aead08c5f7f8.webp";
   const TOKEN_DESCRIPTION: vector<u8>  = b"$XWORRY The biggest airdrop on SUI mainnet";
   const MINT_REF_PERCENT_DENUMERATOR: u64 = 1000;

   const EInsufficientBalance: u64 = 0;
   const EMintEventEnd: u64 = 1;
   const ELevelInfoNotSet: u64 = 2;
   const ELevelInfoExists: u64 = 3;
   const EInvalidMaxTotalMint: u64 = 4;
   const EUserAlreadyMinted: u64 = 5;
   const EDueTimeNotValid: u64 = 6;
   const EMaxTotalMintNotGtCurrentMint: u64 = 7;
   const ENumMustGtZero: u64 = 8;
   const EMaxTotalMintIsReached: u64 = 9;
   const ERefPercentInvalid: u64 = 10;
   const ENotAllowSelfRef: u64 = 11;
   const ENotAdmin: u64 = 12;
   

   /// Type that marks the capability to mint new XYZNFT's.
   struct MinterCap has key { id: UID }

    /// Event marking when a XYZNFT has been minted
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

   struct LevelInfoKey<phantom T> has store, copy, drop {
     level_name: vector<u8>
   }

   struct LevelInfoValue<phantom T> has store, copy, drop {
     mint_price: u64,
     level_value: u64,
     next_level_value: u64,
     next_level_name: vector<u8>,
     rarity_numerator: u64,
     rarity_denumerator: u64,
   }
   struct UserInfo has store {
     is_mint: bool
     }

   /// An example NFT that can be minted by anybody
   struct XYZNFT has key, store {
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
     balance: Balance<SUI>,
     mint_ref_percent: FixedPoint32,
     ref_pool_balance: Balance<SUI>,
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
            utf8(b"https://abc.xyz"),
            utf8(b"{image_url}"),
            utf8(b"{description}"),
            utf8(b"https://abc.xyz"),
            utf8(b"{creator}"),
        ];

     let nft_display = display::new_with_fields<XYZNFT>(
            &publisher, nft_keys, nft_values, ctx
        );
     let minting_treasury = MintingTreasury {
            id: object::new(ctx),
            balance: balance::zero<SUI>(),
            beneficiary: sender,
            current_mint: 0,
            max_total: U64_MAX,
            due_time: 0,
            mint_ref_percent: create_from_rational(0, MINT_REF_PERCENT_DENUMERATOR),
            ref_pool_balance: balance::zero<SUI>()
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
   ): XYZNFT {

      let sender = tx_context::sender(ctx);

      let nft = XYZNFT {
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

   /// Add level price info
   public(friend) fun add_level_price_info<T>(
     _:&MinterCap, 
     treasury: &mut MintingTreasury, 
     mint_price: u64, 
     level_name: vector<u8>,
     level_value: u64,
     next_level_name: vector<u8>,
     rarity_numerator: u64,
     rarity_denumerator: u64,
     ) {
          assert!(
               mint_price > 0 && rarity_numerator > 0 && rarity_denumerator > 0 && level_value > 0 && rarity_denumerator >= rarity_numerator, 
               ENumMustGtZero
          );
          assert!(
               !field::exists_with_type<LevelInfoKey<T>, LevelInfoValue<T>>(
                    &treasury.id, 
                    LevelInfoKey<T> { level_name }
               ), 
               ELevelInfoExists
          );
          field::add(
               &mut treasury.id, 
               LevelInfoKey<T>{ level_name },  
               LevelInfoValue<T>{
                    level_value,
                    mint_price,
                    next_level_name, 
                    next_level_value: level_value + 1,
                    rarity_numerator,
                    rarity_denumerator
               }
          );
     }

   /// Edit level price info
   public(friend) fun edit_level_price_info<T>(
     _:&MinterCap, 
     minting_treasury: &mut MintingTreasury, 
     mint_price: u64,
     level_name: vector<u8>,
     level_value: u64,
     next_level_name: vector<u8>,
     rarity_numerator: u64,
     rarity_denumerator: u64,
   ) {
     assert!(
          mint_price > 0 && rarity_numerator > 0 && rarity_denumerator > 0 && level_value > 0 && rarity_denumerator >= rarity_numerator,
          ENumMustGtZero
     );
     assert!(
          field::exists_with_type<LevelInfoKey<T>, LevelInfoValue<T>>(
               &minting_treasury.id, 
               LevelInfoKey<T> { level_name }
          ), 
          ELevelInfoNotSet
     );
     *field::borrow_mut<LevelInfoKey<T>, LevelInfoValue<T>>(&mut minting_treasury.id, LevelInfoKey<T>{ level_name }) = LevelInfoValue<T> { 
          mint_price,
          level_value,
          next_level_name,
          next_level_value: level_value + 1,
          rarity_numerator,
          rarity_denumerator
     };
   }

   /// Delete level price info
   public(friend) fun delete_level_price_info<T>(
     _:&MinterCap, 
     minting_treasury: &mut MintingTreasury, 
     level_name: vector<u8>
   ) {
     assert!(
          field::exists_with_type<LevelInfoKey<T>, LevelInfoValue<T>>(
               &minting_treasury.id, 
               LevelInfoKey<T> { level_name }
          ), 
          ELevelInfoNotSet
     );
     field::remove<LevelInfoKey<T>, LevelInfoValue<T>>(&mut minting_treasury.id, LevelInfoKey<T> { level_name });
   }

   /// Get level price info
   public fun get_level_price_info<T>(
     minting_treasury: &MintingTreasury,
     level_name: vector<u8>
   ): LevelInfoValue<T> {
     assert!(
         field::exists_with_type<LevelInfoKey<T>, LevelInfoValue<T>>(
               &minting_treasury.id, 
               LevelInfoKey<T> { level_name }
          ), 
          ELevelInfoNotSet 
     );
     *field::borrow<LevelInfoKey<T>, LevelInfoValue<T>>(&minting_treasury.id, LevelInfoKey<T>{ level_name })
   }

   /// Get rarity probability from level info
   public fun get_level_info_probability<T>( level_info_value: &LevelInfoValue<T> ): FixedPoint32 {
     create_from_rational(level_info_value.rarity_numerator, level_info_value.rarity_denumerator)
   }

   /// Get next level name from given nft
   public fun get_nft_next_level_name<T>(
     nft: &XYZNFT,
     minting_treasury: &MintingTreasury
   ): vector<u8> {
     let level_price_info = get_level_price_info<T>(minting_treasury, *bytes(&nft.level));
     level_price_info.next_level_name
   }

   /// Get next level value from given nft
   public fun get_nft_next_level_value<T>(
     nft: &XYZNFT,
     minting_treasury: &MintingTreasury
   ): u64 {
     let level_price_info = get_level_price_info<T>(minting_treasury, *bytes(&nft.level));
     level_price_info.next_level_value
   }
   /// Get level mint price
   public fun get_level_mint_price<T>(
     level_info_value: &LevelInfoValue<T>
   ): u64 {
     level_info_value.mint_price
   }
   

   /// Paid public mint to an account
   public(friend) fun mint_to_account(
        minting_treasury: &mut MintingTreasury,
        clock: &Clock,
        fee: Coin<SUI>,
        ref_address: address,
        ctx: &mut TxContext
    ) {
     // Check if not exceed due_time
     assert!(
          clock::timestamp_ms(clock) <= minting_treasury.due_time, 
          EMintEventEnd
     );
     // Check if level_one price info exists
     assert!(
          field::exists_with_type<LevelInfoKey<SUI>, LevelInfoValue<SUI>>(
               &minting_treasury.id, 
               LevelInfoKey{ level_name : b"level_one" }
          ), 
          ELevelInfoNotSet
     );
     // Check if max_total is reached
     assert!(
         minting_treasury.max_total > minting_treasury.current_mint,
         EMaxTotalMintIsReached
     );
     let sender = sender(ctx);
     assert!(sender != ref_address, ENotAllowSelfRef);
     // Take the mint_fee of level_one price info
     let level_one_info = *field::borrow<LevelInfoKey<SUI>, LevelInfoValue<SUI>>(&minting_treasury.id, LevelInfoKey<SUI>{ level_name : b"level_one" });
     // Check if fee is sufficient
     assert!(
          coin::value(&fee) >= level_one_info.mint_price, 
          EInsufficientBalance
     );
     
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
     let remain_amount = balance::value(balance) - level_one_info.mint_price;
     let ref_amount = multiply_u64(level_one_info.mint_price, minting_treasury.mint_ref_percent);
     if(ref_address != @zero_ref && balance::value(&minting_treasury.ref_pool_balance) >= ref_amount){
          transfer::public_transfer<Coin<SUI>>(
               coin::take<SUI>(&mut minting_treasury.ref_pool_balance, ref_amount, ctx), 
               ref_address
          );
     };
     // Add a payment to the minting treasury balance
     balance::join(&mut minting_treasury.balance, balance::split(balance, level_one_info.mint_price));
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

   /// Free mint a XYZNFT to an account 
   public(friend) fun free_mint_to_account(
      minting_treasury: &mut MintingTreasury,
      clock: &Clock,
      ctx: &mut TxContext
    ) {
     // Check if not exceed due_time
     assert!(
          clock::timestamp_ms(clock) <= minting_treasury.due_time, 
          EMintEventEnd
     );
     // Check if level_one price info exists
     assert!(
          field::exists_with_type<LevelInfoKey<SUI>, LevelInfoValue<SUI>>(
               &minting_treasury.id, 
               LevelInfoKey{ level_name : b"level_one" }
          ), 
          ELevelInfoNotSet
     );
     // Check if max_total is reached
     assert!(
         minting_treasury.max_total > minting_treasury.current_mint,
         EMaxTotalMintIsReached
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
   }

   /// Withdraw SUI in MintingTreasury
   public(friend) fun collect_profits(
        _: &MinterCap,
        mintingtreasury: &mut MintingTreasury,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
     let sender = tx_context::sender(ctx);
     assert!(mintingtreasury.beneficiary == sender, ENotAdmin);
     let amount = balance::value(&mintingtreasury.balance);
     let profits = coin::take(&mut mintingtreasury.balance, amount, ctx);
     // if ref_pool_balance is not zero, then transfer to sender
     let ref_pool_balance_amount = balance::value(&mintingtreasury.ref_pool_balance);
     if(
          ref_pool_balance_amount > 0 && 
          clock::timestamp_ms(clock) > mintingtreasury.due_time
     ){
          let ref_pool_balance = coin::take(&mut mintingtreasury.ref_pool_balance, ref_pool_balance_amount, ctx);
          transfer::public_transfer(ref_pool_balance, sender);
     };
     transfer::public_transfer(profits, sender);
    }

   /// Update the `description` of `nft` to `new_description`
   public fun update_description(
        nft: &mut XYZNFT,
        new_description: vector<u8>,
        _: &mut TxContext
   ) {
        nft.description = utf8(new_description)
   }

   /// Permanently delete `nft`
   public fun burn(nft: XYZNFT) {
        let XYZNFT { id, name: _, description: _, image_url: _, creator: _, level: _} = nft;
        object::delete(id)
   }

   /// Permanently delete `minterCap`
   public fun burn_cap(cap: MinterCap) {
        let MinterCap { id } = cap;
        object::delete(id)
   }

   /// Get the NFT's `name`
   public fun name(nft: &XYZNFT): &String {
        &nft.name
    }

   /// Get the NFT's `description`
   public fun description(nft: &XYZNFT): &String {
        &nft.description    
    }

   /// Get the NFT's `url`
   public fun image_url(nft: &XYZNFT): &Url {
        &nft.image_url
   }

   /// Get the NFT's `creator`
   public fun creator(nft: &XYZNFT): &address {
        &nft.creator
   }

   /// Transfer minter cap
   public(friend) fun transfer_minter_cap(
     cap: MinterCap, 
     minting_treasury: &mut MintingTreasury, 
     ctx: &mut TxContext
     ) {
     let sender = tx_context::sender(ctx);
     transfer::transfer(cap, sender);
     minting_treasury.beneficiary = sender;
   }

   /// Set the max total nft available for minting
   public(friend) fun set_max_total_mints(
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

   public(friend) fun set_due_time(
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

   public(friend) fun set_mint_ref_percent(
     _: &MinterCap, 
     minting_treasury: &mut MintingTreasury,
     ref_percent: u64
   ){
     assert!(
          ref_percent < MINT_REF_PERCENT_DENUMERATOR && ref_percent > 0, 
          ERefPercentInvalid
     );
     minting_treasury.mint_ref_percent = create_from_rational(ref_percent, MINT_REF_PERCENT_DENUMERATOR);
   }
   public(friend) fun deposit_to_ref_pool(
     _: &MinterCap, 
     minting_treasury: &mut MintingTreasury,
     deposit: Coin<SUI>
   ){
     balance::join(&mut minting_treasury.ref_pool_balance, coin::into_balance(deposit));
   }

   public fun update_nft_to_next_level(
     nft: XYZNFT,
     next_level_name: vector<u8>,
     is_upgradable: bool,
     ctx: &mut TxContext 
   ) {
     let new_level_name = if(is_upgradable) {
          utf8(next_level_name)
     } else {
          nft.level
     };
     let new_nft = mint(nft.name, nft.description, nft.image_url, new_level_name, ctx);
     transfer::transfer(new_nft, tx_context::sender(ctx));
     burn(nft);
   }

   public fun get_beneficiary(
     minting_treasury: &MintingTreasury,
   ): address {
     minting_treasury.beneficiary
   }

   public fun get_nft_id(
     nft: &XYZNFT
   ): ID {
     object::uid_to_inner(&nft.id)
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