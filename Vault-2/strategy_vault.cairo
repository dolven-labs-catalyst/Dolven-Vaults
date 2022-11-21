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
    sqrt
)
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_le, uint256_lt, uint256_sub
from contracts.openzeppelin.security.safemath import SafeUint256

from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_nn, is_nn_le, is_in_range
from contracts.openzeppelin.token.ERC20.interfaces.IERC20 import IERC20
from contracts.openzeppelin.access.ownable import Ownable
from contracts.openzeppelin.security.pausable import Pausable
from contracts.openzeppelin.security.reentrancy_guard import ReentrancyGuard
from contracts.Interfaces.IDolvenUnstaker import IDolvenUnstaker
from contracts.Interfaces.ITicketManager import ITicketManager

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
func allStakedAmount() -> (amount: felt) {
}

@storage_var
func allPaidReward() -> (amount: felt) {
}

@storage_var
func allRewardDebt() -> (amount: felt) {
}

@storage_var
func poolTokenAmount() -> (amount: felt) {
}

@storage_var
func rewardPerTimestamp() -> (timestamp: felt) {
}

@storage_var
func accTokensPerShare() -> (amount: felt) {
}

@storage_var
func stakerCount() -> (count: felt) {
}

@storage_var
func isFarming() -> (value: felt) {
}

@storage_var
func ticketManager() -> (value: felt) {
}

@storage_var
func unstakerAddress() -> (contract_address: felt) {
}


// #Structs

struct UserInfo {
    amount: felt,  // How many tokens the user has staked.
    rewardDebt: felt,  // Reward debt
    lockType: felt,  // Lock type
    updateTime: felt,  // update time
    isRegistered: felt,  // is user participated before
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
func TokensStaked(user_account: felt, amount: felt, reward: felt, totalStakedValue: felt) {
}

@event
func StakeWithdrawn(
    user_account: felt, amount: felt, reward: felt, totalStakedValue: felt
) {
}

@event
func FundsWithdrawed(user_account: felt, amount: felt) {
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
    Ownable.initializer(_admin);
    let (time) = get_block_timestamp();
    let res: felt = is_le(_startTimestamp, _finishTimestamp);
    let res_x: felt = is_le(_finishTimestamp, time);
    let res_t: felt = _finishTimestamp - _startTimestamp;
    let (_rewardPerTimestamp, _) = unsigned_div_rem(
        _poolTokenAmount, res_t
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
    poolTokenAmount.write(_poolTokenAmount);
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
    tvl: felt,
    _lastRewardTimestamp: felt,
    _allPaidReward: felt,
    _allRewardDebt: felt,
    _poolTokenAmount: felt,
    _rewardPerTimestamp: felt,
    _accTokensPerShare: felt,
    _isFarming: felt,
) {
    let _stakingToken: felt = stakingToken.read();
    let _rewardToken: felt = rewardToken.read();
    let _startTime: felt = startTimestamp.read();
    let _finihTime: felt = finishTimestamp.read();
    let tvl: felt = allStakedAmount.read();
    let _lastRewardTimestamp: felt = lastRewardTimestamp.read();
    let _allPaidReward: felt = allPaidReward.read();
    let _allRewardDebt: felt = allRewardDebt.read();
    let _poolTokenAmount: felt = poolTokenAmount.read();
    let _rewardPerTimestamp: felt = rewardPerTimestamp.read();
    let _accTokensPerShare: felt = accTokensPerShare.read();
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
    res: felt
) {
    let res: felt = accTokensPerShare.read();
    return (res,);
}

@view
func returnTicketManager{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    let res: felt = ticketManager.read();
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
func get_tvl{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    let res: felt = allStakedAmount.read();
    return (res,);
}

@view
func pendingReward{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account_address: felt
) -> (reward: felt) {
    alloc_locals;
    let user: UserInfo = userInfo.read(account_address);
    let tempAccTokensPerShare: felt = accTokensPerShare.read();
    let _lastRewardTime: felt = lastRewardTimestamp.read();
    let _allStakedAmount: felt = allStakedAmount.read();
    let _rewardPerTimestamp: felt = rewardPerTimestamp.read();
    let (time) = get_block_timestamp();
    let res: felt = is_le(time, _lastRewardTime);
    let is_tvl_zero: felt = is_not_zero(_allStakedAmount);
    let wei: felt = 10 ** 18;
    if (res == 0) {
        if (is_tvl_zero == 0) {
            let multiplier: felt = get_multiplier(_lastRewardTime, time);
            let reward: felt = multiplier * _rewardPerTimestamp;
            let wei_reward: felt = reward * wei;
            //1,918,260,473,588,342,423,000,000,000,000,000,000
            let (dived_data, _) = unsigned_div_rem(wei_reward, _allStakedAmount);
            //2,471,985,146,376,729.92654639175257731958
            let tempAccTokensPerShare: felt = tempAccTokensPerShare + dived_data;
            //15,593,000,983,725,014,553
            let _returnData: felt = user.amount * tempAccTokensPerShare;
            //452,197,028,528,025,422,037,000,000,000,000,000,000
            let (returnData, _) = unsigned_div_rem(_returnData, wei);
           //452,197,028,528,025,422,037
            let result: felt = returnData - user.rewardDebt;
            //-117,558,266,152,595,732,775
            return (result,);
        }
        let _returnData: felt = user.amount * tempAccTokensPerShare;
        let (returnData, _) = unsigned_div_rem(_returnData, wei);
        let result: felt = returnData - user.rewardDebt;

        return (result,);
    }

    let _returnData: felt = user.amount * tempAccTokensPerShare;
    let (returnData, _) = unsigned_div_rem(_returnData, wei);
    let result: felt = returnData - user.rewardDebt;
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
) -> (res: UserInfo, user_ticket_count : felt) {
    let user : UserInfo = userInfo.read(account_address);
    let _ticketManager : felt = ticketManager.read();
    let user_ticket : felt = ITicketManager.get_userTickets(_ticketManager, account_address, 0);
    return (user, user_ticket,);
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
    Ownable.assert_only_owner();
    lockTypes.write(lockIndex, lockDuration);
    return ();
}

@external
func setTicketManager{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt
) -> () {
    Ownable.assert_only_owner();
    ticketManager.write(address);
    return ();
}



@external
func unlockTokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(nonce_: felt) {
    ReentrancyGuard._start();
    Pausable.assert_not_paused();
    let (caller) = get_caller_address();
    let (unstaker) = get_unstakerAddress();
    IDolvenUnstaker.unlockTokens(unstaker, caller, nonce_);
    ReentrancyGuard._end();
    return ();
}

@external
func cancelLock{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(nonce_: felt) {
    Pausable.assert_not_paused();
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
func delege{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amountToStake: felt, _staker: felt, _lockType: felt
) {
    alloc_locals;
    ReentrancyGuard._start();
    Pausable.assert_not_paused();
    assert_nn_le(_lockType, 3);
    let staker: felt = detectAddress(_staker);
    let current_participant_count: felt = stakerCount.read();
    updatePool();
    let user: UserInfo = userInfo.read(staker);
    let (_stakingToken) = stakingToken.read();
    let (this) = get_contract_address();
    let _tvl: felt = allStakedAmount.read();
    let user_new_amount: felt = user.amount;
    let (time) = get_block_timestamp();

    let is_amount_more_zero: felt = is_le(1, user.amount);
    let is_lock_type_less_than_current_lock_type: felt = is_le(user.lockType, _lockType);
    if (is_amount_more_zero == 1) {
        with_attr error_message("DolvenVault::delegate cannot decrease lock type") {
            assert is_lock_type_less_than_current_lock_type = 1;
        }
    }

    let pending: felt = transferPendingReward(user);

    let (caller_) = get_caller_address();
    let unstakerAddress_: felt = unstakerAddress.read();
    let amountToTransfer : Uint256 = felt_to_uint256(_amountToStake);
    if (caller_ == unstakerAddress_) {
        let (txs_success: felt) = IERC20.transferFrom(
            _stakingToken, unstakerAddress_, this, amountToTransfer
        );

        with_attr error_message("DolvenVault::delegate Delegation payment failed") {
            assert txs_success = TRUE;
        }
    } else {
        let (txs_success: felt) = IERC20.transferFrom(_stakingToken, staker, this, amountToTransfer);

        with_attr error_message("DolvenVault::delegate Delegation payment failed") {
            assert txs_success = TRUE;
        }
    }

    let user_new_amount : felt = _amountToStake + user.amount;
    with_attr error_message("DolvenVault::delegate Delegation payment failed") {
        assert txs_success = TRUE;
    }


    let new_tvl: felt = _tvl + _amountToStake;
    allStakedAmount.write(new_tvl);

    if (user.isRegistered == 0) {
        stakerCount.write(current_participant_count + 1);
        stakers.write(current_participant_count + 1, staker);
    }

    let _allRewardDebt: felt = allRewardDebt.read();
    let new_rewardDebt: felt = _allRewardDebt - user.rewardDebt;

    let wei: felt = 10 ** 18;
    let _accTokensPerShare: felt = accTokensPerShare.read();
    let _userRewardDebt: felt = user_new_amount * _accTokensPerShare;
    let (new_userRewardDebt, _) = unsigned_div_rem(
        _userRewardDebt, wei
    );
    let __allRewardDebt : felt = new_rewardDebt + new_userRewardDebt;
    allRewardDebt.write(__allRewardDebt);

    let new_user_data = UserInfo(
        amount=user_new_amount,
        rewardDebt=new_userRewardDebt,
        lockType=_lockType,
        updateTime=time,
        isRegistered=1,
    );
    let _ticketManager : felt = ticketManager.read();
    ITicketManager.updateTickets(_ticketManager, _lockType, user_new_amount, staker, time);
    userInfo.write(staker, new_user_data);
    TokensStaked.emit(
        user_account=staker, amount=_amountToStake, reward=pending, totalStakedValue=new_tvl
    );
    ReentrancyGuard._end();
    return ();
}

@external
func unDelegate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amountToWithdraw: felt
) {
    alloc_locals;
    ReentrancyGuard._start();
    Pausable.assert_not_paused();
    let (caller) = get_caller_address();
    assert_not_zero(caller);
    let user: UserInfo = userInfo.read(caller);
    let is_amount_biggerthan_right: felt = is_le(amountToWithdraw, user.amount);
    with_attr error_message("DolvenVault::unDelegate Invalid Amount") {
        assert is_amount_biggerthan_right = TRUE;
    }
    updatePool();
    let pending: felt = transferPendingReward(user);
    let is_amount_diff_than_zero: felt = is_not_zero(amountToWithdraw);
    if (is_amount_diff_than_zero == 1) {
        let current_participant_count: felt = stakerCount.read();
        let new_user_amount: felt = user.amount - amountToWithdraw;
        
        if (new_user_amount == 0) {
            stakerCount.write(current_participant_count - 1);
            return ();
        } 

        processInternalStakeData(
                user.amount,
                user.rewardDebt,
                amountToWithdraw,
                pending,
                new_user_amount,
                user.lockType,
            );
        _lock(amountToWithdraw);
        ReentrancyGuard._end();

        return ();

    } else {
    //harvest
        processInternalStakeData(
            user.amount,
            user.rewardDebt,
            amountToWithdraw,
            pending,
            user.amount,
            user.lockType,
        );
      
        ReentrancyGuard._end();

        return ();
    }
}

@external
func withdrawFunds{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    Ownable.assert_only_owner();
    ReentrancyGuard._start();
    Pausable.assert_not_paused();
    let (time) = get_block_timestamp();
    let _finishTimestamp: felt = finishTimestamp.read();
    let isWithdrawOpen: felt = is_le(_finishTimestamp, time);
    with_attr error_message("DolvenVault::withdrawFunds Too Early") {
        assert isWithdrawOpen = TRUE;
    }
    updatePool();
    let _allRewardDebt: felt = allRewardDebt.read();
    let __allStakedAmount: felt = allStakedAmount.read();
    let _accTokensPerShare: felt = accTokensPerShare.read();
    let _allStakedAmount: felt = __allStakedAmount * _accTokensPerShare;
    let wei: felt = 10 ** 18;
    let (allStakedAmount_, _) = unsigned_div_rem(
        _allStakedAmount, wei
    );
    let pending: felt = allStakedAmount_ - _allRewardDebt;

    let _poolTokenAmount: felt = poolTokenAmount.read();
    let _allPaidReward: felt = allPaidReward.read();
    let _returnAmount: felt =_poolTokenAmount - _allPaidReward;
    let returnAmount: felt = _returnAmount - pending;
    let __returnAmount : Uint256 = felt_to_uint256(returnAmount);
    let res: felt = _allPaidReward + returnAmount;
    allPaidReward.write(res);

    let (caller) = get_caller_address();
    let _rewardToken: felt = rewardToken.read();
    let (is_tx_success: felt) = IERC20.transfer(
        contract_address=_rewardToken, recipient=caller, amount=__returnAmount
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
    tokenAmount: felt
) {
    alloc_locals;
    Ownable.assert_only_owner();
    ReentrancyGuard._start();
    Pausable.assert_not_paused();
    let _finishTimestamp: felt = finishTimestamp.read();

    let (current_time) = get_block_timestamp();
    let is_pool_available: felt = is_le(current_time, _finishTimestamp);
    let _rewardToken: felt = rewardToken.read();
    let (caller) = get_caller_address();
    let (this) = get_contract_address();
    with_attr error_message("DolvenVault::extendDuration too late") {
        assert is_pool_available = TRUE;
    }
    let _tokenAmount : Uint256 = felt_to_uint256(tokenAmount);
    let (is_txs_success: felt) = IERC20.transferFrom(_rewardToken, caller, this, _tokenAmount);
    with_attr error_message("DolvenVault::extendDuration Fund Transfer Failed") {
        assert is_txs_success = TRUE;
    }

    let _poolTokenAmount: felt = poolTokenAmount.read();
    let poolTokenAmount_: felt = _poolTokenAmount + tokenAmount;
    poolTokenAmount.write(poolTokenAmount_);
    let _finishTimestamp: felt = finishTimestamp.read();
    let _rewardPerTimestamp: felt = rewardPerTimestamp.read();
    let addAmount: felt = tokenAmount + _rewardPerTimestamp;
    let new_finish_timestamp: felt = _finishTimestamp + addAmount;
    finishTimestamp.write(new_finish_timestamp);

    ReentrancyGuard._end();
    return ();
}

// # Internal Functions

func _lock{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_amount: felt) {
    alloc_locals;
    let tokenAddress: felt = stakingToken.read();
    let (unstaker) = get_unstakerAddress();
    let (caller) = get_caller_address();
    let user: UserInfo = userInfo.read(caller);
    let amount : Uint256 = felt_to_uint256(_amount);
    IERC20.approve(tokenAddress, unstaker, amount);
    IDolvenUnstaker.lockTokens(unstaker, caller, _amount, user.lockType);
    return ();
}

func processInternalStakeData{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_amount: felt,
    rewardDebt: felt,
    amountToWithdraw: felt,
    pending: felt,
    new_amount: felt,
    _lockType: felt,
) {
    alloc_locals;
    let (caller) = get_caller_address();
    let _allRewardDebt: felt = allRewardDebt.read();
    let new_rewardDebt: felt = _allRewardDebt - rewardDebt;

    let wei: felt = 10 ** 18;
    let _accTokensPerShare: felt = accTokensPerShare.read();
    let _userRewardDebt: felt = new_amount * _accTokensPerShare;
    let ( new_userRewardDebt, _) = unsigned_div_rem(
        _userRewardDebt, wei
    );

    let __allRewardDebt: felt = new_rewardDebt + new_userRewardDebt;
    allRewardDebt.write(__allRewardDebt);

    let tvl: felt = allStakedAmount.read();
    let new_tvl: felt = tvl - amountToWithdraw;
    allStakedAmount.write(new_tvl);

    let time: felt = get_block_timestamp();
    let new_user_data = UserInfo(
        amount=new_amount,
        rewardDebt=new_userRewardDebt,
        lockType=_lockType,
        updateTime=time,
        isRegistered=1,
    );
    let (time) = get_block_timestamp();

    userInfo.write(caller, new_user_data);
    let _ticketManager : felt = ticketManager.read();
    ITicketManager.updateTickets(_ticketManager, _lockType, new_amount, caller, time);

    StakeWithdrawn.emit(
        user_account=caller, amount=amountToWithdraw, reward=pending, totalStakedValue=new_tvl
    );

    return ();
}

func detectAddress{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
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
    let _finishTimestamp : felt = finishTimestamp.read();
    let is_le__to__finishTimestamp = is_le(_to, _finishTimestamp);
    let is_le__to__from = is_le(_to, _from);
    let is_le__finishTimestamp__from = is_le(_finishTimestamp, _from);
    if (is_le__to__from == TRUE) {
        return (0,);
    }
    if (is_le__to__finishTimestamp == TRUE) {
        return (_to - _from,);
    } else {
        if (is_le__finishTimestamp__from == TRUE) {
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
    let _rewardPerTime: felt = rewardPerTimestamp.read();
    let _allStakedAmount: felt = allStakedAmount.read();
    let condition: felt = is_not_zero(_allStakedAmount);
    if (res == 1) {
        return ();
    }

    if (condition == 0) {
        lastRewardTimestamp.write(_blockTime);
        return ();
    }

    let wei: felt = 10 ** 18;
    let _multiplier: felt = get_multiplier(_lastRewardTime, _blockTime);
    let reward: felt = _multiplier * _rewardPerTime;
    let data_x: felt = reward * wei;
    let (rw_data: felt, _) = unsigned_div_rem(data_x, _allStakedAmount);
    let _accTokensPerShare: felt = accTokensPerShare.read();
    let new_accPerShare: felt = rw_data + _accTokensPerShare;
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
) -> (res: felt) {
    alloc_locals;
    let is_amount_less_than_zero : felt = is_le(_user.amount, 0);
    if (is_amount_less_than_zero == 0){
        let wei: felt = 10 ** 18;
        let _accTokensPerShare: felt = accTokensPerShare.read();

        let __pending: felt = _user.amount * _accTokensPerShare;
        let (_pending, _) = unsigned_div_rem(__pending, wei);
        let pending: felt = _pending - _user.rewardDebt;
        let pending_uint : Uint256 = felt_to_uint256(pending);
        let res_condition: felt = is_le(1, pending);
        let _rewardToken: felt = rewardToken.read();
        let (caller) = get_caller_address();
        if (res_condition == 1) {
            let _allPaidReward: felt = allPaidReward.read();
            let _updatedReward: felt = _allPaidReward + pending;
            IERC20.transfer(contract_address=_rewardToken, recipient=caller, amount=pending_uint);
            allPaidReward.write(_updatedReward);
            return (pending,);
        }
        return (pending,);
    }
    return (0,);
}