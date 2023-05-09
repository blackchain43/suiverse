// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module version_package::version {
  use std::ascii;
  use std::type_name;
  use sui::address;
  use sui::hex::{Self};
  use sui::package::{Self, Publisher};
  use sui::transfer::{Self};
  use sui::tx_context::{TxContext};
  use sui::table::{Self, Table};
  use sui::object::{Self, UID};

  struct VERSION has drop {}

  struct Version has key {
	  id: UID,
	  versions: Table<address, u64>
  }

  fun init(otw: VERSION, ctx: &mut TxContext){
    package::claim_and_keep(otw, ctx);
    let version = Version{
      id: object::new(ctx),
      versions: table::new<address, u64>(ctx)
    };
    transfer::share_object(version);
  }

  public entry fun add(
    publisher: &Publisher,
    version: &mut Version,
  ) {
    let package_address = address::from_bytes(hex::decode(*ascii::as_bytes(package::published_package(publisher))));
    table::add<address, u64>(&mut version.versions, package_address, 0);
  }
  
  public entry fun set(
    publisher: &Publisher,
    version: &mut Version,
    value: u64,
  ) {
    let package_address = address::from_bytes(hex::decode(*ascii::as_bytes(package::published_package(publisher))));
    *table::borrow_mut<address, u64>(&mut version.versions, package_address) = value;
  }

  public fun get_by_T<T>(
    version: &Version,
  ): u64 {
    let ref_version = version;
    let version_type = type_name::get<T>();
    let version_type_address = type_name::get_address(&version_type);
    get(ref_version, address::from_bytes(hex::decode(*ascii::as_bytes(&version_type_address))))
  }

  public fun get(
    version: &Version,
    type_address: address,
  ): u64 {
    *table::borrow<address, u64>(&version.versions, type_address)
  }

  public fun borrow_mut(
    publisher: &Publisher,
    version: &mut Version,
  ): &mut u64 {
    let package_address = address::from_bytes(hex::decode(*ascii::as_bytes(package::published_package(publisher))));
    table::borrow_mut<address, u64>(&mut version.versions, package_address)
  }

  public fun contains(
    version: &Version,
    package_address: address,
  ): bool{
    table::contains<address, u64>(&version.versions, package_address)
  }
}