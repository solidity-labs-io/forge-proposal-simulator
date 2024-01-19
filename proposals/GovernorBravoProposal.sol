// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@forge-std/console.sol";
import {Proposal} from "./Proposal.sol";
import {Address} from "@utils/Address.sol";
import {Constants} from "@utils/Constants.sol";
import {TimelockInterface} from "@comp-governance/GovernorBravoInterfaces.sol";

contract GovernorBravoProposal is Proposal {
    using Address for address;

    /// @notice Getter function for `GovernorBravoDelegate.propose()` calldata
    function getProposeCalldata() public view returns (bytes memory proposeCalldata) {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = getProposalActions();
        string[] memory signatures = new string[](targets.length);

        proposeCalldata = abi.encodeWithSignature(
            "propose(address[],uint256[],string[],bytes[],string)",
            targets,
            values,
            signatures,
            calldatas,
            description()
        );

        if (DEBUG) {
            console.log("Calldata for proposal:");
            console.logBytes(proposeCalldata);
        }
    }

    /// @notice Simulate governance proposal
    /// @param governorAddress address of the Governor Bravo Delegator contract
    /// @param governanceToken address of the governance token of the system
    /// @param proposerAddress address of the proposer
    function _simulateActions(address governorAddress, address governanceToken, address proposerAddress)
        internal
    {
        uint8 state;
        bytes memory data;
        {
        // Ensure proposer has meets minimum proposal threshold and quorum votes to pass the proposal
        data = governorAddress.functionCall(abi.encodeWithSignature("proposalThreshold()"));
        uint256 proposalThreshold = abi.decode(data, (uint256));
        data = governorAddress.functionCall(abi.encodeWithSignature("quorumVotes()"));
        uint256 quorumVotes = abi.decode(data, (uint256));

        uint256 votingPower = quorumVotes > proposalThreshold ? quorumVotes : proposalThreshold;
        deal(governanceToken, proposerAddress, votingPower);
        }

        bytes memory proposeCalldata = getProposeCalldata();

        vm.prank(proposerAddress);
        data = address(payable(governorAddress)).functionCall(proposeCalldata);
        uint256 proposalId = abi.decode(data, (uint256));

        if (DEBUG) {
            console.log(
                "schedule batch calldata with ",
                actions.length,
                (actions.length > 1 ? "actions" : "action")
            );

            if (data.length > 0) {
                console.log("proposalId: %s", proposalId);
            }
        }

        // Check proposal is in Pending state
        data = governorAddress.functionCall(abi.encodeWithSignature("state(uint256)", proposalId));
        state = abi.decode(data, (uint8));
        require(state == 0);

        // Roll to Active state (voting period)
        data = governorAddress.functionCall(abi.encodeWithSignature("votingDelay()"));
        uint256 votingDelay = abi.decode(data, (uint256));
        vm.roll(block.number + votingDelay + 1);
        data = governorAddress.functionCall(abi.encodeWithSignature("state(uint256)", proposalId));
        state = abi.decode(data, (uint8));
        require(state == 1);

        // Vote YES
        vm.prank(proposerAddress);
        governorAddress.functionCall(abi.encodeWithSignature("castVote(uint256,uint8)", proposalId, 1));

        // Roll to allow proposal state transitions
        data = governorAddress.functionCall(abi.encodeWithSignature("votingDelay()"));
        uint256 votingPeriod = abi.decode(data, (uint256));
        vm.warp(block.number + votingPeriod);
        data = governorAddress.functionCall(abi.encodeWithSignature("state(uint256)", proposalId));
        state = abi.decode(data, (uint8));
        require(state == 4);

        // Queue the proposal
        governorAddress.functionCall(abi.encodeWithSignature("queue(uint256)", proposalId));
        data = governorAddress.functionCall(abi.encodeWithSignature("state(uint256)", proposalId));
        state = abi.decode(data, (uint8));
        require(state == 5);

        data = governorAddress.functionCall(abi.encodeWithSignature("timelock()"));
        address timelockAddress = abi.decode(data, (address));
        TimelockInterface timelock = TimelockInterface(timelockAddress);
        vm.warp(block.timestamp + timelock.delay());

        // Execute the proposal
        governorAddress.functionCall(abi.encodeWithSignature("execute(uint256)", proposalId));
        data = governorAddress.functionCall(abi.encodeWithSignature("state(uint256)", proposalId));
        state = abi.decode(data, (uint8));
        require(state == 7);
    }
}