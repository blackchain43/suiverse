module governance::utils {
  use std::type_name;
  use std::ascii;
  const MAX_U_128: u256 = 1340282366920938463463374607431768211455;
  const MAX_U_64: u64 = 18446744073709551615;

  public fun get_type_name<T>(): vector<u8> {
      let name = type_name::into_string(type_name::get<T>());
      ascii::into_bytes(name)
  }

  public fun max_u_128(): u256 {
      MAX_U_128
  }

  public fun max_u_64(): u64 {
      MAX_U_64
  }

}