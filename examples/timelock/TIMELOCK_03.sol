pragma solidity 0.8.19;

import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";

// Mock proposal that withdraws MockToken from Vault.
contract TIMELOCK_03 is TimelockProposal {

    // Returns the name of the proposal.
    function name() public pure override returns(string memory) {
	return "TIMELOCK_PROPOSAL_MOCK";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns(string memory) {
	return "Withdraw tokens from Vault";
    }

    // Sets up actions for the proposal, in this case, withdrawing MockToken into Vault.
    function _build(Addresses addresses) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	address timelockVault= addresses.getAddress("VAULT");
	address token = addresses.getAddress("TOKEN_1");
	uint256 balance = MockToken(token).balanceOf(address(timelockVault));
	_pushAction(timelockVault, abi.encodeWithSignature("withdraw(address,address,uint256)", token, timelock, balance), "Withdraw tokens from Vault");
    }

    // Executes the proposal actions.
    function _run(Addresses addresses, address) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
	address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

	// Simulate time passing, vault time lock is 1 week
	vm.warp(block.timestamp + 1 weeks + 1);

        _simulateActions(timelock, proposer, executor);
    }

    // Validates the post-execution state.
    function _validate(Addresses addresses, address) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
	MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

	assertEq(timelockVault.owner(), timelock);
        assertTrue(timelockVault.tokenWhitelist(address(token)));
	assertFalse(timelockVault.paused());

	assertEq(token.owner(), timelock);
	assertEq(token.balanceOf(address(timelockVault)), 0);
	assertEq(token.balanceOf(timelock), 10_000_000e18);
    }
}
