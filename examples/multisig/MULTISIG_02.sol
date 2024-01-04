pragma solidity 0.8.19;

import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {SimpleContract} from "@examples/SimpleContract.sol";

// MULTISIG_02: A proposal contract for deploying two mock contracts.
contract MULTISIG_02 is MultisigProposal {

    // Returns the name of the proposal.
    function name() public pure override returns(string memory) {
	return "MULTISIG_02";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns(string memory) {
	return "Multisig proposal mock";
     }
    
    // Deploys two mock contracts and registers their addresses.
    function _deploy(Addresses addresses, address) internal override {
	SimpleContract mock3 = new SimpleContract();
	SimpleContract mock4 = new SimpleContract();

	address devMultisig = addresses.getAddress("DEV_MULTISIG");
	mock3.transferOwnership(devMultisig);
	mock4.transferOwnership(devMultisig);

	addresses.addAddress("MOCK_3", address(mock3));
	addresses.addAddress("MOCK_4", address(mock4));
    }

    // Executes the proposal actions. If the multisig address is not a contract, it deploys a new Safe contract.
    function _run(Addresses addresses, address) internal override {
	address multisig = addresses.getAddress("DEV_MULTISIG");

	// call etch on multisig address to pretend it is a contract
	_simulateActions(multisig);
    }

    // Validates the post-execution state of the mock contracts.
    function _validate(Addresses addresses, address) internal override {
	SimpleContract mock1 = SimpleContract(addresses.getAddress("MOCK_3"));
	assertFalse(mock1.active());

	SimpleContract mock2 = SimpleContract(addresses.getAddress("MOCK_4"));
	assertFalse(mock2.active());
    }
}
