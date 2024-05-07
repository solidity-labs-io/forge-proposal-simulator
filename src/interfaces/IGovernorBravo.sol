// SPDX-License-Identifier: MIT
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

    function proposalCount() external view returns (uint256);

    function quorumVotes() external view returns (uint256);

    function proposalThreshold() external view returns (uint256);

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
        );

    function queue(uint256 proposalId) external;

    function execute(uint256 proposalId) external;

    function state(uint256 proposalId) external view returns (ProposalState);

    function castVote(uint256 proposalId, uint8 voteValue) external;

    function votingDelay() external view returns (uint256);

    function votingPeriod() external view returns (uint256);

    function timelock() external view returns (address);
}
