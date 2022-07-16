%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IDolvenVault:
    func delege(_amountToStake : Uint256, _staker : felt, _lockType : felt):
    end
end
