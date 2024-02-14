// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import {Proposal} from "./Proposal.sol";
import {Address} from "@utils/Address.sol";
import {IVotes} from "openzeppelin/governance/utils/IVotes.sol";
import {GovernorBravoDelegate} from "Governors/OlympusGovernorBravo/OlympusGovernorBravo.sol";
import {ITimelock} from "Governors/OlympusGovernorBravo/interfaces/ITimelock.sol";
import {GovernorBravoDelegateStorageV1 as Bravo} from "Governors/OlympusGovernorBravo/abstracts/GovernorBravoStorage.sol";

contract GovernorBravoProposal is Proposal {
    using Address for address;

    /// @notice Getter function for `GovernorBravoDelegate.propose()` calldata
    function getCalldata() public view override returns (bytes memory data) {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = getProposalActions();
        string[] memory signatures = new string[](targets.length);

        data = abi.encodeWithSignature(
            "propose(address[],uint256[],string[],bytes[],string)",
            targets,
            values,
            signatures,
            calldatas,
            description()
        );

        if (DEBUG && HIDE_DEBUG) {
            console.log("Calldata for proposal %s:", id());
            console.logBytes(data);
        }
    }

    /// @notice Getter function to get calldata from the proposal id of the forked environment
    function getForkCalldata(
        address governor
    ) public view returns (bytes memory data) {
        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        ) = GovernorBravoDelegate(governor).getActions(id());

        data = abi.encodeWithSignature(
            "propose(address[],uint256[],string[],bytes[],string)",
            targets,
            values,
            signatures,
            calldatas,
            description()
        );

        if (DEBUG && HIDE_DEBUG) {
            console.log("Calldata for proposal %s submitted on mainnet:", id());
            console.logBytes(data);
        }
    }

    // @notice Check proposal calldata against the forked environment
    function checkCalldata(
        address check,
        bool debug
    ) public virtual override returns (bool) {
        bytes memory dataSim = getCalldata();
        bytes memory dataFork = getForkCalldata(check);

        bool doMatch = _bytesMatch(dataSim, dataFork);

        if (debug) {
            console.log("\n  CALLDATA CHECK OUTCOME:");
            if (doMatch) {
                console.log(
                    "  > Simulated calldata matches proposal id %s on mainnet",
                    id()
                );
            } else {
                // Check if proposal id exists on mainnet
                bytes memory notFound = abi.encodeWithSignature(
                    "propose(address[],uint256[],string[],bytes[],string)",
                    new address[](0),
                    new uint256[](0),
                    new string[](0), 
                    new bytes[](0),
                    description()
                );
                _bytesMatch(notFound, dataFork)
                    ? console.log(
                        "  x Proposal id %s not found on mainnet",
                        id())
                    : console.log(
                        "  x Simulated calldata does not match proposal id %s on mainnet",
                        id());
            }
            console.log(" ");
        }

        return doMatch;
    }

    /// @notice Simulate governance proposal
    /// @param governorAddress address of the Governor Bravo Delegator contract
    /// @param governanceToken address of the governance token of the system
    /// @param proposerAddress address of the proposer
    function _simulateActions(
        address governorAddress,
        address governanceToken,
        address proposerAddress
    ) internal {
        GovernorBravoDelegate governor = GovernorBravoDelegate(governorAddress);

        {
            // Ensure proposer has meets minimum proposal threshold and quorum votes to pass the proposal
            uint256 quorumVotes = governor.getHighRiskQuorumVotes();
            uint256 proposalThreshold = governor.getProposalThresholdVotes();
            uint256 votingPower = quorumVotes > proposalThreshold
                ? quorumVotes
                : proposalThreshold;
            deal(governanceToken, proposerAddress, votingPower);
            // Delegate proposer's votes to itself
            vm.prank(proposerAddress);
            IVotes(governanceToken).delegate(proposerAddress);
            vm.roll(block.number + 1);
        }

        bytes memory proposeData = getCalldata();
        // Ensure actions are only printed once
        setHideDebug(true);

        // Register the proposal
        vm.prank(proposerAddress);
        bytes memory data = address(payable(governorAddress)).functionCall(proposeData);
        uint256 proposalId = abi.decode(data, (uint256));

        if (DEBUG) {
            console.log(
                "\n  Schedule batch calldata with ",
                actions.length,
                (actions.length > 1 ? "actions." : "action.")
            );
        }

        // Check proposal is in Pending state
        require(governor.state(proposalId) == Bravo.ProposalState.Pending);

        // Roll to allow proposal activation
        vm.roll(block.number + governor.votingDelay() + 1);
        require(governor.state(proposalId) == Bravo.ProposalState.Pending);

        // Activate the proposal
        vm.prank(proposerAddress);
        governor.activate(proposalId);

        // Roll to Active state (voting period)
        vm.roll(block.number + governor.votingDelay() + 1);
        require(governor.state(proposalId) == Bravo.ProposalState.Active);

        // Vote YES
        vm.prank(proposerAddress);
        governor.castVote(proposalId, 1);

        // Roll to allow proposal state transitions
        vm.roll(block.number + governor.votingPeriod());
        require(governor.state(proposalId) == Bravo.ProposalState.Succeeded);

        // Queue the proposal
        governor.queue(proposalId);
        require(governor.state(proposalId) == Bravo.ProposalState.Queued);

        // Warp to allow proposal execution on timelock
        ITimelock timelock = ITimelock(governor.timelock());
        vm.warp(block.timestamp + timelock.delay());

        // Execute the proposal
        governor.execute(proposalId);
        require(governor.state(proposalId) == Bravo.ProposalState.Executed);
    }

    function _bytesMatch(
        bytes memory a_,
        bytes memory b_
    ) internal pure returns (bool) {
        if (a_.length != b_.length) {
            return false;
        }
        for (uint i = 0; i < a_.length; i++) {
            if (a_[i] != b_[i]) {
                return false;
            }
        }
        return true;
    }
}

