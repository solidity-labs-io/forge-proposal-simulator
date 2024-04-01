pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {Proposal} from "@proposals/Proposal.sol";

// MULTISIG_01 proposal deploys a Vault contract and an ERC20 token contract
// Then the proposal transfers ownership of both Vault and ERC20 to the multisig address
// Finally the proposal whitelist the ERC20 token in the Vault contract
contract MULTISIG_01 is MultisigProposal {
    string private constant ADDRESSES_PATH = "./addresses/Addresses.json";

    constructor()
        Proposal(
            ADDRESSES_PATH,
            "DEV_MULTISIG",
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        )
    {}

    // Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "MULTISIG_01";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Deploy Vault contract";
    }

    /// @notice Deploys a vault contract and an ERC20 token contract.
    /// @param addresses The addresses contract.
    function _deploy(Addresses addresses, address) internal override {
        if (!addresses.isAddressSet("VAULT")) {
            Vault timelockVault = new Vault();
            addresses.addAddress("VAULT", address(timelockVault), true);
        }

        if (!addresses.isAddressSet("TOKEN_1")) {
            MockToken token = new MockToken();
            addresses.addAddress("TOKEN_1", address(token), true);
        }
    }

    /// @notice proposal action steps:
    /// 1. Transfers vault ownership to dev multisig.
    /// 2. Transfer token ownership to dev multisig.
    /// 3. Transfers all tokens to dev multisig.
    /// @param addresses The addresses contract.
    function _afterDeploy(
        Addresses addresses,
        address deployer
    ) internal override {
        address devMultisig = addresses.getAddress("DEV_MULTISIG");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        timelockVault.transferOwnership(devMultisig);
        token.transferOwnership(devMultisig);
        token.transfer(devMultisig, token.balanceOf(address(deployer)));
    }

    /// @notice Sets up actions for the proposal, in this case, setting the MockToken to active.
    /// @param addresses The addresses contract.
    function _build(Addresses addresses) internal override {
        /// STATICCALL -- not recorded for the run stage
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");

        /// CALLS -- mutative and recorded
        Vault(timelockVault).whitelistToken(token, true);
    }

    /// @notice Executes the proposal actions.
    /// @param addresses The addresses contract.
    function _run(Addresses addresses, address) internal override {
        /// Call parent _run function to check if there are actions to execute
        super._run(addresses, address(0));

        address multisig = addresses.getAddress("DEV_MULTISIG");

        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");

        /// CALLS -- mutative and recorded
        _simulateActions(multisig);
    }

    /// @notice Validates the post-execution state.
    /// @param addresses The addresses contract.
    function _validate(Addresses addresses, address) internal override {
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
