// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";

import {Addresses} from "@addresses/Addresses.sol";
import {GovernorBravoProposal} from "@proposals/GovernorBravoProposal.sol";
import {MockBravoProposal} from "@mocks/MockBravoProposal.sol";

contract BravoProposalIntegrationTest is Test {
    Addresses public addresses;
    GovernorBravoProposal public proposal;

    function setUp() public {
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 1;

        // Instantiate the Addresses contract
        addresses = new Addresses("./addresses", chainIds);
        vm.makePersistent(address(addresses));

        // Instantiate the BravoProposal contract
        proposal = GovernorBravoProposal(new MockBravoProposal());

        proposal.setPrimaryForkId(vm.createSelectFork("mainnet"));

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

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = proposal.getProposalActions();

        address target = addresses.getAddress("COMPOUND_CONFIGURATOR");
        assertEq(targets.length, 2, "Wrong targets length");
        assertEq(targets[0], target, "Wrong target at index 0");
        assertEq(targets[1], target, "Wrong target at index 1");

        uint256 expectedValue = 0;
        assertEq(values.length, 2, "Wrong values length");
        assertEq(values[0], expectedValue, "Wrong value at index 0");
        assertEq(values[1], expectedValue, "Wrong value at index 1");

        uint64 kink = 750000000000000000;
        assertEq(calldatas.length, 2);
        assertEq(
            calldatas[0],
            abi.encodeWithSignature(
                "setBorrowKink(address,uint64)",
                addresses.getAddress("COMPOUND_COMET"),
                kink
            ),
            "Wrong calldata at index 0"
        );

        assertEq(
            calldatas[1],
            abi.encodeWithSignature(
                "setSupplyKink(address,uint64)",
                addresses.getAddress("COMPOUND_COMET"),
                kink
            ),
            "Wrong calldata at index 1"
        );
    }

    function test_simulate() public {
        test_build();

        proposal.simulate();

        // check that proposal exists
        assertTrue(proposal.getProposalId() > 0);

        proposal.validate();
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
}
