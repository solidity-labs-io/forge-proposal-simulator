pragma solidity 0.8.19;

import "@forge-std/console.sol";
import {Proposal} from "./Proposal.sol";
import {Multicall3} from "@utils/Multicall3.sol";
import {Safe} from "@utils/Safe.sol";

contract MultisigProposal is Proposal {
    // Multicall3 address using CREATE2
    address constant public MULTICALL = 0xcA11bde05977b3631167028862bE2a173976CA11;

    struct Call {
        address target;
        bytes callData;
    }

    /// @notice log calldata
    function printCalldata() public view override returns(bytes memory data){
        uint256 actionsLength = actions.length;
        Call[] memory calls = new Call[](actionsLength);

        for(uint256 i; i < actionsLength; i++) {
            require(actions[i].target != address(0), "Invalid target for multisig");
            calls[i] = Call({ target: actions[i].target, callData: actions[i].arguments });
        }

        data = abi.encodeWithSignature("aggregate((address,bytes)[])", calls);

	if(DEBUG) {
	    console.log("Calldata:");
	    console.logBytes(data);
	}
    }

    function _simulateActions(address multisig) internal {
	vm.startPrank(multisig);
	
	uint256 multicallSize;
	assembly {
	    // retrieve the size of the code, this needs assembly
            multicallSize := extcodesize(MULTICALL)
	}
	if(multicallSize == 0) {
	    Multicall3 multicall = new Multicall3();
	    vm.etch(MULTICALL, address(multicall).code);
	}

	bytes memory data = printCalldata();
	Safe(multisig).execute(MULTICALL, 0, data, Safe.Operation.DelegateCall, 10_000_000);
    }
}
