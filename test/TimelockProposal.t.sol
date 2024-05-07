// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";
import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";
import {ITimelockController} from "@interfaces/ITimelockController.sol";

import {Addresses} from "@addresses/Addresses.sol";
import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {Vault} from "@mocks/Vault.sol";
import {Token} from "@mocks/Token.sol";
import {MockTimelockProposal} from "@mocks/MockTimelockProposal.sol";

contract TimelockProposalUnitTest is Test {
    Addresses public addresses;
    TimelockProposal public proposal;

    function setUp() public {
        // Instantiate the Addresses contract
        addresses = new Addresses("./addresses/Addresses.json");
        vm.makePersistent(address(addresses));

        // Instantiate the TimelockProposal contract
        proposal = TimelockProposal(new MockTimelockProposal());

        // Set the addresses contract
        proposal.setAddresses(addresses);

        // Set the timelock address
        proposal.setTimelock(addresses.getAddress("PROTOCOL_TIMELOCK"));
    }

    function test_deploy() public {
        vm.startPrank(addresses.getAddress("DEPLOYER_EOA"));
        proposal.deploy();
        vm.stopPrank();

        address expectedOwner = addresses.getAddress("PROTOCOL_TIMELOCK");

        // check that the vault was deployed
        assertTrue(addresses.isAddressSet("VAULT"));
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        assertEq(timelockVault.owner(), expectedOwner, "Wrong owner");

        // check that the token was deployed
        assertTrue(addresses.isAddressSet("TOKEN_1"));
        Token token = Token(addresses.getAddress("TOKEN_1"));
        assertEq(token.owner(), expectedOwner, "Wrong owner");
        assertEq(
            token.balanceOf(expectedOwner),
            token.totalSupply(),
            "Wrong token balance"
        );
    }

    function test_setUp() public {
        test_deploy();

        assertEq(
            proposal.name(),
            string("TIMELOCK_MOCK"),
            "Wrong proposal name"
        );
        assertEq(
            proposal.description(),
            string("Timelock proposal mock"),
            "Wrong proposal description"
        );
        assertEq(
            address(proposal.timelock()),
            addresses.getAddress("PROTOCOL_TIMELOCK"),
            "Wrong timelock address"
        );
    }

    function test_build() public {
        vm.expectRevert("No actions found");
        proposal.getProposalActions();

        Token token = Token(addresses.getAddress("TOKEN_1"));

        uint256 expectedBalance = token.balanceOf(
            addresses.getAddress("PROTOCOL_TIMELOCK")
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
            addresses.getAddress("VAULT"),
            "Wrong target at index 0"
        );
        assertEq(
            targets[1],
            addresses.getAddress("TOKEN_1"),
            "Wrong target at index 1"
        );
        assertEq(
            targets[2],
            addresses.getAddress("VAULT"),
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
                addresses.getAddress("TOKEN_1"),
                true
            ),
            "Wrong calldata at index 0"
        );
        assertEq(
            calldatas[1],
            abi.encodeWithSignature(
                "approve(address,uint256)",
                addresses.getAddress("VAULT"),
                expectedBalance
            ),
            "Wrong calldata at index 1"
        );
        assertEq(
            calldatas[2],
            abi.encodeWithSignature(
                "deposit(address,uint256)",
                addresses.getAddress("TOKEN_1"),
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
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        Token token = Token(addresses.getAddress("TOKEN_1"));

        assertEq(
            timelockVault.owner(),
            addresses.getAddress("PROTOCOL_TIMELOCK"),
            "Wrong owner"
        );

        assertTrue(
            timelockVault.tokenWhitelist(addresses.getAddress("TOKEN_1")),
            "Token not whitelisted"
        );

        assertEq(
            token.balanceOf(addresses.getAddress("VAULT")),
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

        bytes32 salt = keccak256(abi.encode(proposal.description()));
        uint256 delay = TimelockController(
            payable(addresses.getAddress("PROTOCOL_TIMELOCK"))
        ).getMinDelay();

        bytes memory expectedData = abi.encodeWithSignature(
            "scheduleBatch(address[],uint256[],bytes[],bytes32,bytes32,uint256)",
            targets,
            values,
            calldatas,
            bytes32(0),
            salt,
            delay
        );

        bytes memory data = proposal.getCalldata();

        assertEq(data, expectedData, "Wrong scheduleBatch calldata");
    }

    function test_getExecuteCalldata() public {
        test_build();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = proposal.getProposalActions();

        bytes32 salt = keccak256(abi.encode(proposal.description()));

        bytes memory expectedData = abi.encodeWithSignature(
            "executeBatch(address[],uint256[],bytes[],bytes32,bytes32)",
            targets,
            values,
            calldatas,
            bytes32(0),
            salt
        );

        bytes memory data = proposal.getExecuteCalldata();

        assertEq(data, expectedData, "Wrong executeBatch calldata");
    }
}
