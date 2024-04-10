pragma solidity ^0.8.0;

import "@forge-std/Script.sol";

import {GovernorBravoDelegator} from "@comp-governance/GovernorBravoDelegator.sol";

import {Addresses} from "@addresses/Addresses.sol";

import {MockERC20Votes} from "@mocks/MockERC20Votes.sol";
import {Timelock} from "@mocks/bravo/Timelock.sol";
import {GovernorBravoDelegate} from "@mocks/bravo/GovernorBravoDelegate.sol";

contract DeployGovernorBravo is Script {
    function run() public virtual {
        Addresses addresses = new Addresses("./addresses/Addresses.json");

        vm.startBroadcast();
        // Deploy and configure the timelock
        Timelock timelock = new Timelock(msg.sender, 1);

        // Deploy the governance token
        MockERC20Votes govToken = new MockERC20Votes("Governance Token", "GOV");

        govToken.mint(msg.sender, 1e21);

        // Deploy the GovernorBravoDelegate implementation
        GovernorBravoDelegate implementation = new GovernorBravoDelegate();

        // Deploy and configure the GovernorBravoDelegator
        GovernorBravoDelegator governor = new GovernorBravoDelegator(
            address(timelock), // timelock
            address(govToken), // governance token
            msg.sender, // admin
            address(implementation), // implementation
            10_000, // voting period
            10_000, // voting delay
            1e21 // proposal threshold
        );

        timelock.queueTransaction(
            address(timelock),
            0,
            "",
            abi.encodeWithSignature(
                "setPendingAdmin(address)",
                address(governor)
            ),
            block.timestamp + 120
        );

        vm.stopBroadcast();

        // Update PROTOCOL_GOVERNOR address
        addresses.changeAddress("PROTOCOL_GOVERNOR", address(governor), true);

        // Update PROTOCOL_TIMELOCK address
        addresses.changeAddress("PROTOCOL_TIMELOCK", address(timelock), true);

        addresses.changeAddress(
            "PROTOCOL_GOVERNANCE_TOKEN",
            address(govToken),
            true
        );

        addresses.printRecordedAddresses();
    }
}
