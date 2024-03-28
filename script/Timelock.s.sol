pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";
import {TIMELOCK_01} from "@examples/timelock/TIMELOCK_01.sol";
import {Constants} from "@utils/Constants.sol";
import {IProposal} from "@proposals/IProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

// @notice TimelockScript is a script that run TIMELOCK_01 proposal
// TIMELOCK_01 proposal deploys a Vault contract and an ERC20 token contract
// Then the proposal transfers ownership of both Vault and ERC20 to the timelock address
// Finally the proposal whitelist the ERC20 token in the Vault contract
// @dev Use this script to simulates or run a single proposal
// Use this as a template to create your own script
// `forge script script/Timelock.s.sol:TimelockScript -vvvv --rpc-url {rpc} --broadcast --verify --etherscan-api-key {key}`
contract TimelockScript is Script {
    IProposal proposal;

    constructor() {
        proposal = new TIMELOCK_01();
    }

    function run() public {
        Addresses addresses = proposal.addresses();

        // Verify if the timelock address is a contract; if is not (e.g. running on a empty blockchain node), deploy a new TimelockController and update the address.
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        uint256 timelockSize;
        assembly {
            // retrieve the size of the code, this needs assembly
            timelockSize := extcodesize(timelock)
        }
        if (timelockSize == 0) {
            // Get proposer and executor addresses
            address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
            address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

            // Create arrays of addresses to pass to the TimelockController constructor
            address[] memory proposers = new address[](1);
            proposers[0] = proposer;
            address[] memory executors = new address[](1);
            executors[0] = executor;

            // Deploy a new TimelockController
            TimelockController timelockController = new TimelockController(
                10_000,
                proposers,
                executors,
                address(0)
            );
            // Update PROTOCOL_TIMELOCK address
            addresses.changeAddress(
                "PROTOCOL_TIMELOCK",
                address(timelockController),
                true
            );

            proposal.setDebug(true);

            // Execute proposal
            proposal.run();
        }
    }
}
