pragma solidity ^0.8.0;

import "@forge-std/Test.sol";

import {Constants} from "@utils/Constants.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Proposal} from "@proposals/Proposal.sol";

/// @notice this is a helper contract to execute a proposal before running integration tests.
/// @dev should be inherited by integration test contracts.
contract MultisigPostProposalCheck is Test {
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
