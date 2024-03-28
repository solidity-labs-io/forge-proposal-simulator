pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {GovernorBravoProposal} from "@proposals/GovernorBravoProposal.sol";
import {Proposal} from "@proposals/Proposal.sol";

/// @notice Mock proposal that withdraws MockToken from Vault.
contract BRAVO_03 is GovernorBravoProposal {
    /// @notice proposal name.
    string public override name = "BRAVO_03";

    string private constant ADDRESSES_PATH = "./addresses/Addresses.json";

    constructor()
        Proposal(
            ADDRESSES_PATH,
            0x1a9C8182C09F50C8318d769245beA52c32BE35BC,
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        )
    {}

    /// @notice Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Withdraw tokens from Vault";
    }

    /// @notice Sets up actions for the proposal, in this case, withdrawing MockToken into Vault.
    /// @param addresses The addresses contract.
    function _build(Addresses addresses) internal override {
        /// STATICCALL -- not recorded for the run stage
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");
        uint256 balance = MockToken(token).balanceOf(address(timelockVault));

        /// CALL -- filtered out because VM calls are not recorded
        vm.warp(block.timestamp + 1 weeks + 1);

        /// CALLS -- mutative and recorded
        Vault(timelockVault).withdraw(token, payable(timelock), balance);
    }

    /// @notice Executes the proposal actions.
    /// @param addresses The addresses contract.
    function _run(Addresses addresses, address) internal override {
        /// Call parent _run function to check if there are actions to execute
        super._run(addresses, address(0));

        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");
        address govToken = addresses.getAddress("PROTOCOL_GOVERNANCE_TOKEN");
        address proposer = addresses.getAddress("BRAVO_PROPOSER");

        /// Simulate time passing, vault time lock is 1 week
        vm.warp(block.timestamp + 1 weeks + 1);

        _simulateActions(governor, govToken, proposer);
    }

    /// @notice Validates the post-execution state.
    /// @param addresses The addresses contract.
    function _validate(Addresses addresses, address) internal override {
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        (uint256 amount, ) = timelockVault.deposits(address(token), timelock);
        assertEq(amount, 0);
        assertEq(timelockVault.owner(), timelock);
        assertTrue(timelockVault.tokenWhitelist(address(token)));
        assertFalse(timelockVault.paused());

        assertEq(token.owner(), timelock);
        assertEq(token.balanceOf(address(timelockVault)), 0);
        assertEq(token.balanceOf(timelock), 10_000_000e18);
    }
}
