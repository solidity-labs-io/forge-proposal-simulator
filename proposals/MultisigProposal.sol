pragma solidity 0.8.19;

import "@forge-std/console.sol";
import {Proposal} from "./Proposal.sol";
import {Address} from "@utils/Address.sol";
import {Constants} from "@utils/Constants.sol";

contract MultisigProposal is Proposal {
    using Address for address;
    // Multicall3 address using CREATE2
    address public constant MULTICALL = 0xcA11bde05977b3631167028862bE2a173976CA11;
    bytes32 public constant MULTISIG_BYTECODE_HASH = bytes32(0xb89c1b3bdf2cf8827818646bce9a8f6e372885f8c55e5c07acbd307cb133b000);

    struct Call {
        address target;
        bytes callData;
    }

    /// @notice log calldata
    function getCalldata() public view override returns (bytes memory data) {
        uint256 actionsLength = actions.length;
        Call[] memory calls = new Call[](actionsLength);

        for (uint256 i; i < actionsLength; i++) {
            require(actions[i].target != address(0), "Invalid target for multisig");
            calls[i] = Call({target: actions[i].target, callData: actions[i].arguments});
        }

        data = abi.encodeWithSignature("aggregate((address,bytes)[])", calls);

        if (DEBUG) {
            console.log("Calldata:");
            console.logBytes(data);
        }
    }

    function _simulateActions(address multisig) internal {
	require(multisig.getContractHash() == MULTISIG_BYTECODE_HASH, "Invalid multisig bytecode hash");

        vm.startPrank(multisig);

        uint256 multicallSize;
        assembly {
            // retrieve the size of the code, this needs assembly
            multicallSize := extcodesize(MULTICALL)
        }
        if (multicallSize == 0) {
            vm.etch(MULTICALL, Constants.MULTICALL_BYTECODE);
        }

        bytes memory data = getCalldata();
	bytes memory result = MULTICALL.functionCall(data); 

	if (DEBUG && result.length > 0) {
	    console.log("Multicall result:");
	    console.logBytes(result);
	}

        vm.stopPrank();
    }


}
