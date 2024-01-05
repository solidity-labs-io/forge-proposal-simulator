pragma solidity 0.8.19;

import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Vault} from "@examples/Vault.sol";
import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";
import {MockToken} from "@examples/MockToken.sol";

// Mock proposal that deposits MockToken into Vault.
contract TIMELOCK_02 is TimelockProposal {

    // Returns the name of the proposal.
    function name() public pure override returns(string memory) {
	return "TIMELOCK_02";
    }
    // Provides a brief description of the proposal.
    function description() public pure override returns(string memory) {
	return "Deposit MockToken into Vault";
    }

    // Sets up actions for the proposal, in this case, depositing MockToken into Vault.
    function _build(Addresses addresses) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	address timelockVault= addresses.getAddress("VAULT");
	address token = addresses.getAddress("TOKEN_1");
	uint256 balance = MockToken(token).balanceOf(address(timelock));
	_pushAction(token, abi.encodeWithSignature("approve(address,uint256)", timelockVault, balance), "Approve MockToken for Vault");
	_pushAction(timelockVault, abi.encodeWithSignature("deposit(address,uint256)", token, balance), "Deposit MockToken into Vault");
    }

    // Executes the proposal actions.
    function _run(Addresses addresses, address) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
	address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

        _simulateActions(timelock, proposer, executor);
    }

    // Validates the post-execution state
    function _validate(Addresses addresses, address) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
	MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

	assertEq(timelockVault.owner(), timelock);
        assertTrue(timelockVault.tokenWhitelist(address(token)));
	assertFalse(timelockVault.paused());

	assertEq(token.owner(), timelock);
	assertEq(token.balanceOf(address(timelockVault)), token.totalSupply());
    }
}
