// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockGovernorAlpha {
    function proposalCount() public pure returns (uint256) {
        return 1;
    }

    function quorumVotes() public pure returns (uint) {
        return 1e21;
    }
}
