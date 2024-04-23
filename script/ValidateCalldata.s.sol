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

        uint256 proposalId = vm.parseUint(vm.prompt("Proposal id"));

        (uint256 id, , , , , , , , , ) = governor.proposals(proposalId);

        string memory proposalPath = vm.prompt("Proposal path");

        Proposal proposal = Proposal(deployCode(proposalPath));
        vm.makePersistent(address(proposal));

        proposal.run(false, false, true, false, false, false, false);

        proposal.getCalldata();

        (
            address[] memory targets,
            uint[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        ) = governor.getActions(id);

        bytes memory data = abi.encodeWithSignature(
            "propose(address[],uint256[],string[],bytes[],string)",
            targets,
            values,
            signatures,
            calldatas,
            proposal.description()
        );

        //console.logBytes(data);
        for (uint256 i = 0; i < calldatas.length; i++) {
            console.log("targets on chain: ", targets[i]);
            console.log("values on chain: ", values[i]);
            console.log("signatures on chain: ", signatures[i]);
            console.logBytes(calldatas[i]);
        }

        assertEq(proposal.getCalldata(), data);
    }
}
