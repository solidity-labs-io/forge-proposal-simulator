pragma solidity 0.8.19;

import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {SimpleContract} from "@examples/SimpleContract.sol";

// Mock proposal that deploys two SimpleContract instances and transfers ownership to the dev multisig.
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

	addresses.addAddress("MOCK_3", address(mock3));
	addresses.addAddress("MOCK_4", address(mock4));
    }

    // Transfers ownership of the mock contracts to the dev multisig.
    function _afterDeploy(Addresses addresses, address) internal override {
	address devMultisig = addresses.getAddress("DEV_MULTISIG");
	SimpleContract mock3 = SimpleContract(addresses.getAddress("MOCK_3"));
	SimpleContract mock4 = SimpleContract(addresses.getAddress("MOCK_4"));
	mock3.transferOwnership(devMultisig);
	mock4.transferOwnership(devMultisig);
    }

    // Executes the proposal actions. 
    function _run(Addresses addresses, address) internal override {
	address multisig = addresses.getAddress("DEV_MULTISIG");

	_simulateActions(multisig);
    }

    // Validates the post-execution state of the mock contracts.
    function _validate(Addresses addresses, address) internal override {
	address devMultisig = addresses.getAddress("DEV_MULTISIG");
	SimpleContract mock1 = SimpleContract(addresses.getAddress("MOCK_3"));
	assertEq(mock1.owner(), devMultisig);
	assertFalse(mock1.active());

	SimpleContract mock2 = SimpleContract(addresses.getAddress("MOCK_4"));
	assertEq(mock2.owner(), devMultisig);
	assertFalse(mock2.active());
    }
}
