module satlayer_core::satlayer_pool;

use satlayer_core::version::Version;
use std::type_name::{Self, TypeName};
use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::{Self, Coin, TreasuryCap};
use sui::event;
use sui::table::{Self, Table};

/* ================= constants ================= */

// Version Constant for Module Upgradability
const VERSION: u64 = 1;

// The Minimum Withdrawal Cooldown for Queue Withdrawal
const MIN_WITHDRAWAL_COOLDOWN: u64 = 7 * 24 * 60 * 60 * 1000;
// The Maximum Withdrawal Cooldown for Queue Withdrawal
const MAX_WITHDRAWAL_COOLDOWN: u64 = 14 * 24 * 60 *60 * 1000;

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
// Initial Receipient Token Total Supply must be zero
const EInitialTotalSupplyMustbeZero: u64 = 7;
// Withdraw Cooldown should be lies on min_withdrawal_cooldown and max_withdrawal_cooldown
const EInvalidCoolDownTime: u64 = 8;
// When Staking Caps is enabled Deposit amount must be greater or equal to minimumm deposit amount;
const EDepositAmountLessThanMinDepositAmount: u64 = 9;
// New Update Cooldown Must be Greater than Previous cooldown
const ENewCooldownMustGreaterThanPrevious: u64 = 10;

/* ================= AdminCap ================= */

/// There can only ever be one `AdminCap` for a `Vault`
public struct AdminCap has key, store {
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
    caps_enabled: bool,
    // balance of Input Token
    balance: Balance<T>,
    // minimum deposit token with respect to token decimals of deposit token
    min_deposit_amount: u64,
    // withdrawal timestamp
    withdrawal_cooldown: u64,
    // Maps user address to withdrawal request timestamp and withdraw amount
    withdraw_info: Table<address, WithdrawInfo>,
    // Tresaury cap of receipt token
    treasury_cap: TreasuryCap<K>,
}

/// Struct to represent withdrawal information of user
public struct WithdrawInfo has drop, store {
    withdrawal_requests: u64,
    withdraw_amount: u64,
}

/* ================= events ================= */

public struct DepositEvent<phantom K> has copy, drop {
    sender: address,
    coin_type: TypeName,
    actual_amount: u64,
}

public struct WithdrawEvent<phantom K> has copy, drop {
    sender: address,
    amount: u64,
}

public struct WithdrawalRequest<phantom K> has copy, drop {
    sender: address,
    amount: u64,
    receipt_token_burned: u64,
    withdrawal_timestamp: u64,
}

public struct SetStakingCapEvent<phantom K> has copy, drop {
    admin: address,
    vault: ID,
    new_cap: u64,
}

public struct CapsEnabledEvent<phantom K> has copy, drop {
    admin: address,
    vault: ID,
    enabled: bool,
}

public struct ToggleVaultEvent<phantom K> has copy, drop {
    admin: address,
    vault: ID,
    status: bool,
}

public struct UpdateWithdrawalTimeEvent<phantom K> has copy, drop {
    admin: address,
    vault: ID,
    new_cooldown_time: u64,
}

public struct InitializeVaultEvent<phantom T, phantom K> has copy, drop {
    admin: address,
    vault: ID,
    input_coin_type: TypeName,
    receipt_coin_type: TypeName,
    staking_cap: u64,
    min_deposit_amount: u64,
    withdrawal_cooldown: u64,
}

/* ================= Init ================= */

fun init(ctx: &mut TxContext) {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };

    transfer::public_transfer(admin_cap, ctx.sender());
}

// Once the receipt token is deployed, admin calls this function with the treasury cap of the receipt token
public fun initialize_vault<T, K>(
    _cap: &AdminCap,
    receipt_treasury_cap: TreasuryCap<K>,
    staking_cap: u64,
    min_deposit_amount: u64,
    withdrawal_cooldown: u64,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.validate_version(VERSION);

    assert!(receipt_treasury_cap.total_supply() == 0, EInitialTotalSupplyMustbeZero);
    assert!(
        withdrawal_cooldown >= MIN_WITHDRAWAL_COOLDOWN && withdrawal_cooldown <= MAX_WITHDRAWAL_COOLDOWN,
        EInvalidCoolDownTime,
    );

    let vault = Vault<T, K> {
        id: object::new(ctx),
        staking_cap,
        is_paused: true,
        caps_enabled: true,
        balance: balance::zero<T>(),
        min_deposit_amount,
        withdrawal_cooldown,
        withdraw_info: table::new(ctx),
        treasury_cap: receipt_treasury_cap,
    };

    event::emit(InitializeVaultEvent<T, K> {
        admin: ctx.sender(),
        vault: object::id(&vault),
        input_coin_type: type_name::get<T>(),
        receipt_coin_type: type_name::get<K>(),
        staking_cap,
        min_deposit_amount,
        withdrawal_cooldown,
    });

    transfer::public_share_object(vault);
}

/* ================= Deposit ================= */

public fun deposit_for<T, K>(
    vault: &mut Vault<T, K>,
    deposit_amount: Coin<T>,
    version: &Version,
    ctx: &mut TxContext,
): Coin<K> {
    version.validate_version(VERSION);

    assert!(!vault.is_paused, EVaultIsPaused);
    assert!(deposit_amount.value() > 0, EDepositAmountCannotBeZero);

    if (vault.caps_enabled) {
        assert!(
            deposit_amount.value() >= vault.min_deposit_amount,
            EDepositAmountLessThanMinDepositAmount,
        );

        if (vault.balance.value() + deposit_amount.value() > vault.staking_cap) abort ECapReached;
    };

    let actual_amount = deposit_amount.value();
    vault.balance.join<T>(deposit_amount.into_balance());

    let receipt_coin = vault.treasury_cap.mint<K>(actual_amount, ctx);

    let coin_type = type_name::get<K>();

    event::emit(DepositEvent<K> {
        sender: ctx.sender(),
        coin_type,
        actual_amount,
    });

    receipt_coin
}

/* ================= Withdrawal Request ================= */

public fun queue_withdrawal<T, K>(
    vault: &mut Vault<T, K>,
    receipt_token: Coin<K>,
    clock: &Clock,
    version: &Version,
    ctx: &TxContext,
) {
    version.validate_version(VERSION);

    assert!(!vault.is_paused, EVaultIsPaused);
    assert!(receipt_token.value() > 0, EWithdrawalAmountCannotBeZero);

    if (!vault.withdraw_info.contains(ctx.sender())) {
        let withdraw_info = WithdrawInfo {
            withdrawal_requests: clock.timestamp_ms() + vault.withdrawal_cooldown,
            withdraw_amount: receipt_token.value(),
        };

        vault.withdraw_info.add<address, WithdrawInfo>(ctx.sender(), withdraw_info);
    } else {
        let withdraw_info = vault.withdraw_info.borrow_mut(ctx.sender());

        withdraw_info.withdrawal_requests = clock.timestamp_ms() + vault.withdrawal_cooldown;
        withdraw_info.withdraw_amount = withdraw_info.withdraw_amount + receipt_token.value();
    };

    event::emit(WithdrawalRequest<K> {
        sender: ctx.sender(),
        amount: receipt_token.value(),
        receipt_token_burned: receipt_token.value(),
        withdrawal_timestamp: clock.timestamp_ms(),
    });

    vault.treasury_cap.burn<K>(receipt_token);
}

/* ================= Claim Withdraw Request ================= */

public fun withdraw<T, K>(
    vault: &mut Vault<T, K>,
    clock: &Clock,
    version: &Version,
    ctx: &mut TxContext,
): Coin<T> {
    version.validate_version(VERSION);

    assert!(!vault.is_paused, EVaultIsPaused);
    assert!(vault.withdraw_info.contains(ctx.sender()), EUserNotExistsForWithdrawal);

    let withdraw_info = vault.withdraw_info.borrow(ctx.sender());
    assert!(clock.timestamp_ms() >= withdraw_info.withdrawal_requests, EWithdrawAttemptedTooEarly);

    // splitting balance to provide the recipient
    let withdraw_info = vault.withdraw_info.remove(ctx.sender());
    let return_balance = vault.balance.split<T>(withdraw_info.withdraw_amount);

    let return_coin = coin::from_balance(return_balance, ctx);

    event::emit(WithdrawEvent<K> {
        sender: ctx.sender(),
        amount: return_coin.value(),
    });

    return_coin
}

/* ================= ADMIN  ================= */

public fun set_staking_cap<T, K>(
    _: &AdminCap,
    vault: &mut Vault<T, K>,
    new_cap: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.validate_version(VERSION);
    assert!(vault.staking_cap != new_cap, EParamsUnchanged);
    vault.staking_cap = new_cap;

    event::emit(SetStakingCapEvent<K> {
        admin: ctx.sender(),
        vault: object::id(vault),
        new_cap: new_cap,
    });
}

public fun update_withdrawal_time<T, K>(
    _: &AdminCap,
    vault: &mut Vault<T, K>,
    new_cooldown_time: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.validate_version(VERSION);
    assert!(
        new_cooldown_time > vault.withdrawal_cooldown &&  new_cooldown_time <= MAX_WITHDRAWAL_COOLDOWN,
        ENewCooldownMustGreaterThanPrevious,
    );
    vault.withdrawal_cooldown = new_cooldown_time;

    event::emit(UpdateWithdrawalTimeEvent<K> {
        admin: ctx.sender(),
        vault: object::id(vault),
        new_cooldown_time,
    });
}

public fun toggle_vault_pause<T, K>(
    _: &AdminCap,
    vault: &mut Vault<T, K>,
    pause: bool,
    version: &Version,
    ctx: &TxContext,
) {
    version.validate_version(VERSION);
    assert!(vault.is_paused != pause, EParamsUnchanged);
    vault.is_paused = pause;

    event::emit(ToggleVaultEvent<K> {
        admin: ctx.sender(),
        vault: object::id(vault),
        status: pause,
    });
}

public fun set_caps_enabled<T, K>(
    _: &AdminCap,
    vault: &mut Vault<T, K>,
    enabled: bool,
    version: &Version,
    ctx: &TxContext,
) {
    version.validate_version(VERSION);
    assert!(vault.caps_enabled != enabled, EParamsUnchanged);
    vault.caps_enabled = enabled;

    event::emit(CapsEnabledEvent<K> {
        admin: ctx.sender(),
        vault: object::id(vault),
        enabled,
    });
}

/* ================= Getter Function  ================= */

public fun get_staking_cap<T, K>(vault: &Vault<T, K>): u64 {
    vault.staking_cap
}

public fun get_withdrawal_cooldown_time<T, K>(vault: &Vault<T, K>): u64 {
    vault.withdrawal_cooldown
}

public fun get_total_vault_balance<T, K>(vault: &Vault<T, K>): u64 {
    vault.balance.value()
}

public fun get_vault_is_paused<T, K>(vault: &Vault<T, K>): bool {
    vault.is_paused
}

public fun get_user_withdraw_info<T, K>(vault: &Vault<T, K>, ctx: &TxContext): (u64, u64) {
    let withdraw_info = vault.withdraw_info.borrow(ctx.sender());
    let withdrawal_requests = withdraw_info.withdrawal_requests;
    let withdraw_amount = withdraw_info.withdraw_amount;
    (withdrawal_requests, withdraw_amount)
}

#[test_only]
public fun get_withdrawal_timestamp<T, K>(vault: &Vault<T, K>, ctx: &TxContext): u64 {
    let withdraw_info = vault.withdraw_info.borrow(ctx.sender());
    withdraw_info.withdrawal_requests
}

#[test_only]
public fun get_withdraw_amount<T, K>(vault: &Vault<T, K>, ctx: &TxContext): u64 {
    let withdraw_info = vault.withdraw_info.borrow(ctx.sender());
    withdraw_info.withdraw_amount
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
