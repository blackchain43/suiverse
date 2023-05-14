// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module blackchainverse::blackchain {
  use std::vector;
  use sui::address;
  use sui::package;
  use sui::transfer;
  use sui::object::{Self, UID};
  use std::string::{utf8, String};
  use sui::vec_map::{Self, VecMap};
  use sui::display::{Self, Display};
  use sui::tx_context::{TxContext};
  use blackchainverse::utils::{check_version, from_same_package};
  use version_package::version::Version;
  use sui::package::Publisher;
  use sui::tx_context;
  use version_package::version;
  use nft_protocol::mint_cap::MintCap;
  use sui::transfer_policy;
  use sui::transfer::{public_share_object, public_transfer};
  use kiosk_policies::royalty_rule;

  /// Constants
  const PUBLISHER: address = @0xff29c1854f97ddd25745959f692e5544f907cd974a3e249f0dabed21173acbed;

  /// Error codes
  const ENotAdmin: u64 = 0;
  const ENotAllowed: u64 = 1;
  const ENotAllowedToMutate: u64 = 2;


  struct NFT<phantom T> has store, key {
    id: UID,
    index: u64,
    name: String,
    image_url: String,
    properties: VecMap<String, String>
  }
  struct SharedPublisher has store, key {
	  id: UID,
	  publisher: Publisher
  }
  struct BLACKCHAINVERSE has drop {}

  fun init(otw: BLACKCHAINVERSE, ctx: &mut TxContext){
    let publisher = package::claim<BLACKCHAINVERSE>(otw, ctx);
    transfer::public_share_object(SharedPublisher {
      id: object::new(ctx),
      publisher,
    });
  }

  public fun create_display<NFT_TYPE>(
    version: &Version, 
    _: &MintCap<NFT_TYPE>, 
    shared_publisher: &SharedPublisher,
    ctx: &mut TxContext
  ): Display<NFT<NFT_TYPE>> {
    check_version(version);
    let display = display::new<NFT<NFT_TYPE>>(
      &shared_publisher.publisher,
      ctx
    );
    display::add(
      &mut display, 
      utf8(b"name"), 
      utf8(b"{name}")
    );
    display::add(
      &mut display, 
      utf8(b"image_url"), 
      utf8(b"{image_url}")
    );
    display::add(
      &mut display, 
      utf8(b"thumbnail_url"), 
      utf8(b"{image_url}")
    );
    display::update_version(&mut display);
    display
  }

  public fun mutate_name_and_image_url<NFT_TYPE, WITNESS: drop>(
    _witness: WITNESS, 
    nft: &mut NFT<NFT_TYPE>, 
    new_name: String, 
    new_image_url: String
  ) {
    assert!(from_same_package<NFT_TYPE, WITNESS>(), ENotAllowedToMutate);
    nft.name = new_name;
    nft.image_url = new_image_url;
  }

  fun publisher_borrow(shared_publisher: &SharedPublisher): &Publisher {
    &shared_publisher.publisher
  }

  public fun burn<NFT_TYPE, WITNESS: drop>(
    _witness: WITNESS, 
    nft: NFT<NFT_TYPE>,
  ) {
    assert!(from_same_package<NFT_TYPE, WITNESS>(), ENotAllowed);
    let NFT<NFT_TYPE>{ id , index: _, name: _, image_url: _, properties: _} = nft;
    object::delete(id);
  }

  public fun set_version(
    shared_publisher: &SharedPublisher,
    version: &mut Version,
    new_version: u64,
    ctx: &mut TxContext
  ) {
    assert!(tx_context::sender(ctx) == PUBLISHER, ENotAdmin);
    version::set(publisher_borrow(shared_publisher), version, new_version);
  }

  public fun new_version(
    shared_publisher: &SharedPublisher,
    version: &mut Version,
    ctx: &mut TxContext
  ) {
    assert!(tx_context::sender(ctx) == PUBLISHER, ENotAdmin);
    version::add(publisher_borrow(shared_publisher), version);
  }

  public fun set_collection_info<NFT_TYPE>(
    version: &Version,
    nft_display: &mut Display<NFT<NFT_TYPE>>,
    collection_name: String,
    cover_image_url: String,
    symbol: String,
    description: String,
    creator: address,
    _ctx: &mut TxContext
  ) {
    check_version(version);
    display::add<NFT<NFT_TYPE>>(nft_display, utf8(b"collection_name"), collection_name);
    display::add<NFT<NFT_TYPE>>(nft_display, utf8(b"collection_image"), cover_image_url);
    display::add<NFT<NFT_TYPE>>(nft_display, utf8(b"symbol"), symbol);
    display::add<NFT<NFT_TYPE>>(nft_display, utf8(b"description"), description);
    display::add<NFT<NFT_TYPE>>(nft_display, utf8(b"creator"), address::to_string(creator));
    display::update_version<NFT<NFT_TYPE>>(nft_display); 
  }

  public fun mint_nft_with_cap<NFT_TYPE>(
    version: &Version,
    index: u64, 
    name: String, 
    image_url: String, 
    _mint_cap: &MintCap<NFT_TYPE>, 
    property_keys: vector<String>, 
    property_values: vector<String>,
    ctx: &mut TxContext,
  ): NFT<NFT_TYPE> {
    check_version(version);
    let len = vector::length(&property_keys);
    assert!(
      len == vector::length(&property_values),
      ENotAllowed
    );
    let properties = vec_map::empty<String, String>();
    let i = 0;
    while (i < len) {
      let key = vector::pop_back(&mut property_keys);
      let val = vector::pop_back(&mut property_values);
      vec_map::insert<String, String>(&mut properties, key, val);
      i = i + 1;
    };
    let nft = NFT<NFT_TYPE> {
      id: object::new(ctx),
      index,
      name,
      image_url,
      properties,
    };
    nft
  }

  public entry fun create_then_set_display_and_transfer_policy_then_royalty_rule<T>(
        version: &Version,
        cap: &MintCap<T>,
        publisher: &SharedPublisher,
        display_name: String,
        display_value: String,
        royalty_bps: u16,
        royalty_min_amount: u64,
        ctx: &mut TxContext
    ) {

        check_version(version);
        let sender = tx_context::sender(ctx);
        let display = create_display(version, cap, publisher, ctx);
        display::add<NFT<T>>(&mut display, display_name, display_value);
        display::update_version(&mut display);
        let (policy, policy_cap) = transfer_policy::new<NFT<T>>(&publisher.publisher, ctx);
        royalty_rule::add(&mut policy, &mut policy_cap, royalty_bps, royalty_min_amount);

        public_share_object(policy);
        public_transfer(display, sender);
        public_transfer(policy_cap, sender);

  }
  public entry fun create_then_set_display_and_transfer_policy_then_royalty_rule_v1<T>(
        version: &Version,
        cap: &MintCap<T>,
        publisher: &SharedPublisher,
        collection_name: String,
        cover_image_url: String,
        symbol: String,
        description: String,
        creator: address,
        display_name: String,
        display_value: String,
        royalty_bps: u16,
        royalty_min_amount: u64,
        ctx: &mut TxContext
    ) {

        check_version(version);
        let sender = tx_context::sender(ctx);
        let display = create_display(version, cap, publisher, ctx);
        set_collection_info(
            version,
            &mut display,
            collection_name,
            cover_image_url,
            symbol,
            description,
            creator,
            ctx
        );
        display::add<NFT<T>>(&mut display, display_name, display_value);
        let (policy, policy_cap) = transfer_policy::new<NFT<T>>(&publisher.publisher, ctx);
        royalty_rule::add(&mut policy, &mut policy_cap, royalty_bps, royalty_min_amount);

        public_share_object(policy);
        public_transfer(display, sender);
        public_transfer(policy_cap, sender);

    }
}