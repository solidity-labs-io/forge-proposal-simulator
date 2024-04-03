pragma solidity ^0.8.0;

import "@forge-std/Script.sol";

import {GovernorBravoDelegator} from "@comp-governance/GovernorBravoDelegator.sol";

import {Proposal} from "@proposals/Proposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

import {MockGovernorAlpha} from "@mocks/MockGovernorAlpha.sol";
import {MockERC20Votes} from "@mocks/MockERC20Votes.sol";
import {Timelock} from "@mocks/bravo/Timelock.sol";
import {GovernorBravoDelegate} from "@mocks/bravo/GovernorBravoDelegate.sol";

contract DeployGovernorBravo is Script {
    function run() public virtual {
        Addresses addresses = new Addresses("./addresses/Addresses.json");

        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");

        address payable timelock = payable(
            addresses.getAddress("PROTOCOL_TIMELOCK")
        );

        uint256 eta = 1712166492;

        vm.startBroadcast();

        // Deploy mock GovernorAlpha
        address govAlpha = address(new MockGovernorAlpha());

        Timelock(timelock).executeTransaction(
            timelock,
            0,
            "",
            abi.encodeWithSignature(
                "setPendingAdmin(address)",
                address(governor)
            ),
            eta
        );

        // Initialize GovernorBravo
        GovernorBravoDelegate(governor)._initiate(govAlpha);

        vm.stopBroadcast();
    }
}
