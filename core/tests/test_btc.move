
#[test_only]
module satlayer_core::test_btc;

use sui::coin;

public struct TEST_BTC has drop {}

#[lint_allow(share_owned)]
fun init(witness: TEST_BTC, ctx: &mut TxContext) {
    let (treasury, meta) = coin::create_currency(
        witness,
        9,
        b"test_btc",
        b"",
        b"",
        option::none(),
        ctx,
    );
    transfer::public_share_object(meta);
    transfer::public_transfer(treasury, tx_context::sender(ctx));
}
