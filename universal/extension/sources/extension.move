// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module extension::extension{
  use extension::tax::{ Self, Tax };
  use extension::utils::{ Self, Marker };
  use sui::dynamic_field::{ Self as field };
  use sui::object::{ Self, UID };
  use sui::package::{ Self, Publisher };
  use sui::transfer::{ public_transfer, public_share_object };
  use sui::tx_context::{ TxContext, sender };

  const ENotPublisher: u64 = 1;
  const ETaxConfigExists: u64 = 2;
  const ETaxConfigNotExists: u64 = 3;

  struct Extension has store, key {
    id: UID
  }

  struct EXTENSION has drop {}

  fun init(otw: EXTENSION, ctx: &mut TxContext) {
    let publisher = package::claim<EXTENSION>(otw, ctx);
    public_transfer(
      publisher,
      sender(ctx)
    );
    public_share_object(
      Extension { id: object::new(ctx) }
    );
  }

  public fun add_tax_config<T>(
    publisher: &Publisher, 
    extension: &mut Extension, 
    tax_receiver: address, 
    royalty: u64, 
    penalty_ratio: u64, 
    min_price: u64
  ) {
    assert!(
      package::from_package<EXTENSION>(publisher),
      ENotPublisher
    );
    assert!(
      !field::exists_with_type<Marker<T, Tax<T>>, Tax<T>>(
        &extension.id,
        utils::marker<T, Tax<T>>()
      ),
      ETaxConfigExists
    );
    let tax_config = tax::new_tax<T>(
      tax_receiver, 
      royalty, 
      penalty_ratio, 
      min_price
    );
    field::add<Marker<T, Tax<T>>, Tax<T>>(
      &mut extension.id,
      utils::marker<T, Tax<T>>(),
      tax_config
    );
  }
  public fun remove_tax_config<T>(publisher: &Publisher, extension: &mut Extension) {
    assert!(
      package::from_package<EXTENSION>(publisher),
      ENotPublisher
    );
    assert!(
      field::exists_with_type<Marker<T, Tax<T>>, Tax<T>>(
        &extension.id,
        utils::marker<T, Tax<T>>()
      ),
      ETaxConfigNotExists
    );
    field::remove<Marker<T, Tax<T>>, Tax<T>>(
      &mut extension.id,
      utils::marker<T, Tax<T>>()
    );
  }
  public fun calc_tax<T>(extension: &Extension, price: u64): (bool, u64 , address) {
    let is_taxed: bool;
    let tax_amount: u64;
    let tax_receiver: address;
    if(
      !field::exists_with_type<Marker<T, Tax<T>>, Tax<T>>(
        &extension.id,
        utils::marker<T, Tax<T>>()
      )
    ){
      is_taxed = false;
      tax_amount = 0;
      tax_receiver = @admin;
    } else {
      let tax_config = field::borrow<Marker<T, Tax<T>>, Tax<T>>(&extension.id, utils::marker<T, Tax<T>>());
      (is_taxed, tax_amount) = tax::calc_tax<T>(tax_config, price);
      tax_receiver = tax::get_beneficiary<T>(tax_config);
    };
    (is_taxed, tax_amount, tax_receiver)
  }
}