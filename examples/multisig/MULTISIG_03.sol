pragma solidity 0.8.19;

import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {SimpleContract} from "@examples/SimpleContract.sol";

// MULTISIG_03: A proposal contract for manipulating two mock contracts.
contract MULTISIG_03 is MultisigProposal {

    // Returns the name of the proposal.
    function name() public pure override returns(string memory) {
	return "MULTISIG_03";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns(string memory) {
	return "Multisig proposal mock";
     }
    
    // Sets up actions for the proposal, marking the mock contracts as active.
    function _build(Addresses addresses) internal override {
	address mock1 = addresses.getAddress("MOCK_3");
	_pushAction(mock1, abi.encodeWithSignature("setActive(bool)", true), "Set active to true");

	address mock2 = addresses.getAddress("MOCK_4");
	_pushAction(mock2, abi.encodeWithSignature("setActive(bool)", true), "Set active to true");
    }

    // Executes the proposal actions. 
    function _run(Addresses addresses, address) internal override {
	address multisig = addresses.getAddress("DEV_MULTISIG");

	_simulateActions(multisig);
    }

    // Validates the post-execution state of the mock contracts.
    function _validate(Addresses addresses, address) internal override {
	SimpleContract mock1 = SimpleContract(addresses.getAddress("MOCK_3"));
	assertTrue(mock1.active());

	SimpleContract mock2 = SimpleContract(addresses.getAddress("MOCK_4"));
	assertTrue(mock2.active());
    }
}
