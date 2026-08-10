// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";

import {Addresses} from "@addresses/Addresses.sol";

import {MockMultisigProposal} from "@mocks/MockMultisigProposal.sol";
import {MultisigProposal} from "@proposals/MultisigProposal.sol";

contract MultisigProposalIntegrationTest is Test {
    Addresses public addresses;
    MultisigProposal public proposal;

    function setUp() public {
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 1;

        // Instantiate the Addresses contract
        addresses = new Addresses("./addresses", chainIds);
        vm.makePersistent(address(addresses));

        // Instantiate the MultisigProposal contract
        proposal = MultisigProposal(new MockMultisigProposal());

        proposal.setPrimaryForkId(vm.createSelectFork("mainnet"));

        // Set the addresses contract
        proposal.setAddresses(addresses);
    }

    function test_setUp() public view {
        assertEq(
            proposal.name(),
            string("OPTMISM_MULTISIG_MOCK"),
            "Wrong proposal name"
        );
        assertEq(
            proposal.description(),
            string("Mock proposal that upgrade the L1 NFT Bridge"),
            "Wrong proposal description"
        );
    }

    function test_deploy() public {
        vm.startPrank(addresses.getAddress("DEPLOYER_EOA"));
        proposal.deploy();
        vm.stopPrank();

        assertTrue(
            addresses.isAddressSet("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION")
        );
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

        // check that the proposal targets are correct
        assertEq(targets.length, 1, "Wrong targets length");
        assertEq(
            targets[0],
            addresses.getAddress("OPTIMISM_PROXY_ADMIN"),
            "Wrong target at index 0"
        );

        // check that the proposal values are correct
        assertEq(values.length, 1, "Wrong values length");
        assertEq(values[0], 0, "Wrong value at index 0");

        // check that the proposal calldatas are correct
        assertEq(calldatas.length, 1);
        assertEq(
            calldatas[0],
            abi.encodeWithSignature(
                "upgrade(address,address)",
                addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_PROXY"),
                addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION")
            ),
            "Wrong calldata at index 0"
        );
    }

    function test_simulate() public {
        test_build();

        proposal.simulate();

        proposal.validate();
    }

    function test_getCalldata() public {
        test_build();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = proposal.getProposalActions();

        bytes memory encodedTxs;

        for (uint256 i = 0; i < targets.length; i++) {
            uint8 operation = 0;
            address to = targets[i];
            uint256 value = values[i];
            bytes memory callData = calldatas[i];

            encodedTxs = bytes.concat(
                encodedTxs,
                abi.encodePacked(
                    operation, to, value, uint256(callData.length), callData
                )
            );
        }

        bytes memory expectedData =
            abi.encodeWithSignature("multiSend(bytes)", encodedTxs);

        bytes memory data = proposal.getCalldata();

        assertEq(data, expectedData, "Wrong multiSend calldata");
    }

    function test_getProposalId() public {
        vm.expectRevert("Not implemented");
        proposal.getProposalId();
    }
}
