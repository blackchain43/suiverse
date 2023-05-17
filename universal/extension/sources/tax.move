// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module extension::tax{

  const BASE_DENUMERATOR: u64 = 10000;

  struct Tax<phantom T> has copy, drop, store {
    tax_receiver: address,
    royalty: u64,
    penalty_ratio: u64,
    min_price: u64
  }

  public fun new_tax<T>(
    tax_receiver: address,
    royalty: u64,
    penalty_ratio: u64,
    min_price: u64
  ): Tax<T> {
    Tax<T> {
      tax_receiver,
      royalty,
      penalty_ratio,
      min_price
    }
  }

  public fun calc_tax<T>(
    tax: &Tax<T>,
    price: u64
  ): (bool, u64) {
    let is_penalty: bool;
    let tax_amount: u64;
    if(is_available(tax, price)){
      tax_amount = tax.penalty_ratio * price / BASE_DENUMERATOR;
      is_penalty = true;
    } else {
      tax_amount = tax.royalty * price / BASE_DENUMERATOR;
      is_penalty = false;
    };
    (is_penalty, tax_amount)
    
  }
  public fun get_beneficiary<T>(tax: &Tax<T>): address {
    tax.tax_receiver
  }

  public fun get_tax_ratio<T>(tax: &Tax<T>): u64 {
    tax.penalty_ratio
  }

  public fun is_available<T>(tax: &Tax<T>, price: u64): bool {
    tax.min_price >= price
  }
}