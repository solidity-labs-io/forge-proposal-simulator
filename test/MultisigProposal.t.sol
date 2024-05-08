// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";

import {Addresses} from "@addresses/Addresses.sol";
import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {Vault} from "@mocks/Vault.sol";
import {Token} from "@mocks/Token.sol";
import {MockMultisigProposal} from "@mocks/MockMultisigProposal.sol";

contract MultisigProposalIntegrationTest is Test {
    Addresses public addresses;
    MultisigProposal public proposal;

    struct Call {
        address target;
        bytes callData;
    }

    function setUp() public {
        // Instantiate the Addresses contract
        addresses = new Addresses("./addresses/Addresses.json");
        vm.makePersistent(address(addresses));

        // Instantiate the MultisigProposal contract
        proposal = MultisigProposal(new MockMultisigProposal());

        // Set the addresses contract
        proposal.setAddresses(addresses);
    }

    function test_setUp() public view {
        assertEq(
            proposal.name(),
            string("MULTISIG_MOCK"),
            "Wrong proposal name"
        );
        assertEq(
            proposal.description(),
            string("Multisig proposal mock"),
            "Wrong proposal description"
        );
    }

    function test_deploy() public {
        vm.startPrank(addresses.getAddress("DEPLOYER_EOA"));
        proposal.deploy();
        vm.stopPrank();

        address expectedOwner = addresses.getAddress("DEV_MULTISIG");

        // check that the vault was deployed
        assertTrue(addresses.isAddressSet("MULTISIG_VAULT"));
        Vault timelockVault = Vault(addresses.getAddress("MULTISIG_VAULT"));
        assertEq(timelockVault.owner(), expectedOwner, "Wrong owner");

        // check that the token was deployed
        assertTrue(addresses.isAddressSet("MULTISIG_TOKEN"));
        Token token = Token(addresses.getAddress("MULTISIG_TOKEN"));
        assertEq(token.owner(), expectedOwner, "Wrong owner");
        assertEq(
            token.balanceOf(expectedOwner),
            token.totalSupply(),
            "Wrong token balance"
        );
    }

    function test_build() public {
        test_deploy();

        vm.expectRevert("No actions found");
        proposal.getProposalActions();

        Token token = Token(addresses.getAddress("MULTISIG_TOKEN"));

        uint256 expectedBalance = token.balanceOf(
            addresses.getAddress("DEV_MULTISIG")
        );

        proposal.build();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = proposal.getProposalActions();

        // check that the proposal targets are correct
        assertEq(targets.length, 3, "Wrong targets length");
        assertEq(
            targets[0],
            addresses.getAddress("MULTISIG_VAULT"),
            "Wrong target at index 0"
        );
        assertEq(
            targets[1],
            addresses.getAddress("MULTISIG_TOKEN"),
            "Wrong target at index 1"
        );
        assertEq(
            targets[2],
            addresses.getAddress("MULTISIG_VAULT"),
            "Wrong target at index 2"
        );

        // check that the proposal values are correct
        assertEq(values.length, 3, "Wrong values length");
        assertEq(values[0], 0, "Wrong value at index 0");
        assertEq(values[1], 0, "Wrong value at index 1");
        assertEq(values[2], 0, "Wrong value at index 2");

        // check that the proposal calldatas are correct
        assertEq(calldatas.length, 3);
        assertEq(
            calldatas[0],
            abi.encodeWithSignature(
                "whitelistToken(address,bool)",
                addresses.getAddress("MULTISIG_TOKEN"),
                true
            ),
            "Wrong calldata at index 0"
        );
        assertEq(
            calldatas[1],
            abi.encodeWithSignature(
                "approve(address,uint256)",
                addresses.getAddress("MULTISIG_VAULT"),
                expectedBalance
            ),
            "Wrong calldata at index 1"
        );
        assertEq(
            calldatas[2],
            abi.encodeWithSignature(
                "deposit(address,uint256)",
                addresses.getAddress("MULTISIG_TOKEN"),
                expectedBalance
            ),
            "Wrong calldata at index 2"
        );
    }

    function test_simulate() public {
        test_build();

        proposal.simulate();

        // check that the proposal actions were executed
        Vault timelockVault = Vault(addresses.getAddress("MULTISIG_VAULT"));
        Token token = Token(addresses.getAddress("MULTISIG_TOKEN"));

        assertEq(
            timelockVault.owner(),
            addresses.getAddress("DEV_MULTISIG"),
            "Wrong owner"
        );

        assertTrue(
            timelockVault.tokenWhitelist(
                addresses.getAddress("MULTISIG_TOKEN")
            ),
            "Token not whitelisted"
        );

        assertEq(
            token.balanceOf(addresses.getAddress("MULTISIG_VAULT")),
            token.totalSupply(),
            "Wrong token balance"
        );
    }

    function test_getCalldata() public {
        test_build();

        (address[] memory targets, , bytes[] memory calldatas) = proposal
            .getProposalActions();

        Call[] memory calls = new Call[](targets.length);

        for (uint256 i; i < calls.length; i++) {
            calls[i] = Call({target: targets[i], callData: calldatas[i]});
        }

        bytes memory expectedData = abi.encodeWithSignature(
            "aggregate((address,bytes)[])",
            calls
        );

        bytes memory data = proposal.getCalldata();

        assertEq(data, expectedData, "Wrong scheduleBatch calldata");
    }

    function test_checkOnChainCalldata() public {
        vm.expectRevert("Not implemented");
        proposal.checkOnChainCalldata();
    }

    function test_validate() public {
        test_simulate();

        proposal.validate();
    }
}
