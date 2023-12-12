pragma solidity 0.8.19;

import {Proposal} from "./Proposal.sol";

abstract contract MultisigProposal is Proposal {
    /// @notice simulate multisig proposal
    /// @param multisigAddress address of the multisig doing the calls
    function _simulateMultisigActions(address multisigAddress) internal {
        require(actions.length > 0, "Empty Multisig operation");

        vm.startPrank(multisigAddress);

        for (uint256 i = 0; i < actions.length; i++) {
            (bool success, bytes memory result) = actions[i].target.call{
                value: actions[i].value
            }(actions[i].arguments);

            require(success, string(result));
        }

        vm.stopPrank();
    }
}
