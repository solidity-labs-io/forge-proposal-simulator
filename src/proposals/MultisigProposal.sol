// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@forge-std/console.sol";

import {Proposal} from "./Proposal.sol";
import {Address} from "@utils/Address.sol";
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

    /// @notice Override to encode every action as a delegatecall.
    function isDelegateCall() public view virtual returns (bool) {
        return false;
    }

    /// @notice return calldata, log if debug is set to true
    function getCalldata() public view override returns (bytes memory) {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory arguments
        ) = getProposalActions();

        require(
            targets.length == values.length
                && values.length == arguments.length,
            "Array lengths mismatch"
        );

        bytes memory encodedTxs;
        uint8 operation =
            isDelegateCall() ? Constants.DELEGATE_CALL : Constants.CALL;

        for (uint256 i = 0; i < targets.length; i++) {
            address to = targets[i];
            uint256 value = values[i];
            bytes memory data = arguments[i];

            encodedTxs = bytes.concat(
                encodedTxs,
                abi.encodePacked(
                    operation, to, value, uint256(data.length), data
                )
            );
        }

        // The final calldata to send to the MultiSend contract
        return abi.encodeWithSignature("multiSend(bytes)", encodedTxs);
    }

    /// @notice return the transaction fields to enter in the Safe UI.
    function getSafeTransaction()
        public
        view
        returns (address to, uint256 value, bytes memory data, uint8 operation)
    {
        to = isDelegateCall()
            ? Constants.SAFE_MULTISEND_CONTRACT
            : Constants.SAFE_MULTISEND_CALL_ONLY_CONTRACT;
        value = 0;
        data = getCalldata();
        operation = Constants.DELEGATE_CALL;
    }

    /// @notice Check if there are any on-chain proposal that matches the
    /// proposal calldata
    function getProposalId() public pure override returns (uint256) {
        revert("Not implemented");
    }

    function _simulateActions(address multisig) internal {
        bytes memory originalBytecode = multisig.code;
        vm.etch(multisig, Constants.SAFE_RUNTIME_BYTECODE);

        (address to, uint256 value, bytes memory data, uint8 operation) =
            getSafeTransaction();

        bytes memory safeCalldata = abi.encodeWithSignature(
            "execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)",
            to,
            value,
            data,
            operation,
            0,
            0,
            0,
            address(0),
            address(0),
            ""
        );

        vm.startPrank(multisig);

        (bool success, bytes memory returndata) = multisig.call(safeCalldata);

        vm.stopPrank();

        vm.etch(multisig, originalBytecode);

        Address.verifyCallResult(success, returndata);
    }

    function _printProposalCalldata() internal virtual override {
        (address to, uint256 value, bytes memory data, uint8 operation) =
            getSafeTransaction();

        console.log(
            "\n\n---------------- Safe Transaction Fields --------------"
        );
        console.log("to:", to);
        console.log("value:", value);
        console.log("data:");
        console.logBytes(data);
        console.log("operation:", operation);
    }
}
