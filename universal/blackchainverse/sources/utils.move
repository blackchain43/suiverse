// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0


module blackchainverse::utils {
  use std::ascii;
  use std::type_name;
  use sui::address;
  use sui::hex;
  use version_package::version::{ Self, Version };

  const EVersionMisMatch: u64 = 0;
  struct UTILS has drop {}

  public fun from_same_package<T1, T2>(): bool {
    let first_type = type_name::get<T1>();
    let second_type = type_name::get<T2>();
    type_name::get_address(&first_type) == type_name::get_address(&second_type)
  }

  public fun check_version(version: &Version){
    let current_package_address = address::from_bytes(
      hex::decode(
        *ascii::as_bytes(
          &type_name::get_address(
            &type_name::get<UTILS>()
            )
          )
        )
      );
    assert!(
      version::get(version, current_package_address) == 0,
      EVersionMisMatch
    );
  }  
}