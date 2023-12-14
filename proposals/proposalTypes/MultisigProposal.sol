pragma solidity 0.8.19;

import {Proposal} from "./Proposal.sol";
import {OwnerManager} from "@safe/base/OwnerManager.sol";
import {Addresses} from "@addresses/Addresses.sol";

contract MultisigProposal is Proposal {
    function run(Addresses addresses) public override {}

}
