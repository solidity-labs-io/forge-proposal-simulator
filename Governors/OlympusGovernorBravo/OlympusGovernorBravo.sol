// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

import {ContractUtils} from "./lib/ContractUtils.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

import {IgOHM} from "./interfaces/IgOHM.sol";
import {ITimelock} from "./interfaces/ITimelock.sol";
import {IGovernorBravoEventsAndErrors} from "./interfaces/IGovernorBravoEvents.sol";

import {GovernorBravoDelegateStorageV2} from "./abstracts/GovernorBravoStorage.sol";

import "./Kernel.sol";

contract GovernorBravoDelegate is GovernorBravoDelegateStorageV2, IGovernorBravoEventsAndErrors {
    // --- CONSTANTS ---------------------------------------------------------------

    /// @notice The name of this contract
    string public constant name = "Olympus Governor Bravo";

    /// @notice The minimum setable proposal threshold
    uint256 public constant MIN_PROPOSAL_THRESHOLD_PCT = 15_000; // 0.015% (out of 100_000_000)

    /// @notice The maximum setable proposal threshold
    uint256 public constant MAX_PROPOSAL_THRESHOLD_PCT = 1_000_000; // 1% (out of 100_000_000)

    /// @notice The minimum setable voting period
    uint256 public constant MIN_VOTING_PERIOD = 21600; // About 3 days (12s block time)

    /// @notice The max setable voting period
    uint256 public constant MAX_VOTING_PERIOD = 100800; // About 2 weeks (12s block time)

    /// @notice The min setable voting delay
    uint256 public constant MIN_VOTING_DELAY = 7200; // About 1 day (12s block time)

    /// @notice The max setable voting delay
    uint256 public constant MAX_VOTING_DELAY = 50400; // About 1 week (12s block time)

    /// @notice The minimum level of gOHM supply acceptable for OCG operations
    uint256 public constant MIN_GOHM_SUPPLY = 1_000e18;

    /// @notice The percentage of total supply in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    /// @dev    Olympus has a variable supply system, that actively fluctuates fairly significantly, so it is better to use
    ///         a percentage of total supply, rather than a fixed number of tokens.
    uint256 public constant quorumPct = 20_000_000; // 20% (out of 100_000_000)

    /// @notice The percentage of total supply in support of a proposal related to a high risk module in the Default system required
    ///         in order for a quorum to be reached and for a vote to succeed
    /// @dev    Olympus has a variable supply system, that actively fluctuates fairly significantly, so it is better to use
    ///         a percentage of total supply, rather than a fixed number of tokens.
    uint256 public constant highRiskQuorum = 20_000_000; // 20% (out of 100_000_000)

    /// @notice The percentage of votes that must be in favor of a proposal for it to succeed
    uint256 public constant approvalThresholdPct = 60_000_000; // 60% (out of 100_000_000)

    /// @notice The maximum number of actions that can be included in a proposal
    uint256 public constant proposalMaxOperations = 15; // 15 actions

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

    // --- INITIALIZE --------------------------------------------------------------

    /**
     * @notice Used to initialize the contract during delegator constructor
     * @param timelock_ The address of the Timelock
     * @param gohm_ The address of the gOHM token
     * @param kernel_ The address of the kernel
     * @param vetoGuardian_ The address of the veto guardian
     * @param votingPeriod_ The initial voting period
     * @param votingDelay_ The initial voting delay
     * @param proposalThreshold_ The initial proposal threshold (percentage of total supply. out of 1000)
     */
    function initialize(
        address timelock_,
        address gohm_,
        address kernel_,
        address vetoGuardian_,
        uint256 votingPeriod_,
        uint256 votingDelay_,
        uint256 activationGracePeriod_,
        uint256 proposalThreshold_
    ) public virtual {
        if (msg.sender != admin) revert GovernorBravo_OnlyAdmin();
        if (address(timelock) != address(0)) revert GovernorBravo_AlreadyInitialized();
        if (
            gohm_ == address(0) ||
            kernel_ == address(0) ||
            timelock_ == address(0) ||
            vetoGuardian_ == address(0)
        ) revert GovernorBravo_AddressZero();
        if (votingPeriod_ < MIN_VOTING_PERIOD || votingPeriod_ > MAX_VOTING_PERIOD)
            revert GovernorBravo_InvalidPeriod();
        if (votingDelay_ < MIN_VOTING_DELAY || votingDelay_ > MAX_VOTING_DELAY)
            revert GovernorBravo_InvalidDelay();
        if (
            proposalThreshold_ < MIN_PROPOSAL_THRESHOLD_PCT ||
            proposalThreshold_ > MAX_PROPOSAL_THRESHOLD_PCT
        ) revert GovernorBravo_InvalidThreshold();

        // Set up contract dependencies
        timelock = ITimelock(timelock_);
        gohm = IgOHM(gohm_);
        kernel = kernel_;

        // Configure voting parameters
        vetoGuardian = vetoGuardian_;
        votingDelay = votingDelay_;
        votingPeriod = votingPeriod_;
        activationGracePeriod = activationGracePeriod_;
        proposalThreshold = proposalThreshold_;
    }

    // --- GOVERNANCE LOGIC --------------------------------------------------------

    /**
     * @notice Function used to propose a new proposal. Sender must have delegates above the proposal threshold
     * @param targets Target addresses for proposal calls
     * @param values Eth values for proposal calls
     * @param signatures Function signatures for proposal calls
     * @param calldatas Calldatas for proposal calls
     * @param description String description of the proposal
     * @return Proposal id of new proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        if (_isEmergency()) revert GovernorBravo_Emergency_SupplyTooLow();
        // Allow addresses above proposal threshold and whitelisted addresses to propose
        if (gohm.getPriorVotes(msg.sender, block.number - 1) <= getProposalThresholdVotes())
            revert GovernorBravo_Proposal_ThresholdNotMet();
        if (
            targets.length != values.length ||
            targets.length != signatures.length ||
            targets.length != calldatas.length
        ) revert GovernorBravo_Proposal_LengthMismatch();
        if (targets.length == 0) revert GovernorBravo_Proposal_NoActions();
        if (targets.length > proposalMaxOperations) revert GovernorBravo_Proposal_TooManyActions();

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(latestProposalId);
            if (proposersLatestProposalState == ProposalState.Active)
                revert GovernorBravo_Proposal_AlreadyActive();
            if (proposersLatestProposalState == ProposalState.Pending)
                revert GovernorBravo_Proposal_AlreadyPending();
        }

        uint256 startBlock = block.number + votingDelay;

        proposalCount++;
        uint256 newProposalID = proposalCount;

        // Get codehashes for each target
        // NOTE: using targets.length here rather than caching it before IS less efficient, but allows us to avoid
        // a stack-too-deep error while avoiding the much more expensive read of lengths for each loop iteration
        bytes32[] memory codehashes = new bytes32[](targets.length);
        {
            uint256 numTargets = targets.length;
            for (uint256 i; i < numTargets; ) {
                codehashes[i] = ContractUtils.getCodeHash(targets[i]);
                unchecked {
                    ++i;
                }
            }
        }

        {
            // Given Olympus's dynamic supply, we need to capture quorum and proposal thresholds in terms
            // of the total supply at the time of proposal creation.
            uint256 proposalThresholdVotes = getProposalThresholdVotes();

            Proposal storage newProposal = proposals[newProposalID];
            // This should never happen but add a check in case.
            if (newProposal.id != 0) revert GovernorBravo_Proposal_IdCollision();

            // Set basic proposal data to prevent reentrancy
            latestProposalIds[msg.sender] = newProposalID;
            newProposal.startBlock = startBlock;

            newProposal.id = newProposalID;
            newProposal.proposer = msg.sender;
            newProposal.proposalThreshold = proposalThresholdVotes;
            newProposal.targets = targets;
            newProposal.values = values;
            newProposal.signatures = signatures;
            newProposal.calldatas = calldatas;
            newProposal.codehashes = codehashes;
        }

        emit ProposalCreated(
            newProposalID,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            description
        );
        return newProposalID;
    }

    /**
     * @notice Create proposal in case of emergency
     * @dev Can only be called by the veto guardian in the event of an emergency
     * @param targets Target addresses for proposal calls
     * @param values Eth values for proposal calls
     * @param signatures Function signatures for proposal calls
     * @param calldatas Calldatas for proposal calls
     */
    function emergencyPropose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) external returns (uint256) {
        if (!_isEmergency()) revert GovernorBravo_NotEmergency();
        if (msg.sender != vetoGuardian) revert GovernorBravo_OnlyVetoGuardian();

        // Perform basic checks on the proposal data
        uint256 numActions = targets.length;
        if (
            numActions != values.length ||
            numActions != signatures.length ||
            numActions != calldatas.length
        ) revert GovernorBravo_Proposal_LengthMismatch();
        if (numActions == 0) revert GovernorBravo_Proposal_NoActions();
        if (numActions > proposalMaxOperations) revert GovernorBravo_Proposal_TooManyActions();

        // Increment the proposal count to avoid collisions with future normal proposals
        // and to allow for proper queueing and execution on the Timelock
        proposalCount++;
        uint256 newProposalID = proposalCount;

        // Get codehashes for each target
        bytes32[] memory codehashes = new bytes32[](numActions);
        {
            for (uint256 i; i < numActions; ) {
                codehashes[i] = ContractUtils.getCodeHash(targets[i]);
                unchecked {
                    ++i;
                }
            }
        }

        {
            // Set basic proposal data so there is a record
            Proposal storage newProposal = proposals[newProposalID];
            // This should never happen but add a check in case.
            if (newProposal.id != 0) revert GovernorBravo_Proposal_IdCollision();

            newProposal.id = newProposalID;
            newProposal.proposer = msg.sender;
            newProposal.targets = targets;
            newProposal.values = values;
            newProposal.signatures = signatures;
            newProposal.calldatas = calldatas;
            newProposal.codehashes = codehashes;
        }

        emit ProposalCreated(
            newProposalID,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            block.number,
            "Emergency Proposal"
        );
        return newProposalID;
    }

    /**
     * @notice Activates voting for a proposal
     * @dev This also captures quorum based on total supply to ensure it's as close as possible to the proposal start time
     */
    function activate(uint256 proposalId) external {
        if (_isEmergency()) revert GovernorBravo_Emergency_SupplyTooLow();
        if (state(proposalId) != ProposalState.Pending) revert GovernorBravo_Vote_Closed();

        Proposal storage proposal = proposals[proposalId];
        if (block.number <= proposal.startBlock) revert GovernorBravo_Proposal_TooEarly();
        if (proposal.votingStarted || proposal.endBlock != 0)
            revert GovernorBravo_Proposal_AlreadyActivated();

        proposal.votingStarted = true;
        proposal.endBlock = block.number + votingPeriod;

        // In the future we can use this to set quorum based on a classification of the proposals risk
        // for the time being, we will use a single quorum value for all proposals
        // uint256 quorumVotes;
        // if (_isHighRiskProposal(proposal.targets, proposal.signatures, proposal.calldatas)) {
        //     quorumVotes = getHighRiskQuorumVotes();
        // } else {
        //     quorumVotes = getQuorumVotes();
        // }

        proposal.quorumVotes = getQuorumVotes();
        emit ProposalVotingStarted(proposalId);
    }

    /**
     * @notice Queues a successful proposal
     * @param proposalId The id of the proposal to queue
     */
    function queue(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        if (_isEmergency()) {
            // In an emergency state, only the veto guardian can queue proposals
            if (msg.sender != vetoGuardian) revert GovernorBravo_OnlyVetoGuardian();
        } else {
            // Check if proposal is succeeded
            if (state(proposalId) != ProposalState.Succeeded)
                revert GovernorBravo_Queue_FailedProposal();

            // Check that proposer has not fallen below proposal threshold since proposal creation
            if (
                gohm.getPriorVotes(proposal.proposer, block.number - 1) < proposal.proposalThreshold
            ) revert GovernorBravo_Queue_BelowThreshold();
        }

        uint256 eta = block.timestamp + timelock.delay();
        uint256 numActions = proposal.targets.length;
        for (uint256 i = 0; i < numActions; i++) {
            _queueOrRevertInternal(
                proposalId,
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function _queueOrRevertInternal(
        uint256 proposalId,
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        if (
            timelock.queuedTransactions(
                keccak256(abi.encode(proposalId, target, value, signature, data, eta))
            )
        ) revert GovernorBravo_Queue_AlreadyQueued();

        timelock.queueTransaction(proposalId, target, value, signature, data, eta);
    }

    /**
     * @notice Executes a queued proposal if eta has passed
     * @param proposalId The id of the proposal to execute
     */
    function execute(uint256 proposalId) external payable {
        Proposal storage proposal = proposals[proposalId];

        if (_isEmergency()) {
            // In an emergency state, only the veto guardian can queue proposals
            if (msg.sender != vetoGuardian) revert GovernorBravo_OnlyVetoGuardian();
        } else {
            // Check if proposal is succeeded
            if (state(proposalId) != ProposalState.Queued) revert GovernorBravo_Execute_NotQueued();
            // Check that proposer has not fallen below proposal threshold since proposal creation
            if (
                gohm.getPriorVotes(proposal.proposer, block.number - 1) < proposal.proposalThreshold
            ) revert GovernorBravo_Execute_BelowThreshold();
        }

        proposal.executed = true;
        uint256 numActions = proposal.targets.length;
        for (uint256 i = 0; i < numActions; i++) {
            timelock.executeTransaction{value: proposal.values[i]}(
                proposalId,
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.codehashes[i],
                proposal.eta
            );
        }
        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Cancels a proposal only if sender is the proposer, or proposer delegates dropped below proposal threshold
     * @param proposalId The id of the proposal to cancel
     */
    function cancel(uint256 proposalId) external {
        if (state(proposalId) == ProposalState.Executed)
            revert GovernorBravo_Cancel_AlreadyExecuted();

        Proposal storage proposal = proposals[proposalId];

        // Proposer can cancel
        if (msg.sender != proposal.proposer) {
            if (
                gohm.getPriorVotes(proposal.proposer, block.number - 1) >=
                proposal.proposalThreshold
            ) revert GovernorBravo_Cancel_AboveThreshold();
        }

        proposal.canceled = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(
                proposalId,
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalCanceled(proposalId);
    }

    /**
     * @notice Vetoes a proposal only if sender is the veto guardian
     * @param proposalId The id of the proposal to veto
     */
    function veto(uint256 proposalId) external {
        if (msg.sender != vetoGuardian) revert GovernorBravo_OnlyVetoGuardian();
        if (state(proposalId) == ProposalState.Executed)
            revert GovernorBravo_Veto_AlreadyExecuted();

        Proposal storage proposal = proposals[proposalId];

        proposal.vetoed = true;
        for (uint256 i; i < proposal.targets.length; ) {
            // If the proposal has been queued, cancel on the timelock
            if (
                timelock.queuedTransactions(
                    keccak256(
                        abi.encode(
                            proposalId,
                            proposal.targets[i],
                            proposal.values[i],
                            proposal.signatures[i],
                            proposal.calldatas[i],
                            proposal.eta
                        )
                    )
                )
            ) {
                timelock.cancelTransaction(
                    proposalId,
                    proposal.targets[i],
                    proposal.values[i],
                    proposal.signatures[i],
                    proposal.calldatas[i],
                    proposal.eta
                );
            }

            unchecked {
                ++i;
            }
        }

        emit ProposalVetoed(proposalId);
    }

    /**
     * @notice Cast a vote for a proposal
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     */
    function castVote(uint256 proposalId, uint8 support) external {
        emit VoteCast(
            msg.sender,
            proposalId,
            support,
            castVoteInternal(msg.sender, proposalId, support),
            ""
        );
    }

    /**
     * @notice Cast a vote for a proposal with a reason
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @param reason The reason given for the vote by the voter
     */
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external {
        emit VoteCast(
            msg.sender,
            proposalId,
            support,
            castVoteInternal(msg.sender, proposalId, support),
            reason
        );
    }

    /**
     * @notice Cast a vote for a proposal by signature
     * @dev External function that accepts EIP-712 signatures for voting on proposals.
     */
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainIdInternal(), address(this))
        );
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ECDSA.recover(digest, v, r, s);
        if (signatory == address(0)) revert GovernorBravo_InvalidSignature();
        emit VoteCast(
            signatory,
            proposalId,
            support,
            castVoteInternal(signatory, proposalId, support),
            ""
        );
    }

    /**
     * @notice Internal function that caries out voting logic
     * @param voter The voter that is casting their vote
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @return The number of votes cast
     */
    function castVoteInternal(
        address voter,
        uint256 proposalId,
        uint8 support
    ) internal returns (uint256) {
        if (state(proposalId) != ProposalState.Active) revert GovernorBravo_Vote_Closed();
        if (support > 2) revert GovernorBravo_Vote_InvalidType();
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        if (receipt.hasVoted) revert GovernorBravo_Vote_AlreadyCast();

        // Get the user's votes at the start of the proposal and at the time of voting. Take the minimum.
        uint256 originalVotes = gohm.getPriorVotes(voter, proposal.startBlock);
        uint256 currentVotes = gohm.getPriorVotes(voter, block.number - 1);
        uint256 votes = currentVotes > originalVotes ? originalVotes : currentVotes;

        if (support == 0) {
            proposal.againstVotes = proposal.againstVotes + votes;
        } else if (support == 1) {
            proposal.forVotes = proposal.forVotes + votes;
        } else if (support == 2) {
            proposal.abstainVotes = proposal.abstainVotes + votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        return votes;
    }

    // --- ADMIN FUNCTIONS ---------------------------------------------------------

    /**
     * @notice Admin function for setting the voting delay
     * @param newVotingDelay new voting delay, in blocks
     */
    function _setVotingDelay(uint256 newVotingDelay) external {
        if (msg.sender != admin) revert GovernorBravo_OnlyAdmin();
        if (newVotingDelay < MIN_VOTING_DELAY || newVotingDelay > MAX_VOTING_DELAY)
            revert GovernorBravo_InvalidDelay();

        uint256 oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, votingDelay);
    }

    /**
     * @notice Admin function for setting the voting period
     * @param newVotingPeriod new voting period, in blocks
     */
    function _setVotingPeriod(uint256 newVotingPeriod) external {
        if (msg.sender != admin) revert GovernorBravo_OnlyAdmin();
        if (newVotingPeriod < MIN_VOTING_PERIOD || newVotingPeriod > MAX_VOTING_PERIOD)
            revert GovernorBravo_InvalidPeriod();

        uint256 oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

    /**
     * @notice Admin function for setting the proposal threshold
     * @dev newProposalThreshold must be greater than the hardcoded min
     * @param newProposalThreshold new proposal threshold
     */
    function _setProposalThreshold(uint256 newProposalThreshold) external {
        if (msg.sender != admin) revert GovernorBravo_OnlyAdmin();
        if (
            newProposalThreshold < MIN_PROPOSAL_THRESHOLD_PCT ||
            newProposalThreshold > MAX_PROPOSAL_THRESHOLD_PCT
        ) revert GovernorBravo_InvalidThreshold();

        uint256 oldProposalThreshold = proposalThreshold;
        proposalThreshold = newProposalThreshold;

        emit ProposalThresholdSet(oldProposalThreshold, proposalThreshold);
    }

    /**
     * @notice Admin function for setting the vetoGuardian. vetoGuardian can veto any proposal
     * @param account Account to set vetoGuardian to (0x0 to remove vetoGuardian)
     */
    function _setVetoGuardian(address account) external {
        if (msg.sender != admin) revert GovernorBravo_OnlyAdmin();
        address oldGuardian = vetoGuardian;
        vetoGuardian = account;

        emit VetoGuardianSet(oldGuardian, vetoGuardian);
    }

    /**
     * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @param newPendingAdmin New pending admin.
     */
    function _setPendingAdmin(address newPendingAdmin) external {
        // Check caller = admin
        if (msg.sender != admin) revert GovernorBravo_OnlyAdmin();

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }

    /**
     * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
     * @dev Admin function for pending admin to accept role and update admin
     */
    function _acceptAdmin() external {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        if (msg.sender != pendingAdmin || msg.sender == address(0))
            revert GovernorBravo_OnlyPendingAdmin();

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    /**
     * @notice Sets whether a module is considered high risk
     * @dev Admin function to set whether a module in the Default Framework is considered high risk
     * @param module_ The module to set the risk of
     * @param isHighRisk_ If the module is high risk
     */
    function _setModuleRiskLevel(bytes5 module_, bool isHighRisk_) external {
        if (msg.sender != admin) revert GovernorBravo_OnlyAdmin();
        isKeycodeHighRisk[toKeycode(module_)] = isHighRisk_;
    }

    // --- HELPER FUNCTIONS: INTERNAL ----------------------------------------------

    /**
     * @dev Checks if the system should be set to an emergency state due to a collapsing supply of gOHM
     */
    function _isEmergency() internal view returns (bool) {
        return gohm.totalSupply() < MIN_GOHM_SUPPLY;
    }

    /**
     * @dev Checks if a proposal is high risk by identifying actions where the Default Framework kernel
     *      is the target, if so, checking if it's installing or deactivating a policy, and if so,
     *      checking if the policy is touching a high risk module. This makes external calls, so when
     *      for future updates to the Governor, make sure that functions where it is used cannot be re-entered.
     */
    function _isHighRiskProposal(
        address[] memory targets,
        string[] memory signatures,
        bytes[] memory calldatas
    ) internal returns (bool) {
        // If proposal interacts with the kernel, and is touching a policy that interacts with
        // a flagged module, then it is high risk.
        uint256 numActions = targets.length;

        for (uint256 i = 0; i < numActions; i++) {
            address target = targets[i];
            string memory signature = signatures[i];
            bytes memory data = calldatas[i];

            if (target == address(this) || target == address(timelock)) {
                return true;
            }

            if (target == kernel) {
                // Get function selector
                bytes4 selector = bytes(signature).length == 0
                    ? bytes4(data)
                    : bytes4(keccak256(bytes(signature)));

                // Check if the action is making a core change to system via the kernel
                if (selector == Kernel.executeAction.selector) {
                    uint8 action;
                    address actionTarget;

                    // We know the proper size of calldata for an `executeAction` call, so we can parse it
                    if (bytes(signature).length == 0 && data.length == 0x44) {
                        assembly {
                            action := mload(add(data, 0x24)) // accounting for length and selector in first 4 bytes
                            actionTarget := mload(add(data, 0x44))
                        }
                    } else if (data.length == 0x40) {
                        (action, actionTarget) = abi.decode(data, (uint8, address));
                    } else {
                        revert GovernorBravo_InvalidCalldata();
                    }

                    // If the action is changing the executor (4) or migrating the kernel (5)
                    if (action == 4 || action == 5) {
                        return true;
                    }
                    // If the action is upgrading a module (1)
                    else if (action == 1) {
                        // Check if the module has a high risk keycode
                        if (isKeycodeHighRisk[Module(actionTarget).KEYCODE()]) return true;
                    }
                    // If the action is installing (2) or deactivating (3) a policy, pull the list of dependencies
                    else if (action == 2 || action == 3) {
                        // Call `configureDependencies` on the policy
                        Keycode[] memory dependencies = Policy(actionTarget)
                            .configureDependencies();

                        // Iterate over dependencies and looks for high risk keycodes
                        uint256 numDeps = dependencies.length;
                        for (uint256 j; j < numDeps; j++) {
                            Keycode dep = dependencies[j];
                            if (isKeycodeHighRisk[dep]) return true;
                        }
                    }
                }
            }
        }

        return false;
    }

    // --- GETTER FUNCTIONS: SYSTEM ------------------------------------------------

    /**
     * @notice View function that gets the chain ID of the current network
     * @return The chain ID
     */
    function getChainIdInternal() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    /**
     * @notice View function that gets the proposal threshold in number of gOHM based on current supply
     * @return The proposal threshold in number of gOHM
     */
    function getProposalThresholdVotes() public view returns (uint256) {
        return (gohm.totalSupply() * proposalThreshold) / 100_000_000;
    }

    /**
     * @notice View function that gets the quorum in number of gOHM based on current supply
     * @return The quorum in number of gOHM
     */
    function getQuorumVotes() public view returns (uint256) {
        return (gohm.totalSupply() * quorumPct) / 100_000_000;
    }

    /**
     * @notice View function that gets the high risk quorum in number of gOHM based on current supply
     * @return The high risk quorum in number of gOHM
     */
    function getHighRiskQuorumVotes() public view returns (uint256) {
        return (gohm.totalSupply() * highRiskQuorum) / 100_000_000;
    }

    // --- GETTER FUNCTIONS: PROPOSAL ----------------------------------------------

    /**
     * @notice Gets the quorum required for a given proposal
     * @param proposalId the id of the proposal
     * @return The quorum required for the given proposal
     */
    function getProposalQuorum(uint256 proposalId) external view returns (uint256) {
        return proposals[proposalId].quorumVotes;
    }

    /**
     * @notice Gets the proposer votes threshold required for a given proposal
     * @param proposalId the id of the proposal
     * @return The proposer votes threshold required for the given proposal
     */
    function getProposalThreshold(uint256 proposalId) external view returns (uint256) {
        return proposals[proposalId].proposalThreshold;
    }

    /**
     * @notice Gets the eta value for a given proposal
     * @param proposalId the id of the proposal
     * @return The eta value for the given proposal
     */
    function getProposalEta(uint256 proposalId) external view returns (uint256) {
        return proposals[proposalId].eta;
    }

    /**
     * @notice Gets the against, for, and abstain votes for a given proposal
     * @param proposalId the id of the proposal
     * @return The against, for, and abstain votes for the given proposal
     */
    function getProposalVotes(
        uint256 proposalId
    ) external view returns (uint256, uint256, uint256) {
        Proposal storage p = proposals[proposalId];
        return (p.againstVotes, p.forVotes, p.abstainVotes);
    }

    /**
     * @notice Gets actions of a proposal
     * @param proposalId the id of the proposal
     * @return targets of the proposal actions
     * @return values of the proposal actions
     * @return signatures of the proposal actions
     * @return calldatas of the proposal actions
     */
    function getActions(
        uint256 proposalId
    )
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    /**
     * @notice Gets the receipt for a voter on a given proposal
     * @param proposalId the id of proposal
     * @param voter The address of the voter
     * @return The voting receipt
     */
    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    /**
     * @notice Gets the voting outcome of the proposal
     * @param proposalId the id of proposal
     * @return The voting outcome
     */
    function getVoteOutcome(uint256 proposalId) public view returns (bool) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.forVotes == 0 && proposal.againstVotes == 0) {
            return false;
        } else if (
            (proposal.forVotes * 100_000_000) / (proposal.forVotes + proposal.againstVotes) <
            approvalThresholdPct ||
            proposal.forVotes < proposal.quorumVotes
        ) {
            return false;
        }

        return true;
    }

    /**
     * @notice Gets the state of a proposal
     * @param proposalId The id of the proposal
     * @return Proposal state
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        if (proposalCount < proposalId) revert GovernorBravo_Proposal_IdInvalid();
        Proposal storage proposal = proposals[proposalId];
        if (
            proposal.startBlock == 0 &&
            proposal.proposer == vetoGuardian &&
            proposal.targets.length > 0
        ) {
            // We want to short circuit the proposal state if it's an emergency proposal
            // We do not want to leave the proposal in a perpetual pending state (or otherwise)
            // where a user may be able to cancel or reuse it
            return ProposalState.Emergency;
        } else if (proposal.vetoed) {
            return ProposalState.Vetoed;
        } else if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (
            block.number <= proposal.startBlock || !proposal.votingStarted || proposal.endBlock == 0
        ) {
            if (block.number > proposal.startBlock + activationGracePeriod) {
                return ProposalState.Expired;
            }

            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (!getVoteOutcome(proposalId)) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + timelock.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }
}


