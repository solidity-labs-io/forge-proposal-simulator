// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@forge-std/console.sol";

import {IGovernorAlpha, GovernorBravoDelegateStorageV1} from "@interface/IGovernorBravo.sol";
import {TimelockInterface} from "@interface/IGovernorBravo.sol";
import {IVotes} from "@interface/IVotes.sol";

import {Address} from "@utils/Address.sol";
import {Proposal} from "./Proposal.sol";

abstract contract GovernorBravoProposal is Proposal {
    using Address for address;

    /// @notice Governor Bravo contract
    /// @dev must be set by the inheriting contract
    IGovernorAlpha public governor;

    /// @notice set the Governor Bravo contract
    function setGovernor(address _governor) public {
        governor = IGovernorAlpha(_governor);
    }

    /// @notice Getter function for `GovernorBravoDelegate.propose()` calldata
    function getCalldata()
        public
        view
        virtual
        override
        returns (bytes memory data)
    {
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
    }

    /// @notice Check if there are any on-chain proposals that match the
    /// proposal calldata
    function checkOnChainCalldata()
        public
        view
        override
        returns (bool calldataExist)
    {
        uint256 proposalCount = GovernorBravoDelegateStorageV1(
            address(governor)
        ).proposalCount();

        while (proposalCount > 0) {
            (
                address[] memory targets,
                uint256[] memory values,
                string[] memory signatures,
                bytes[] memory calldatas
            ) = governor.getActions(proposalCount);
            proposalCount--;

            bytes memory onchainCalldata = abi.encodeWithSignature(
                "propose(address[],uint256[],string[],bytes[],string)",
                targets,
                values,
                signatures,
                calldatas,
                description()
            );

            bytes memory proposalCalldata = getCalldata();

            if (keccak256(proposalCalldata) == keccak256(onchainCalldata)) {
                if (DEBUG) {
                    console.log(
                        "Proposal calldata matches on-chain calldata with proposalId: ",
                        proposalCount
                    );
                }
                return true;
            }
        }
        return false;
    }

    /// @notice Simulate governance proposal
    /// @param governanceToken address of the governance token of the system
    /// @param proposerAddress address of the proposer
    function _simulateActions(
        address governanceToken,
        address proposerAddress
    ) internal {
        {
            // Ensure proposer has meets minimum proposal threshold and quorum votes to pass the proposal
            uint256 quorumVotes = governor.quorumVotes();
            uint256 proposalThreshold = GovernorBravoDelegateStorageV1(
                address(governor)
            ).proposalThreshold();
            uint256 votingPower = quorumVotes > proposalThreshold
                ? quorumVotes
                : proposalThreshold;
            deal(governanceToken, proposerAddress, votingPower);
            // Delegate proposer's votes to itself
            vm.prank(proposerAddress);
            IVotes(governanceToken).delegate(proposerAddress);
            vm.roll(block.number + 1);
        }

        bytes memory proposeCalldata = getCalldata();

        // Register the proposal
        vm.prank(proposerAddress);
        bytes memory data = address(governor).functionCall(proposeCalldata);
        uint256 proposalId = abi.decode(data, (uint256));

        GovernorBravoDelegateStorageV1 governorCast = GovernorBravoDelegateStorageV1(
                address(governor)
            );

        // Check proposal is in Pending state
        require(
            governorCast.state(proposalId) ==
                GovernorBravoDelegateStorageV1.ProposalState.Pending
        );

        // Roll to Active state (voting period)
        vm.roll(block.number + governorCast.votingDelay() + 1);
        require(
            governorCast.state(proposalId) ==
                GovernorBravoDelegateStorageV1.ProposalState.Active
        );

        // Vote YES
        vm.prank(proposerAddress);
        governor.castVote(proposalId, 1);

        // Roll to allow proposal state transitions
        vm.roll(block.number + governorCast.votingPeriod());
        require(
            governorCast.state(proposalId) ==
                GovernorBravoDelegateStorageV1.ProposalState.Succeeded
        );

        // Queue the proposal
        governor.queue(proposalId);
        require(
            governorCast.state(proposalId) ==
                GovernorBravoDelegateStorageV1.ProposalState.Queued
        );

        // Warp to allow proposal execution on timelock
        TimelockInterface timelock = TimelockInterface(governorCast.timelock());
        vm.warp(block.timestamp + timelock.delay());

        // Execute the proposal
        governor.execute(proposalId);
        require(
            governorCast.state(proposalId) ==
                GovernorBravoDelegateStorageV1.ProposalState.Executed
        );
    }
}
