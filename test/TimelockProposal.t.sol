// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";

import {Addresses} from "@addresses/Addresses.sol";
import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {MockTimelockProposal} from "@mocks/MockTimelockProposal.sol";
import {ITimelockController} from "@interface/ITimelockController.sol";

contract TimelockProposalIntegrationTest is Test {
    Addresses public addresses;
    TimelockProposal public proposal;

    function setUp() public {
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 1;

        // Instantiate the Addresses contract
        addresses = new Addresses("./addresses", chainIds);
        vm.makePersistent(address(addresses));

        // Instantiate the TimelockProposal contract
        proposal = TimelockProposal(new MockTimelockProposal());

        proposal.setPrimaryForkId(vm.createSelectFork("mainnet"));

        // Set the addresses contract
        proposal.setAddresses(addresses);

        // Set the timelock address
        proposal.setTimelock(addresses.getAddress("ARBITRUM_L1_TIMELOCK"));
    }

    function test_setUp() public view {
        assertEq(
            proposal.name(),
            string("ARBITRUM_L1_TIMELOCK_MOCK"),
            "Wrong proposal name"
        );
        assertEq(
            proposal.description(),
            string("Mock proposal that upgrades the weth gateway"),
            "Wrong proposal description"
        );
    }

    function test_deploy() public {
        vm.startPrank(addresses.getAddress("DEPLOYER_EOA"));
        proposal.deploy();
        vm.stopPrank();

        // calls after deploy mock to mock arbitrum outbox contract
        proposal.preBuildMock();

        assertTrue(
            addresses.isAddressSet("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION")
        );
        assertTrue(addresses.isAddressSet("ARBITRUM_GAC_UPGRADE_WETH_GATEWAY"));
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
            addresses.getAddress("ARBITRUM_L1_UPGRADE_EXECUTOR"),
            "Wrong target at index 0"
        );

        // check that the proposal values are correct
        assertEq(values.length, 1, "Wrong values length");
        assertEq(values[0], 0, "Wrong value at index 0");

        bytes memory innerCalldata = abi.encodeWithSignature(
            "upgradeWethGateway(address,address,address)",
            addresses.getAddress("ARBITRUM_L1_PROXY_ADMIN"),
            addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_PROXY"),
            addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION")
        );
        // check that the proposal calldatas are correct
        assertEq(calldatas.length, 1);
        assertEq(
            calldatas[0],
            abi.encodeWithSignature(
                "execute(address,bytes)",
                addresses.getAddress("ARBITRUM_GAC_UPGRADE_WETH_GATEWAY"),
                innerCalldata
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

        bytes32 salt = keccak256(abi.encode(proposal.description()));
        uint256 delay = ITimelockController(
            payable(addresses.getAddress("ARBITRUM_L1_TIMELOCK"))
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

    function test_getProposalId() public {
        test_simulate();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = proposal.getProposalActions();

        bytes32 salt = keccak256(abi.encode(proposal.description()));

        bytes32 hash = ITimelockController(
            payable(addresses.getAddress("ARBITRUM_L1_TIMELOCK"))
        ).hashOperationBatch(targets, values, calldatas, bytes32(0), salt);

        assertEq(proposal.getProposalId(), uint256(hash));
    }
}
