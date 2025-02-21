#[test_only]
module satlayer_core::vault_test;

use satlayer_core::satlayer_pool::{Self, Vault, AdminCap};
use satlayer_core::version::{Self, Version, VAdminCap};
use satlayer_core::test_lbtc::TEST_LBTC;
use satlayer_core::test_vlbtc::TEST_VLBTC;
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

    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
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

    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, USER_ONE); 
    let vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    assert_eq(satlayer_pool::get_vault_is_paused(&vault), true);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test]
public fun test_set_staking_cap() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

     let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, USER_ONE); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);

    satlayer_pool::set_staking_cap<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        &mut vault,
        15_000_000_000,
        &world.version
    ); 

    assert_eq(
        satlayer_pool::get_staking_cap<TEST_LBTC, TEST_VLBTC>(&vault),
        15_000_000_000
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test]
public fun test_update_withdrawal_time() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

     let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, USER_ONE); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);

    satlayer_pool::update_withdrawal_time<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault,
        10*60*1000,
        &world.version,
    ); 

    assert_eq(
        satlayer_pool::get_withdrawal_time<TEST_LBTC, TEST_VLBTC>(&vault),
        10*60*1000
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EVaultIsPaused)] 
public fun test_revert_deposit_for_when_paused() { 
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vlbtc 
    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_LBTC, TEST_VLBTC>` 
    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    // step 3: User to deposit the LBTC in the `Vault<TEST_LBTC, TEST_VLBTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    let coin_test_lbtc = coin::mint_for_testing<TEST_LBTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vlbtc = satlayer_pool::deposit_for<TEST_LBTC, TEST_VLBTC>(
        &mut vault,
        coin_test_lbtc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    transfer::public_transfer(return_coin_test_vlbtc, USER_ONE);
    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    next_tx(&mut world.scenario, OWNER);
    end_world(world);

}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::ECapReached)] 
public fun test_revert_deposit_for_when_cap_is_reached() { 
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    // step_1: create the treasury cap for testing for test vlbtc
    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_LBTC, TEST_VLBTC>` 
    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault, 
        false,
        &world.version, 
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 3: User to deposit the LBTC in the `Vault<TEST_LBTC, TEST_VLBTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    let coin_test_lbtc = coin::mint_for_testing<TEST_LBTC>(5_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vlbtc = satlayer_pool::deposit_for<TEST_LBTC, TEST_VLBTC>(
        &mut vault,
        coin_test_lbtc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vlbtc.value(), 5_000_000_000);
    transfer::public_transfer(return_coin_test_vlbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 4: User Two trying to deposit more than cap
    next_tx(&mut world.scenario, USER_TWO); 

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    let coin_test_lbtc = coin::mint_for_testing<TEST_LBTC>(6_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vlbtc = satlayer_pool::deposit_for<TEST_LBTC, TEST_VLBTC>(
        &mut vault,
        coin_test_lbtc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    transfer::public_transfer(return_coin_test_vlbtc, USER_TWO);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test] 
public fun test_deposit_for() { 
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    // step_1: create the treasury cap for testing for test vlbtc
    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_LBTC, TEST_VLBTC>` 
    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 3: User to deposit the LBTC in the `Vault<TEST_LBTC, TEST_VLBTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    let coin_test_lbtc = coin::mint_for_testing<TEST_LBTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vlbtc = satlayer_pool::deposit_for<TEST_LBTC, TEST_VLBTC>(
        &mut vault,
        coin_test_lbtc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vlbtc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vlbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EDepositAmountCannotBeZero)] 
public fun test_revert_deposit_for_with_coin_zero() { 
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    // step_1: create the treasury cap for testing for test vlbtc
    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_LBTC, TEST_VLBTC>` 
    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 3: User to deposit the LBTC in the `Vault<TEST_LBTC, TEST_VLBTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    let coin_test_lbtc = coin::zero<TEST_LBTC>(ctx(&mut world.scenario));

    let return_coin_test_vlbtc = satlayer_pool::deposit_for<TEST_LBTC, TEST_VLBTC>(
        &mut vault,
        coin_test_lbtc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    transfer::public_transfer(return_coin_test_vlbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EVaultIsPaused)] 
public fun test_revert_queue_withdrawal_when_paused() {
     let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vlbtc 
    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_LBTC, TEST_VLBTC>` 
    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 3: User to deposit the LBTC in the `Vault<TEST_LBTC, TEST_VLBTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    let coin_test_lbtc = coin::mint_for_testing<TEST_LBTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vlbtc = satlayer_pool::deposit_for<TEST_LBTC, TEST_VLBTC>(
        &mut vault,
        coin_test_lbtc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vlbtc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vlbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault, 
        true, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 


    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(3 * 60 * 1000);

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    let coin_vlbtc = ts::take_from_sender<Coin<TEST_VLBTC>>(&world.scenario);

    satlayer_pool::queue_withdrawal<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        coin_vlbtc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test] 
public fun test_queue_withdrawal() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vlbtc 
    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_LBTC, TEST_VLBTC>` 
    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 3: User to deposit the LBTC in the `Vault<TEST_LBTC, TEST_VLBTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    let coin_test_lbtc = coin::mint_for_testing<TEST_LBTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vlbtc = satlayer_pool::deposit_for<TEST_LBTC, TEST_VLBTC>(
        &mut vault,
        coin_test_lbtc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vlbtc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vlbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(3 * 60 * 1000);

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    let coin_vlbtc = ts::take_from_sender<Coin<TEST_VLBTC>>(&world.scenario);

    satlayer_pool::queue_withdrawal<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        coin_vlbtc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    // assertion check of user's withdrawal timestamp.
    assert_eq(
        satlayer_pool::get_withdrawal_timestamp<TEST_LBTC, TEST_VLBTC>(&vault, ctx(&mut world.scenario)), 
        3*60*1000 + 5*60*1000
    );

    assert_eq(
        satlayer_pool::get_withdraw_amount<TEST_LBTC, TEST_VLBTC>(&vault, ctx(&mut world.scenario)),
        1_000_000_000
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test] 
public fun test_queue_withdrawal_multiple_times() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vlbtc 
    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_LBTC, TEST_VLBTC>` 
    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 3: User to deposit the LBTC in the `Vault<TEST_LBTC, TEST_VLBTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    let coin_test_lbtc = coin::mint_for_testing<TEST_LBTC>(5_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vlbtc = satlayer_pool::deposit_for<TEST_LBTC, TEST_VLBTC>(
        &mut vault,
        coin_test_lbtc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vlbtc.value(), 5_000_000_000);
    transfer::public_transfer(return_coin_test_vlbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(3 * 60 * 1000);

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    let mut coin_vlbtc = ts::take_from_sender<Coin<TEST_VLBTC>>(&world.scenario);
    let coin_splited_value = coin_vlbtc.split<TEST_VLBTC>(2_500_000_000, ctx(&mut world.scenario));
    satlayer_pool::queue_withdrawal<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        coin_splited_value,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    // assertion check of user's withdrawal timestamp.
    assert_eq(
        satlayer_pool::get_withdrawal_timestamp<TEST_LBTC, TEST_VLBTC>(&vault, ctx(&mut world.scenario)), 
        3*60*1000 + 5*60*1000
    );

    assert_eq(
        satlayer_pool::get_withdraw_amount<TEST_LBTC, TEST_VLBTC>(&vault, ctx(&mut world.scenario)),
        2_500_000_000
    );

    // Testing again adding lbtc to withdraw the coins
    next_tx(&mut world.scenario, USER_ONE);

    clock.set_for_testing(8*60*1000); 
    // let coin_vlbtc = coin::mint_for_testing<TEST_VLBTC>(1_000_000_000, ctx(&mut world.scenario));

     satlayer_pool::queue_withdrawal<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        coin_vlbtc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    // assertion check of user's withdrawal timestamp.
    assert_eq(
        satlayer_pool::get_withdrawal_timestamp<TEST_LBTC, TEST_VLBTC>(&vault, ctx(&mut world.scenario)), 
        8*60*1000 + 5*60*1000
    );

    assert_eq(
        satlayer_pool::get_withdraw_amount<TEST_LBTC, TEST_VLBTC>(&vault, ctx(&mut world.scenario)),
        5_000_000_000
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EVaultIsPaused)] 
public fun test_revert_withdraw_when_paused() {
     let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vlbtc 
    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_LBTC, TEST_VLBTC>` 
    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 3: User to deposit the LBTC in the `Vault<TEST_LBTC, TEST_VLBTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    let coin_test_lbtc = coin::mint_for_testing<TEST_LBTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vlbtc = satlayer_pool::deposit_for<TEST_LBTC, TEST_VLBTC>(
        &mut vault,
        coin_test_lbtc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vlbtc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vlbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(3 * 60 * 1000);

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    let coin_vlbtc = ts::take_from_sender<Coin<TEST_VLBTC>>(&world.scenario);

    satlayer_pool::queue_withdrawal<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        coin_vlbtc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);


    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault, 
        true, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 5: USER ONE withdrawing after execeeding Withdrawal 
    clock.set_for_testing(8*60*1000 + 1); 

    next_tx(&mut world.scenario, USER_ONE); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    let coin_lbtc = satlayer_pool::withdraw<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );
    transfer::public_transfer(coin_lbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EUserNotExistsForWithdrawal)]
public fun test_revert_withdraw_with_unauthorized_user() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vlbtc 
    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_LBTC, TEST_VLBTC>` 
    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 3: User to deposit the LBTC in the `Vault<TEST_LBTC, TEST_VLBTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    let coin_test_lbtc = coin::mint_for_testing<TEST_LBTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vlbtc = satlayer_pool::deposit_for<TEST_LBTC, TEST_VLBTC>(
        &mut vault,
        coin_test_lbtc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vlbtc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vlbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(3 * 60 * 1000);

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    let coin_vlbtc = ts::take_from_sender<Coin<TEST_VLBTC>>(&world.scenario);

    satlayer_pool::queue_withdrawal<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        coin_vlbtc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);

    // step 5: USER ONE withdrawing after execeeding Withdrawal 
    clock.set_for_testing(8*60*1000 + 1); 

    next_tx(&mut world.scenario, USER_TWO); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    let coin_lbtc = satlayer_pool::withdraw<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    transfer::public_transfer(coin_lbtc, USER_TWO);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EWithdrawAttemptedTooEarly)]
public fun test_revert_withdraw_before_withdrawal_timestamp() {
     let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vlbtc 
    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_LBTC, TEST_VLBTC>` 
    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 3: User to deposit the LBTC in the `Vault<TEST_LBTC, TEST_VLBTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    let coin_test_lbtc = coin::mint_for_testing<TEST_LBTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vlbtc = satlayer_pool::deposit_for<TEST_LBTC, TEST_VLBTC>(
        &mut vault,
        coin_test_lbtc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vlbtc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vlbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(3 * 60 * 1000);

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    let coin_vlbtc = ts::take_from_sender<Coin<TEST_VLBTC>>(&world.scenario);

    satlayer_pool::queue_withdrawal<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        coin_vlbtc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);

    // step 5: USER ONE withdrawing after execeeding Withdrawal 
    clock.set_for_testing(4*60*1000); 

    next_tx(&mut world.scenario, USER_ONE); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    let coin_lbtc = satlayer_pool::withdraw<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );
    transfer::public_transfer(coin_lbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}

#[test, expected_failure(abort_code=satlayer_core::satlayer_pool::EWithdrawalAmountCannotBeZero)]
public fun test_revert_withdrawal_with_amount_zero(){
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vlbtc 
    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_LBTC, TEST_VLBTC>` 
    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 3: User to deposit the LBTC in the `Vault<TEST_LBTC, TEST_VLBTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    let coin_test_lbtc = coin::mint_for_testing<TEST_LBTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vlbtc = satlayer_pool::deposit_for<TEST_LBTC, TEST_VLBTC>(
        &mut vault,
        coin_test_lbtc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vlbtc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vlbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(3 * 60 * 1000);

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    let coin_vlbtc = coin::zero<TEST_VLBTC>(ctx(&mut world.scenario));

    satlayer_pool::queue_withdrawal<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        coin_vlbtc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);

    // step 5: USER ONE withdrawing after execeeding Withdrawal 
    clock.set_for_testing(8*60*1000 + 1); 

    next_tx(&mut world.scenario, USER_ONE); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    let coin_lbtc = satlayer_pool::withdraw<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );
    assert_eq(coin_lbtc.value(), 0_000_000_000); 
    transfer::public_transfer(coin_lbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}


#[test] 
public fun test_withdraw() {
    let mut world = start_world(); 

    next_tx(&mut world.scenario, OWNER); 

    //step1: create the the treasury cap for testing for test_vlbtc 
    let treasury_cap = coin::create_treasury_cap_for_testing<TEST_VLBTC>(ctx(&mut world.scenario));

    // step 2: initialize the vault of type `Vault<TEST_LBTC, TEST_VLBTC>` 
    satlayer_pool::initialize_vault<TEST_LBTC, TEST_VLBTC>(
        &world.admin_cap, 
        treasury_cap, 
        10_000_000_000, 
        5*60*1000, 
        &world.version,
        ctx(&mut world.scenario),
    );

    next_tx(&mut world.scenario, OWNER); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    
    satlayer_pool::toggle_vault_pause<TEST_LBTC, TEST_VLBTC>(
        & world.admin_cap, 
        &mut vault, 
        false, 
        &world.version,
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 3: User to deposit the LBTC in the `Vault<TEST_LBTC, TEST_VLBTC>`
    next_tx(&mut world.scenario, USER_ONE); 

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario);
    let coin_test_lbtc = coin::mint_for_testing<TEST_LBTC>(1_000_000_000, ctx(&mut world.scenario));

    let return_coin_test_vlbtc = satlayer_pool::deposit_for<TEST_LBTC, TEST_VLBTC>(
        &mut vault,
        coin_test_lbtc, 
        &world.version,
        ctx(&mut world.scenario)
    );

    assert_eq(return_coin_test_vlbtc.value(), 1_000_000_000);
    transfer::public_transfer(return_coin_test_vlbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault); 

    // step 4: User One reqresting for queue withdrawal  
    next_tx(&mut world.scenario, USER_ONE); 
    let mut clock = clock::create_for_testing(ctx(&mut world.scenario)); 

    clock.set_for_testing(3 * 60 * 1000);

    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    let coin_vlbtc = ts::take_from_sender<Coin<TEST_VLBTC>>(&world.scenario);

    satlayer_pool::queue_withdrawal<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        coin_vlbtc,
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);

    // step 5: USER ONE withdrawing after execeeding Withdrawal 
    clock.set_for_testing(8*60*1000 + 1); 

    next_tx(&mut world.scenario, USER_ONE); 
    let mut vault = ts::take_shared<Vault<TEST_LBTC, TEST_VLBTC>>(&world.scenario); 
    let coin_lbtc = satlayer_pool::withdraw<TEST_LBTC, TEST_VLBTC>(
        &mut vault, 
        &clock, 
        &world.version,
        ctx(&mut world.scenario),
    );
    assert_eq(coin_lbtc.value(), 1_000_000_000); 
    transfer::public_transfer(coin_lbtc, USER_ONE);

    ts::return_shared<Vault<TEST_LBTC, TEST_VLBTC>>(vault);
    clock.destroy_for_testing();
    next_tx(&mut world.scenario, OWNER);
    end_world(world);
}


