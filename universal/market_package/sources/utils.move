// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module market_package::util {
  use std::ascii;
  use std::type_name;
  use sui::address;
  use sui::hex;
  use sui::package::{Self, Publisher};
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use version_package::version::{Self, Version};

  struct UTILS has drop {}
  const EVersionMismatch: u64 = 0;

  fun init(otw: UTILS, ctx: &mut TxContext){
    transfer::public_transfer(
      package::claim<UTILS>(otw, ctx),
      tx_context::sender(ctx)
    );
  }

  public fun check_version(version: &Version){
    let utils_type_name = type_name::get<UTILS>();
    let utils_package_address = address::from_bytes(hex::decode(*ascii::as_bytes(&type_name::get_address(&utils_type_name))));
    assert!(
      version::get(version, utils_package_address) == 2, EVersionMismatch
    );
  }

  public fun new_version(
    publisher: &Publisher,
    version: &mut Version,
    _ctx: &mut TxContext
  ) {
    version::add(publisher, version);
  }
  public fun set_version(
    publisher: &Publisher,
    version: &mut Version,
    version_value: u64,
    _ctx: &mut TxContext
  ){
    version::set(publisher, version, version_value);
  }
}