// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module main_package::main_module {
    use dep_package::dep_module::{Self, WhiteList};
    use nonfungible::nft::{Self, MintingTreasury};
    use sui::tx_context::{TxContext, sender};
    use sui::coin::{Coin};
    use sui::sui::SUI;

    const EAddressNotInWhitelist: u64 = 0;
    public entry fun claim(
        mintingtreasury: &mut MintingTreasury,
        whitelist: &WhiteList,
        fee: Coin<SUI>,
        ctx: &mut TxContext
    ){
        let sender = sender(ctx);

        //check whitelist
        assert!(dep_module::is_whitelisted(whitelist, sender, ctx), EAddressNotInWhitelist);

        //mint nft
        nft::mint_to_account(
            mintingtreasury,
            b"Worry Pepe",
            b"Worry Pepe NFT On Sui",
            b"https://img-08.stickers.cloud/packs/787053f4-0bd6-45f0-9a58-715b54913177/webp/ce810738-214d-4b3b-ab2f-aead08c5f7f8.webp",
            fee,
            ctx
        );
    }

}
