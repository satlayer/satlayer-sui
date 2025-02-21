module coin::template{

use sui::coin::{Self, TreasuryCap};
use sui::url;

/// The OTW for the Coin
public struct TEMPLATE has drop {}

const SYMBOL: vector<u8> = b"Symbol";
const NAME: vector<u8> = b"Name";
const DESCRIPTION: vector<u8> = b"Description";
const ICON_URL: vector<u8> = b"Icon_url";

/// Init the Coin
fun init(otw: TEMPLATE, ctx: &mut TxContext) {
    let treasury_cap = create_currency(otw, ctx);
    transfer::public_transfer(treasury_cap, ctx.sender());
}

fun create_currency<T: drop>(
        otw: T,
        ctx: &mut TxContext
    ): TreasuryCap<T> {
        let icon_url = if (ICON_URL == b"") {
            option::none()
        } else {
            option::some(url::new_unsafe_from_bytes(ICON_URL))
        };

        let (treasury_cap, metadata) = coin::create_currency(
            otw, 
            9,
            SYMBOL,
            NAME,
            DESCRIPTION,
            icon_url,
            ctx
        );

        transfer::public_freeze_object(metadata);
        treasury_cap
}

#[test_only] 
public fun init_for_testing(ctx: &mut TxContext) {
    init(TEMPLATE {}, ctx);
}
}