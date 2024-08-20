pragma solidity ^0.8.0;

import "forge-std/mocks/MockERC20.sol";

import {MockVotingContract} from "mocks/MockVotingContract.sol";

import {MultisigProposal} from "@proposals/MultisigProposal.sol";

contract MultisigProposal_03 is MultisigProposal {
    function name() public pure override returns (string memory) {
        return "MOCK_MULTISIG_PROPOSAL_03";
    }

    function description() public pure override returns (string memory) {
        return "Mock multisig proposal 03";
    }

    function run() public override {
        super.run();
    }

    function deploy() public override {
        string[] memory candidates = new string[](10);
        candidates[0] = "candidate0";
        candidates[1] = "candidate1";
        candidates[2] = "candidate2";
        candidates[3] = "candidate3";
        candidates[4] = "candidate4";
        candidates[5] = "candidate5";
        candidates[6] = "candidate6";
        candidates[7] = "candidate7";
        candidates[8] = "candidate8";
        candidates[9] = "candidate9";
        MockVotingContract votingContract = new MockVotingContract(candidates);

        // add Voting contract address
        addresses.addAddress("VOTING_CONTRACT", address(votingContract), true);
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("PROTOCOL_MULTISIG"))
    {
        MockVotingContract votingContract =
            MockVotingContract(addresses.getAddress("VOTING_CONTRACT"));

        // actions
        votingContract.vote("candidate0");
        votingContract.vote("candidate2");
        votingContract.vote("candidate4");
        votingContract.vote("candidate7");
        votingContract.vote("candidate9");
        votingContract.vote("candidate5");
        votingContract.vote("candidate8");
    }
}
