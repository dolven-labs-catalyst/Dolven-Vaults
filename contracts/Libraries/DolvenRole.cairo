%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.math import assert_not_equal

@storage_var
func bearer(address: felt) -> (res: felt) {
}

namespace DolvenRoles {
    @external
    func add{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account_address: felt
    ) {
        let userStatus: felt = bearer.read(account_address);
        with_attr error_message("DolvenRole::already upgraded") {
            assert userStatus = FALSE;
        }
        bearer.write(account_address, TRUE);
        return ();
    }

    @external
    func remove{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account_address: felt
    ) {
        let userStatus: felt = bearer.read(account_address);
        with_attr error_message("DolvenRole::upgrade first") {
            assert userStatus = TRUE;
        }
        bearer.write(account_address, FALSE);
        return ();
    }

    func has{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account_address: felt
    ) -> (res: felt) {
        assert_not_equal(account_address, 0);
        let account_status: felt = bearer.read(account_address);
        return (account_status,);
    }
}
    
