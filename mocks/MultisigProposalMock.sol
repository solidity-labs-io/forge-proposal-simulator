pragma solidity 0.8.19;

import {MultisigProposal} from "@proposals/proposalTypes/MultisigProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

contract MultisigProposalMock is MultisigProposal {

    function name() public pure override returns(string memory) {
	return "MULTISIG_PROPOSAL_MOCK_01";
    }
    
    function _run(Addresses addresses, address) internal override {
	address multisig = addresses.getAddress("DEV_MULTISIG");

	// call etch on multisig address to pretend it is a contract
	vm.etch(multisig, "0x01");
	_simulateActions(multisig);
    }
}
