// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";

import {Addresses} from "@addresses/Addresses.sol";
import {GovernorBravoProposal} from "@proposals/GovernorBravoProposal.sol";
import {MockDuplicatedActionProposal} from
    "@mocks/MockDuplicatedActionProposal.sol";

contract DuplicatedActionProposalIntegrationTest is Test {
    Addresses public addresses;
    GovernorBravoProposal public proposal;

    function setUp() public {
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 1;

        // Instantiate the Addresses contract
        addresses = new Addresses("./addresses", chainIds);
        vm.makePersistent(address(addresses));

        // Instantiate the BravoProposal contract
        proposal = GovernorBravoProposal(new MockDuplicatedActionProposal());

        proposal.setPrimaryForkId(vm.createSelectFork("mainnet"));

        // Set the addresses contract
        proposal.setAddresses(addresses);

        // Set the bravo address
        proposal.setGovernor(addresses.getAddress("COMPOUND_GOVERNOR_BRAVO"));
    }

    function test_build() public {
        vm.expectRevert("No actions found");
        proposal.getProposalActions();

        vm.expectRevert("Duplicated action found");
        proposal.build();
    }
}
