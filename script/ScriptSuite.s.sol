pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {IProposal} from "@proposals/IProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

contract ScriptSuite is Script {
    IProposal proposal;
    Addresses addresses;

    constructor(string memory ADDRESS_PATH, address _proposal) {
        addresses = new Addresses(ADDRESS_PATH);
        proposal = IProposal(_proposal);
    }

    function run() external virtual {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(signerPrivateKey);
        proposal.run(addresses, msg.sender);
        vm.stopBroadcast();
    }
}
