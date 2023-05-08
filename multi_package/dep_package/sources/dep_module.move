// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module dep_package::dep_module {

    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::table::{Self, Table};

    const EAddressInWhitelist: u64 = 0;
    const EAddressNotInWhitelist: u64 = 1;

    struct AdminCap has key { id: UID }

    struct WhiteList has key { 
        id: UID,
        data: Table<address, bool>,
    }

    fun init(ctx: &mut TxContext){

        let sender = tx_context::sender(ctx);

        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, sender);

        transfer::share_object(
            WhiteList {
                id: object::new(ctx),
                data: table::new<address, bool>(ctx)
            }
        );    
    }

    public entry fun add_to_whitelist(
        _: &AdminCap, 
        whitelist: &mut WhiteList, 
        wallet_address: address,
        _ctx: &mut TxContext,
    ) 
    {
        // Check if the wallet address is already in the whitelist
        assert!(
            !table::contains(&whitelist.data, wallet_address), EAddressInWhitelist
        );
        table::add(&mut whitelist.data, wallet_address, true);
    }

    public entry fun remove_from_whitelist(
       _: &AdminCap, 
       whitelist: &mut WhiteList, 
       wallet_address: address,
       _ctx: &mut TxContext, 
    )
    {
        // Check if the wallet address is already in the whitelist
        assert!(
            table::contains(&whitelist.data, wallet_address), EAddressNotInWhitelist
        );
        table::remove(&mut whitelist.data, wallet_address);
    }

    public fun is_whitelisted(
        whitelist: &WhiteList, 
        wallet_address: address,
        _ctx: &mut TxContext, 
    ): bool
    {
        table::contains(&whitelist.data, wallet_address)
    }

}
