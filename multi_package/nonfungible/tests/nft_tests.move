// #[test_only]
// module nonfungible::nft_tests {
//    use nonfungible::nft::{Self, S6kTestNFT, MinterCap, MintingTreasury};
//    use sui::test_scenario::{Self as test, Scenario};
//    use sui::transfer;
//    use sui::coin::{Self, Coin};
//    use sui::sui::SUI;
//    use std::string;
   
//    struct NFT_TESTS has drop {}
//    #[test]
//     fun mint_transfer_update() {
//         let addr1 = @0xA;
//         let addr2 = @0xB;
//         // create the NFT
//         let scenario_val = test::begin(addr1);
//         let scenario = &mut scenario_val;
//         let ctx = test::ctx(scenario);
//         let witness = NFT_TESTS{};
//         let coin = coin::mint_for_testing<SUI>(10, ctx);
        
//         test::next_tx(scenario, addr1); 
//         {
//             nft::init_for_testing(witness, ctx)
//         };
//         test::next_tx(scenario, addr1);
//         {
//             let treasury = test::take_shared<MintingTreasury>(scenario);
//             let mintercap = test::take_from_address<MinterCap>(scenario, addr1);
//             nft::owner_mint_to_account(&mintercap, &mut treasury, b"test", b"a test", b"https://www.sui.io", coin, ctx);
//             nft::burn_cap(mintercap, ctx);
//         };
//         // send it from A to B
//         test::next_tx(scenario, addr1);
//         {
//             let nft = test::take_from_sender<S6kTestNFT>(scenario);
//             transfer::transfer(nft, addr2);
//         };
//         // update its description
//         test::next_tx(scenario, addr2);
//         {
//             let nft = test::take_from_sender<S6kTestNFT>(scenario);
//             nft::update_description(&mut nft, b"a new description", ctx) ;
//             assert!(*string::bytes(nft::description(&nft)) == b"a new description", 0);
//             test::return_to_sender(scenario, nft);
//         };
//         // burn it
//         test::next_tx(scenario, addr2);
//         {
//             let nft = test::take_from_sender<S6kTestNFT>(scenario);
//             nft::burn(nft, ctx);
//         }
//     }
// }