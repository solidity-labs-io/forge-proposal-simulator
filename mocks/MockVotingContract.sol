pragma solidity ^0.8.0;

/// @notice This is a mock contract for testing purposes only, it SHOULD NOT be used in production.
contract MockVotingContract {
    mapping(string candidate => uint256 votes) public votesReceived;
    string[] public candidateList;

    constructor(string[] memory candidateNames) {
        candidateList = candidateNames;
    }

    function vote(string memory candidate) public {
        votesReceived[candidate] += 1;
    }

    function totalVotesFor(string memory candidate) public view returns (uint) {
        return votesReceived[candidate];
    }
}
