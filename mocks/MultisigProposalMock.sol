pragma solidity 0.8.19;

import {MultisigProposal} from "@proposals/proposalTypes/MultisigProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

contract MultisigProposalMock is MultisigProposal {
    function run(Addresses addresses, address) public override {
	address multisig = addresses.getAddress("DEV_MULTISIG");

	vm.etch(multisig, "0x01");
	_simulateActions(multisig);
    }
}
