pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {Proposal} from "@proposals/Proposal.sol";
import {MockToken} from "@examples/MockToken.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {AlphaProposal} from "@proposals/AlphaProposal.sol";
import {GovernorBravoProposal} from "@proposals/GovernorBravoProposal.sol";

/// BRAVO_01 proposal deploys a Vault contract and an ERC20 token contract
/// Then the proposal transfers ownership of both Vault and ERC20 to the governor address
/// Finally the proposal whitelist the ERC20 token in the Vault contract
contract BRAVO_01 is AlphaProposal, GovernorBravoProposal {
    /// @notice Returns the name of the proposal.
    string public override name = "BRAVO_01";

    /// @notice Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Governor Bravo proposal mock";
    }

    /// @notice Returns the calldata for the proposal.
    /// overrides the AlphaProposal.getCalldata and GovernorBravoProposal.getCalldata functions.
    /// returns GovernorBravoProposal.getCalldata();
    function getCalldata()
        public
        view
        override(Proposal, GovernorBravoProposal)
        returns (bytes memory data)
    {
        return GovernorBravoProposal.getCalldata();
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

    /// @notice steps:
    /// 1. Transfers vault ownership to timelock.
    /// 2. Transfer token ownership to timelock.
    /// 3. Transfers all tokens to timelock.
    /// @param addresses The addresses contract.
    /// @param deployer The contract deployer address.
    function _afterDeploy(
        Addresses addresses,
        address deployer
    ) internal override {
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        timelockVault.transferOwnership(timelock);
        token.transferOwnership(timelock);
        token.transfer(timelock, token.balanceOf(address(deployer)));
    }

    /// @notice Sets up actions for the proposal, in this case, setting the MockToken to active.
    /// @param addresses The addresses contract.
    function _build(
        Addresses addresses
    )
        internal
        override
        buildModifier(addresses.getAddress("PROTOCOL_TIMELOCK"), addresses)
    {
        /// STATICCALL -- not recorded for the run stage
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");

        /// CALL -- mutative and recorded
        Vault(timelockVault).whitelistToken(token, true);
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

    /// @notice Validates the post-execution state.
    /// @param addresses The addresses contract.
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
