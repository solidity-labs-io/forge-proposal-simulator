pragma solidity 0.8.19;

import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {SimpleContract} from "@examples/SimpleContract.sol";
import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";

// Mock proposal that sets the active state of two mock contracts to true.
contract TIMELOCK_03 is TimelockProposal {

    // Returns the name of the proposal.
    function name() public pure override returns(string memory) {
	return "TIMELOCK_PROPOSAL_MOCK";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns(string memory) {
	return "Timelock proposal mock";
     }
	
    // Sets up actions for the proposal, marking the mock contracts as active.
    function _build(Addresses addresses) internal override {
	address mock1 = addresses.getAddress("MOCK_1");
	_pushAction(mock1, abi.encodeWithSignature("setActive(bool)", true), "Set deployed to true");

	address mock2 = addresses.getAddress("MOCK_2");
	_pushAction(mock2, abi.encodeWithSignature("setActive(bool)", true), "Set deployed to true");
    }

    // Executes the proposal actions.
    function _run(Addresses addresses, address) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
	address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

	_simulateActions(timelock, proposer, executor);
    }

    // Validates the post-execution state of the mock contracts.
    function _validate(Addresses addresses, address) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	SimpleContract mock1 = SimpleContract(addresses.getAddress("MOCK_1"));
	assertEq(mock1.owner(), timelock);
	assertTrue(mock1.active());

	SimpleContract mock2 = SimpleContract(addresses.getAddress("MOCK_2"));
	assertEq(mock2.owner(), timelock);
	assertTrue(mock2.active());
    }
}
