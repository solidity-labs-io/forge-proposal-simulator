pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {Proposal} from "@proposals/Proposal.sol";

/// Mock proposal that withdraw tokens from Vault
contract MULTISIG_03 is MultisigProposal {
    string private constant ADDRESSES_PATH = "./addresses/Addresses.json";

    constructor() Proposal(ADDRESSES_PATH, "DEV_MULTISIG") {
        string memory urlOrAlias = vm.envOr("ETH_RPC_URL", string("sepolia"));
        primaryForkId = vm.createFork(urlOrAlias);
    }

    /// Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "MULTISIG_03";
    }

    /// Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Withdraw tokens from Vault";
    }

    /// @notice Sets up actions for the proposal, in this case, withdrawing MockToken into Vault.
    function _build() internal override {
        /// STATICCALL -- not recorded for the run stage
        address devMultisig = addresses.getAddress("DEV_MULTISIG");
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");
        uint256 balance = MockToken(token).balanceOf(address(timelockVault));

        /// CALL -- filtered out because VM calls are not recorded
        vm.warp(block.timestamp + 1 weeks + 1);

        /// CALLS -- mutative and recorded
        Vault(timelockVault).withdraw(token, payable(devMultisig), balance);
    }

    // Executes the proposal actions.
    function _run() internal override {
        // Call parent _run function to check if there are actions to execute
        super._run();

        address multisig = addresses.getAddress("DEV_MULTISIG");

        // Simulate time passing, vault time lock is 1 week
        vm.warp(block.timestamp + 1 weeks + 1);

        _simulateActions(multisig);
    }

    // Validates the post-execution state.
    function _validate() internal override {
        address devMultisig = addresses.getAddress("DEV_MULTISIG");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        (uint256 amount, ) = timelockVault.deposits(
            address(token),
            devMultisig
        );
        assertEq(amount, 0);

        assertEq(timelockVault.owner(), devMultisig);
        assertTrue(timelockVault.tokenWhitelist(address(token)));
        assertFalse(timelockVault.paused());

        assertEq(token.owner(), devMultisig);
        assertEq(token.balanceOf(address(timelockVault)), 0);
        assertEq(token.balanceOf(devMultisig), 10_000_000e18);
    }
}
