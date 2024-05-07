// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Addresses} from "@addresses/Addresses.sol";

import {MultisigProposal} from "@proposals/MultisigProposal.sol";

import {Vault} from "@mocks/Vault.sol";
import {Token} from "@mocks/Token.sol";

contract MockMultisigProposal is MultisigProposal {
    function name() public pure override returns (string memory) {
        return "MULTISIG_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Multisig proposal mock";
    }

    function run() public override {
        addresses = new Addresses(
            vm.envOr("ADDRESSES_PATH", string("./addresses/Addresses.json"))
        );
        vm.makePersistent(address(addresses));

        super.run();
    }

    function deploy() public override {
        address multisig = addresses.getAddress("DEV_MULTISIG");
        if (!addresses.isAddressSet("MULTISIG_VAULT")) {
            Vault timelockVault = new Vault();

            addresses.addAddress(
                "MULTISIG_VAULT",
                address(timelockVault),
                true
            );

            timelockVault.transferOwnership(address(multisig));
        }

        if (!addresses.isAddressSet("MULTISIG_TOKEN")) {
            Token token = new Token();
            addresses.addAddress("MULTISIG_TOKEN", address(token), true);

            token.transferOwnership(address(multisig));
            token.transfer(address(multisig), token.balanceOf(address(this)));
        }
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("DEV_MULTISIG"))
    {
        address multisig = addresses.getAddress("DEV_MULTISIG");

        /// STATICCALL -- not recorded for the run stage
        address timelockVault = addresses.getAddress("MULTISIG_VAULT");
        address token = addresses.getAddress("MULTISIG_TOKEN");
        uint256 balance = Token(token).balanceOf(address(multisig));

        Vault(timelockVault).whitelistToken(token, true);

        /// CALLS -- mutative and recorded
        Token(token).approve(timelockVault, balance);
        Vault(timelockVault).deposit(token, balance);
    }

    /// @notice Executes the proposal actions.
    function simulate() public override {
        /// Call parent simulate function to check if there are actions to execute
        super.simulate();

        address multisig = addresses.getAddress("DEV_MULTISIG");

        /// Dev is proposer and executor
        _simulateActions(multisig);
    }
}
