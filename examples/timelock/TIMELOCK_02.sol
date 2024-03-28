pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {Proposal} from "@proposals/Proposal.sol";

// Mock proposal that deposits MockToken into Vault.
contract TIMELOCK_02 is TimelockProposal {
    string private constant ADDRESSES_PATH = "./addresses/Addresses.json";

    constructor()
        Proposal(
            ADDRESSES_PATH,
            0x1a9C8182C09F50C8318d769245beA52c32BE35BC,
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        )
    {}

    /// @notice Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "TIMELOCK_02";
    }

    /// @notice Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Deposit MockToken into Vault";
    }

    /// @notice Sets up actions for the proposal, in this case, depositing MockToken into Vault.
    function _build(Addresses addresses) internal override {
        /// STATICCALL -- not recorded for the run stage
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");
        uint256 balance = MockToken(token).balanceOf(address(timelock));

        /// CALLS -- mutative and recorded
        MockToken(token).approve(timelockVault, balance);
        Vault(timelockVault).deposit(token, balance);
    }

    // Executes the proposal actions.
    function _run(Addresses addresses, address) internal override {
        // Call parent _run function to check if there are actions to execute
        super._run(addresses, address(0));

        address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
        address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

        _simulateActions(proposer, executor);
    }

    // Validates the post-execution state
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
