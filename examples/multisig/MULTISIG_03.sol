pragma solidity 0.8.19;

import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";

// Mock proposal that withdraw tokens from Vault
contract MULTISIG_03 is MultisigProposal {

    // Returns the name of the proposal.
    function name() public pure override returns(string memory) {
        return "MULTISIG_03";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns(string memory) {
	return "Withdraw tokens from Vault";
    }

    // Sets up actions for the proposal, in this case, withdrawing MockToken into Vault.
    function _build(Addresses addresses) internal override {
	address devMultisig = addresses.getAddress("DEV_MULTISIG");
	address timelockVault= addresses.getAddress("VAULT");
	address token = addresses.getAddress("TOKEN_1");
	uint256 balance = MockToken(token).balanceOf(address(timelockVault));
	_pushAction(timelockVault, abi.encodeWithSignature("withdraw(address,address,uint256)", token, devMultisig, balance), "Deposit MockToken into Vault");
    }

    // Executes the proposal actions.
    function _run(Addresses addresses, address) internal override {
        address multisig = addresses.getAddress("DEV_MULTISIG");

	// Simulate time passing, vault time lock is 1 week
	vm.warp(block.timestamp + 1 weeks + 1);

        _simulateActions(multisig);
    }

    // Validates the post-execution state.
    function _validate(Addresses addresses, address) internal override {
	address devMultisig = addresses.getAddress("DEV_MULTISIG");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
	MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

	assertEq(timelockVault.owner(), devMultisig);
        assertTrue(timelockVault.tokenWhitelist(address(token)));
	assertFalse(timelockVault.paused());

	assertEq(token.owner(), devMultisig);
	assertEq(token.balanceOf(address(timelockVault)), 0);
	assertEq(token.balanceOf(devMultisig), 10_000_000e18);
    }
}
