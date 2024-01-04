pragma solidity 0.8.19;

import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {SimpleContract} from "@examples/SimpleContract.sol";
import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";

// Mock proposal that deploys two SimpleContract instances and transfers ownership to the timelock.
contract TIMELOCK_02 is TimelockProposal {

    // Returns the name of the proposal.
    function name() public pure override returns(string memory) {
	return "TIMELOCK_PROPOSAL_MOCK";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns(string memory) {
	return "Timelock proposal mock";
     }
    
    // Deploys two mock contracts and registers their addresses.
    function _deploy(Addresses addresses, address) internal override {
	SimpleContract mock3 = new SimpleContract();
	SimpleContract mock4 = new SimpleContract();

	addresses.addAddress("MOCK_3", address(mock3));
	addresses.addAddress("MOCK_4", address(mock4));
    }

    // Transfers ownership of the mock contracts to the timelock.
    function _afterDeploy(Addresses addresses, address) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	SimpleContract mock3 = SimpleContract(addresses.getAddress("MOCK_3"));
	SimpleContract mock4 = SimpleContract(addresses.getAddress("MOCK_4"));				      

	mock3.transferOwnership(timelock);
	mock4.transferOwnership(timelock);
    }
	
    // Validates the post-execution state of the mock contracts.
    function _validate(Addresses addresses, address) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	SimpleContract mock3 = SimpleContract(addresses.getAddress("MOCK_3"));
	assertEq(mock3.owner(), timelock);
	assertFalse(mock3.active());

	SimpleContract mock4 = SimpleContract(addresses.getAddress("MOCK_4"));
	assertEq(mock4.owner(), timelock);
	assertFalse(mock4.active());
    }
}
