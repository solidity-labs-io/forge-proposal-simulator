// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

import {IgOHM} from "../interfaces/IgOHM.sol";
import {ITimelock} from "../interfaces/ITimelock.sol";

abstract contract GovernorBravoDelegatorStorage {
    // --- PROXY STATE VARIABLES ---------------------------------------------------

    /// @notice Administrator for this contract
    address public admin;

    /// @notice Pending administrator for this contract
    address public pendingAdmin;

    /// @notice Active brains of Governor
    address public implementation;
}

/**
 * @title Storage for Governor Bravo Delegate
 * @notice For future upgrades, do not change GovernorBravoDelegateStorageV1. Create a new
 * contract which implements GovernorBravoDelegateStorageV1 and following the naming convention
 * GovernorBravoDelegateStorageVX.
 */
abstract contract GovernorBravoDelegateStorageV1 is GovernorBravoDelegatorStorage {
    // --- DATA STRUCTURES ---------------------------------------------------------

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposer;
        /// @notice The proposal balance threshold that the proposer must stay above to keep their proposal active
        uint256 proposalThreshold;
        /// @notice The quorum for this proposal based on gOHM total supply at the time of proposal creation
        uint256 quorumVotes;
        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;
        /// @notice the ordered list of target addresses for calls to be made
        address[] targets;
        /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint256[] values;
        /// @notice The ordered list of function signatures to be called
        string[] signatures;
        /// @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;
        /// @notice The codehash for each target contract
        bytes32[] codehashes;
        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;
        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;
        /// @notice Current number of votes in favor of this proposal
        uint256 forVotes;
        /// @notice Current number of votes in opposition to this proposal
        uint256 againstVotes;
        /// @notice Current number of votes for abstaining for this proposal
        uint256 abstainVotes;
        /// @notice Flag marking whether the voting period for a proposal has been activated
        bool votingStarted;
        /// @notice Flag marking whether the proposal has been vetoed
        bool vetoed;
        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;
        /// @notice Flag marking whether the proposal has been executed
        bool executed;
        /// @notice Receipts of ballots for the entire set of voters
        mapping(address => Receipt) receipts;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;
        /// @notice Whether or not the voter supports the proposal or abstains
        uint8 support;
        /// @notice The number of votes the voter had, which were cast
        uint256 votes;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed,
        Vetoed,
        Emergency
    }

    // --- STATE VARIABLES ---------------------------------------------------------

    /// @notice The delay before voting on a proposal may take place, once proposed, in blocks
    uint256 public votingDelay;

    /// @notice The duration of voting on a proposal, in blocks
    uint256 public votingPeriod;

    /// @notice The grace period after the voting delay through which a proposal may be activated
    uint256 public activationGracePeriod;

    /// @notice The percentage of total supply required in order for a voter to become a proposer
    /// @dev    Out of 1000
    uint256 public proposalThreshold;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    /// @notice The address of the Olympus Protocol Timelock
    ITimelock public timelock;

    /// @notice The address of the Olympus governance token
    IgOHM public gohm;

    /// @notice The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;

    /// @notice The latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds;
}

abstract contract GovernorBravoDelegateStorageV2 is GovernorBravoDelegateStorageV1 {
    // --- STATE VARIABLES ---------------------------------------------------------

    /// @notice Modules in the Default system that are considered high risk
    /// @dev    In Default Framework, Keycodes are used to uniquely identify modules. They are a
    ///         wrapper over the bytes5 data type, and allow us to easily check if a proposal is
    ///         touching any specific modules
    mapping(Keycode => bool) public isKeycodeHighRisk;

    /// @notice Address which has veto power over all proposals
    address public vetoGuardian;

    /// @notice The central hub of the Default Framework system that manages modules and policies
    /// @dev    Used in this adaptation of Governor Bravo to identify high risk proposals
    address public kernel;
}
