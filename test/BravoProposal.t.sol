// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";

import {Addresses} from "@addresses/Addresses.sol";
import {GovernorBravoProposal} from "@proposals/GovernorBravoProposal.sol";
import {Vault} from "@mocks/Vault.sol";
import {Token} from "@mocks/Token.sol";
import {MockBravoProposal} from "@mocks/MockBravoProposal.sol";

contract BravoProposalIntegrationTest is Test {
    Addresses public addresses;
    GovernorBravoProposal public proposal;

    function setUp() public {
        // Instantiate the Addresses contract
        addresses = new Addresses("./addresses/Addresses.json");
        vm.makePersistent(address(addresses));

        // Instantiate the BravoProposal contract
        proposal = GovernorBravoProposal(new MockBravoProposal());

        // Set the addresses contract
        proposal.setAddresses(addresses);

        // Set the bravo address
        proposal.setGovernor(addresses.getAddress("COMPOUND_GOVERNOR_BRAVO"));
    }

    function test_setUp() public view {
        assertEq(
            proposal.name(),
            string("ADJUST_WETH_IR_CURVE"),
            "Wrong proposal name"
        );
        assertEq(
            proposal.description(),
            string(
                "Mock proposal that adjust IR Curve for Compound v3 WETH on Mainnet"
            ),
            "Wrong proposal description"
        );
        assertEq(
            address(proposal.governor()),
            addresses.getAddress("COMPOUND_GOVERNOR_BRAVO"),
            "Wrong governor address"
        );
    }

    function test_build() public {
        vm.expectRevert("No actions found");
        proposal.getProposalActions();

        proposal.build();
    }

    function test_simulate() public {
        test_build();

        proposal.simulate();

        // check that proposal exists
        assertTrue(proposal.checkOnChainCalldata());
    }

    function test_getCalldata() public {
        test_build();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = proposal.getProposalActions();

        string[] memory signatures = new string[](targets.length);

        bytes memory expectedData = abi.encodeWithSignature(
            "propose(address[],uint256[],string[],bytes[],string)",
            targets,
            values,
            signatures,
            calldatas,
            proposal.description()
        );

        bytes memory data = proposal.getCalldata();

        assertEq(data, expectedData, "Wrong propose calldata");
    }

    function test_checkOnChainCalldata() public {
        test_build();

        assertTrue(proposal.checkOnChainCalldata());
    }

    function test_validate() public {
        test_simulate();

        proposal.validate();
    }
}
