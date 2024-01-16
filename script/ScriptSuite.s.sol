pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {IProposal} from "@proposals/IProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

contract ScriptSuite is Script {
    IProposal proposal;
    Addresses addresses;

    constructor(string memory ADDRESS_PATH, IProposal _proposal) {
        addresses = new Addresses(ADDRESS_PATH);
        proposal = _proposal;
    }

    function run() public virtual {
        proposal.run(addresses, msg.sender);

        console.log("Addresses added after running proposals:");
        (
            string[] memory recordedNames,
            ,
            address[] memory recordedAddresses
        ) = addresses.getRecordedAddresses();
        for (uint256 j = 0; j < recordedNames.length; j++) {
            console.log(recordedNames[j], recordedAddresses[j]);
        }
    }
}
