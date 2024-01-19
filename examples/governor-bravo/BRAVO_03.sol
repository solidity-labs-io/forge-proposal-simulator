pragma solidity ^0.8.0;

import {GovernorBravoProposal} from "@proposals/GovernorBravoProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";

// Mock proposal that withdraws MockToken from Vault.
contract BRAVO_03 is GovernorBravoProposal {
    // Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "BRAVO_03";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Withdraw tokens from Vault";
    }

    // Sets up actions for the proposal, in this case, withdrawing MockToken into Vault.
    function _build(Addresses addresses) internal override {
        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");
        uint256 balance = MockToken(token).balanceOf(address(timelockVault));
        _pushAction(
            timelockVault,
            abi.encodeWithSignature(
                "withdraw(address,address,uint256)",
                token,
                governor,
                balance
            ),
            "Withdraw tokens from Vault"
        );
    }

    // Executes the proposal actions.
    function _run(Addresses addresses, address) internal override {
        // Call parent _run function to check if there are actions to execute
        super._run(addresses, address(0));

        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");
        address govToken = addresses.getAddress("PROTOCOL_GOVERNANCE_TOKEN");
        address proposer = addresses.getAddress("BRAVO_PROPOSER");

        // Simulate time passing, vault time lock is 1 week
        vm.warp(block.timestamp + 1 weeks + 1);

        _simulateActions(governor, proposer, govToken);
    }

    // Validates the post-execution state.
    function _validate(Addresses addresses, address) internal override {
        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        (uint256 amount, ) = timelockVault.deposits(address(token), governor);
        assertEq(amount, 0);
        assertEq(timelockVault.owner(), governor);
        assertTrue(timelockVault.tokenWhitelist(address(token)));
        assertFalse(timelockVault.paused());

        assertEq(token.owner(), governor);
        assertEq(token.balanceOf(address(timelockVault)), 0);
        assertEq(token.balanceOf(governor), 10_000_000e18);
    }
}
