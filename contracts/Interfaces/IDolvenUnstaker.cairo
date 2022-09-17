%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IDolvenUnstaker {
    func lockTokens(user_address: felt, _amount: Uint256, lockType_: felt) {
    }
    func unlockTokens(user_: felt, nonce: felt) {
    }
    func cancelTokens(user_: felt, nonce: felt) {
    }
}
