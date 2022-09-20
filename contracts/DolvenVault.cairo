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
    split_felt,
    assert_lt_felt,
    assert_le_felt,
    assert_le,
    unsigned_div_rem,
    signed_div_rem,
)
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_le, uint256_lt
from openzeppelin.security.safemath import SafeUint256

from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_nn, is_nn_le, is_in_range
from openzeppelin.token.ERC20.interfaces.IERC20 import IERC20
from openzeppelin.access.ownable import Ownable
from openzeppelin.security.pausable import Pausable
from openzeppelin.security.reentrancy_guard import ReentrancyGuard
from Interfaces.IDolvenUnstaker import IDolvenUnstaker

// #Storages

@storage_var
func stakingToken() -> (token: felt) {
}

@storage_var
func rewardToken() -> (token: felt) {
}

@storage_var
func startTimestamp() -> (timestamp: felt) {
}

@storage_var
func lastRewardTimestamp() -> (timestamp: felt) {
}

@storage_var
func finishTimestamp() -> (timestamp: felt) {
}

@storage_var
func allStakedAmount() -> (amount: Uint256) {
}

@storage_var
func allPaidReward() -> (amount: Uint256) {
}

@storage_var
func allRewardDebt() -> (amount: Uint256) {
}

@storage_var
func poolTokenAmount() -> (amount: Uint256) {
}

@storage_var
func rewardPerTimestamp() -> (timestamp: Uint256) {
}

@storage_var
func accTokensPerShare() -> (amount: Uint256) {
}

@storage_var
func totalTicketCount() -> (ticketCount: Uint256) {
}

@storage_var
func stakerCount() -> (count: felt) {
}

@storage_var
func isFarming() -> (value: felt) {
}

@storage_var
func limitForTicket() -> (limit: Uint256) {
}

@storage_var
func unstakerAddress() -> (contract_address: felt) {
}

// #Structs

struct UserInfo {
    amount: Uint256,  // How many tokens the user has staked.
    rewardDebt: Uint256,  // Reward debt
    lockType: felt,  // Lock type
    updateTime: felt,  // update time
    dlTicket: Uint256,  // pp ticket count
    isRegistered: felt,  // is user participated before
}

// #Mappings

@storage_var
func totalLockedTicket_byBlocktime(time: felt) -> (ttc: Uint256) {
}

@storage_var
func ticketCountOfUser_byTime(user_account: felt, time: felt) -> (ttc: Uint256) {
}

@storage_var
func userInfo(user_address: felt) -> (info: UserInfo) {
}

@storage_var
func stakers(id: felt) -> (address: felt) {
}

@storage_var
func lockTypes(id: felt) -> (duration: felt) {
}
// 0 -> 20 days lock after undelegate 1x
// 1 -> 40 days lock afer undelegate 2x
// 2 -> 80 days lock after undelegate 6x
// 3 -> 160 days lock after undelegate 10x

// #Events

@event
func TokensStaked(user_account: felt, amount: Uint256, reward: Uint256, totalStakedValue: Uint256) {
}

@event
func StakeWithdrawn(
    user_account: felt, amount: Uint256, reward: Uint256, totalStakedValue: Uint256
) {
}

@event
func FundsWithdrawed(user_account: felt, amount: Uint256) {
}

// #constructor
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _stakingToken: felt,
    _poolToken: felt,
    _startTimestamp: felt,
    _finishTimestamp: felt,
    _poolTokenAmount: felt,
    _limitForTicket: felt,
    _isFarming: felt,
    _admin: felt,
) {
    alloc_locals;
    let __poolTokenAmount: Uint256 = Uint256(_poolTokenAmount, 0);
    let __limitForTicket: Uint256 = Uint256(_limitForTicket, 0);
    Ownable.initializer(_admin);
    let (time) = get_block_timestamp();
    let res: felt = is_le(_startTimestamp, _finishTimestamp);
    let res_x: felt = is_le(_finishTimestamp, time);
    let res_t: felt = _finishTimestamp - _startTimestamp;
    let removeValue: Uint256 = Uint256(res_t, 0);
    let (local _rewardPerTimestamp: Uint256, _) = SafeUint256.div_rem(
        __poolTokenAmount, removeValue
    );
    with_attr error_message("start block must be less than finish block") {
        assert res = 1;
    }
    with_attr error_message("finish block must be more than current block") {
        assert res_x = 0;
    }
    stakingToken.write(_stakingToken);
    rewardToken.write(_poolToken);
    startTimestamp.write(_startTimestamp);
    finishTimestamp.write(_finishTimestamp);
    poolTokenAmount.write(__poolTokenAmount);
    limitForTicket.write(__limitForTicket);
    rewardPerTimestamp.write(_rewardPerTimestamp);
    isFarming.write(_isFarming);
    return ();
}

// #getters

@view
func get_properties{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    _stakingToken: felt,
    _rewardToken: felt,
    _startTime: felt,
    _finihTime: felt,
    tvl: Uint256,
    _lastRewardTimestamp: felt,
    _allPaidReward: Uint256,
    _allRewardDebt: Uint256,
    _poolTokenAmount: Uint256,
    _rewardPerTimestamp: Uint256,
    _accTokensPerShare: Uint256,
    _isFarming: felt,
) {
    let _stakingToken: felt = stakingToken.read();
    let _rewardToken: felt = rewardToken.read();
    let _startTime: felt = startTimestamp.read();
    let _finihTime: felt = finishTimestamp.read();
    let tvl: Uint256 = allStakedAmount.read();
    let _lastRewardTimestamp: felt = lastRewardTimestamp.read();
    let _allPaidReward: Uint256 = allPaidReward.read();
    let _allRewardDebt: Uint256 = allRewardDebt.read();
    let _poolTokenAmount: Uint256 = poolTokenAmount.read();
    let _rewardPerTimestamp: Uint256 = rewardPerTimestamp.read();
    let _accTokensPerShare: Uint256 = accTokensPerShare.read();
    let _isFarming: felt = isFarming.read();
    return (
        _stakingToken,
        _rewardToken,
        _startTime,
        _finihTime,
        tvl,
        _lastRewardTimestamp,
        _allPaidReward,
        _allRewardDebt,
        _poolTokenAmount,
        _rewardPerTimestamp,
        _accTokensPerShare,
        _isFarming,
    );
}

@view
func get_rewardPerTm{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    let rpt: felt = rewardPerTimestamp.read();
    return (rpt,);
}

@view
func get_totalLockedTicket_byTime{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    block_time: felt
) -> (res: Uint256) {
    let total_locked_ticket: Uint256 = totalLockedTicket_byBlocktime.read(block_time);
    return (total_locked_ticket,);
}

@view
func get_totalTicketCount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: Uint256
) {
    let ttc: Uint256 = totalTicketCount.read();
    return (ttc,);
}

@view
func get_userTicketCount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account: felt, blockTime: felt
) -> (res: Uint256) {
    alloc_locals;
    let user: UserInfo = userInfo.read(account);
    let is_earlier_than_given: felt = is_nn_le(user.updateTime, blockTime);
    if (is_earlier_than_given == 1) {
        return (user.dlTicket,);
    } else {
        let ticketCount: Uint256 = ticketCountOfUser_byTime.read(account, blockTime);
        return (ticketCount,);
    }
}

@view
func get_userLockType{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account: felt
) -> (res: felt) {
    let rpt: UserInfo = userInfo.read(account);
    let lockType: felt = rpt.lockType;
    return (lockType,);
}

@view
func get_isFarming{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    let _isFarming: felt = isFarming.read();
    return (_isFarming,);
}

@view
func get_limitForTicket{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: Uint256
) {
    let limit: Uint256 = limitForTicket.read();
    return (limit,);
}

@view
func get_lock_types{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    index: felt
) -> (res: felt) {
    let duration: felt = lockTypes.read(index);
    return (duration,);
}

@view
func _isPaused{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: felt) {
    let (status) = Pausable.is_paused();
    return (status,);
}

@view
func returnTokensPerShare{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: Uint256
) {
    let res: Uint256 = accTokensPerShare.read();
    return (res,);
}

@view
func get_unstakerAddress{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    let res: felt = unstakerAddress.read();
    return (res,);
}

@view
func pendingReward{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account_address: felt
) -> (reward: Uint256) {
    alloc_locals;
    let zero_as_uint256: Uint256 = Uint256(0, 0);
    let (user: UserInfo) = userInfo.read(account_address);
    let tempAccTokensPerShare: Uint256 = accTokensPerShare.read();
    let _lastRewardTime: felt = lastRewardTimestamp.read();
    let _allStakedAmount: Uint256 = allStakedAmount.read();
    let _rewardPerTimestamp: Uint256 = rewardPerTimestamp.read();
    let (time) = get_block_timestamp();
    let res: felt = is_le(time, _lastRewardTime);
    let res_y: felt = uint256_eq(_allStakedAmount, Uint256(0, 0));
    let wei: felt = 10 ** 18;
    let wei_as_uint256: Uint256 = felt_to_uint256(wei);
    if (res == 0) {
        if (res_y == 0) {
            let _multiplier: felt = get_multiplier(_lastRewardTime, time);
            let multiplier: Uint256 = felt_to_uint256(_multiplier);
            let reward: Uint256 = SafeUint256.mul(multiplier, _rewardPerTimestamp);
            let wei_reward: Uint256 = SafeUint256.mul(reward, wei_as_uint256);
            let (local dived_data: Uint256, _) = SafeUint256.div_rem(wei_reward, _allStakedAmount);
            let tempAccTokensPerShare: Uint256 = SafeUint256.add(tempAccTokensPerShare, dived_data);
            let _returnData: Uint256 = SafeUint256.mul(user.amount, tempAccTokensPerShare);
            let (local returnData: Uint256, _) = SafeUint256.div_rem(_returnData, wei_as_uint256);
            let result: Uint256 = SafeUint256.sub_le(returnData, user.rewardDebt);
            return (result,);
        }
        let _returnData: Uint256 = SafeUint256.mul(user.amount, tempAccTokensPerShare);
        let (local returnData: Uint256, _) = SafeUint256.div_rem(_returnData, wei_as_uint256);
        let result: Uint256 = SafeUint256.sub_le(returnData, user.rewardDebt);

        return (result,);
    }

    let _returnData: Uint256 = SafeUint256.mul(user.amount, tempAccTokensPerShare);
    let (local returnData: Uint256, _) = SafeUint256.div_rem(_returnData, wei_as_uint256);
    let result: Uint256 = SafeUint256.sub_le(returnData, user.rewardDebt);
    return (result,);
}

@view
func getInvestors{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res_len: felt, res: felt*, res_addresses_len: felt, res_addresses: felt*
) {
    let (users_len, users, user_addresses_len, user_addresses) = recursiveGetInvestors(0);
    return (
        users_len * UserInfo.SIZE,
        users - users_len * UserInfo.SIZE,
        user_addresses_len,
        user_addresses - user_addresses_len,
    );
}

func recursiveGetInvestors{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_index: felt
) -> (_users_len: felt, _users: UserInfo*, user_addresses_len: felt, user_addresses: felt*) {
    alloc_locals;
    let (users_count) = get_staker_count();
    let (userAddress) = stakers.read(user_index);
    let (_userInfo: UserInfo) = userInfo.read(userAddress);
    if (user_index == users_count + 1) {
        let (found_investors: UserInfo*) = alloc();
        let (user_addresses: felt*) = alloc();
        return (0, found_investors, 0, user_addresses);
    }

    let (
        users_len, user_memory_location: UserInfo*, addresses_len, addresses: felt*
    ) = recursiveGetInvestors(user_index + 1);
    assert [user_memory_location] = _userInfo;
    assert [addresses] = userAddress;
    return (users_len + 1, user_memory_location + UserInfo.SIZE, addresses_len + 1, addresses + 1);
}

@view
func getUserInfo{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account_address: felt
) -> (res: UserInfo) {
    let (user: UserInfo) = userInfo.read(account_address);
    return (user,);
}

@view
func get_staker_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    let (count) = stakerCount.read();
    return (count,);
}

// #External Functions

@external
func setLockDuration{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lockIndex: felt, lockDuration: felt
) -> () {
    lockTypes.write(lockIndex, lockDuration);
    return ();
}

@external
func dropToken{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    addresses_len: felt, addresses: felt*, amounts_len: felt, amounts: Uint256*
) {
    Ownable.assert_only_owner();
    ReentrancyGuard._start();
    assert addresses_len = amounts_len;
    recursive_drop_token(0, addresses, amounts, addresses_len);
    let current_staker_count: felt = stakerCount.read();
    let new_staker_count: felt = current_staker_count + addresses_len;
    stakerCount.write(new_staker_count);
    ReentrancyGuard._end();
    return ();
}

@external
func unlockTokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(nonce_: felt) {
    ReentrancyGuard._start();
    let (caller) = get_caller_address();
    let (unstaker) = get_unstakerAddress();
    IDolvenUnstaker.unlockTokens(unstaker, caller, nonce_);
    ReentrancyGuard._end();
    return ();
}

@external
func cancelLock{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(nonce_: felt) {
    let (caller) = get_caller_address();
    let (unstaker) = get_unstakerAddress();

    IDolvenUnstaker.cancelTokens(unstaker, caller, nonce_);
    return ();
}

@external
func set_unstakerAddress{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    unstaker_address_: felt
) {
    Ownable.assert_only_owner();
    unstakerAddress.write(unstaker_address_);
    return ();
}

@external
func changePause{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Ownable.assert_only_owner();
    ReentrancyGuard._start();
    let current_status: felt = Pausable.is_paused();
    if (current_status == 1) {
        Pausable._unpause();
    } else {
        Pausable._pause();
    }
    ReentrancyGuard._end();

    return ();
}

@external
func changeTicketLimit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amountToStake: Uint256
) {
    Ownable.assert_only_owner();
    ReentrancyGuard._start();
    limitForTicket.write(_amountToStake);

    ReentrancyGuard._end();
    return ();
}

@external
func delege{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amountToStake: Uint256, _staker: felt, _lockType: felt
) {
    alloc_locals;
    ReentrancyGuard._start();
    assert_nn_le(_lockType, 3);
    let staker: felt = detectAddresss(_staker);
    let current_participant_count: felt = stakerCount.read();
    updatePool();
    let user: UserInfo = userInfo.read(staker);
    let (_stakingToken) = stakingToken.read();
    let (this) = get_contract_address();
    let _tvl: Uint256 = allStakedAmount.read();
    let user_new_amount: Uint256 = user.amount;
    let (time) = get_block_timestamp();

    let is_amount_more_zero: felt = uint256_lt(Uint256(0, 0), user.amount);
    let is_lock_type_less_than_current_lock_type: felt = is_le(user.lockType, _lockType);
    if (is_amount_more_zero == 1) {
        with_attr error_message("DolvenVault::delegate cannot decrease lock type") {
            assert is_lock_type_less_than_current_lock_type = 1;
        }
    }

    let pending: Uint256 = transferPendingReward(user);

    let (caller_) = get_caller_address();
    let unstakerAddress_: felt = unstakerAddress.read();

    if (caller_ == unstakerAddress_) {
        let (txs_success: felt) = IERC20.transferFrom(
            _stakingToken, unstakerAddress_, this, _amountToStake
        );

        with_attr error_message("DolvenVault::delegate Delegation payment failed") {
            assert txs_success = TRUE;
        }
    } else {
        let (txs_success: felt) = IERC20.transferFrom(_stakingToken, staker, this, _amountToStake);

        with_attr error_message("DolvenVault::delegate Delegation payment failed") {
            assert txs_success = TRUE;
        }
    }

    let user_new_amount: Uint256 = SafeUint256.add(_amountToStake, user.amount);
    let user_old_ticket_count: Uint256 = user.dlTicket;
    with_attr error_message("DolvenVault::delegate Delegation payment failed") {
        assert txs_success = TRUE;
    }

    let resTicketCount : Uint256 = returnTicket(user_new_amount, _lockType);

    let new_tvl: Uint256 = SafeUint256.add(_tvl, _amountToStake);
    allStakedAmount.write(new_tvl);

    if (user.isRegistered == 0) {
        stakerCount.write(current_participant_count + 1);
        stakers.write(current_participant_count + 1, staker);
    }

    let _allRewardDebt: Uint256 = allRewardDebt.read();
    let new_rewardDebt: Uint256 = SafeUint256.sub_le(_allRewardDebt, user.rewardDebt);

    let wei: felt = 10 ** 18;
    let wei_as_uint256: Uint256 = Uint256(wei, 0);
    let _accTokensPerShare: Uint256 = accTokensPerShare.read();
    let _userRewardDebt: Uint256 = SafeUint256.mul(user.amount, _accTokensPerShare);
    let (local new_userRewardDebt: Uint256, _) = SafeUint256.div_rem(
        _userRewardDebt, wei_as_uint256
    );
    let __allRewardDebt : Uint256 = SafeUint256.add(new_rewardDebt, new_userRewardDebt);
    allRewardDebt.write(__allRewardDebt);

    let new_user_data = UserInfo(
        amount=user_new_amount,
        rewardDebt=new_userRewardDebt,
        lockType=_lockType,
        updateTime=time,
        dlTicket=resTicketCount,
        isRegistered=1,
    );
    let oldTotalTicketCount: Uint256 = totalTicketCount.read();
    let difference: Uint256 = SafeUint256.sub_le(resTicketCount, user_old_ticket_count);
    let newTotalTicketCount: Uint256 = SafeUint256.add(oldTotalTicketCount, difference);

    totalTicketCount.write(newTotalTicketCount);
    totalLockedTicket_byBlocktime.write(time, resTicketCount);
    ticketCountOfUser_byTime.write(caller_, time, resTicketCount);
    userInfo.write(staker, new_user_data);
    TokensStaked.emit(
        user_account=staker, amount=_amountToStake, reward=pending, totalStakedValue=new_tvl
    );
    ReentrancyGuard._end();
    return ();
}

@external
func unDelegate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amountToWithdraw: Uint256
) {
    alloc_locals;
    ReentrancyGuard._start();
    let (caller) = get_caller_address();
    assert_not_zero(caller);
    let user: UserInfo = userInfo.read(caller);
    let is_amount_biggerthan_right: felt = uint256_le(amountToWithdraw, user.amount);
    with_attr error_message("DolvenVault::unDelegate Invalid Amount") {
        assert is_amount_biggerthan_right = TRUE;
    }
    updatePool();
    let pending: Uint256 = transferPendingReward(user);
    let is_amount_less_than_zero: felt = uint256_le(amountToWithdraw, Uint256(0, 0));
    let user_new_ticket: Uint256 = user.dlTicket;
    let current_participant_count: felt = stakerCount.read();
    let new_user_amount: Uint256 = SafeUint256.sub_le(user.amount, amountToWithdraw);
    if (is_amount_less_than_zero == 0) {
        let zero_as_uint256: Uint256 = Uint256(0, 0);
        let is_same: felt = uint256_eq(new_user_amount, zero_as_uint256);
        let user_new_ticket: Uint256 = returnTicket(new_user_amount, user.lockType);
        _lock(amountToWithdraw);
        if (is_same == 1) {
            stakerCount.write(current_participant_count - 1);
            let user_new_ticket: Uint256 = zero_as_uint256;
        } else {
            let user_new_ticket: Uint256 = returnTicket(new_user_amount, user.lockType);
            processInternalStakeData(
                user.amount,
                user.rewardDebt,
                amountToWithdraw,
                pending,
                user_new_ticket,
                new_user_amount,
                user.lockType,
                user.dlTicket,
            );
            ReentrancyGuard._end();

            return ();
        }
    } else {
        let user_new_ticket: Uint256 = returnTicket(new_user_amount, user.lockType);
        processInternalStakeData(
            user.amount,
            user.rewardDebt,
            amountToWithdraw,
            pending,
            user_new_ticket,
            new_user_amount,
            user.lockType,
            user.dlTicket,
        );
        ReentrancyGuard._end();

        return ();
    }

    processInternalStakeData(
        user.amount,
        user.rewardDebt,
        amountToWithdraw,
        pending,
        user_new_ticket,
        new_user_amount,
        user.lockType,
        user.dlTicket,
    );

    ReentrancyGuard._end();
    return ();
}

@external
func withdrawFunds{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    Ownable.assert_only_owner();
    ReentrancyGuard._start();
    let (time) = get_block_timestamp();
    let _finishTimestamp: felt = finishTimestamp.read();
    let isWithdrawOpen: felt = is_le(_finishTimestamp, time);
    with_attr error_message("DolvenVault::withdrawFunds Too Early") {
        assert isWithdrawOpen = TRUE;
    }
    updatePool();
    let _allRewardDebt: Uint256 = allRewardDebt.read();
    let __allStakedAmount: Uint256 = allStakedAmount.read();
    let _accTokensPerShare: Uint256 = accTokensPerShare.read();
    let _allStakedAmount: Uint256 = SafeUint256.mul(__allStakedAmount, _accTokensPerShare);
    let wei: felt = 10 ** 18;
    let wei_as_uint256: Uint256 = Uint256(wei, 0);
    let (local allStakedAmount_: Uint256, _) = SafeUint256.div_rem(
        _allStakedAmount, wei_as_uint256
    );
    let pending: Uint256 = SafeUint256.sub_le(allStakedAmount_, _allRewardDebt);

    let _poolTokenAmount: Uint256 = poolTokenAmount.read();
    let _allPaidReward: Uint256 = allPaidReward.read();
    let _returnAmount: Uint256 = SafeUint256.sub_le(_poolTokenAmount, _allPaidReward);
    let returnAmount: Uint256 = SafeUint256.sub_le(_returnAmount, pending);
    let res: Uint256 = SafeUint256.add(_allPaidReward, returnAmount);
    allPaidReward.write(res);

    let (caller) = get_caller_address();
    let _rewardToken: felt = rewardToken.read();
    let (is_tx_success: felt) = IERC20.transfer(
        contract_address=_rewardToken, recipient=caller, amount=returnAmount
    );
    with_attr error_message("DolvenVault::withdrawFunds payment failed") {
        assert is_tx_success = TRUE;
    }
    FundsWithdrawed.emit(caller, returnAmount);
    ReentrancyGuard._end();
    return ();
}

@external
func extendDuration{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenAmount: Uint256
) {
    alloc_locals;
    Ownable.assert_only_owner();
    ReentrancyGuard._start();
    let _finishTimestamp: felt = finishTimestamp.read();

    let (current_time) = get_block_timestamp();
    let is_pool_available: felt = is_le(current_time, _finishTimestamp);
    let _rewardToken: felt = rewardToken.read();
    let (caller) = get_caller_address();
    let (this) = get_contract_address();
    with_attr error_message("DolvenVault::extendDuration too late") {
        assert is_pool_available = TRUE;
    }

    let (is_txs_success: felt) = IERC20.transferFrom(_rewardToken, caller, this, tokenAmount);
    with_attr error_message("DolvenVault::extendDuration Fund Transfer Failed") {
        assert is_txs_success = TRUE;
    }

    let _poolTokenAmount: Uint256 = poolTokenAmount.read();
    let poolTokenAmount_: Uint256 = SafeUint256.add(_poolTokenAmount, tokenAmount);
    poolTokenAmount.write(poolTokenAmount_);
    let _finishTimestamp: felt = finishTimestamp.read();
    let _rewardPerTimestamp: Uint256 = rewardPerTimestamp.read();
    let addAmount: Uint256 = SafeUint256.add(tokenAmount, _rewardPerTimestamp);
    let finishTimestamp_as_uint: Uint256 = Uint256(_finishTimestamp, 0);
    let new_finish_timestamp: Uint256 = SafeUint256.add(finishTimestamp_as_uint, addAmount);
    let res: felt = new_finish_timestamp.low;
    finishTimestamp.write(res);

    ReentrancyGuard._end();
    return ();
}

// # Internal Functions

func recursive_drop_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    index: felt, addresses: felt*, amounts: Uint256*, length: felt
) {
    alloc_locals;
    if (index == length) {
        return ();
    }
    let userAddress: felt = addresses[index];
    let userGiftAmount: Uint256 = amounts[index];
    let _userInfo: UserInfo = userInfo.read(userAddress);
    let (time) = get_block_timestamp();
    if (_userInfo.isRegistered == FALSE) {
        let current_staker_count: felt = stakerCount.read();

        let user_new_amount: Uint256 = SafeUint256.add(_userInfo.amount, userGiftAmount);
        let new_ticket_amount: Uint256 = returnTicket(user_new_amount, _userInfo.lockType);
        let difference: Uint256 = SafeUint256.sub_le(new_ticket_amount, _userInfo.dlTicket);
        let _totalTicketCount: Uint256 = totalTicketCount.read();
        let new_total_ticket_count: Uint256 = SafeUint256.add(new_ticket_amount, _totalTicketCount);
        ticketCountOfUser_byTime.write(userAddress, time, new_ticket_amount);
        totalTicketCount.write(new_total_ticket_count);

        stakers.write(current_staker_count + 1, userAddress);

        let new_user: UserInfo = UserInfo(
            amount=user_new_amount,
            rewardDebt=Uint256(0, 0),
            lockType=3,
            updateTime=time,
            dlTicket=new_ticket_amount,
            isRegistered=TRUE,
        );
        userInfo.write(userAddress, new_user);

        recursive_drop_token(index + 1, addresses, amounts, length);

        return ();
    } else {
        let user_new_amount: Uint256 = SafeUint256.add(_userInfo.amount, userGiftAmount);
        let new_ticket_amount: Uint256 = returnTicket(user_new_amount, _userInfo.lockType);
        let difference: Uint256 = SafeUint256.sub_le(new_ticket_amount, _userInfo.dlTicket);
        let _totalTicketCount: Uint256 = totalTicketCount.read();
        let new_total_ticket_count: Uint256 = SafeUint256.add(new_ticket_amount, _totalTicketCount);
        ticketCountOfUser_byTime.write(userAddress, time, new_ticket_amount);
        totalTicketCount.write(new_total_ticket_count);

        let new_user: UserInfo = UserInfo(
            amount=user_new_amount,
            rewardDebt=_userInfo.rewardDebt,
            lockType=_userInfo.lockType,
            updateTime=time,
            dlTicket=new_ticket_amount,
            isRegistered=TRUE,
        );
        userInfo.write(userAddress, new_user);

        recursive_drop_token(index + 1, addresses, amounts, length);

        return ();
    }
}

func _lock{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_amount: Uint256) {
    let tokenAddress: felt = stakingToken.read();
    let (unstaker) = get_unstakerAddress();
    let (caller) = get_caller_address();
    let user: UserInfo = userInfo.read(caller);
    IERC20.approve(tokenAddress, unstaker, _amount);
    IDolvenUnstaker.lockTokens(unstaker, caller, _amount, user.lockType);
    return ();
}

func processInternalStakeData{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_amount: Uint256,
    rewardDebt: Uint256,
    amountToWithdraw: Uint256,
    pending: Uint256,
    user_ticket_count: Uint256,
    new_amount: Uint256,
    _lockType: felt,
    user_old_ticket_count: Uint256,
) {
    alloc_locals;
    let (caller) = get_caller_address();
    let _allRewardDebt: Uint256 = allRewardDebt.read();
    let new_rewardDebt: Uint256 = SafeUint256.sub_le(_allRewardDebt, rewardDebt);

    let wei: felt = 10 ** 18;
    let wei_as_uint256: Uint256 = Uint256(wei, 0);
    let _accTokensPerShare: Uint256 = accTokensPerShare.read();
    let _userRewardDebt: Uint256 = SafeUint256.mul(user_amount, _accTokensPerShare);
    let (local new_userRewardDebt: Uint256, _) = SafeUint256.div_rem(
        _userRewardDebt, wei_as_uint256
    );

    let __allRewardDebt: Uint256 = SafeUint256.add(new_rewardDebt, new_userRewardDebt);
    allRewardDebt.write(__allRewardDebt);

    let tvl: Uint256 = allStakedAmount.read();
    let new_tvl: Uint256 = SafeUint256.sub_le(tvl, amountToWithdraw);
    allStakedAmount.write(new_tvl);

    let time: felt = get_block_timestamp();
    let new_user_data = UserInfo(
        amount=new_amount,
        rewardDebt=new_userRewardDebt,
        lockType=_lockType,
        updateTime=time,
        dlTicket=user_ticket_count,
        isRegistered=1,
    );
    let (time) = get_block_timestamp();
    let diff: Uint256 = SafeUint256.sub_le(user_old_ticket_count, user_ticket_count);
    let oldTotalTicketCount: Uint256 = totalTicketCount.read();
    let newTotalTicketCount: Uint256 = SafeUint256.sub_le(oldTotalTicketCount, diff);
    ticketCountOfUser_byTime.write(caller, time, user_ticket_count);
    totalTicketCount.write(newTotalTicketCount);
    totalLockedTicket_byBlocktime.write(time, newTotalTicketCount);
    userInfo.write(caller, new_user_data);

    StakeWithdrawn.emit(
        user_account=caller, amount=amountToWithdraw, reward=pending, totalStakedValue=new_tvl
    );

    return ();
}

func returnTicket{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_new_amount: Uint256, _lockType: felt
) -> (res: Uint256) {
    alloc_locals;
    let _limitForTicket: Uint256 = limitForTicket.read();
    let is_farming_: felt = isFarming.read();
    if (is_farming_ == 1) {
        if (_lockType == 0) {
            let (local ticketValue: Uint256, _) = SafeUint256.div_rem(
                user_new_amount, _limitForTicket
            );
            return (ticketValue,);
        }

        if (_lockType == 1) {
            let (local _ticketValue: Uint256, _) = SafeUint256.div_rem(
                user_new_amount, _limitForTicket
            );
            let ticketValue: Uint256 = SafeUint256.mul(_ticketValue, Uint256(2, 0));
            return (ticketValue,);
        }

        if (_lockType == 2) {
            let (local _ticketValue: Uint256, _) = SafeUint256.div_rem(
                user_new_amount, _limitForTicket
            );
            let ticketValue: Uint256 = SafeUint256.mul(_ticketValue, Uint256(6, 0));
            return (ticketValue,);
        }

        if (_lockType == 3) {
            let (local _ticketValue: Uint256, _) = SafeUint256.div_rem(
                user_new_amount, _limitForTicket
            );
            let ticketValue: Uint256 = SafeUint256.mul(_ticketValue, Uint256(10, 0));
            return (ticketValue,);
        }
    } else {
        if (_lockType == 0) {
            let (local _ticketValue: Uint256, _) = SafeUint256.div_rem(
                user_new_amount, _limitForTicket
            );
            let ticketValue: Uint256 = SafeUint256.mul(_ticketValue, Uint256(2, 0));
            return (ticketValue,);
        }

        if (_lockType == 1) {
            let (local _ticketValue: Uint256, _) = SafeUint256.div_rem(
                user_new_amount, _limitForTicket
            );
            let ticketValue: Uint256 = SafeUint256.mul(_ticketValue, Uint256(4, 0));
            return (ticketValue,);
        }

        if (_lockType == 2) {
            let (local _ticketValue: Uint256, _) = SafeUint256.div_rem(
                user_new_amount, _limitForTicket
            );
            let ticketValue: Uint256 = SafeUint256.mul(_ticketValue, Uint256(12, 0));
            return (ticketValue,);
        }

        if (_lockType == 3) {
            let (local _ticketValue: Uint256, _) = SafeUint256.div_rem(
                user_new_amount, _limitForTicket
            );
            let ticketValue: Uint256 = SafeUint256.mul(_ticketValue, Uint256(20, 0));
            return (ticketValue,);
        }
    }
    return (Uint256(0, 0),);
}

func detectAddresss{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt
) -> (res: felt) {
    let is_address_not_zero: felt = is_not_zero(address);
    let staker: felt = 0;
    let (caller) = get_caller_address();
    assert_not_zero(caller);

    if (is_address_not_zero == 0) {
        let staker: felt = caller;
        return (staker,);
    }

    if (is_address_not_zero == 1) {
        let staker: felt = address;
        return (staker,);
    }

    return (0,);
}

func get_multiplier{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _from: felt, _to: felt
) -> (res: felt) {
    alloc_locals;
    let (_finishTimestamp) = finishTimestamp.read();
    let is_le__to__finishTimestamp = is_le(_to, _finishTimestamp);
    let is_le__to__from = is_le(_to, _from);
    let is_le__finishTimestamp__from = is_le(_finishTimestamp, _from);
    if (is_le__to__from == 1) {
        return (0,);
    }
    if (is_le__to__finishTimestamp == 1) {
        return (_to - _from,);
    } else {
        if (is_le__finishTimestamp__from == 1) {
            return (0,);
        } else {
            return (_finishTimestamp - _from,);
        }
    }
}

func updatePool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (_blockTime) = get_block_timestamp();
    let _lastRewardTime: felt = lastRewardTimestamp.read();
    let res: felt = is_le(_blockTime, _lastRewardTime);
    let _rewardPerTime: Uint256 = rewardPerTimestamp.read();
    let _allStakedAmount: Uint256 = allStakedAmount.read();
    let zero_as_uint256: Uint256 = Uint256(0, 0);
    let condition: felt = uint256_eq(_allStakedAmount, zero_as_uint256);
    if (res == 1) {
        return ();
    }

    if (condition == 1) {
        lastRewardTimestamp.write(_blockTime);
        return ();
    }

    let wei: felt = 10 ** 18;
    let wei_as_uint256: Uint256 = felt_to_uint256(wei);
    let _multiplier: felt = get_multiplier(_lastRewardTime, _blockTime);
    let multiplier: Uint256 = felt_to_uint256(_multiplier);
    let reward: Uint256 = SafeUint256.mul(multiplier, _rewardPerTime);
    let data_x: Uint256 = SafeUint256.mul(reward, wei_as_uint256);
    let (local rw_data: Uint256, _) = SafeUint256.div_rem(data_x, _allStakedAmount);
    let _accTokensPerShare: Uint256 = accTokensPerShare.read();
    let new_accPerShare: Uint256 = SafeUint256.add(rw_data, _accTokensPerShare);
    accTokensPerShare.write(new_accPerShare);
    lastRewardTimestamp.write(_blockTime);

    return ();
}

func felt_to_uint256{range_check_ptr}(x) -> (uint_x: Uint256) {
    let (high, low) = split_felt(x);
    return (Uint256(low=low, high=high),);
}

func uint256_to_felt{range_check_ptr}(value: Uint256) -> (value: felt) {
    assert_lt_felt(value.high, 2 ** 123);
    return (value.high * (2 ** 128) + value.low,);
}

func transferPendingReward{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _user: UserInfo
) -> (res: Uint256) {
    alloc_locals;
    let is_amount_less_than_zero: felt = uint256_le(_user.amount, Uint256(0, 0));
    if (is_amount_less_than_zero == 0) {
        let wei: felt = 10 ** 18;
        let wei_as_uint256: Uint256 = felt_to_uint256(wei);
        let _accTokensPerShare: Uint256 = accTokensPerShare.read();

        let __pending: Uint256 = SafeUint256.mul(_user.amount, _accTokensPerShare);
        let (local _pending: Uint256, _) = SafeUint256.div_rem(__pending, wei_as_uint256);
        let pending: Uint256 = SafeUint256.sub_le(_pending, _user.rewardDebt);

        let res_condition: felt = uint256_lt(Uint256(0, 0), pending);
        let _rewardToken: felt = rewardToken.read();
        let (caller) = get_caller_address();
        let _allPaidReward: Uint256 = allPaidReward.read();
        let _updatedReward: Uint256 = SafeUint256.add(_allPaidReward, pending);
        if (res_condition == 1) {
            IERC20.transfer(contract_address=_rewardToken, recipient=caller, amount=pending);
            allPaidReward.write(_updatedReward);
            return (pending,);
        }
        return (pending,);
    }
    return (Uint256(0, 0),);
}
