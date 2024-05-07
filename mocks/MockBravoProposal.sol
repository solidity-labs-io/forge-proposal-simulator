// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Proposal} from "@proposals/Proposal.sol";
import {TimelockProposal} from "@proposals/TimelockProposal.sol";

import {Vault} from "@mocks/Vault.sol";
import {Token} from "@mocks/Token.sol";

contract MockBravoProposal is GovernorBravoProposal {
    function name() public pure override returns (string memory) {
        return "BRAVO_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Bravo proposal mock";
    }

    constructor()
        Proposal("./addresses/Addresses.json")
        GovernorBravoProposal(addresses.getAddress("PROTOCOL_GOVERNOR"))
    {}

    function deploy() public override {
        if (!addresses.isAddressSet("BRAVO_VAULT")) {
            Vault timelockVault = new Vault();

            addresses.addAddress("BRAVO_VAULT", address(timelockVault), true);

            timelockVault.transferOwnership(address(timelock));
        }

        if (!addresses.isAddressSet("BRAVO_VAULT_TOKEN")) {
            Token token = new Token();
            addresses.addAddress("BRAVO_VAULT_TOKEN", address(token), true);

            token.transferOwnership(timelock);
            token.transfer(
                address(timelock),
                token.balanceOf(addresses.getAddress("DEPLOYER_EOA"))
            );
        }
    }

    function build() public override buildModifier(timelock) {
        /// STATICCALL -- not recorded for the run stage
        address timelockVault = addresses.getAddress("BRAVO_VAULT");
        address token = addresses.getAddress("BRAVO_VAULT_TOKEN");
        uint256 balance = Token(token).balanceOf(address(timelock));

        Vault(timelockVault).whitelistToken(token, true);

        /// CALLS -- mutative and recorded
        Token(token).approve(timelockVault, balance);
        Vault(timelockVault).deposit(token, balance);
    }

    /// @notice Executes the proposal actions.
    function simulate() public override {
        /// Call parent simulate function to check if there are actions to execute
        super.simulate();

        address governanceToken = addresses.getAddress(
            "PROTOCOL_GOVERNANCE_TOKEN"
        );
        address proposer = addresses.getAddress("DEPLOYER_EOA");

        /// Dev is proposer and executor
        _simulateActions(governaceToken, proposer);
    }
}
