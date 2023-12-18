pragma solidity 0.8.19;

import {MultisigProposal} from "../proposals/proposalTypes/MultisigProposal.sol";
import {Addresses} from "../addresses/Addresses.sol;

contract MultisigProposal is MultisigProposal {
    function run(Addresses addresses, address) {
	address multisig = addresses.getAddress("DEV_MULTISIG");
	_simulateActions(multisig);
    
}
