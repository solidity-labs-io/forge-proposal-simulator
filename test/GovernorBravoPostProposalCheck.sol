pragma solidity ^0.8.0;

import "@forge-std/Test.sol";

import {GovernorBravoDelegator} from "@comp-governance/GovernorBravoDelegator.sol";
import {GovernorBravoDelegate} from "@comp-governance/GovernorBravoDelegate.sol";
import {Timelock} from "@comp-governance/Timelock.sol";

import {Proposal} from "@proposals/Proposal.sol";
import {MockERC20Votes} from "@mocks/MockERC20Votes.sol";
import {MockGovernorAlpha} from "@mocks/MockGovernorAlpha.sol";
import {Addresses} from "@addresses/Addresses.sol";

/// @notice this is a helper contract to execute a proposal before running integration tests.
/// @dev should be inherited by integration test contracts.
contract GovernorBravoPostProposalCheck is Test {
    Proposal public proposal;
    Addresses public addresses;

    function setUp() public virtual {
        require(
            address(proposal) != address(0),
            "Test must override setUp and set the proposal contract"
        );

        addresses = proposal.addresses();
        vm.makePersistent(address(addresses));

        proposal.run();
    }
}
