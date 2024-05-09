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
        }

        if (!addresses.isAddressSet("MULTISIG_TOKEN")) {
            Token token = new Token();
            addresses.addAddress("MULTISIG_TOKEN", address(token), true);

            // During forge script execution, the deployer of the contracts is
            // the DEPLOYER_EOA. However, when running through forge test, the deployer of the contracts is this contract.
            uint256 balance = token.balanceOf(address(this)) > 0
                ? token.balanceOf(address(this))
                : token.balanceOf(addresses.getAddress("DEPLOYER_EOA"));

            token.transfer(multisig, balance);
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

    function simulate() public override {
        address multisig = addresses.getAddress("DEV_MULTISIG");

        /// Dev is proposer and executor
        _simulateActions(multisig);
    }

    function validate() public view override {
        Vault timelockVault = Vault(addresses.getAddress("MULTISIG_VAULT"));
        Token token = Token(addresses.getAddress("MULTISIG_TOKEN"));
        address multisig = addresses.getAddress("DEV_MULTISIG");

        uint256 balance = token.balanceOf(address(timelockVault));
        (uint256 amount, ) = timelockVault.deposits(address(token), multisig);
        assertEq(amount, balance);

        assertTrue(timelockVault.tokenWhitelist(address(token)));

        assertEq(token.balanceOf(address(timelockVault)), token.totalSupply());
    }
}
