%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_number,
    get_block_timestamp,
)
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import (
    assert_not_zero,
    assert_not_equal,
    assert_nn_le,
    assert_le,
    unsigned_div_rem,
    signed_div_rem,
)
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_le,
    uint256_lt,
    uint256_check,
    uint256_eq,
)
from openzeppelin.security.safemath import SafeUint256
from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_nn, is_in_range
from openzeppelin.token.ERC20.interfaces.IERC20 import IERC20
from openzeppelin.access.ownable import Ownable
from openzeppelin.security.pausable import Pausable
from openzeppelin.security.reentrancy_guard import ReentrancyGuard
from Interfaces.IDolvenVault import IDolvenVault

// # storages


@storage_var
func staking_contract_address() -> (address: felt) {
}

@storage_var
func token_address() -> (address: felt) {
}

@storage_var
func nonceCount() -> (nonceValue: felt) {
}

// # structs

struct Lock {
    user_account: felt,
    lock_timestamp: felt,
    lock_type: felt,
    unlock_timestamp: felt,
    unlocked_timestamp: felt,
    amount: Uint256,
    isUnlocked: felt,
}

// #mappings

@storage_var
func locks(lock_id: felt) -> (detail: Lock) {
}

@storage_var
func user_nonces(account_address: felt, index: felt) -> (userNonce: felt) {
}

@storage_var
func totalLockedValue() -> (tvl: Uint256) {
}

@storage_var
func user_nonces_len_(account_address: felt) -> (length: felt) {
}

// #events

@event
func Unlocked(user_account: felt, amount: Uint256, timestamp: felt, _nonce: felt) {
}
@event
func Locked(user_account: felt, amount: Uint256, timestamp: felt, _nonce: felt) {
}

// #Constructor

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_address_: felt, staking_contract_address_: felt, _admin: felt
) {
    Ownable.initializer(_admin);
    token_address.write(token_address_);
    staking_contract_address.write(staking_contract_address_);
    return ();
}

// #Modifiers

func onlyStakingContract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (caller) = get_caller_address();
    let staking_contract_address_: felt = staking_contract_address.read();
    assert_not_zero(caller);
    with_attr error_message("onlyStakingContract::caller is not the stakingContract") {
        assert caller = staking_contract_address_;
    }
    return ();
}

// # Getters

@view
func get_lock_details{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    nonce_id: felt
) -> (res: Lock) {
    let lock_details: Lock = locks.read(nonce_id);
    return (lock_details,);
}


@view
func nonce_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: felt) {
    let nonce_count_: felt = nonceCount.read();
    return (nonce_count_,);
}

@view
func get_tvl{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: Uint256) {
    let tvl_to_be_unstaked: Uint256 = totalLockedValue.read();
    return (tvl_to_be_unstaked,);
}

@view
func get_staking_contract_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (res: felt) {
    let staking_contract_address_: felt = staking_contract_address.read();
    return (staking_contract_address_,);
}

@view
func get_token_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    let token_address_: felt = token_address.read();
    return (token_address_,);
}

@view
func get_user_locks{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user: felt
) -> (locks_len: felt, locks: felt*, nonces_len : felt, nonces : felt*) {
    let (locks_len, locks, nonces_len, nonces) = recursive_user_locks(user, 0);
    return (locks_len * Lock.SIZE, locks - locks_len * Lock.SIZE, nonces_len, nonces - nonces_len);
}

func recursive_user_locks{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user: felt, index: felt
) -> (locks_len: felt, locks_memoryloc: Lock*, nonces_len : felt, nonces:felt*) {
    alloc_locals;
    let nonce_id: felt = user_nonces.read(user, index);
    if (nonce_id == 0) {
        let (found_locks: Lock*) = alloc();
        let (found_nonces: felt*) = alloc();
        return (0, found_locks, 0, found_nonces);
    }

    let lock_details: Lock = locks.read(nonce_id);
    let (locks_len, locks_memoryloc, nonces_len, nonces) = recursive_user_locks(user, index + 1);
    assert [locks_memoryloc] = lock_details;
    assert [nonces] = nonce_id;
    return (locks_len + 1, locks_memoryloc + Lock.SIZE, nonces_len + 1, nonces + 1);
}

// # External functions

@external
func setTokenAddress{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_address_: felt
) {
    Ownable.assert_only_owner();
    token_address.write(token_address_);
    return ();
}

@external
func setStakingAddress{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    contract_address_: felt
) {
    Ownable.assert_only_owner();
    staking_contract_address.write(contract_address_);
    return ();
}


@external
func lockTokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_address: felt, _amount: Uint256, lockType_: felt
) {
    alloc_locals;
    onlyStakingContract();
    ReentrancyGuard._start();
    let zero_as_uint256: Uint256 = Uint256(0, 0);
    let _stakingToken: felt = token_address.read();
    let (msg_sender) = get_caller_address();
    let (this) = get_contract_address();
    let nonce: felt = nonceCount.read();
    let (time) = get_block_timestamp();
    let lock_duration: felt = IDolvenVault.get_lock_types(msg_sender, lockType_);
    let is_amount_bigger_than_zero: felt = uint256_lt(zero_as_uint256, _amount);
    with_attr error_message("lockTokens::amount is less than or equals to zero") {
        assert is_amount_bigger_than_zero = 1;
    }

    let (is_tx_success: felt) = IERC20.transferFrom(_stakingToken, msg_sender, this, _amount);
    with_attr error_message("lockTokens::token payment failed") {
        assert is_tx_success = TRUE;
    }

    let unlockTime: felt = lock_duration + time;
    let new_lock: Lock = Lock(
        user_account=user_address,
        lock_timestamp=time,
        lock_type=lockType_,
        unlock_timestamp=unlockTime,
        unlocked_timestamp=0,
        amount=_amount,
        isUnlocked=FALSE,
    );
    let old_tvl: Uint256 = totalLockedValue.read();
    let new_tvl: Uint256 = SafeUint256.add(old_tvl, _amount);
    let user_nonce_length: felt = user_nonces_len_.read(user_address);
    user_nonces.write(user_address, user_nonce_length, nonce + 1);
    totalLockedValue.write(new_tvl);
    locks.write(nonce + 1, new_lock);
    nonceCount.write(nonce + 1);
    user_nonces_len_.write(user_address, user_nonce_length + 1);
    Locked.emit(user_address, _amount, time, nonce + 1);
    ReentrancyGuard._end();
    return ();
}

@external
func unlockTokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_: felt, nonce: felt
) {
    onlyStakingContract();
    unlock(user_, nonce);
    return ();
}

@external
func cancelTokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_: felt, nonce: felt
) {
    onlyStakingContract();
    cancelLock(user_, nonce);
    return ();
}

// #Internal functions

func cancelLock{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_address: felt, nonce
) {
    alloc_locals;
    let lock_details: Lock = locks.read(nonce);
    let is_lock_unlocked: felt = lock_details.isUnlocked;
    let (time) = get_block_timestamp();
    with_attr error_message("unlock::already unlocked") {
        assert is_lock_unlocked = FALSE;
    }
    with_attr error_message("unlock::caller is not owner") {
        assert user_address = lock_details.user_account;
    }
    let staking_token: felt = token_address.read();
    let stake_contract: felt = staking_contract_address.read();
    IERC20.approve(staking_token, stake_contract, lock_details.amount);
    let user_current_lock: felt = IDolvenVault.get_userLockType(stake_contract, user_address);
    let lockTypeNonce: felt = lock_details.lock_type;
    let __lockType: felt = returnLockDetails(lockTypeNonce, user_current_lock);

    IDolvenVault.delege(stake_contract, lock_details.amount, user_address, __lockType);
    let new_lock_details: Lock = Lock(
        user_account=user_address,
        lock_timestamp=0,
        lock_type=0,
        unlock_timestamp=0,
        unlocked_timestamp=time,
        amount=Uint256(0, 0),
        isUnlocked=TRUE,
    );
    let old_tvl: Uint256 = totalLockedValue.read();
    let new_tvl: Uint256 = SafeUint256.sub_le(old_tvl, lock_details.amount);
    totalLockedValue.write(new_tvl);
    locks.write(nonce, new_lock_details);
    return ();
}

func returnLockDetails{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    nonce_lock: felt, current_lock: felt
) -> (res: felt) {
    let is_lock_less_than_current: felt = is_le(nonce_lock, current_lock);
    let __lock_type: felt = 0;
    if (is_lock_less_than_current == 1) {
        return (current_lock,);
    } else {
        return (nonce_lock,);
    }
}

func unlock{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_address: felt, _nonce: felt
) {
    alloc_locals;
    let lock_details: Lock = locks.read(_nonce);
    let _token_address: felt = token_address.read();
    let (time) = get_block_timestamp();
    let is_early: felt = is_le(time, lock_details.unlock_timestamp);
    with_attr error_message("unlock::caller is not owner") {
        assert user_address = lock_details.user_account;
    }
    with_attr error_message("unlock::too early") {
        assert is_early = FALSE;
    }
    let is_lock_unlocked: felt = lock_details.isUnlocked;
    with_attr error_message("unlock::already unlocked") {
        assert is_lock_unlocked = FALSE;
    }
    let is_txs_success: felt = IERC20.transfer(_token_address, user_address, lock_details.amount);
    with_attr error_message("unlock::token payment failed") {
        assert is_txs_success = TRUE;
    }

    let new_lock_details: Lock = Lock(
        user_account=lock_details.user_account,
        lock_timestamp=lock_details.lock_timestamp,
        lock_type=lock_details.lock_type,
        unlock_timestamp=lock_details.unlock_timestamp,
        unlocked_timestamp=time,
        amount=Uint256(0, 0),
        isUnlocked=TRUE,
    );
    let old_tvl: Uint256 = totalLockedValue.read();
    let new_tvl: Uint256 = SafeUint256.sub_le(old_tvl, lock_details.amount);
    locks.write(_nonce, new_lock_details);
    totalLockedValue.write(new_tvl);
    Unlocked.emit(lock_details.user_account, lock_details.amount, time, _nonce);
    return ();
}
