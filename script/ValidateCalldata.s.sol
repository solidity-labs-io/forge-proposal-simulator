pragma solidity ^0.8.0;

import "@forge-std/Script.sol";

import {Addresses} from "@addresses/Addresses.sol";

import {MockGovernorAlpha} from "@mocks/MockGovernorAlpha.sol";
import {GovernorBravoDelegate} from "@mocks/bravo/GovernorBravoDelegate.sol";
import {GovernorBravoDelegateStorageV1} from "@comp-governance/GovernorBravoInterfaces.sol";

import {Proposal} from "@proposals/Proposal.sol";

contract ValidateCalldata is Script {
    function run() public virtual {
        Addresses addresses = new Addresses("./addresses/Addresses.json");

        GovernorBravoDelegate governor = GovernorBravoDelegate(
            addresses.getAddress("PROTOCOL_GOVERNOR")
        );

        uint256 proposalId = vm.parseUint(vm.prompt("Proposal ID"));

        (uint256 id, , , , , , , , , ) = governor.proposals(proposalId);

        console.log("Proposal ID: ", id);

        string memory proposalPath = vm.prompt("Proposal path");

        Proposal proposal = Proposal(deployCode(proposalPath));
        vm.makePersistent(address(proposal));

        proposal.run();
    }
}
