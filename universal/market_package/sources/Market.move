// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module market_package::market {
  use market_package::marketplace::{ Self, MarketPlace };
  use market_package::utils;
  use kiosk_policies::royalty_rule;
  use sui::balance;
  use sui::coin::{ Self, Coin };
  use sui::dynamic_field;
  use sui::event;
  use sui::object::{ Self, ID, UID };
  use sui::sui::SUI;
  use sui::transfer;
  use sui::transfer_policy::{ Self, TransferPolicy };
  use sui::tx_context::{ TxContext, sender };
  use version_package::version::{ Version };

  const EDoNotHaveRoyalty: u64 = 0;
  const EInvalidPrice: u64 = 1;
  const ESenderIsNotAllowed: u64 = 2;
  const EListingNotExist: u64 = 3;

  struct Item has copy, drop, store {
    id: ID
  }
  struct Listing<phantom T> has store, key {
    id: UID,
    nft: ID,
    seller: address,
    price: u64,
    market_id: ID,
    does_royalty: bool
  }
  struct ListEvent<phantom T> has copy, drop {
    seller: address,
    listing_id: ID,
    nft_id: ID,
    price: u64,
    marketplace: ID,
    does_royalty: bool
  }
  struct DelistEvent<phantom T> has copy, drop {
    seller: address,
    listing_id: ID,
    nft_id: ID,
    marketplace: ID
  }
  struct ChangePriceEvent<phantom T> has copy, drop {
    seller: address,
    listing_id: ID,
    nft_id: ID,
    marketplace: ID,
    old_price: u64,
    new_price: u64
  }
  struct BuyEvent<phantom T> has copy, drop {
    seller: address,
    buyer: address,
    listing_id: ID,
    nft_id: ID,
    marketplace: ID,
    price: u64
  }
  public fun list_generic<T1: store + key, T2>(
    version: &Version, 
    nft: T1, 
    listing_price: u64, 
    marketplace: &MarketPlace<T2>, 
    does_royalty: bool, 
    ctx: &mut TxContext
  ) {
    utils::check_version(version);
    assert!(listing_price > 0, EInvalidPrice);
    let nft_id = *object::borrow_id<T1>(&nft);
    let market_id = *object::borrow_id<MarketPlace<T2>>(marketplace);
    let sender = sender(ctx);
    let listing = Listing<T2> {
      id: object::new(ctx),
      nft: nft_id,
      seller: sender,
      price: listing_price,
      market_id,
      does_royalty
    };
    dynamic_field::add<Item, T1>(
      &mut listing.id,
      Item {
        id: nft_id
      },
      nft
    );
    let listing_id = *object::borrow_id<Listing<T2>>(&listing);
    transfer::public_share_object<Listing<T2>>(listing);
    event::emit(ListEvent<T2>{
      seller: sender,
      listing_id,
      nft_id,
      price: listing_price,
      marketplace: market_id,
      does_royalty
    });
  }
  public fun delist_generic<T1: store + key, T2>(
    version: &Version,
    listing: &mut Listing<T2>,
    ctx: &mut TxContext
  ){
    utils::check_version(version);
    assert!(sender(ctx) == listing.seller, ESenderIsNotAllowed);
    let seller = listing.seller;
    transfer::public_transfer(
      dynamic_field::remove<Item, T1>(
        &mut listing.id, 
        Item { id: listing.nft }
      ),
      seller
    );
    event::emit(
      DelistEvent<T2> {
        seller,
        listing_id: *object::borrow_id<Listing<T2>>(listing),
        nft_id: listing.nft,
        marketplace: listing.market_id
      }
    );
  }

  public fun buy_generic_with_price<T1: store + key, T2>(
    version: &Version,
    listing: &mut Listing<T2>,
    buy_price: u64,
    marketplace: &mut MarketPlace<T2>,
    paid: Coin<T2>,
    ctx: &mut TxContext
  ): Coin<T2> {
    utils::check_version(version);
    assert!(!listing.does_royalty, EDoNotHaveRoyalty);
    assert!(buy_price == listing.price, EInvalidPrice);
    let seller = listing.seller;
    let sender = sender(ctx);
    assert!(seller != sender, ESenderIsNotAllowed);
    let origin_balance = coin::balance_mut<T2>(&mut paid);
    let market_fee = marketplace::calc_market_fee<T2>(marketplace, listing.price);
    marketplace::deposit_profit<T2>(
      marketplace,
      balance::split<T2>(
        origin_balance,
        market_fee
      )
    );
    let net_price = listing.price - market_fee;
    transfer::public_transfer(
      coin::take<T2>(origin_balance, net_price, ctx),
      seller
    );
    transfer::public_transfer(
      dynamic_field::remove<Item, T1>(
        &mut listing.id, 
        Item { id: listing.nft }
      ),
      sender
    );
    event::emit(
      BuyEvent<T2> {
        seller,
        buyer: sender,
        listing_id: *object::borrow_id<Listing<T2>>(listing),
        nft_id: listing.nft,
        marketplace: listing.market_id,
        price: listing.price
      }
    );
    paid
  }

  public fun buy_generic<T1: store + key, T2>(
    version: &Version,
    _listing: &mut Listing<T2>,
    _marketplace: &mut MarketPlace<T2>,
    paid: Coin<T2>,
    _ctx: &mut TxContext
  ): Coin<T2> {
    utils::check_version(version);
    paid
  }

  public fun buy_with_sui<T: store + key>(
    version: &Version,
    _policy: &mut TransferPolicy<T>,
    _listing: &mut Listing<SUI>,
    _marketplace: &mut MarketPlace<SUI>,
    paid_with_sui: Coin<SUI>,
    _ctx: &mut TxContext
  ): Coin<SUI> {
    utils::check_version(version);
    paid_with_sui
  }

  public fun buy_with_sui_with_price<T: store + key>(
    version: &Version,
    policy: &mut TransferPolicy<T>,
    listing: &mut Listing<SUI>,
    buy_price: u64,
    marketplace: &mut MarketPlace<SUI>,
    paid_with_sui: Coin<SUI>,
    ctx: &mut TxContext
  ): Coin<SUI> {
    utils::check_version(version);
    assert!(buy_price == listing.price, EInvalidPrice);
    assert!(!listing.does_royalty, EDoNotHaveRoyalty);
    let seller = listing.seller;
    let sender = sender(ctx);
    assert!(seller != sender, ESenderIsNotAllowed);
    let origin_balance = coin::balance_mut<SUI>(&mut paid_with_sui);
    let market_fee = marketplace::calc_market_fee<SUI>(marketplace, listing.price);
    let loyalty_fee = royalty_rule::fee_amount<T>(policy, listing.price);
    let paid_loyalty = coin::take<SUI>(
      origin_balance,
      loyalty_fee,
      ctx
    );
    let new_transfer_request = transfer_policy::new_request<T>(
      listing.nft,
      listing.price,
      listing.nft
    );
    royalty_rule::pay<T>(
      policy,
      &mut new_transfer_request,
      paid_loyalty
    );
    transfer_policy::confirm_request<T>(
      policy,
      new_transfer_request
    );
    marketplace::deposit_profit<SUI>(
      marketplace,
      balance::split<SUI>(
        origin_balance,
        market_fee
      )
    );
    let net_price = listing.price - market_fee - loyalty_fee;
    transfer::public_transfer<Coin<SUI>>(
      coin::take<SUI>(
        origin_balance,
        net_price,
        ctx
      ),
      seller
    );
    transfer::public_transfer(
      dynamic_field::remove<Item, T>(
        &mut listing.id, 
        Item { id: listing.nft }
      ),
      sender
    );
    event::emit(
      BuyEvent<SUI> {
        seller,
        buyer: sender,
        listing_id: *object::borrow_id<Listing<SUI>>(listing),
        nft_id: listing.nft,
        marketplace: listing.market_id,
        price: listing.price
      }
    );
    paid_with_sui
  }

  public entry fun change_price<T>(
    version: &Version,
    listing: &mut Listing<T>,
    new_price: u64,
    ctx: &mut TxContext
  ) {
    utils::check_version(version);
    let sender = sender(ctx);
    assert!( sender == listing.seller, ESenderIsNotAllowed);
    assert!( new_price > 0, EInvalidPrice);
    assert!( 
      dynamic_field::exists_<Item>(&listing.id, Item{ id: listing.nft }), EListingNotExist
    );
    let old_price = listing.price;
    listing.price = new_price;
    event::emit(
      ChangePriceEvent<T> {
        seller: listing.seller,
        listing_id: *object::borrow_id<Listing<T>>(listing),
        nft_id: listing.nft,
        marketplace: listing.market_id,
        old_price,
        new_price
      }
    );
  }



}