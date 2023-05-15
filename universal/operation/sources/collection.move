module operation::collection {

    use std::option;
    use sui::transfer;
    use sui::object::{UID};
    use std::string::{String};
    use sui::vec_map::{VecMap};
    use sui::display::{Display};
    use sui::tx_context::{Self, TxContext};
    use nft_protocol::mint_cap::{MintCap};
    use nft_protocol::collection;
    use blackchainverse::blackchain::{Self, NFT, SharedPublisher};
    use version_package::version::Version;

    const BURNABLE_BY_OWNER: bool = false;
    const BURNABLE_BY_CREATOR: bool = false;
    const MUTATE_NAME_IMAGE_BY_CREATOR: bool = false;

    const ENotBurnable: u64 = 0;
    const ENotMutable: u64 = 1;

    struct Gekacha has key, store {
        id: UID,
        name: String,
        image_url: String,
        properties: VecMap<String, String>
    }

    struct Witness has drop {}

    /// One time witness is only instantiated in the init method
    struct COLLECTION has drop {}

    fun init(witness: COLLECTION, ctx: &mut TxContext) {
        let (abyss_collection, mint_cap_abyss) =
            collection::create_with_mint_cap<COLLECTION, Gekacha>(&witness, option::none(), ctx);
        transfer::public_transfer(mint_cap_abyss, tx_context::sender(ctx));
        transfer::public_share_object(abyss_collection);
    }

    public entry fun create_collection_display_entry(
        version: &Version,
        publisher: &SharedPublisher,
        cap: &MintCap<Gekacha>,
        ctx: &mut TxContext
    ) {
        let display_gekacha = create_collection_display(version, publisher, cap, ctx);
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(display_gekacha, sender);
    }

    public fun create_collection_display(
        version: &Version,
        publisher: &SharedPublisher,
        cap: &MintCap<Gekacha>,
        ctx: &mut TxContext
    ): Display<NFT<Gekacha>> {
        let display_abyss = blackchain::create_display<Gekacha>(version, cap, publisher, ctx);
        display_abyss
    }

    public fun burn_by_owner(
        nft: NFT<Gekacha>
    ) {
        assert!(BURNABLE_BY_OWNER, ENotBurnable);
        blackchain::burn(Witness{}, nft);
    }

    // only allowed by mint_cap holder
    public fun burn_by_creator(
        _mint_cap: &MintCap<Gekacha>,
        nft: NFT<Gekacha>,
    ) {
        assert!(BURNABLE_BY_CREATOR, ENotBurnable);
        blackchain::burn(Witness{}, nft);
    }

    public fun mutate_name_image_by_creator(
        _mint_cap: &MintCap<Gekacha>,
        nft: &mut NFT<Gekacha>,
        name: String,
        image_url: String
    ) {
        assert!(MUTATE_NAME_IMAGE_BY_CREATOR, ENotMutable);
        blackchain::mutate_name_and_image_url(Witness{}, nft, name, image_url);
    }
}