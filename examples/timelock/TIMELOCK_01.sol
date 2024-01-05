pragma solidity 0.8.19;

import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {MockToken} from "@examples/MockToken.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Vault} from "@examples/Vault.sol";
import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";

// Mock proposal that deploys a Vault contract and an ERC20 token contract.
contract TIMELOCK_01 is TimelockProposal {

    // Returns the name of the proposal.
    function name() public pure override returns(string memory) {
	return "TIMELOCK_01";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns(string memory) {
	return "Timelock proposal mock";
     }
    
    // Deploys a vault contract and an ERC20 token contract.
    function _deploy(Addresses addresses, address) internal override {
        Vault timelockVault = new Vault();
	MockToken token = new MockToken();

        addresses.addAddress("VAULT", address(timelockVault));
	addresses.addAddress("TOKEN_1", address(token));
    }

    // Transfers vault ownership to timelock.
    // Transfer token ownership to timelock.
    // Transfers all tokens to timelock.
    function _afterDeploy(Addresses addresses, address deployer) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	Vault timelockVault = Vault(addresses.getAddress("VAULT"));
	MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

	timelockVault.transferOwnership(timelock);
	token.transferOwnership(timelock);
	token.transfer(timelock, token.balanceOf(address(deployer)));
    }

    // Sets up actions for the proposal, in this case, setting the MockToken to active.
    function _build(Addresses addresses) internal override {
        address timelockVault= addresses.getAddress("VAULT");
	address token = addresses.getAddress("TOKEN_1");
	_pushAction(timelockVault, abi.encodeWithSignature("whitelistToken(address,bool)", token, true), "Set token to active");
    }

    // Executes the proposal actions.
    function _run(Addresses addresses, address) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
	address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

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
	assertEq(token.balanceOf(timelock), token.totalSupply());
    }
}
