pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {MultisigProposal} from "@proposals/MultisigProposal.sol";

/// Mock proposal that deposit MockToken into Vault.
contract MULTISIG_02 is MultisigProposal {
    /// @notice Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "MULTISIG_02";
    }

    /// @notice Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Deposit MockToken into Vault";
    }

    /// @notice Sets up actions for the proposal, in this case, depositing MockToken into Vault.
    function _build(Addresses addresses) internal override {
        /// STATICCALL -- not recorded for the run stage
        address devMultisig = addresses.getAddress("DEV_MULTISIG");
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");
        uint256 balance = MockToken(token).balanceOf(address(devMultisig));

        /// CALLS -- mutative and recorded
        MockToken(token).approve(timelockVault, balance);
        Vault(timelockVault).deposit(token, balance);
    }

    /// @notice Executes the proposal actions.
    function _run(Addresses addresses, address) internal override {
        /// Call parent _run function to check if there are actions to execute
        super._run(addresses, address(0));

        address multisig = addresses.getAddress("DEV_MULTISIG");

        _simulateActions(multisig);
    }

    /// Validates the post-execution state
    function _validate(Addresses addresses, address) internal override {
        address devMultisig = addresses.getAddress("DEV_MULTISIG");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        uint256 balance = token.balanceOf(address(timelockVault));
        (uint256 amount, ) = timelockVault.deposits(
            address(token),
            devMultisig
        );
        assertEq(amount, balance);

        assertEq(timelockVault.owner(), devMultisig);
        assertTrue(timelockVault.tokenWhitelist(address(token)));
        assertFalse(timelockVault.paused());

        assertEq(token.owner(), devMultisig);
        assertEq(balance, token.totalSupply());
    }
}
