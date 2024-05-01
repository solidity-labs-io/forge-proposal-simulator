pragma solidity ^0.8.0;

import "@forge-std/Test.sol";

import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";

import {Proposal} from "@proposals/Proposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

// @notice this is a helper contract to execute a proposal before running integration tests.
// @dev should be inherited by integration test contracts.
contract TimelockPostProposalCheck is Test {
    Proposal public proposal;
    Addresses public addresses;

    function setUp() public virtual {
        require(
            address(proposal) != address(0),
            "Test must override setUp and set the proposal contract"
        );
        addresses = proposal.addresses();

        proposal.run();
    }
}
