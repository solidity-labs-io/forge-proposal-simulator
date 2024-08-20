// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@forge-std/console.sol";

import {
    IGovernor,
    IGovernorTimelockControl,
    IGovernorVotes
} from "@interface/IGovernor.sol";
import {IVotes} from "@interface/IVotes.sol";
import {ITimelockController} from "@interface/ITimelockController.sol";

// TODO move utils to inside src
import {Address} from "@utils/Address.sol";

import {Proposal} from "./Proposal.sol";

abstract contract OZGovernorProposal is Proposal {
    using Address for address;

    /// @notice Governor contract
    /// @dev must be set by the inheriting contract
    IGovernor public governor;

    /// @notice set the Governor contract
    function setGovernor(address _governor) public {
        governor = IGovernor(_governor);
    }

    /// @notice Getter function for `IGovernor.propose()` calldata
    function getCalldata()
        public
        virtual
        override
        returns (bytes memory data)
    {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = getProposalActions();

        data = abi.encodeWithSignature(
            "propose(address[],uint256[],bytes[],string)",
            targets,
            values,
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
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = getProposalActions();

        proposalId = governor.hashProposal(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked(description()))
        );

        // proposal exist if state call doesn't revert
        try governor.state(proposalId) {
            return proposalId;
        } catch {
            return 0;
        }
    }

    /// @notice Simulate governance proposal
    function simulate() public virtual override {
        address proposerAddress = address(1);
        IVotes governanceToken =
            IVotes(IGovernorVotes(address(governor)).token());
        {
            // Ensure proposer has meets minimum proposal threshold and quorum votes to pass the proposal
            uint256 quorumVotes = governor.quorum(block.number - 1);
            uint256 proposalThreshold = governor.proposalThreshold();
            uint256 votingPower = quorumVotes > proposalThreshold
                ? quorumVotes
                : proposalThreshold;
            deal(address(governanceToken), proposerAddress, votingPower);
            vm.roll(block.number - 1);
            // Delegate proposer's votes to itself
            vm.prank(proposerAddress);
            IVotes(governanceToken).delegate(proposerAddress);
            vm.roll(block.number + 2);
        }

        bytes memory proposeCalldata = getCalldata();

        // Register the proposal
        vm.prank(proposerAddress);
        bytes memory data = address(governor).functionCall(proposeCalldata);

        uint256 returnedProposalId = abi.decode(data, (uint256));

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = getProposalActions();

        // Check that the proposal was registered correctly
        uint256 proposalId = governor.hashProposal(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked(description()))
        );

        require(returnedProposalId == proposalId, "Proposal id mismatch");

        // Check proposal is in Pending state
        require(governor.state(proposalId) == IGovernor.ProposalState.Pending);

        // Roll to Active state (voting period)
        vm.roll(block.number + governor.votingDelay() + 1);

        require(governor.state(proposalId) == IGovernor.ProposalState.Active);

        // Vote YES
        vm.prank(proposerAddress);
        governor.castVote(proposalId, 1);

        // Roll to allow proposal state transitions
        vm.roll(block.number + governor.votingPeriod());

        require(governor.state(proposalId) == IGovernor.ProposalState.Succeeded);

        vm.warp(block.timestamp + governor.proposalEta(proposalId) + 1);

        // Queue the proposal
        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked(description()))
        );

        require(governor.state(proposalId) == IGovernor.ProposalState.Queued);

        // Warp to allow proposal execution on timelock
        ITimelockController timelock = ITimelockController(
            IGovernorTimelockControl(address(governor)).timelock()
        );
        vm.warp(block.timestamp + timelock.getMinDelay());

        // Execute the proposal
        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked(description()))
        );

        require(governor.state(proposalId) == IGovernor.ProposalState.Executed);
    }
}
