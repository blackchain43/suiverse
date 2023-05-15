// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module market_package::marketplace {
  use std::fixed_point32;
  use sui::balance::{Self, Balance};
  use sui::coin::{Self, Coin};
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID };
  use version_package::version::{ Version };
  use market_package::utils;

  const EBeneficiaryOrVersionNotMatch: u64 = 1;
  struct MarketPlace<phantom T> has store, key{
    id: UID,
	  beneficiary: address,
	  fee_bps: u64,
	  profit: Balance<T>
  }
  public entry fun create_market<T>(beneficiary: address, fee_bps: u64, ctx: &mut TxContext){
    transfer::public_share_object<MarketPlace<T>>(
      MarketPlace<T>{
        id: object::new(ctx),
        beneficiary: beneficiary,
        fee_bps: fee_bps,
        profit: balance::zero<T>()
      }
    );
  }

  public fun calc_market_fee<T>(marketplace: &MarketPlace<T>, price: u64): u64 {
    fixed_point32::multiply_u64(price, fixed_point32::create_from_rational(marketplace.fee_bps, 10000))
  }

  public fun get_beneficiary<T>(marketplace: &MarketPlace<T>): address {
    marketplace.beneficiary
  }

  public fun get_profit<T>(marketplace: &MarketPlace<T>): u64 {
    balance::value(&marketplace.profit)
  }

  public fun deposit_profit<T>(marketplace: &mut MarketPlace<T>, amount: Balance<T>) {
    balance::join(&mut marketplace.profit, amount);
  } 

  public fun withdraw_profit<T>(version: &Version, marketplace: &mut MarketPlace<T>, amount: u64, ctx: &mut TxContext): Coin<T> {
    utils::check_version(version);
    assert!(tx_context::sender(ctx) == marketplace.beneficiary, EBeneficiaryOrVersionNotMatch);
    coin::from_balance<T>(
      balance::split(&mut marketplace.profit, amount), 
      ctx
    )
  }
}