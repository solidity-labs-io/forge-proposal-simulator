pragma solidity ^0.8.0;

import {console} from "@forge-std/console.sol";
import {Proposal} from "@proposals/Proposal.sol";
import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";
import {Address} from "@utils/Address.sol";

abstract contract TimelockProposal is Proposal {
    using Address for address;

    function predecessor() public view virtual returns (bytes32) {}

    /// @notice get schedule calldata
    function getScheduleCalldata(
        address timelock
    ) public view returns (bytes memory scheduleCalldata) {
        bytes32 salt = keccak256(abi.encode(actions[0].description));

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory payloads
        ) = getProposalActions();
        uint256 delay = TimelockController(payable(timelock)).getMinDelay();

        scheduleCalldata = abi.encodeWithSignature(
            "scheduleBatch(address[],uint256[],bytes[],bytes32,bytes32,uint256)",
            targets,
            values,
            payloads,
            predecessor(),
            salt,
            delay
        );

        if (DEBUG) {
            console.log("Calldata for scheduleBatch:");
            console.logBytes(scheduleCalldata);
        }
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
            predecessor(),
            salt
        );

        if (DEBUG) {
            console.log("Calldata for executeBatch:");
            console.logBytes(executeCalldata);
        }
    }

    /// @notice simulate timelock proposal
    /// @param timelockAddress to execute the proposal against
    /// @param proposerAddress account to propose the proposal to the timelock
    /// @param executorAddress account to execute the proposal on the timelock
    function _simulateActions(
        address timelockAddress,
        address proposerAddress,
        address executorAddress
    ) internal {
        bytes32 salt = keccak256(abi.encode(actions[0].description));
        bytes32 predecessor = bytes32(0);

        if (DEBUG) {
            console.log("salt:");
            console.logBytes32(salt);
        }

        bytes memory scheduleCalldata = getScheduleCalldata(timelockAddress);
        bytes memory executeCalldata = getExecuteCalldata();

        TimelockController timelock = TimelockController(
            payable(timelockAddress)
        );
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
            bytes memory returndata = address(payable(timelockAddress))
                .functionCall(scheduleCalldata);

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

        uint256 delay = timelock.getMinDelay();
        vm.warp(block.timestamp + delay);

        if (!timelock.isOperationDone(proposalId)) {
            vm.prank(executorAddress);

            // Perform the low-level call
            bytes memory returndata = address(payable(timelockAddress))
                .functionCall(executeCalldata);

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
}
