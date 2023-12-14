pragma solidity 0.8.19;

import {Proposal} from "./Proposal.sol";
import {OwnerManager} from "@safe/base/OwnerManager.sol";
import {Addresses} from "@addresses/Addresses.sol";

contract MultisigProposal is Proposal {
    Addresses public addresses;

    constructor(string memory addressesPath) {
        addresses = new Addresses(addressesPath);
    }

    function run() public override {
        // Get owners of the multisig
        address[] memory owners = OwnerManager(executor).getOwners();

        _simulateActions();
    }

    function teardow() public override {}

    function validate() public override {}

}
