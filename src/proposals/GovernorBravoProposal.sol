// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@forge-std/console.sol";

import {
    IGovernorBravo,
    ITimelockBravo,
    IERC20VotesComp
} from "@interface/IGovernorBravo.sol";

import {Address} from "@utils/Address.sol";

import {Proposal} from "./Proposal.sol";

abstract contract GovernorBravoProposal is Proposal {
    using Address for address;

    /// @notice Governor Bravo contract
    /// @dev must be set by the inheriting contract
    IGovernorBravo public governor;

    /// @notice set the Governor Bravo contract
    function setGovernor(address _governor) public {
        governor = IGovernorBravo(_governor);
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
    function getProposalId()
        public
        view
        override
        returns (uint256 proposalId)
    {
        uint256 proposalCount = governor.proposalCount();

        while (proposalCount > 0) {
            (
                address[] memory targets,
                uint256[] memory values,
                string[] memory signatures,
                bytes[] memory calldatas
            ) = governor.getActions(proposalCount);

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
                return proposalCount;
            }

            proposalCount--;
        }
        return 0;
    }

    /// @notice Simulate governance proposal
    function simulate() public override {
        address proposerAddress = address(1);
        IERC20VotesComp governanceToken = governor.comp();
        {
            // Ensure proposer has meets minimum proposal threshold and quorum votes to pass the proposal
            uint256 quorumVotes = governor.quorumVotes();
            uint256 proposalThreshold = governor.proposalThreshold();
            uint256 votingPower = quorumVotes > proposalThreshold
                ? quorumVotes
                : proposalThreshold;
            deal(address(governanceToken), proposerAddress, votingPower);
            // Delegate proposer's votes to itself
            vm.prank(proposerAddress);
            IERC20VotesComp(governanceToken).delegate(proposerAddress);
            vm.roll(block.number + 1);
        }

        bytes memory proposeCalldata = getCalldata();

        // Register the proposal
        vm.prank(proposerAddress);
        bytes memory data = address(governor).functionCall(proposeCalldata);
        uint256 proposalId = abi.decode(data, (uint256));

        // Check proposal is in Pending state
        require(
            governor.state(proposalId) == IGovernorBravo.ProposalState.Pending
        );

        // Roll to Active state (voting period)
        vm.roll(block.number + governor.votingDelay() + 1);
        require(
            governor.state(proposalId) == IGovernorBravo.ProposalState.Active
        );

        // Vote YES
        vm.prank(proposerAddress);
        governor.castVote(proposalId, 1);

        // Roll to allow proposal state transitions
        vm.roll(block.number + governor.votingPeriod());
        require(
            governor.state(proposalId) == IGovernorBravo.ProposalState.Succeeded
        );

        // Queue the proposal
        governor.queue(proposalId);
        require(
            governor.state(proposalId) == IGovernorBravo.ProposalState.Queued
        );

        // Warp to allow proposal execution on timelock
        ITimelockBravo timelock = ITimelockBravo(governor.timelock());
        vm.warp(block.timestamp + timelock.delay());

        // Execute the proposal
        governor.execute(proposalId);
        require(
            governor.state(proposalId) == IGovernorBravo.ProposalState.Executed
        );
    }
}
