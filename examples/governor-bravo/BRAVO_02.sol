pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {Proposal} from "@proposals/Proposal.sol";
import {MockToken} from "@examples/MockToken.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {GovernorBravoProposal} from "@proposals/GovernorBravoProposal.sol";

/// @notice Mock proposal that deposits MockToken into Vault.
contract BRAVO_02 is GovernorBravoProposal {
    /// @notice Returns the name of the proposal.
    string public override name = "BRAVO_02";

    /// @notice Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Deposit MockToken into Vault";
    }

    /// @notice Sets up actions for the proposal, in this case, depositing MockToken into Vault.
    /// @param addresses The addresses contract.
    function _build(
        Addresses addresses
    )
        internal
        override
        buildModifier(addresses.getAddress("PROTOCOL_TIMELOCK"), addresses)
    {
        /// STATICCALL -- not recorded for the run stage
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");
        uint256 balance = MockToken(token).balanceOf(address(timelock));

        /// CALLS -- mutative and recorded
        MockToken(token).approve(timelockVault, balance);
        Vault(timelockVault).deposit(token, balance);
    }

    /// @notice Executes the proposal actions.
    /// @param addresses The addresses contract.
    function _run(Addresses addresses, address) internal override {
        // Call parent _run function to check if there are actions to execute
        super._run(addresses, address(0));

        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");
        address govToken = addresses.getAddress("PROTOCOL_GOVERNANCE_TOKEN");
        address proposer = addresses.getAddress("BRAVO_PROPOSER");

        _simulateActions(governor, govToken, proposer);
    }

    /// @notice Validates the post-execution state
    /// @param addresses The addresses contract.
    function _validate(Addresses addresses, address) internal override {
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        uint256 balance = token.balanceOf(address(timelockVault));
        (uint256 amount, ) = timelockVault.deposits(address(token), timelock);
        assertEq(amount, balance);

        assertEq(timelockVault.owner(), timelock);
        assertTrue(timelockVault.tokenWhitelist(address(token)));
        assertFalse(timelockVault.paused());

        assertEq(token.owner(), timelock);
        assertEq(token.balanceOf(address(timelockVault)), token.totalSupply());
    }
}
