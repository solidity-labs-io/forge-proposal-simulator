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
        proposal.setGovernor(addresses.getAddress("PROTOCOL_GOVERNOR"));
    }

    function test_setUp() public view {
        assertEq(proposal.name(), string("BRAVO_MOCK"), "Wrong proposal name");
        assertEq(
            proposal.description(),
            string("Bravo proposal mock"),
            "Wrong proposal description"
        );
        assertEq(
            address(proposal.governor()),
            addresses.getAddress("PROTOCOL_GOVERNOR"),
            "Wrong timelock address"
        );
    }

    function test_deploy() public {
        vm.startPrank(addresses.getAddress("DEPLOYER_EOA"));
        proposal.deploy();
        vm.stopPrank();

        // check that the vault was deployed
        assertTrue(addresses.isAddressSet("BRAVO_VAULT"));
        Vault timelockVault = Vault(addresses.getAddress("BRAVO_VAULT"));

        // check that the token was deployed
        assertTrue(addresses.isAddressSet("BRAVO_VAULT_TOKEN"));
        Token token = Token(addresses.getAddress("BRAVO_VAULT_TOKEN"));
        assertEq(
            token.balanceOf(addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO")),
            token.totalSupply(),
            "Wrong token balance"
        );
    }

    function test_build() public {
        test_deploy();

        vm.expectRevert("No actions found");
        proposal.getProposalActions();

        Token token = Token(addresses.getAddress("BRAVO_VAULT_TOKEN"));

        address vault = addresses.getAddress("BRAVO_VAULT");

        uint256 expectedBalance = token.balanceOf(
            addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO")
        );

        proposal.build();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = proposal.getProposalActions();

        // check that the proposal targets are correct
        assertEq(targets.length, 3, "Wrong targets length");
        assertEq(targets[0], vault, "Wrong target at index 0");
        assertEq(targets[1], address(token), "Wrong target at index 1");
        assertEq(targets[2], vault, "Wrong target at index 2");

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
                address(token),
                true
            ),
            "Wrong calldata at index 0"
        );
        assertEq(
            calldatas[1],
            abi.encodeWithSignature(
                "approve(address,uint256)",
                vault,
                expectedBalance
            ),
            "Wrong calldata at index 1"
        );
        assertEq(
            calldatas[2],
            abi.encodeWithSignature(
                "deposit(address,uint256)",
                address(token),
                expectedBalance
            ),
            "Wrong calldata at index 2"
        );
    }

    function test_simulate() public {
        test_build();

        proposal.simulate();

        // check that proposal exists
        assertTrue(proposal.checkOnChainCalldata());

        // check that the proposal actions were executed
        Vault vault = Vault(addresses.getAddress("BRAVO_VAULT"));
        Token token = Token(addresses.getAddress("BRAVO_VAULT_TOKEN"));

        assertTrue(
            vault.tokenWhitelist(address(token)),
            "Token not whitelisted"
        );

        assertEq(
            token.balanceOf(address(vault)),
            token.totalSupply(),
            "Wrong token balance"
        );
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
