// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

interface IGovernorBravo {
    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    function votingDelay() external view returns (uint256);

    function votingPeriod() external view returns (uint256);

    function proposalThreshold() external view returns (uint256);

    function proposalCount() external view returns (uint256);

    function quorumVotes() external view returns (uint256);

    function timelock() external view returns (ITimelockBravo);

    function getActions(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        );

    function castVote(uint256 proposalId, uint8 support) external;

    function queue(uint256 proposalId) external;

    function execute(uint256 proposalId) external payable;

    function state(uint256 proposalId) external view returns (ProposalState);

    function comp() external view returns (IERC20VotesComp);
}

interface ITimelockBravo {
    function delay() external view returns (uint256);
    function GRACE_PERIOD() external view returns (uint256);
    function acceptAdmin() external;
    function queuedTransactions(bytes32 hash) external view returns (bool);
    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);
    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external;
    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external payable returns (bytes memory);
}

interface IERC20VotesComp {
    function getPriorVotes(address account, uint256 blockNumber)
        external
        view
        returns (uint96);

    function delegate(address delegatee) external;
}
