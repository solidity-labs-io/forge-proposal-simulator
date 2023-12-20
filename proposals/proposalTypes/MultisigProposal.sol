pragma solidity 0.8.19;

import "@forge-std/console.sol";
import {Proposal} from "./Proposal.sol";

enum Operation {
    Call,
    DelegateCall
}

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
            calls[i] = Call({ target: actions[i].target, callData: actions[i].arguments });
        }

        data = abi.encodeWithSignature("aggregate((address,bytes)[])", calls);

	if(DEBUG) {
	    console.log("Calldata:");
	    console.logBytes(data);
	}
    }

    function _simulateActions(address multisig) internal {
	bytes memory data = printCalldata();

	vm.startPrank(multisig);

	MockSafe safe = new MockSafe();

	require(multisig.code.length > 0, "Multisig must be a contract");

	vm.etch(multisig, address(safe).code);
	safe.execute(MULTICALL, 0, data, Operation.DelegateCall, 10_000_000);
    }
}

contract MockSafe {
    /**
     * @notice Executes either a delegatecall or a call with provided parameters.
     * @dev This method doesn't perform any sanity check of the transaction, such as:
     *      - if the contract at `to` address has code or not
     *      It is the responsibility of the caller to perform such checks.
     * @param to Destination address.
     * @param value Ether value.
     * @param data Data payload.
     * @param operation Operation type.
     * @return success boolean flag indicating if the call succeeded.
     */
    function execute(
        address to,
        uint256 value,
        bytes memory data,
        Operation operation,
        uint256 txGas
    ) public returns (bool success) {
        if (operation == Operation.DelegateCall) {
            /* solhint-disable no-inline-assembly */
            /// @solidity memory-safe-assembly
            assembly {
                success := delegatecall(txGas, to, add(data, 0x20), mload(data), 0, 0)
            }
            /* solhint-enable no-inline-assembly */
        } else {
            /* solhint-disable no-inline-assembly */
            /// @solidity memory-safe-assembly
            assembly {
                success := call(txGas, to, value, add(data, 0x20), mload(data), 0, 0)
            }
            /* solhint-enable no-inline-assembly */
        }
    }
}
