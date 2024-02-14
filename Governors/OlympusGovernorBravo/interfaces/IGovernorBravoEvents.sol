// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.15;

interface IGovernorBravoEventsAndErrors {
    // --- ERRORS ---------------------------------------------------------

    // Admin Errors
    error GovernorBravo_OnlyAdmin();
    error GovernorBravo_OnlyPendingAdmin();
    error GovernorBravo_OnlyVetoGuardian();
    error GovernorBravo_AlreadyInitialized();
    error GovernorBravo_NotActive();
    error GovernorBravo_AddressZero();
    error GovernorBravo_InvalidDelay();
    error GovernorBravo_InvalidPeriod();
    error GovernorBravo_InvalidGracePeriod();
    error GovernorBravo_InvalidThreshold();
    error GovernorBravo_InvalidCalldata();
    error GovernorBravo_Emergency_SupplyTooLow();
    error GovernorBravo_NotEmergency();
    // Proposal Errors
    error GovernorBravo_Proposal_ThresholdNotMet();
    error GovernorBravo_Proposal_LengthMismatch();
    error GovernorBravo_Proposal_NoActions();
    error GovernorBravo_Proposal_TooManyActions();
    error GovernorBravo_Proposal_AlreadyActive();
    error GovernorBravo_Proposal_AlreadyPending();
    error GovernorBravo_Proposal_IdCollision();
    error GovernorBravo_Proposal_IdInvalid();
    error GovernorBravo_Proposal_TooEarly();
    error GovernorBravo_Proposal_AlreadyActivated();
    // Voting Errors
    error GovernorBravo_InvalidSignature();
    error GovernorBravo_Vote_Closed();
    error GovernorBravo_Vote_InvalidType();
    error GovernorBravo_Vote_AlreadyCast();
    // Workflow Errors
    error GovernorBravo_Queue_FailedProposal();
    error GovernorBravo_Queue_AlreadyQueued();
    error GovernorBravo_Queue_BelowThreshold();
    error GovernorBravo_Queue_VetoedProposal();
    error GovernorBravo_Execute_NotQueued();
    error GovernorBravo_Execute_BelowThreshold();
    error GovernorBravo_Execute_VetoedProposal();
    error GovernorBravo_Cancel_AlreadyExecuted();
    error GovernorBravo_Cancel_WhitelistedProposer();
    error GovernorBravo_Cancel_AboveThreshold();
    error GovernorBravo_Veto_AlreadyExecuted();

    // --- EVENTS ------------------------------------------------------------------

    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        string description
    );

    /// @notice Event emitted when a proposal's voting period is activated
    event ProposalVotingStarted(uint256 id);

    /// @notice An event emitted when a vote has been cast on a proposal
    /// @param voter The address which casted a vote
    /// @param proposalId The proposal id which was voted on
    /// @param support Support value for the vote. 0=against, 1=for, 2=abstain
    /// @param votes Number of votes which were cast by the voter
    /// @param reason The reason given for the vote by the voter
    event VoteCast(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 votes,
        string reason
    );

    /// @notice An event emitted when a proposal has been vetoed
    event ProposalVetoed(uint256 id);

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint256 id, uint256 eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 id);

    /// @notice An event emitted when the voting delay is set
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);

    /// @notice An event emitted when the voting period is set
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

    /// @notice Emitted when implementation is changed
    event NewImplementation(address oldImplementation, address newImplementation);

    /// @notice Emitted when proposal threshold is set
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);

    /// @notice Emitted when pendingAdmin is changed
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /// @notice Emitted when pendingAdmin is accepted, which means admin is updated
    event NewAdmin(address oldAdmin, address newAdmin);

    /// @notice Emitted when whitelist account expiration is set
    event WhitelistAccountExpirationSet(address account, uint256 expiration);

    /// @notice Emitted when the whitelistGuardian is set
    event WhitelistGuardianSet(address oldGuardian, address newGuardian);

    /// @notice Emitted when the vetoGuardian is set
    event VetoGuardianSet(address oldGuardian, address newGuardian);
}
