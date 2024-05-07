// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@forge-std/console.sol";

import {TimelockInterface, GovernorBravoDelegateStorageV1 as Bravo} from "@interface/GovernorBravoInterfaces.sol";
import {GovernorBravoDelegateStorageV2} from "@interface/GovernorBravoInterfaces.sol";
import {IVotes} from "@interface/IVotes.sol";

import {Address} from "@utils/Address.sol";
import {Proposal} from "./Proposal.sol";

abstract contract GovernorBravoProposal is Proposal {
    using Address for address;

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
    function checkOnChainCalldata(
        address governorAddress
    ) public view override returns (bool calldataExist) {
        GovernorBravoDelegateStorageV2 governor = GovernorBravoDelegateStorageV2(
                governorAddress
            );

        uint256 proposalCount = governor.proposalCount();

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
                console.log(
                    "Proposal calldata matches on-chain calldata with proposalId: ",
                    proposalCount
                );
                return true;
            }
        }
        return false;
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
        GovernorBravoDelegateStorageV2 governor = GovernorBravoDelegateStorageV2(
                governorAddress
            );

        {
            // Ensure proposer has meets minimum proposal threshold and quorum votes to pass the proposal
            uint256 quorumVotes = governor.quorumVotes();
            uint256 proposalThreshold = governor.proposalThreshold();
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
        bytes memory data = address(payable(governorAddress)).functionCall(
            proposeCalldata
        );
        uint256 proposalId = abi.decode(data, (uint256));

        // Check proposal is in Pending state
        require(governor.state(proposalId) == Bravo.ProposalState.Pending);

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
        TimelockInterface timelock = TimelockInterface(governor.timelock());
        vm.warp(block.timestamp + timelock.delay());

        // Execute the proposal
        governor.execute(proposalId);
        require(governor.state(proposalId) == Bravo.ProposalState.Executed);
    }
}
