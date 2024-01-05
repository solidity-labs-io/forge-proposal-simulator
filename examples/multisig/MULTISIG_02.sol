pragma solidity 0.8.19;

import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";

// Mock proposal that deposit MockToken into Vault.
contract MULTISIG_02 is MultisigProposal {

    // Returns the name of the proposal.
    function name() public pure override returns(string memory) {
        return "MULTISIG_02";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns(string memory) {
	return "Deposit MockToken into Vault";
    }

    // Sets up actions for the proposal, in this case, depositing MockToken into Vault.
    function _build(Addresses addresses) internal override {
	address devMultisig = addresses.getAddress("DEV_MULTISIG");
	address timelockVault= addresses.getAddress("VAULT");
	address token = addresses.getAddress("TOKEN_1");
	uint256 balance = MockToken(token).balanceOf(address(devMultisig));
	_pushAction(token, abi.encodeWithSignature("approve(address,uint256)", timelockVault, balance), "Approve MockToken for Vault");
	_pushAction(timelockVault, abi.encodeWithSignature("deposit(address,uint256)", token, balance), "Deposit MockToken into Vault");
    }

    // Executes the proposal actions.
    function _run(Addresses addresses, address) internal override {
        address multisig = addresses.getAddress("DEV_MULTISIG");

        _simulateActions(multisig);
    }

    // Validates the post-execution state
    function _validate(Addresses addresses, address) internal override {
	address devMultisig = addresses.getAddress("DEV_MULTISIG");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
	MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

	assertEq(timelockVault.owner(), devMultisig);
        assertTrue(timelockVault.tokenWhitelist(address(token)));
	assertFalse(timelockVault.paused());

	assertEq(token.owner(), devMultisig);
	assertEq(token.balanceOf(address(timelockVault)), token.totalSupply());
    }
}
