pragma solidity ^0.8.0;

contract MockVotingContract {
    mapping(string => uint) public votesReceived;
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
