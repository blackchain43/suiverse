// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module market_package::utils {
  use std::ascii;
  use std::type_name;
  use sui::address;
  use sui::hex;
  use sui::package;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use version_package::version;

  struct UTILS has drop {}

  fun init(otw: UTILS, ctx: &mut TxContext){
    transfer::public_transfer(
      package::claim<UTILS>(otw, ctx),
      tx_context::sender(ctx)
    );
  }
}