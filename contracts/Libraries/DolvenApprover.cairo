%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_equal

from starkware.cairo.common.math_cmp import is_not_zero
from Libraries.DolvenRole import DolvenRoles

@storage_var
func firstSignAddress() -> (res : felt):
end

@storage_var
func secondSignAddress() -> (res : felt):
end

@storage_var
func signed(address : felt) -> (res : felt):
end

@event
func ApproverAdded(user_account : felt):
end

@event
func ApproverRemoved(user_account : felt):
end

@external
func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _firstSignAddress : felt, _secondSignAddress : felt, initialApprover : felt
):
    firstSignAddress.write(_firstSignAddress)
    secondSignAddress.write(_secondSignAddress)
    _addApprover(initialApprover)
    return ()
end

# # Modifier
func onlyApprover{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (caller) = get_caller_address()
    let _isApprover : felt = isApprover(caller)
    with_attr error_message("DolvenApprover::not allowed"):
        assert _isApprover = TRUE
    end
    return ()
end

# # Getters

@view
func isApprover{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
) -> (res : felt):
    let res : felt = DolvenRoles.has(account)
    return (res)
end

@view
func isSigned{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
) -> (res : felt):
    let res : felt = signed.read(account)
    return (res)
end

@view
func get_firstSigner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    res : felt
):
    let res : felt = firstSignAddress.read()
    return (res)
end

@view
func get_secondSigner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    res : felt
):
    let res : felt = secondSignAddress.read()
    return (res)
end

@view
func isEqual{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    param : felt, param_ : felt
) -> (res : felt):
    if param == param_:
        return (1)
    else:
        return (0)
    end
end

@view
func getOpposite{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    param : felt
) -> (res : felt):
    if param == TRUE:
        return (FALSE)
    else:
        return (TRUE)
    end
end

# # External Functions

@external
func addApprover{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(account : felt):
    alloc_locals
    let _firstSignAddress : felt = firstSignAddress.read()
    let _secondSignAddress : felt = secondSignAddress.read()
    let isSigned_first : felt = signed.read(_firstSignAddress)
    let isSigned_second : felt = signed.read(_secondSignAddress)
    let allSigned : felt = isEqual(isSigned_first, isSigned_second)
    with_attr error_message("DolvenApprover::first sign"):
        assert allSigned = 1
    end
    _addApprover(account)
    signed.write(_firstSignAddress, FALSE)
    signed.write(_secondSignAddress, FALSE)
    return ()
end

@external
func removeApprover{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
):
    alloc_locals
    let _firstSignAddress : felt = firstSignAddress.read()
    let _secondSignAddress : felt = secondSignAddress.read()
    let isSigned_first : felt = signed.read(_firstSignAddress)
    let isSigned_second : felt = signed.read(_secondSignAddress)
    let allSigned : felt = isEqual(isSigned_first, isSigned_second)
    with_attr error_message("DolvenApprover::first sign"):
        assert allSigned = 1
    end
    _removeApprover(account)
    signed.write(_firstSignAddress, FALSE)
    signed.write(_secondSignAddress, FALSE)
    return ()
end

@external
func renounceApprover{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    let _firstSignAddress : felt = firstSignAddress.read()
    let _secondSignAddress : felt = secondSignAddress.read()
    let isSigned_first : felt = signed.read(_firstSignAddress)
    let isSigned_second : felt = signed.read(_secondSignAddress)
    let allSigned : felt = isEqual(isSigned_first, isSigned_second)
    let (caller) = get_caller_address()
    assert_not_equal(caller, 0)
    with_attr error_message("DolvenApprover::first sign"):
        assert allSigned = 1
    end
    _removeApprover(caller)
    signed.write(_firstSignAddress, FALSE)
    signed.write(_secondSignAddress, FALSE)
    return ()
end

# # Internal Functions

func sign{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals
    let _firstSignAddress : felt = firstSignAddress.read()
    let _secondSignAddress : felt = secondSignAddress.read()
    let (caller) = get_caller_address()
    assert_not_equal(caller, 0)
    let isFirstAddressValid : felt = isEqual(_firstSignAddress, caller)
    let isSecondAddressValid : felt = isEqual(_secondSignAddress, caller)
    let sum : felt = isFirstAddressValid + isSecondAddressValid
    let res : felt = is_not_zero(sum)
    with_attr error_message("DolvenApprover::not signer"):
        assert res = 1
    end
    let isSigned : felt = signed.read(caller)
    let oppositeStatus : felt = getOpposite(isSigned)
    with_attr error_message("DolvenApprover::already signed"):
        assert oppositeStatus = TRUE
    end
    signed.write(caller, TRUE)
    return ()
end

func _addApprover{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
):
    DolvenRoles.add(account)
    ApproverAdded.emit(account)
    return ()
end

func _removeApprover{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
):
    DolvenRoles.remove(account)
    ApproverRemoved.emit(account)
    return ()
end
