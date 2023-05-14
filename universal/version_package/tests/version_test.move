#[test_only]
module version_package::versio_test {
    use sui::test_scenario;
    use version_package::version;
    use sui::package;

    #[test]
    fun test(){
        let creator = @0xA;

        let scenario_val = test_scenario::begin(creator);
        // init
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            version::init_for_test(ctx)
        };

        test_scenario::next_tx(scenario, creator);

        // test_scenario::next_tx(scenario, creator);
        // {
        //     let publisher = test_scenario::take_from_address<package::Publisher>(scenario,creator);
        //     let global_version = test_scenario::take_shared<version::Version>(scenario);

        //     version::add(&publisher, &mut global_version);

        //     assert!(version::contains(&global_version, @version), 1);

        //     assert!(version::get(&global_version, @version) == 0, 2);

        //     version::set(&publisher, &mut global_version, 1);

        //     assert!(version::get(&global_version, @version) == 1, 3);

        //     test_scenario::return_to_address(creator,publisher);
        //     test_scenario::return_shared(global_version);
        // };
        test_scenario::end(scenario_val);
    }
}