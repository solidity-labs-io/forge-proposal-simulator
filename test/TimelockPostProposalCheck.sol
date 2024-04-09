pragma solidity ^0.8.0;

import "@forge-std/Test.sol";

import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";

import {Proposal} from "@proposals/Proposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

// @notice this is a helper contract to execute a proposal before running integration tests.
// @dev should be inherited by integration test contracts.
contract TimelockPostProposalCheck is Test {
    Proposal public proposal;
    Addresses public addresses;

    function setUp() public virtual {
        require(
            address(proposal) != address(0),
            "Test must override setUp and set the proposal contract"
        );
        addresses = proposal.addresses();

        // Verify if the timelock address is a contract; if is not (e.g. running on a empty blockchain node), deploy a new TimelockController and update the address.
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        uint256 timelockSize;
        assembly {
            // retrieve the size of the code, this needs assembly
            timelockSize := extcodesize(timelock)
        }
        if (timelockSize == 0) {
            // Get proposer and executor addresses
            address dev = addresses.getAddress("DEV");

            // Create arrays of addresses to pass to the TimelockController constructor
            address[] memory proposers = new address[](1);
            proposers[0] = dev;
            address[] memory executors = new address[](1);
            executors[0] = dev;

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
        }

        proposal.run();
    }
}
