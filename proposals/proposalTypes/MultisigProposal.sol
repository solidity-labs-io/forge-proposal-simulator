pragma solidity 0.8.19;

import {console} from "@forge-std/console.sol";
import {Test} from "@forge-std/Test.sol";
import {Proposal} from "./Proposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

contract MultisigProposal is Proposal {
    // Multicall3 address using CREATE2
    address constant MULTICALL =0xcA11bde05977b3631167028862bE2a173976CA11;

    struct Call {
        address target;
        bytes callData;
    }

    /// @notice simulate multisig proposal
    function _simulateActions(address) internal view {
        uint256 actionsLength = actions.length;
        Call[] memory calls = new Call[](actionsLength);

        for(uint i; i < actionsLength; i++) {
            calls[i] = Call({ target: actions[i].target, callData: actions[i].arguments });
        }

        bytes memory data = abi.encodeWithSignature("aggregate((address,bytes)[])", calls);
	console.logBytes(data);
    }
}
