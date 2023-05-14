module version_package::version {
    use sui::table;
    use sui::package;
    use sui::object::UID;
    use sui::tx_context::TxContext;
    use sui::transfer;
    use sui::object;
    use sui::package::Publisher;
    use std::ascii;
    use sui::hex;
    use sui::address;
    use std::type_name;

    struct VERSION has drop{}

    // id 0x940519686e92ae9d33d3b15d76cf49568ed59e33ccd032d1cd853e329f51afdd
    struct Version has key{
        id: UID,
        versions: table::Table<address, u64>
    }

    #[test_only]
    public fun init_for_test(ctx: &mut TxContext){
        init(VERSION{}, ctx)
    }

    fun init(witness:VERSION,ctx: &mut TxContext){
        package::claim_and_keep(witness,ctx);
        transfer::share_object(Version{
            id: object::new(ctx),
            versions: table::new(ctx)
        })
    }

    #[test_only]
    public fun add_for_test(addr: address, global_version : &mut Version){
        table::add(&mut global_version.versions, addr,0);
    }

    #[test_only]
    public fun set_for_test(addr: address, global_version : &mut Version, version: u64){
        *table::borrow_mut(&mut global_version.versions, addr) = version;
    }

    #[test_only]
    public fun borrow_mut_for_test(addr: address, global_version : &mut Version): &mut u64 {
        table::borrow_mut(&mut global_version.versions, addr)
    }

    public entry fun add(publisher: &Publisher , global_version : &mut Version) {
        let addr = address::from_bytes(hex::decode(*ascii::as_bytes(package::published_package(publisher))));
        table::add(&mut global_version.versions, addr,0);
    }

    public entry fun set(publisher: &Publisher , global_version : &mut Version, version: u64) {
        let addr = address::from_bytes(hex::decode(*ascii::as_bytes(package::published_package(publisher))));
        *table::borrow_mut(&mut global_version.versions, addr) = version;
    }

    public fun get_by_T<T>(global_version : & Version):u64{
        get(global_version, address::from_bytes(hex::decode(*ascii::as_bytes(&type_name::get_address(&type_name::get<T>())))))
    }

    public fun get( global_version : & Version, addr: address): u64 {
        *table::borrow(& global_version.versions, addr)
    }

    public fun borrow_mut(publisher: &Publisher , global_version : &mut Version): &mut u64 {
        let addr = address::from_bytes(hex::decode(*ascii::as_bytes(package::published_package(publisher))));
        table::borrow_mut(&mut global_version.versions, addr)
    }

    public fun contains( global_version : & Version, addr: address): bool {
        table::contains(& global_version.versions, addr)
    }
}