module satlayer_core::version;

// === Errors ===

const EWrongVersion: u64 = 1001; 

// === Constant ===

const VERSION_INIT: u64 = 1; 

// === Structs ===

public struct Version has key, store {
    id: UID, 
    version: u64,
}

public struct VAdminCap has key, store {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    transfer::public_transfer(VAdminCap {
        id: object::new(ctx)
    }, ctx.sender());
    transfer::share_object(Version {
        id: object::new(ctx),
        version: VERSION_INIT,
    });
}

public fun validate_version(
    version: &Version, 
    mod_version: u64
){
    assert!(mod_version == version.version, EWrongVersion);
}

public fun migrate(_: &VAdminCap, self: &mut Version, new_version: u64) {
    assert!(new_version > self.version, EWrongVersion); 
    self.version = new_version;
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}