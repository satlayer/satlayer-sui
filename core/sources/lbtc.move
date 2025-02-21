module satlayer_core::lbtc;

use sui::coin;

public struct LBTC has drop {}

#[lint_allow(share_owned)]
fun init(witness: LBTC, ctx: &mut TxContext) {
    let (treasury, meta) = coin::create_currency(
        witness,
        9,
        b"lbtc",
        b"",
        b"",
        option::none(),
        ctx,
    );
    transfer::public_share_object(meta);
    transfer::public_transfer(treasury, tx_context::sender(ctx));
}
