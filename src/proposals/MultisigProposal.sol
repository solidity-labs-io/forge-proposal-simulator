pragma solidity ^0.8.0;

import "@forge-std/console.sol";

import {Address} from "@utils/Address.sol";
import {Proposal} from "./Proposal.sol";
import {Constants} from "@utils/Constants.sol";

abstract contract MultisigProposal is Proposal {
    using Address for address;

    bytes32 public constant MULTISIG_BYTECODE_HASH = bytes32(
        0xb89c1b3bdf2cf8827818646bce9a8f6e372885f8c55e5c07acbd307cb133b000
    );

    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    /// @notice return calldata, log if debug is set to true
    function getCalldata() public view override returns (bytes memory data) {
        /// get proposal actions
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory arguments
        ) = getProposalActions();

        /// create calls array with targets and arguments
        Call3Value[] memory calls = new Call3Value[](targets.length);

        for (uint256 i; i < calls.length; i++) {
            require(targets[i] != address(0), "Invalid target for multisig");
            calls[i] = Call3Value({
                target: targets[i],
                allowFailure: false,
                value: values[i],
                callData: arguments[i]
            });
        }

        /// generate calldata
        data = abi.encodeWithSignature(
            "aggregate3Value((address,bool,uint256,bytes)[])", calls
        );
    }

    /// @notice Check if there are any on-chain proposal that matches the
    /// proposal calldata
    function getProposalId() public pure override returns (uint256) {
        revert("Not implemented");
    }

    function _simulateActions(address multisig) internal {
        vm.startPrank(multisig);

        /// this is a hack because multisig execTransaction requires owners signatures
        /// so we cannot simulate it exactly as it will be executed on mainnet
        vm.etch(multisig, Constants.MULTICALL_BYTECODE);

        bytes memory data = getCalldata();

        multisig.functionCall(data);

        /// revert contract code to original safe bytecode
        vm.etch(multisig, Constants.SAFE_BYTECODE);

        vm.stopPrank();
    }
}
