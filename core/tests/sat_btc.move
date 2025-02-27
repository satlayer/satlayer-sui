#[test_only]
module satlayer_core::sat_btc;

use sui::coin;

public struct SAT_BTC has drop {}

#[lint_allow(share_owned)]
fun init(witness: SAT_BTC, ctx: &mut TxContext) {
    let (treasury, meta) = coin::create_currency(
        witness,
        9,
        b"sat_btc",
        b"",
        b"",
        option::none(),
        ctx,
    );
    transfer::public_share_object(meta);
    transfer::public_transfer(treasury, tx_context::sender(ctx));
}
