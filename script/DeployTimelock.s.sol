pragma solidity ^0.8.0;

import "@forge-std/Script.sol";

import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";

import {Proposal} from "@proposals/Proposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

contract DeployTimelock is Script {
    function run() public virtual {
        Addresses addresses = new Addresses("./addresses/Addresses.json");

        // Get proposer and executor addresses
        address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
        address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

        // Create arrays of addresses to pass to the TimelockController constructor
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](1);
        executors[0] = executor;

        vm.startBroadcast();
        // Deploy a new TimelockController
        TimelockController timelockController = new TimelockController(
                                                                       60,
                                                                       proposers,
                                                                       executors,
                                                                       address(0)
        );
        vm.stopBroadcast();

        // Add PROTOCOL_TIMELOCK address
        addresses.addAddress(
                             "PROTOCOL_TIMELOCK",
                             address(timelockController),
                             true
        );
    }
}
