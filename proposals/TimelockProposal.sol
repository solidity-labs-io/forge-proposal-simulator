pragma solidity ^0.8.0;

import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";

import {Addresses} from "@addresses/Addresses.sol";
import {console} from "@forge-std/console.sol";

import {Address} from "@utils/Address.sol";
import {Proposal} from "@proposals/Proposal.sol";

abstract contract TimelockProposal is Proposal {
    using Address for address;

    /// @notice get schedule calldata
    function getCalldata()
        public
        view
        override
        returns (bytes memory scheduleCalldata)
    {
        bytes32 salt = keccak256(abi.encode(actions[0].description));
        bytes32 predecessor = bytes32(0);

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory payloads
        ) = getProposalActions();

        address addressCaller = addresses.getAddress(caller);
        uint256 delay = TimelockController(payable(addressCaller)).getMinDelay();

        scheduleCalldata = abi.encodeWithSignature(
            "scheduleBatch(address[],uint256[],bytes[],bytes32,bytes32,uint256)",
            targets,
            values,
            payloads,
            predecessor,
            salt,
            delay
        );
    }

    /// @notice get execute calldata
    function getExecuteCalldata()
        public
        view
        returns (bytes memory executeCalldata)
    {
        bytes32 salt = keccak256(abi.encode(actions[0].description));
        bytes32 predecessor = bytes32(0);

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory payloads
        ) = getProposalActions();

        executeCalldata = abi.encodeWithSignature(
            "executeBatch(address[],uint256[],bytes[],bytes32,bytes32)",
            targets,
            values,
            payloads,
            predecessor,
            salt
        );
    }

    /// @notice simulate timelock proposal
    /// @param proposerAddress account to propose the proposal to the timelock
    /// @param executorAddress account to execute the proposal on the timelock
    function _simulateActions(
        address proposerAddress,
        address executorAddress
    ) internal {
        bytes32 salt = keccak256(abi.encode(actions[0].description));
        bytes32 predecessor = bytes32(0);

        if (DEBUG) {
            console.log("salt:");
            console.logBytes32(salt);
        }

        bytes memory scheduleCalldata = getCalldata();
        bytes memory executeCalldata = getExecuteCalldata();

        address addressCaller = addresses.getAddress(caller);
        TimelockController timelockController = TimelockController(
            payable(addressCaller)
        );
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory payloads
        ) = getProposalActions();

        bytes32 proposalId = timelockController.hashOperationBatch(
            targets,
            values,
            payloads,
            predecessor,
            salt
        );

        if (
            !timelockController.isOperationPending(proposalId) &&
            !timelockController.isOperation(proposalId)
        ) {
            vm.prank(proposerAddress);

            // Perform the low-level call
            bytes memory returndata = address(payable(addressCaller)).functionCall(
                scheduleCalldata
            );

            if (DEBUG) {
                console.log(
                    "schedule batch calldata with ",
                    actions.length,
                    (actions.length > 1 ? "actions" : "action")
                );

                if (returndata.length > 0) {
                    console.log("returndata");
                    console.logBytes(returndata);
                }
            }
        } else if (DEBUG) {
            console.log("proposal already scheduled for id");
            console.logBytes32(proposalId);
        }

        uint256 delay = timelockController.getMinDelay();
        vm.warp(block.timestamp + delay);

        if (!timelockController.isOperationDone(proposalId)) {
            vm.prank(executorAddress);

            // Perform the low-level call
            bytes memory returndata = address(payable(addressCaller)).functionCall(
                executeCalldata
            );

            if (DEBUG) {
                console.log("executed batch calldata");

                if (returndata.length > 0) {
                    console.log("returndata");
                    console.logBytes(returndata);
                }
            }
        } else if (DEBUG) {
            console.log("proposal already executed");
        }
    }

    /// @notice print schedule and execute calldata
    function _printCalldata() internal view override {
        console.log(
            "\n\n------------------ Schedule Calldata ------------------"
        );
        console.logBytes(getCalldata());

        console.log(
            "\n\n------------------ Execute Calldata ------------------"
        );
        console.logBytes(getExecuteCalldata());
    }
}
