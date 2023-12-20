pragma solidity 0.8.19;

import "@forge-std/console.sol";
import {Proposal} from "./Proposal.sol";

enum Operation {
    Call,
    DelegateCall
}

/// @title Multicall3
/// @notice Aggregate results from multiple function calls
/// @dev Multicall & Multicall2 backwards-compatible
/// @dev Aggregate methods are marked `payable` to save 24 gas per call
/// @author Michael Elliot <mike@makerdao.com>
/// @author Joshua Levine <joshua@makerdao.com>
/// @author Nick Johnson <arachnid@notdot.net>
/// @author Andreas Bigger <andreas@nascent.xyz>
/// @author Matt Solomon <matt@mattsolomon.dev>
contract Multicall3 {
    struct Call {
        address target;
        bytes callData;
    }

    struct Call3 {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    /// @notice Backwards-compatible call aggregation with Multicall
    /// @param calls An array of Call structs
    /// @return blockNumber The block number where the calls were executed
    /// @return returnData An array of bytes containing the responses
    function aggregate(Call[] calldata calls) public payable returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        uint256 length = calls.length;
        returnData = new bytes[](length);
        Call calldata call;
        for (uint256 i = 0; i < length;) {
            bool success;
            call = calls[i];
            (success, returnData[i]) = call.target.call(call.callData);
            require(success, "Multicall3: call failed");
            unchecked { ++i; }
        }
    }
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
	
	uint256 multicallSize;
	assembly {
	    // retrieve the size of the code, this needs assembly
            multicallSize := extcodesize(MULTICALL)
	}
	if(multicallSize == 0) {
	    Multicall3 multicall = new Multicall3();
	    vm.etch(MULTICALL, address(multicall).code);
	}

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
