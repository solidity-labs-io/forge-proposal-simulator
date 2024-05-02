pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {Proposal} from "@proposals/Proposal.sol";

// Mock proposal that withdraws MockToken from Vault.
contract TIMELOCK_03 is TimelockProposal {
    string private constant ADDRESSES_PATH = "./addresses/Addresses.json";

    constructor() Proposal(ADDRESSES_PATH, "PROTOCOL_TIMELOCK") {
        string memory urlOrAlias = vm.envOr("ETH_RPC_URL", string("sepolia"));
        primaryForkId = vm.createFork(urlOrAlias);
    }

    /// @notice Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "TIMELOCK_PROPOSAL_MOCK";
    }

    /// @notice Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Withdraw tokens from Vault";
    }

    /// @notice Sets up actions for the proposal, in this case, withdrawing MockToken into Vault.
    function build() public override buildModifier buildModifier {
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
    function simulate() public override {
        /// Call parent _run function to check if there are actions to execute
        super.simulate();

        address dev = addresses.getAddress("DEV");

        /// Simulate time passing, vault time lock is 1 week
        vm.warp(block.timestamp + 1 weeks + 1);

        /// Dev is proposer and executor
        _simulateActions(dev, dev);
    }

    /// @notice Validates the post-execution state.
    function validate() public override {
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
