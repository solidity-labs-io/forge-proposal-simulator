pragma solidity 0.8.19;

import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Vault} from "@examples/Vault.sol";
import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";

// Mock proposal that deploys two Vault instances and transfers ownership to the timelock.
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
	Vault mock3 = new Vault();
	Vault mock4 = new Vault();

	addresses.addAddress("MOCK_3", address(mock3));
	addresses.addAddress("MOCK_4", address(mock4));
    }

    // Transfers ownership of the mock contracts to the timelock.
    function _afterDeploy(Addresses addresses, address) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	Vault mock3 = Vault(addresses.getAddress("MOCK_3"));
	Vault mock4 = Vault(addresses.getAddress("MOCK_4"));				      

	mock3.transferOwnership(timelock);
	mock4.transferOwnership(timelock);
    }
	
    // Validates the post-execution state of the mock contracts.
    function _validate(Addresses addresses, address) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	Vault mock3 = Vault(addresses.getAddress("MOCK_3"));
	assertEq(mock3.owner(), timelock);

	Vault mock4 = Vault(addresses.getAddress("MOCK_4"));
	assertEq(mock4.owner(), timelock);
    }
}
