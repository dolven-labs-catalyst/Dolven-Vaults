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


struct Checkpoint {
    amount : felt,
    block_time : felt,
}

//vault types => 0 -> total, 1 -> staking, 2 -> farming 

@storage_var
func totalTicketCount(vault_type : felt) -> (ticketCount: felt) {
}

@storage_var
func userTickets(account : felt, vault_type : felt) -> (ticketCount: felt) {
}

@storage_var
func limitForTicket(vault_type : felt) -> (tokenCount: felt) {
}

@storage_var
func admin_accounts(vault_type : felt) -> (account: felt) {
}

@storage_var
func lock_multiples(vault_type : felt, lock_type : felt) -> (multipler: felt) {
}

@storage_var
func delegator_count() -> (count: felt) {
}


//checkpoint storage
@storage_var
func user_ticket_size(user_account: felt) -> (count: felt) {
}

@storage_var
func user_checkpoint_by_nonce(user_account: felt, index: felt) -> (ckpt: Checkpoint) {
}

@storage_var
func totalTicketCount_size() -> (count: felt) {
}

@storage_var
func totalLockedTicket_byNonce(id: felt) -> (res: Checkpoint) {
}


@event
func TicketUpdated(user_address: felt, new_ticket_amount: felt, oldTicketAmount: felt, totalTicketAmount: felt, time : felt) {
}

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    staking_vault : felt, farming_vault : felt, 
) {
    admin_accounts.write(0, staking_vault);
    admin_accounts.write(1, farming_vault);
    return();
}
// views

@view
func get_totalTicketCount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    vault_type : felt
) -> (amount : felt){
    let amount : felt = totalTicketCount.read(vault_type);
    return(amount,);
}

@view
func get_userTickets{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account : felt, vault_type : felt
) -> (amount : felt){
    let amount : felt = userTickets.read(account, vault_type);
    return(amount,);
}

@view
func get_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
     vault_type : felt
) -> (amount : felt){
    let amount : felt = limitForTicket.read(vault_type);
    return(amount,);
}

@view
func get_admins{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
     vault_type : felt
) -> (account : felt){
    let account : felt = admin_accounts.read(vault_type);
    return(account,);
}

@view
func get_lockMultiples{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
     vault_type : felt, lock_type : felt
) -> (multipler : felt){
    let multipler : felt = lock_multiples.read(vault_type,lock_type);
    return(multipler,);
}


// setters


@external
func set_Limits{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    vault_type : felt, amount : felt
) {
    Ownable.assert_only_owner();
    limitForTicket.write(vault_type, amount);
    return();
}

@external
func set_VaultAddresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    vault_type : felt, account : felt
) {
    Ownable.assert_only_owner();
    admin_accounts.write(vault_type, account);
    return();
}

@external
func set_lockMultiples{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    vault_type : felt, lock_type : felt, multiple : felt
) {
    Ownable.assert_only_owner();
    lock_multiples.write(vault_type, lock_type, multiple);
    return();
}

// externals

@view
func calcTicketCount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _user_new_amount : felt, _lock_type : felt, vault_type : felt
) -> (ticketAmount : felt) {
    
    alloc_locals;
    let multiple : felt = lock_multiples.read(vault_type, _lock_type);
    let _limitForTicket: felt = limitForTicket.read(vault_type);

        
    let (_ticketValue, _) = unsigned_div_rem(
        _user_new_amount, _limitForTicket
    );
    let ticketValue = multiple * _ticketValue;
    return (ticketValue,);
}

@external
func updateTickets{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    lock_type : felt, amount : felt, user_address : felt, time : felt
) {
    alloc_locals;
    assertAdmin();
    let (time) = get_block_timestamp();
    let vault_type : felt = detectVaultType();
    let oldUserTicketCount : felt = userTickets.read(user_address, vault_type + 1);
    let totalOldTicketCount : felt = totalTicketCount.read(0);
    let totalOldTicketCount_vaultType : felt = totalTicketCount.read(vault_type);

    let newTicketAmount : felt = calcTicketCount(amount, lock_type, vault_type);
    let diff :felt = newTicketAmount - oldUserTicketCount;

    let newTotalTicketCount : felt = totalOldTicketCount + diff;
    let newTotalTicketCount_vaultType : felt = totalOldTicketCount_vaultType + diff;

    // user updates

    let oldUserTicketSize : felt = user_ticket_size.read(user_address);
    let newCheckpoint : Checkpoint = Checkpoint(
        amount=newTicketAmount,
        block_time=time,
    );

    user_checkpoint_by_nonce.write(user_address, oldUserTicketSize, newCheckpoint);
    userTickets.write(user_address, vault_type, newTicketAmount);
    user_ticket_size.write(user_address, oldUserTicketSize + 1);

    //total ticket

    let oldTotalTicketCount_size : felt = totalTicketCount_size.read();
    let newTotalCheckpoint : Checkpoint = Checkpoint(
        amount=newTotalTicketCount,
        block_time=time,
    );

    totalLockedTicket_byNonce.write(oldTotalTicketCount_size, newTotalCheckpoint);
    totalTicketCount.write(vault_type, newTotalTicketCount_vaultType);
    totalTicketCount.write(0, newTotalTicketCount);
    totalTicketCount_size.write(oldTotalTicketCount_size + 1);

    TicketUpdated.emit(user_address=user_address, new_ticket_amount=newTicketAmount, oldTicketAmount=oldUserTicketCount, totalTicketAmount=newTotalTicketCount, time=time);
    
    let is_enough : felt = is_le(1, newTicketAmount);
    let already_have_ticket : felt = is_le(1, oldUserTicketSize);
    
    if(is_enough == TRUE){
        if(already_have_ticket == FALSE){
            let _delegatorCount : felt = delegator_count.read();
            delegator_count.write(_delegatorCount + 1);
            return();
        }
        return();
    }else{
        if(already_have_ticket == TRUE){
            let _delegatorCount : felt = delegator_count.read();
            delegator_count.write(_delegatorCount - 1);
            return();
        }
        return();
    }

}


// checkpoint lookup
//checkpoint type -> 0 for total values 
//checkpoint type -> 1 for user based values
@view
func _checkpointsLookup{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_address : felt, find_time : felt, checkpointType : felt
) -> (res: felt){
    alloc_locals;
    let length : felt = 0;

    if(checkpointType == 0){
        let len : felt = user_ticket_size.read(user_address);
        length = len;
    }else{
        let len : felt = totalTicketCount_size.read();
        length = len;
    }

    let low : felt = 0;
    let high : felt= length;

    let is_more_than_five :felt = is_le(5, length);
    if(is_more_than_five == TRUE){
        let _sqrt_length : felt = sqrt(length);
        let mid : felt = length - _sqrt_length; 


        if(checkpointType == 0){
            let (point) = user_checkpoint_by_nonce.read(user_address, mid);
        }else{
            let (point) = totalLockedTicket_byNonce.read(mid);
        }

        //from < find_time
        let is_from_less_than_find : felt = is_le(point.block_time + 1, find_time);

        if(is_from_less_than_find == FALSE){
            return recursive_checkup(low, mid, find_time, user_address, checkpointType);
        }else{
            return recursive_checkup(mid + 1, high, find_time, user_address, checkpointType);
        }
    }
    return recursive_checkup(low, high, find_time, user_address, checkpointType);
}


func find_average{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    low : felt, high : felt
) -> (res: felt){
    let sum : felt = low + high;
    let (div_sum, _) = unsigned_div_rem(sum, 2);
    return(div_sum,);
}


func recursive_checkup{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    low : felt, high : felt, find_time : felt, user_address : felt, checkpointType: felt
) -> (res : felt){
    alloc_locals;
    let is_low_less_than_high :felt = is_le(low + 1, high);

    if(is_low_less_than_high == FALSE){
        if(high == 0){
            return(0,);
        }
        if(checkpointType == 0){
            let (point) = user_checkpoint_by_nonce.read(user_address, high -1);
        }else{
            let (point) = totalLockedTicket_byNonce.read(high -1);
        }
        let res : felt = point.amount;
        return(res,);
    }
    
    let mid : felt = find_average(low, high);
     if(checkpointType == 0){
        let (point) = user_checkpoint_by_nonce.read(user_address, mid);
    }else{
        let (point) = totalLockedTicket_byNonce.read(mid);
    }
    let from_time : felt = point.block_time;
    //from < find_time
    let is_from_less_than_find :felt = is_le(from_time + 1, find_time);

    if(is_from_less_than_find == FALSE){
        return recursive_checkup(low, mid, find_time, user_address, checkpointType);
    }else{
        return recursive_checkup(mid + 1, high, find_time, user_address, checkpointType);
    }
    
}

// internal 

func detectVaultType{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (vault_type : felt){
    let (msg_sender) = get_caller_address();
    assert_not_zero(msg_sender);
    let (stakingVault) = get_admins(0); 
    let (farmingVault) = get_admins(1); 

    if(msg_sender == stakingVault){
        return(0,);
    }else{
        return(1,);
    }
}

func assertAdmin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
    let (msg_sender) = get_caller_address();
    assert_not_zero(msg_sender);

    let (stakingVault) = get_admins(0); 
    let (farmingVault) = get_admins(1); 

    if(stakingVault == msg_sender){
        return();
    }else{
        if(farmingVault == msg_sender){
            return();
        }
        with_attr error_message("TicketManager::unauthorized access ") {
        assert 1 = 0;
        }
        return();
    }

}



