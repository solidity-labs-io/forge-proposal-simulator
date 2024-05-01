pragma solidity ^0.8.0;

import "@forge-std/Script.sol";
import "@forge-std/Test.sol";

import {Addresses} from "@addresses/Addresses.sol";

import {MockGovernorAlpha} from "@mocks/MockGovernorAlpha.sol";
import {GovernorBravoDelegate} from "@mocks/bravo/GovernorBravoDelegate.sol";
import {GovernorBravoDelegateStorageV1} from "@comp-governance/GovernorBravoInterfaces.sol";

import {Proposal} from "@proposals/Proposal.sol";

contract ValidateCalldata is Script, Test {
    function run() public virtual {
        Addresses addresses = new Addresses("./addresses/Addresses.json");

        GovernorBravoDelegate governor = GovernorBravoDelegate(
            addresses.getAddress("PROTOCOL_GOVERNOR")
        );

        string memory proposalPath = vm.prompt("Proposal path");

        Proposal proposal = Proposal(deployCode(proposalPath));
        vm.makePersistent(address(proposal));

        proposal.build();

        bool matches = proposal.checkOnChainCalldata(address(governor));

        require(matches, "Calldata does not match on-chain proposal");
    }
}
