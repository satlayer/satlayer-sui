#[test_only]
module satlayer_core::vault_test;

use satlayer_core::satlayer_pool::{Self, Vault, AdminCap};
use satlayer_core::version::{Self, Version, VAdminCap};
use satlayer_core::test_btc::TEST_BTC;
use satlayer_core::sat_btc::SAT_BTC;
use sui::coin::{Self, Coin};
use sui::test_scenario::{Self as ts, Scenario, next_tx, ctx};
use sui::test_utils::assert_eq;
use sui::clock::{Self};

const OWNER: address = @0xBABE;
const USER_ONE: address = @0xACDE;
const USER_TWO: address = @0xADCD;

public struct World {
    scenario: Scenario, 
    admin_cap: AdminCap, 
    vadmin_cap: VAdminCap, 
    version: Version, 
} 

public fun start_world(): World {
   let mut scenario = ts::begin(OWNER); 

   satlayer_pool::init_for_testing(ctx(&mut scenario));
   version::init_for_testing(ctx(&mut scenario));
   
   next_tx(&mut scenario, OWNER);
   let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
   let vadmin_cap = ts::take_from_sender<VAdminCap>(&scenario);
   let version = ts::take_shared<Version>(&scenario); 

    World {
        scenario, 
        admin_cap,
        vadmin_cap,
        version, 
    }
}

public fun end_world(world: World) {
    let World {
        scenario, 
        admin_cap,
        vadmin_cap,
        version,
    } = world;

    ts::return_to_sender<AdminCap>(&scenario, admin_cap); 
    ts::return_to_sender<VAdminCap>(&scenario, vadmin_cap);
    ts::return_shared<Version>(version);
    scenario.end();
}

#[test]
fun publish_package() {
    let world = start_world(); 
    end_world(world);
}

#[test] 
public fun test_initialize_vault() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EInvalidCoolDownTime)] 
public fun test_revert_initialize_vault() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        15*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test] 
public fun test_check_vault_is_paused() { 
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, USER_ONE); 
    let vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    assert_eq(satlayer_pool::get_vault_is_paused(&vault), true);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test]
public fun test_set_staking_cap() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

     let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, USER_ONE); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);

    satlayer_pool::set_staking_cap<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        &mut vault,
        15_000_000_000,
        &world.version
    ); 

    assert_eq(
        satlayer_pool::get_staking_cap<TEST_BTC, SAT_BTC>(&vault),
        15_000_000_000
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test]
public fun test_update_withdrawal_time() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

     let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, USER_ONE); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);

    satlayer_pool::update_withdrawal_time<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault,
        10*24*60*60*1000,
        &world.version,
    ); 

    assert_eq(
        satlayer_pool::get_withdrawal_cooldown_time<TEST_BTC, SAT_BTC>(&vault),
        10*24*60*60*1000
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EInvalidCoolDownTime)]
public fun test_revert_update_withdrawal_time() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

     let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        15*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, USER_ONE); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);

    satlayer_pool::update_withdrawal_time<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault,
        10*24*60*60*1000,
        &world.version,
    ); 

    assert_eq(
        satlayer_pool::get_withdrawal_cooldown_time<TEST_BTC, SAT_BTC>(&vault),
        10*24*60*60*1000
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EVaultIsPaused)] 
public fun test_revert_deposit_for_when_paused() { 
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vtest_btc 
    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_BTC, SAT_BTC>` 
    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    // step 3: User to deposit the test_btc in the `Vault<TEST_BTC, SAT_BTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    let coin_test_btc = coin::mint_for_testing<TEST_BTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vtest_btc = satlayer_pool::deposit_for<TEST_BTC, SAT_BTC>(
        &mut vault,
        coin_test_btc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    transfer::public_transfer(return_coin_test_vtest_btc, USER_ONE);
    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    next_tx(&mut world.scenario, OWNER);
    end_world(world);

}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::ECapReached)] 
public fun test_revert_deposit_for_when_cap_is_reached() { 
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    // step_1: create the treasury cap for testing for test vtest_btc
    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_BTC, SAT_BTC>` 
    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault, 
        false,
        &world.version, 
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 3: User to deposit the test_btc in the `Vault<TEST_BTC, SAT_BTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    let coin_test_btc = coin::mint_for_testing<TEST_BTC>(5_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vtest_btc = satlayer_pool::deposit_for<TEST_BTC, SAT_BTC>(
        &mut vault,
        coin_test_btc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vtest_btc.value(), 5_000_000_000);
    transfer::public_transfer(return_coin_test_vtest_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 4: User Two trying to deposit more than cap
    next_tx(&mut world.scenario, USER_TWO); 

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    let coin_test_btc = coin::mint_for_testing<TEST_BTC>(6_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vtest_btc = satlayer_pool::deposit_for<TEST_BTC, SAT_BTC>(
        &mut vault,
        coin_test_btc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    transfer::public_transfer(return_coin_test_vtest_btc, USER_TWO);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test] 
public fun test_deposit_for() { 
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    // step_1: create the treasury cap for testing for test vtest_btc
    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_BTC, SAT_BTC>` 
    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 3: User to deposit the test_btc in the `Vault<TEST_BTC, SAT_BTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    let coin_test_btc = coin::mint_for_testing<TEST_BTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vtest_btc = satlayer_pool::deposit_for<TEST_BTC, SAT_BTC>(
        &mut vault,
        coin_test_btc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vtest_btc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vtest_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EDepositAmountCannotBeZero)] 
public fun test_revert_deposit_for_with_coin_zero() { 
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    // step_1: create the treasury cap for testing for test vtest_btc
    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_BTC, SAT_BTC>` 
    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 3: User to deposit the test_btc in the `Vault<TEST_BTC, SAT_BTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    let coin_test_btc = coin::zero<TEST_BTC>(ctx(&mut world.scenario));

    let return_coin_test_vtest_btc = satlayer_pool::deposit_for<TEST_BTC, SAT_BTC>(
        &mut vault,
        coin_test_btc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    transfer::public_transfer(return_coin_test_vtest_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EVaultIsPaused)] 
public fun test_revert_queue_withdrawal_when_paused() {
     let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vtest_btc 
    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_BTC, SAT_BTC>` 
    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 3: User to deposit the test_btc in the `Vault<TEST_BTC, SAT_BTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    let coin_test_btc = coin::mint_for_testing<TEST_BTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vtest_btc = satlayer_pool::deposit_for<TEST_BTC, SAT_BTC>(
        &mut vault,
        coin_test_btc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vtest_btc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vtest_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault, 
        true, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 


    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(8*24*60*60*1000);

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    let coin_vtest_btc = ts::take_from_sender<Coin<SAT_BTC>>(&world.scenario);

    satlayer_pool::queue_withdrawal<TEST_BTC, SAT_BTC>(
        &mut vault, 
        coin_vtest_btc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test] 
public fun test_queue_withdrawal() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vtest_btc 
    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_BTC, SAT_BTC>` 
    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 3: User to deposit the test_btc in the `Vault<TEST_BTC, SAT_BTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    let coin_test_btc = coin::mint_for_testing<TEST_BTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vtest_btc = satlayer_pool::deposit_for<TEST_BTC, SAT_BTC>(
        &mut vault,
        coin_test_btc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vtest_btc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vtest_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(8 * 24* 60 * 60 * 1000);

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    let coin_vtest_btc = ts::take_from_sender<Coin<SAT_BTC>>(&world.scenario);

    satlayer_pool::queue_withdrawal<TEST_BTC, SAT_BTC>(
        &mut vault, 
        coin_vtest_btc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    // assertion check of user's withdrawal timestamp.
    assert_eq(
        satlayer_pool::get_withdrawal_timestamp<TEST_BTC, SAT_BTC>(&vault, ctx(&mut world.scenario)), 
        8*24*60*60*1000 + 7*24*60*60*1000
    );

    assert_eq(
        satlayer_pool::get_withdraw_amount<TEST_BTC, SAT_BTC>(&vault, ctx(&mut world.scenario)),
        1_000_000_000
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test] 
public fun test_queue_withdrawal_multiple_times() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vtest_btc 
    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_BTC, SAT_BTC>` 
    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 3: User to deposit the test_btc in the `Vault<TEST_BTC, SAT_BTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    let coin_test_btc = coin::mint_for_testing<TEST_BTC>(5_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vtest_btc = satlayer_pool::deposit_for<TEST_BTC, SAT_BTC>(
        &mut vault,
        coin_test_btc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vtest_btc.value(), 5_000_000_000);
    transfer::public_transfer(return_coin_test_vtest_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(8 * 24 * 60 * 60 * 1000);

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    let mut coin_vtest_btc = ts::take_from_sender<Coin<SAT_BTC>>(&world.scenario);
    let coin_splited_value = coin_vtest_btc.split<SAT_BTC>(2_500_000_000, ctx(&mut world.scenario));
    satlayer_pool::queue_withdrawal<TEST_BTC, SAT_BTC>(
        &mut vault, 
        coin_splited_value,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    // assertion check of user's withdrawal timestamp.
    assert_eq(
        satlayer_pool::get_withdrawal_timestamp<TEST_BTC, SAT_BTC>(&vault, ctx(&mut world.scenario)), 
        8*24*60*60*1000 + 7*24*60*60*1000
    );

    assert_eq(
        satlayer_pool::get_withdraw_amount<TEST_BTC, SAT_BTC>(&vault, ctx(&mut world.scenario)),
        2_500_000_000
    );

    // Testing again adding test_btc to withdraw the coins
    next_tx(&mut world.scenario, USER_ONE);

    clock.set_for_testing(9*24*60*60*1000); 
    // let coin_vtest_btc = coin::mint_for_testing<SAT_BTC>(1_000_000_000, ctx(&mut world.scenario));

     satlayer_pool::queue_withdrawal<TEST_BTC, SAT_BTC>(
        &mut vault, 
        coin_vtest_btc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    // assertion check of user's withdrawal timestamp.
    assert_eq(
        satlayer_pool::get_withdrawal_timestamp<TEST_BTC, SAT_BTC>(&vault, ctx(&mut world.scenario)), 
        9*24*60*60*1000 + 7*24*60*60*1000
    );

    assert_eq(
        satlayer_pool::get_withdraw_amount<TEST_BTC, SAT_BTC>(&vault, ctx(&mut world.scenario)),
        5_000_000_000
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EVaultIsPaused)] 
public fun test_revert_withdraw_when_paused() {
     let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vtest_btc 
    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_BTC, SAT_BTC>` 
    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 3: User to deposit the test_btc in the `Vault<TEST_BTC, SAT_BTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    let coin_test_btc = coin::mint_for_testing<TEST_BTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vtest_btc = satlayer_pool::deposit_for<TEST_BTC, SAT_BTC>(
        &mut vault,
        coin_test_btc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vtest_btc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vtest_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(8*24*60*60*1000);

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    let coin_vtest_btc = ts::take_from_sender<Coin<SAT_BTC>>(&world.scenario);

    satlayer_pool::queue_withdrawal<TEST_BTC, SAT_BTC>(
        &mut vault, 
        coin_vtest_btc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);


    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault, 
        true, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 5: USER ONE withdrawing after execeeding Withdrawal 
    clock.set_for_testing(8*24*60*60*1000 + 1); 

    next_tx(&mut world.scenario, USER_ONE); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    let coin_test_btc = satlayer_pool::withdraw<TEST_BTC, SAT_BTC>(
        &mut vault, 
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );
    transfer::public_transfer(coin_test_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EUserNotExistsForWithdrawal)]
public fun test_revert_withdraw_with_unauthorized_user() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vtest_btc 
    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_BTC, SAT_BTC>` 
    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 3: User to deposit the test_btc in the `Vault<TEST_BTC, SAT_BTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    let coin_test_btc = coin::mint_for_testing<TEST_BTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vtest_btc = satlayer_pool::deposit_for<TEST_BTC, SAT_BTC>(
        &mut vault,
        coin_test_btc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vtest_btc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vtest_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(3 * 60 * 1000);

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    let coin_vtest_btc = ts::take_from_sender<Coin<SAT_BTC>>(&world.scenario);

    satlayer_pool::queue_withdrawal<TEST_BTC, SAT_BTC>(
        &mut vault, 
        coin_vtest_btc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);

    // step 5: USER ONE withdrawing after execeeding Withdrawal 
    clock.set_for_testing(8*60*1000 + 1); 

    next_tx(&mut world.scenario, USER_TWO); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    let coin_test_btc = satlayer_pool::withdraw<TEST_BTC, SAT_BTC>(
        &mut vault, 
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    transfer::public_transfer(coin_test_btc, USER_TWO);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EWithdrawAttemptedTooEarly)]
public fun test_revert_withdraw_before_withdrawal_timestamp() {
     let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vtest_btc 
    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_BTC, SAT_BTC>` 
    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 3: User to deposit the test_btc in the `Vault<TEST_BTC, SAT_BTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    let coin_test_btc = coin::mint_for_testing<TEST_BTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vtest_btc = satlayer_pool::deposit_for<TEST_BTC, SAT_BTC>(
        &mut vault,
        coin_test_btc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vtest_btc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vtest_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(8*24*60*60*1000);

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    let coin_vtest_btc = ts::take_from_sender<Coin<SAT_BTC>>(&world.scenario);

    satlayer_pool::queue_withdrawal<TEST_BTC, SAT_BTC>(
        &mut vault, 
        coin_vtest_btc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);

    // step 5: USER ONE withdrawing after execeeding Withdrawal 
    clock.set_for_testing(11*24*60*60*1000); 

    next_tx(&mut world.scenario, USER_ONE); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    let coin_test_btc = satlayer_pool::withdraw<TEST_BTC, SAT_BTC>(
        &mut vault, 
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );
    transfer::public_transfer(coin_test_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EWithdrawalAmountCannotBeZero)]
public fun test_revert_withdrawal_with_amount_zero(){
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vtest_btc 
    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_BTC, SAT_BTC>` 
    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 3: User to deposit the test_btc in the `Vault<TEST_BTC, SAT_BTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    let coin_test_btc = coin::mint_for_testing<TEST_BTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vtest_btc = satlayer_pool::deposit_for<TEST_BTC, SAT_BTC>(
        &mut vault,
        coin_test_btc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vtest_btc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vtest_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(3 * 60 * 1000);

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    let coin_vtest_btc = coin::zero<SAT_BTC>(ctx(&mut world.scenario));

    satlayer_pool::queue_withdrawal<TEST_BTC, SAT_BTC>(
        &mut vault, 
        coin_vtest_btc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);

    // step 5: USER ONE withdrawing after execeeding Withdrawal 
    clock.set_for_testing(3*60*1000 + 7*24*60*60*1000); 

    next_tx(&mut world.scenario, USER_ONE); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    let coin_test_btc = satlayer_pool::withdraw<TEST_BTC, SAT_BTC>(
        &mut vault, 
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );
    assert_eq(coin_test_btc.value(), 0_000_000_000); 
    transfer::public_transfer(coin_test_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}


#[test] 
public fun test_withdraw() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vtest_btc 
    let treasury_cap = coin::create_treasury_cap_for_testing<SAT_BTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_BTC, SAT_BTC>` 
    satlayer_pool::initialize_vault<TEST_BTC, SAT_BTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        7*24*60*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_BTC, SAT_BTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 3: User to deposit the test_btc in the `Vault<TEST_BTC, SAT_BTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario);
    let coin_test_btc = coin::mint_for_testing<TEST_BTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vtest_btc = satlayer_pool::deposit_for<TEST_BTC, SAT_BTC>(
        &mut vault,
        coin_test_btc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vtest_btc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vtest_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(3 * 60 * 1000);

    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    let coin_vtest_btc = ts::take_from_sender<Coin<SAT_BTC>>(&world.scenario);

    satlayer_pool::queue_withdrawal<TEST_BTC, SAT_BTC>(
        &mut vault, 
        coin_vtest_btc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);

    // step 5: USER ONE withdrawing after execeeding Withdrawal 
    clock.set_for_testing(8*60*1000 + 7*24*60*60*1000); 

    next_tx(&mut world.scenario, USER_ONE); 
    let mut vault = ts::take_shared<Vault<TEST_BTC, SAT_BTC>>(&world.scenario); 
    let coin_test_btc = satlayer_pool::withdraw<TEST_BTC, SAT_BTC>(
        &mut vault, 
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );
    assert_eq(coin_test_btc.value(), 1_000_000_000); 
    transfer::public_transfer(coin_test_btc, USER_ONE);

    ts::return_shared<Vault<TEST_BTC, SAT_BTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}


