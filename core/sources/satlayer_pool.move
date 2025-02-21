module satlayer_core::satlayer_pool;

use sui::balance::{Self, Balance}; 
use sui::clock::{Clock}; 
use sui::coin::{Self, Coin, TreasuryCap};
use sui::table::{Self, Table};
use sui::event::{Self};
use std::type_name::{Self, TypeName}; 
use satlayer_core::version::{Version};
/* ================= constants ================= */

const VERSION: u64 = 1;

/* ================= errors ================= */

// users not exists for withdrawal
const EUserNotExistsForWithdrawal: u64 = 0;
// withdrawal timestamp not reached 
const EWithdrawAttemptedTooEarly: u64 = 1;
// same toggle bool value 
const EParamsUnchanged: u64 = 2;
// vault is paused 
const EVaultIsPaused: u64 = 3;
// cap reached
const ECapReached: u64 = 4;
// Deposit coin cannot be zero 
const EDepositAmountCannotBeZero: u64 = 5;
// Withdraw Amount cannot be zero 
const EWithdrawalAmountCannotBeZero: u64 = 6;

/* ================= AdminCap ================= */

/// There can only ever be one `AdminCap` for a `Vault`
public struct AdminCap has key, store{
    id: UID,
}

/* ================= Vault ================= */

public struct Vault<phantom T, phantom K> has key, store {
    id: UID, 
    // staking limit cap 
    staking_cap: u64, 
    // whether staking into vault is paused or not 
    is_paused: bool, 
    // whether cap is enabled or not
    caps_enabled:  bool, 
    // balance of Input Token 
    balance: Balance<T>, 
    // withdrawal timestamp 
    withdrawal_time: u64,
    // Maps user address to withdrawal request timestamp 
    withdrawal_requests: Table<address, u64>,  
    // withdraw amount after withdraw request
    withdraw_amount: Table<address, u64>,
    // Tresaury cap of receipt token
    treasury_cap: TreasuryCap<K>, 
}

/* ================= events ================= */

public struct DepositEvent<phantom K> has copy, drop {
    coin_type: TypeName,
    deposit_amount: u64, 
    receipt_token_minted: u64, 
}

public struct WithdrawEvent<phantom K> has copy, drop {
    amount: u64, 
}

public struct WithdrawalRequest<phantom K> has copy, drop {
    amount: u64, 
    receipt_token_burned: u64,
    withdrawal_timestamp: u64,
}


/* ================= Init ================= */

fun init(ctx: &mut TxContext) {
    let admin_cap = AdminCap {
        id: object::new(ctx)
    };

    transfer::public_transfer(admin_cap, ctx.sender());
}

// Once the receipt token is deployed, admin calls this function with the treasury cap of the receipt token
public fun initialize_vault<T, K>(_cap: &AdminCap, receipt_treasury_cap: TreasuryCap<K>, staking_cap: u64, withdrawal_time: u64, version: &Version, ctx: &mut TxContext) {
    version.validate_version(VERSION);

    let vault = Vault<T, K>{
        id: object::new(ctx), 
        staking_cap, 
        is_paused: true, 
        caps_enabled: true,
        balance: balance::zero<T>(), 
        withdrawal_time,
        withdrawal_requests: table::new(ctx),
        withdraw_amount: table::new(ctx),
        treasury_cap: receipt_treasury_cap, 
    };
    transfer::public_share_object(vault);
}

/* ================= Deposit ================= */

public fun deposit_for<T, K>(vault: &mut Vault<T,K>, deposit_amount: Coin<T>, version: &Version, ctx: &mut TxContext): Coin<K> {
    version.validate_version(VERSION);

    assert!(!vault.is_paused, EVaultIsPaused);
    assert!(deposit_amount.value() > 0, EDepositAmountCannotBeZero);
    if(vault.caps_enabled && vault.balance.value() + deposit_amount.value() > vault.staking_cap) abort ECapReached;

    let deposit_value = deposit_amount.value(); 

    let balance_before = vault.balance.value();
    vault.balance.join<T>(deposit_amount.into_balance());
    let actual_amount = vault.balance.value() - balance_before;
    
    let receipt_coin = vault.treasury_cap.mint<K>(actual_amount, ctx);

    let coin_type = type_name::get<K>();
    event::emit(
       DepositEvent<K>{
        coin_type, 
        deposit_amount: deposit_value,
        receipt_token_minted: receipt_coin.value(), 
    });

    receipt_coin
}
/* ================= Withdrawal Request ================= */

// Note: User can split the coin 

public fun queue_withdrawal<T, K>(vault: &mut Vault<T,K>, receipt_token: Coin<K>, clock: &Clock, version:&Version, ctx:&mut TxContext){
    version.validate_version(VERSION);

    assert!(!vault.is_paused, EVaultIsPaused);
    assert!(receipt_token.value() > 0, EWithdrawalAmountCannotBeZero);

    if(!vault.withdrawal_requests.contains(ctx.sender())) {
        vault.withdrawal_requests.add<address, u64>(ctx.sender(), clock.timestamp_ms() + vault.withdrawal_time );
        vault.withdraw_amount.add<address, u64>(ctx.sender(), receipt_token.value());
    } else {
        *vault.withdrawal_requests.borrow_mut(ctx.sender()) = clock.timestamp_ms() + vault.withdrawal_time;
        let withdraw_amount = vault.withdraw_amount.borrow_mut(ctx.sender());
        *withdraw_amount = *withdraw_amount + receipt_token.value();
    };

    event::emit(WithdrawalRequest<K>{
        amount: receipt_token.value(), 
        receipt_token_burned: receipt_token.value(),
        withdrawal_timestamp: clock.timestamp_ms(),
    });

    vault.treasury_cap.burn<K>(receipt_token);
}

/* ================= Claim Withdraw Request ================= */

public fun withdraw<T, K>(vault: &mut Vault<T,K>, clock: &Clock, version: &Version, ctx: &mut TxContext) : Coin<T> {
    version.validate_version(VERSION);

    assert!(!vault.is_paused, EVaultIsPaused);
    assert!(vault.withdrawal_requests.contains(ctx.sender()), EUserNotExistsForWithdrawal);
    assert!(clock.timestamp_ms() > *vault.withdrawal_requests.borrow(ctx.sender()), EWithdrawAttemptedTooEarly);

    // splitting balance to provide the recipient
    let withdraw_amount = vault.withdraw_amount.remove(ctx.sender());
    let return_balance = vault.balance.split<T>(withdraw_amount);
    
    let return_coin = coin::from_balance(return_balance, ctx);
    // removing the recipient address from the withdrawal requests
    let _ = vault.withdrawal_requests.remove(ctx.sender());

    event::emit(WithdrawEvent<K>{
        amount: return_coin.value()
    });
    
    return_coin
}

/* ================= ADMIN  ================= */

public fun set_staking_cap<T, K>(
    _: &AdminCap, 
    vault: &mut Vault<T, K>, 
    new_cap: u64,
    version: &Version,
) {
    version.validate_version(VERSION);
    vault.staking_cap = new_cap;
}

public fun update_withdrawal_time<T, K>(
    _: &AdminCap, 
    vault: &mut Vault<T, K>, 
    new_time: u64,
    version: &Version,
) {
    version.validate_version(VERSION);
    vault.withdrawal_time = new_time;
}

public fun toggle_vault_pause<T, K>(
    _: &AdminCap, 
    vault: &mut Vault<T, K>,
    pause: bool,
    version: &Version,
) {
    version.validate_version(VERSION);
    assert!(vault.is_paused != pause, EParamsUnchanged);
    vault.is_paused = pause
}


public fun set_caps_enabled<T, K>(
    _: &AdminCap, 
    vault: &mut Vault<T, K>,
    enabled: bool,
    version: &Version,
) {
    version.validate_version(VERSION);
    assert!(vault.caps_enabled != enabled, EParamsUnchanged);
    vault.caps_enabled = enabled;
}


/* ================= Getter Function  ================= */

public fun get_staking_cap<T, K>(
    vault: &Vault<T, K>, 
): u64 {
    vault.staking_cap
}

public fun get_withdrawal_time<T, K>(
    vault: &Vault<T, K>,
): u64 {
    vault.withdrawal_time
}

public fun get_total_lbtc_balance<T, K>(
    vault: &Vault<T, K> 
): u64 {
    vault.balance.value()
}

public fun get_vault_is_paused<T, K>(
    vault: &Vault<T, K>, 
): bool {
    vault.is_paused
}

#[test_only] 
public fun get_withdrawal_timestamp<T, K>(
    vault: &Vault<T, K>,
    ctx: &TxContext
): u64 {
    *vault.withdrawal_requests.borrow(ctx.sender())
}

#[test_only] 
public fun get_withdraw_amount<T, K>(
    vault: &Vault<T, K>,
    ctx: &TxContext
): u64 {
    *vault.withdraw_amount.borrow(ctx.sender())
}

#[test_only] 
public fun init_for_testing(ctx: &mut TxContext){
    init(ctx);
}