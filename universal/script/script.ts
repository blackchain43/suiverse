import {
  Ed25519Keypair,
  JsonRpcProvider,
  RawSigner,
  TransactionBlock,
  Connection,
  fromB64,
} from "@mysten/sui.js";

// Construct your connection:
const connection = new Connection({
  fullnode: "https://testnet.sui.wav3.net",
  faucet: "https://faucet.testnet.sui.io/gas",
});

// connect to a custom RPC server
const provider = new JsonRpcProvider(connection);
// get tokens from a custom faucet server

const packageObjectId =
  "0xfc9838ccce8786af85299174920dff6a2870a8288fff080062ac24330962baf2";
const kiosk =
  "0x43bb2146b6d4985f3b4a9538ae9187eccc1d9d6e4d9f54bc569164951d8eeeb1";
const version =
  "0x940519686e92ae9d33d3b15d76cf49568ed59e33ccd032d1cd853e329f51afdd";
const display =
  "0x1ed3eed5838e84b25516a5492c5fdbb8a44263c31780b1ae7d35034391ae6984";
const shared_publisher =
  "0xed0b4001aba9b7b8a675fe8abd8874e2b32b0f272950632f0174f9326088d1e9";
const mint_cap =
  "0xef739ef6b63a9d6dfc448011dfe21685634e02e0f686067dab5dcdd9d4bf3945";
const nft_package_id =
  "0xaeb1179b394fe636162ba16ed2d2dd5f948dc3df8cd04cd4ea81f212894354d2";
const transfer_policy =
  "0xbca55cecc45e9ea1ad3d6ae4490fba4a45816b1e4f85dd2e19fa6f5fe83d10c9";
const transfer_cap =
  "0x283d15083dc8645fb3826cb6bfe3fc13558c54d6aaa2a9aaef6bfc831d1186fc";
const nft_1 =
  "0xcc2a81997e485a90902866f6d656904ed80c6d8f048b1d7ca867028953c6dea0";
const nft_2 =
  "0xe003db171ac0efd78c23d9a7ce87dca312e0b214456c2541fff54792df8d3141";
const raw = fromB64("AKpLgasSnYna2p5nyd9nJTSvrwEl1jY3G8RFJ7EjNsZE");
// const raw = fromB64("AFcQCQL3qPXxGIwDuqnX77BpKWIZCm1d9nQX3XkGIkY5");
const keypair = Ed25519Keypair.fromSecretKey(raw.slice(1));
console.log(keypair.getPublicKey().toSuiAddress());
const set_collection_info_tx = async () => {
  const signer = new RawSigner(keypair, provider);
  const tx = new TransactionBlock();
  tx.moveCall({
    target: `${packageObjectId}::souffl3::set_collection_info`,
    arguments: [
      // version
      tx.object(version),
      // display
      tx.object(
        "0x460c9d1e264488b5989f4b2a072115b4b48d772f450cd75a016e768625302861"
      ),
      // collection_name
      tx.pure("Gekacha"),
      // cover_image_url
      tx.pure(
        "https://ipfs.io/ipfs/QmPHxBhZpXRTCF2vdqCmDti6abpkQmViPAQqfrtXpB7jvM?filename=cat_test_sui.jpeg"
      ),
      // symbol
      tx.pure("GKC"),
      // description
      tx.pure("Sui Test"),
      // creator
      tx.pure(
        "0x8db963c4d441298dd16265591c8201af553dae2c3b25fe9eb370c38447fd13ca"
      ),
    ],
    typeArguments: [
      "0x291f45f30d6a9fa71df156d101059e4aaf109f572c1ac8464d7525da053a5897::collection::Gekacha",
    ],
  });
  const result = await signer.signAndExecuteTransactionBlock({
    transactionBlock: tx,
  });
};

const mint_nft_tx = async () => {
  const signer = new RawSigner(keypair, provider);
  const tx = new TransactionBlock();
  const [nft] = tx.moveCall({
    target: `${packageObjectId}::souffl3::mint_nft_with_cap`,
    arguments: [
      // version
      tx.object(version),
      // index
      tx.pure(6),
      // name
      tx.pure("G #6"),
      // image_url
      tx.pure(
        "https://ipfs.io/ipfs/QmPHxBhZpXRTCF2vdqCmDti6abpkQmViPAQqfrtXpB7jvM?filename=cat_test_sui.jpeg"
      ),
      // mint_cap
      tx.object(mint_cap),
      // property_keys
      tx.pure(["G"]),
      tx.pure(["x"]),
      // tx.makeMoveVec({type: 'pure', objects: [tx.pure("G"), tx.pure("N")]}),
      // // property_vals
      // tx.makeMoveVec({type: 'pure', objects: [tx.pure("1"), tx.pure("x")]}),
    ],
    typeArguments: [`${nft_package_id}::collection::Gekacha`],
  });
  tx.transferObjects(
    [nft],
    tx.pure(
      "0x91dabcd5aeca87779a191a70b3849ca7518cd15be36d2ebaa48d970487d785d6"
    )
  );
  const result = await signer.signAndExecuteTransactionBlock({
    transactionBlock: tx,
  });
};

const create_display_tx = async () => {
  const signer = new RawSigner(keypair, provider);
  const tx = new TransactionBlock();
  tx.moveCall({
    target: `${nft_package_id}::collection::create_collection_display_entry`,
    arguments: [
      // version
      tx.object(version),
      // publisher
      tx.object(shared_publisher),
      // cap
      tx.object(mint_cap),
    ],
    typeArguments: [],
  });
  const result = await signer.signAndExecuteTransactionBlock({
    transactionBlock: tx,
  });
};

const create_transfer_policy_tx = async () => {
  const signer = new RawSigner(keypair, provider);
  const tx = new TransactionBlock();
  const [cap] = tx.moveCall({
    target: `${packageObjectId}::souffl3::create_transfer_policy`,
    arguments: [
      // version
      tx.object(version),
      // version
      tx.object(mint_cap),
      // publisher
      tx.object(shared_publisher),
    ],
    typeArguments: [`${nft_package_id}::collection::Gekacha`],
  });
  tx.transferObjects([cap], tx.pure(keypair.getPublicKey().toSuiAddress()));
  const result = await signer.signAndExecuteTransactionBlock({
    transactionBlock: tx,
  });
};

const create_royalty_rule_tx = async () => {
  const signer = new RawSigner(keypair, provider);
  const tx = new TransactionBlock();
  tx.moveCall({
    target: `${kiosk}::royalty_rule::add`,
    arguments: [
      // version
      tx.object(transfer_policy),
      // version
      tx.object(transfer_cap),
      // publisher
      tx.pure(300),
      tx.pure(100000),
    ],
    typeArguments: [
      `${packageObjectId}::souffl3::NFT<${nft_package_id}::collection::Gekacha>`,
    ],
  });
  const result = await signer.signAndExecuteTransactionBlock({
    transactionBlock: tx,
  });
};

const new_version_tx = async () => {
  const signer = new RawSigner(keypair, provider);
  const tx = new TransactionBlock();
  tx.moveCall({
    target: `${packageObjectId}::souffl3::new_version`,
    arguments: [
      // shared_publisher
      tx.object(shared_publisher),
      // version
      tx.object(version),
    ],
    typeArguments: [],
  });
  const result = await signer.signAndExecuteTransactionBlock({
    transactionBlock: tx,
  });
};

const set_version_tx = async () => {
  const signer = new RawSigner(keypair, provider);
  const tx = new TransactionBlock();
  tx.moveCall({
    target: `${packageObjectId}::souffl3::set_version`,
    arguments: [
      // shared_publisher
      tx.object(shared_publisher),
      // version
      tx.object(version),
      // version_num
      tx.pure(0),
    ],
    typeArguments: [],
  });
  const result = await signer.signAndExecuteTransactionBlock({
    transactionBlock: tx,
  });
};

const display_transfer_policy_all_in_one_tx = async () => {
  const signer = new RawSigner(keypair, provider);
  const tx = new TransactionBlock();
  tx.moveCall({
    target: `${packageObjectId}::souffl3::create_then_set_display_and_transfer_policy_then_royalty_rule`,
    arguments: [
      // version
      tx.object(version),
      // version
      tx.object(mint_cap),
      // publisher
      tx.object(shared_publisher),
      // display name
      tx.pure("link"),
      // display value
      tx.pure("https://gekacha.com/{index}.json"),
      // bps
      tx.pure(200),
      // min amount
      tx.pure(100000),
    ],
    typeArguments: [`${nft_package_id}::collection::Gekacha`],
  });
  const result = await signer.signAndExecuteTransactionBlock({
    transactionBlock: tx,
  });
};

// buy_tx()
// list_tx()
// delist_tx()
// changePrice_tx()
// withdraw_tx()
// set_collection_info_tx()
// mint_nft_tx()
// create_display_tx()
new_version_tx();
// set_version_tx()
// create_transfer_policy_tx()
// create_royalty_rule_tx()
// display_transfer_policy_all_in_one_tx()
