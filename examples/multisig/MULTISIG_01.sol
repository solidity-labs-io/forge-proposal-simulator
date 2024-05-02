pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {Proposal} from "@proposals/Proposal.sol";

// MULTISIG_01 proposal deploys a Vault contract and an ERC20 token contract
// Then the proposal transfers ownership of both Vault and ERC20 to the multisig address
// Finally the proposal whitelist the ERC20 token in the Vault contract
contract MULTISIG_01 is MultisigProposal {
    string private constant ADDRESSES_PATH = "./addresses/Addresses.json";

    constructor() Proposal(ADDRESSES_PATH, "DEV_MULTISIG") {
        string memory urlOrAlias = vm.envOr("ETH_RPC_URL", string("sepolia"));
        primaryForkId = vm.createFork(urlOrAlias);
    }

    /// @notice Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "MULTISIG_01";
    }

    /// @notice Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Deploy Vault contract";
    }

    /// @notice Deploys a vault contract and an ERC20 token contract.
    function _deploy() internal override {
        Vault timelockVault = new Vault();
        addresses.addOrChangeAddress("VAULT", address(timelockVault), true);

        MockToken token = new MockToken();
        addresses.addOrChangeAddress("TOKEN_1", address(token), true);
    }

    /// @notice proposal action steps:
    /// 1. Transfers vault ownership to dev multisig.
    /// 2. Transfer token ownership to dev multisig.
    /// 3. Transfers all tokens to dev multisig.
    function _afterDeploy() internal override {
        address devMultisig = addresses.getAddress("DEV_MULTISIG");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        timelockVault.transferOwnership(devMultisig);
        token.transferOwnership(devMultisig);

        // Make sure that DEV is the address you specify in the --sender flag
        token.transfer(
            devMultisig,
            token.balanceOf(addresses.getAddress("DEPLOYER_EOA"))
        );
    }

    /// @notice Sets up actions for the proposal, in this case, setting the MockToken to active.
    function _build() internal override {
        /// STATICCALL -- not recorded for the run stage
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");

        /// CALLS -- mutative and recorded
        Vault(timelockVault).whitelistToken(token, true);
    }

    /// @notice Executes the proposal actions.
    function _run() internal override {
        /// Call parent _run function to check if there are actions to execute
        super._run();

        address multisig = addresses.getAddress("DEV_MULTISIG");

        /// CALLS -- mutative and recorded
        _simulateActions(multisig);
    }

    /// @notice Validates the post-execution state.
    function _validate() internal override {
        address devMultisig = addresses.getAddress("DEV_MULTISIG");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        assertEq(timelockVault.owner(), devMultisig);
        assertTrue(timelockVault.tokenWhitelist(address(token)));
        assertFalse(timelockVault.paused());

        assertEq(token.owner(), devMultisig);
        assertEq(token.balanceOf(devMultisig), token.totalSupply());
    }
}
