pragma solidity 0.8.19;

import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Vault} from "@examples/Vault.sol";
import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";

// Mock proposal that deploys two Vault instances, transfers ownership to the timelock, and sets active to true.
contract TIMELOCK_01 is TimelockProposal {

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
	Vault mock1 = new Vault();
	Vault mock2 = new Vault();

	addresses.addAddress("MOCK_1", address(mock1));
	addresses.addAddress("MOCK_2", address(mock2));
    }

    // Transfers ownership of the mock contracts to the timelock.
    function _afterDeploy(Addresses addresses, address) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	Vault mock1 = Vault(addresses.getAddress("MOCK_1"));
	Vault mock2 = Vault(addresses.getAddress("MOCK_2"));				      

	mock1.transferOwnership(timelock);
	mock2.transferOwnership(timelock);
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
	Vault mock1 = Vault(addresses.getAddress("MOCK_1"));
	assertEq(mock1.owner(), timelock);

	Vault mock2 = Vault(addresses.getAddress("MOCK_2"));
	assertEq(mock2.owner(), timelock);
    }
}
