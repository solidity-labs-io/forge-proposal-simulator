pragma solidity ^0.8.0;

import {console} from "@forge-std/console.sol";

import {ITimelockController} from "@interfaces/ITimelockController.sol";

import {Address} from "@utils/Address.sol";
import {Proposal} from "@proposals/Proposal.sol";

abstract contract TimelockProposal is Proposal {
    using Address for address;

    /// @notice the predecessor timelock id - default is 0 but inherited
    /// @dev default is 0 but can be set by the inheriting contract
    bytes32 public predecessor = bytes32(0);

    /// @notice the timelock controller
    /// @dev must be set by the inheriting contract
    ITimelockController public timelock;

    function setTimelock(address _timelock) public {
        timelock = ITimelockController(_timelock);
    }

    /// @notice get schedule calldata
    function getCalldata()
        public
        view
        override
        returns (bytes memory scheduleCalldata)
    {
        bytes32 salt = keccak256(abi.encode(actions[0].description));

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory payloads
        ) = getProposalActions();

        uint256 delay = timelock.getMinDelay();

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

    /// @notice Check if there are any on-chain proposal that matches the
    /// proposal calldata
    function checkOnChainCalldata()
        public
        view
        override
        returns (bool calldataExist)
    {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory payloads
        ) = getProposalActions();

        bytes32 salt = keccak256(abi.encode(actions[0].description));

        bytes32 hash = timelock.hashOperationBatch(
            targets,
            values,
            payloads,
            predecessor,
            salt
        );

        return timelock.isOperation(hash) || timelock.isOperationPending(hash);
    }

    /// @notice simulate timelock proposal
    /// @param proposerAddress account to propose the proposal to the timelock
    /// @param executorAddress account to execute the proposal on the timelock
    function _simulateActions(
        address proposerAddress,
        address executorAddress
    ) internal {
        bytes32 salt = keccak256(abi.encode(actions[0].description));

        if (DEBUG) {
            console.log("salt:");
            console.logBytes32(salt);
        }

        bytes memory scheduleCalldata = getCalldata();
        bytes memory executeCalldata = getExecuteCalldata();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory payloads
        ) = getProposalActions();

        bytes32 proposalId = timelock.hashOperationBatch(
            targets,
            values,
            payloads,
            predecessor,
            salt
        );

        if (
            !timelock.isOperationPending(proposalId) &&
            !timelock.isOperation(proposalId)
        ) {
            vm.prank(proposerAddress);

            // Perform the low-level call
            bytes memory returndata = address(timelock).functionCall(
                scheduleCalldata
            );

            if (DEBUG && returndata.length > 0) {
                console.log("returndata");
                console.logBytes(returndata);
            }
        } else if (DEBUG) {
            console.log("proposal already scheduled for id");
            console.logBytes32(proposalId);
        }

        uint256 delay = timelock.getMinDelay();
        vm.warp(block.timestamp + delay);

        if (!timelock.isOperationDone(proposalId)) {
            vm.prank(executorAddress);

            // Perform the low-level call
            bytes memory returndata = address(timelock).functionCall(
                executeCalldata
            );

            if (DEBUG && returndata.length > 0) {
                console.log("returndata");
                console.logBytes(returndata);
            }
        } else if (DEBUG) {
            console.log("proposal already executed");
        }
    }

    /// @notice print schedule and execute calldata
    function print() public view override {
        console.log("\n---------------- Proposal Description ----------------");
        console.log(description());

        console.log("\n------------------ Proposal Actions ------------------");
        for (uint256 i; i < actions.length; i++) {
            console.log("%d). %s", i + 1, actions[i].description);
            console.log("target: %s\npayload", actions[i].target);
            console.logBytes(actions[i].arguments);
            console.log("\n");
        }

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
