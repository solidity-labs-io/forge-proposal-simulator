pragma solidity ^0.8.0;

import "@forge-std/Script.sol";

import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";

import {Addresses} from "@addresses/Addresses.sol";

contract DeployTimelock is Script {
    function run() public virtual {
        Addresses addresses = new Addresses("./addresses/Addresses.json");

        // Get proposer and executor addresses
        address dev = addresses.getAddress("DEPLOYER_EOA");

        // Create arrays of addresses to pass to the TimelockController constructor
        address[] memory proposers = new address[](1);
        proposers[0] = dev;
        address[] memory executors = new address[](1);
        executors[0] = dev;

        vm.startBroadcast();
        // Deploy a new TimelockController
        TimelockController timelockController = new TimelockController(
            60,
            proposers,
            executors,
            address(0)
        );
        vm.stopBroadcast();

        // Change PROTOCOL_TIMELOCK address
        addresses.changeAddress(
            "PROTOCOL_TIMELOCK",
            address(timelockController),
            true
        );

        addresses.printJSONChanges();
    }
}
