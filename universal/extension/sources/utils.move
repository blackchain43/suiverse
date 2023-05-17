// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module extension::utils{
  
  struct Marker<phantom T1, phantom T2> has copy, drop, store {}

  public fun marker<T1, T2>(): Marker<T1, T2> {
    Marker<T1, T2>{}
  }
}