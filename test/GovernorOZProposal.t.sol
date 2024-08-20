// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";

import {Addresses} from "@addresses/Addresses.sol";
import {OZGovernorProposal} from "@proposals/OZGovernorProposal.sol";
import {MockOZGovernorProposal} from "@mocks/MockOZGovernorProposal.sol";

contract OZGovernorProposalIntegrationTest is Test {
    Addresses public addresses;
    OZGovernorProposal public proposal;

    function setUp() public {
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 1;

        // Instantiate the Addresses contract
        addresses = new Addresses("./addresses", chainIds);
        vm.makePersistent(address(addresses));

        // Instantiate the OZ Proposal contract
        proposal = OZGovernorProposal(new MockOZGovernorProposal());

        // Select the primary fork
        // ENS Governor is not cross chain so there is only a fork and should be mainnet
        proposal.setPrimaryForkId(vm.createSelectFork("mainnet"));

        // Set the addresses contract
        proposal.setAddresses(addresses);

        // Set the bravo address
        proposal.setGovernor(addresses.getAddress("ENS_GOVERNOR"));
    }

    function test_setUp() public view {
        assertEq(
            proposal.name(),
            string("UPGRADE_DNSSEC_SUPPORT"),
            "Wrong proposal name"
        );
        assertEq(
            proposal.description(),
            string(
                "Call setController on the Root contract at root.ens.eth, passing in the address of the new DNS registrar"
            ),
            "Wrong proposal description"
        );
        assertEq(
            address(proposal.governor()),
            addresses.getAddress("ENS_GOVERNOR"),
            "Wrong governor address"
        );
    }

    function test_deploy() public {
        vm.startPrank(addresses.getAddress("DEPLOYER_EOA"));
        proposal.deploy();
        vm.stopPrank();

        assertTrue(addresses.isAddressSet("ENS_DNSSEC"));
    }

    function test_build() public {
        test_deploy();

        vm.expectRevert("No actions found");
        proposal.getProposalActions();

        proposal.build();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = proposal.getProposalActions();

        address target = addresses.getAddress("ENS_ROOT");
        assertEq(targets.length, 1, "Wrong targets length");
        assertEq(targets[0], target, "Wrong target at index 0");
        assertEq(targets[0], target, "Wrong target at index 1");

        uint256 expectedValue = 0;
        assertEq(values.length, 1, "Wrong values length");
        assertEq(values[0], expectedValue, "Wrong value at index 0");
        assertEq(values[0], expectedValue, "Wrong value at index 1");

        assertEq(calldatas.length, 1);
        assertEq(
            calldatas[0],
            abi.encodeWithSignature(
                "setController(address,bool)",
                addresses.getAddress("ENS_DNSSEC"),
                true
            ),
            "Wrong calldata at index 0"
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

        bytes memory expectedData = abi.encodeWithSignature(
            "propose(address[],uint256[],bytes[],string)",
            targets,
            values,
            calldatas,
            proposal.description()
        );

        bytes memory data = proposal.getCalldata();

        assertEq(data, expectedData, "Wrong propose calldata");
    }
}
