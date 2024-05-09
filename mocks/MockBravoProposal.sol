// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {GovernorBravoProposal} from "@proposals/GovernorBravoProposal.sol";

import {IGovernorAlpha} from "@interface/IGovernorBravo.sol";

import {Addresses} from "@addresses/Addresses.sol";

import {Vault} from "@mocks/Vault.sol";
import {Token} from "@mocks/Token.sol";

contract MockBravoProposal is GovernorBravoProposal {
    function name() public pure override returns (string memory) {
        return "BRAVO_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Bravo proposal mock";
    }

    function run() public override {
        addresses = new Addresses(
            vm.envOr("ADDRESSES_PATH", string("./addresses/Addresses.json"))
        );
        vm.makePersistent(address(addresses));

        governor = IGovernorAlpha(addresses.getAddress("PROTOCOL_GOVERNOR"));

        super.run();
    }

    function deploy() public override {
        address owner = addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO");
        if (!addresses.isAddressSet("BRAVO_VAULT")) {
            Vault timelockVault = new Vault();

            addresses.addAddress("BRAVO_VAULT", address(timelockVault), true);
        }

        if (!addresses.isAddressSet("BRAVO_VAULT_TOKEN")) {
            Token token = new Token();
            addresses.addAddress("BRAVO_VAULT_TOKEN", address(token), true);

            // During forge script execution, the deployer of the contracts is
            // the DEPLOYER_EOA. However, when running through forge test, the deployer of the contracts is this contract.
            uint256 balance = token.balanceOf(address(this)) > 0
                ? token.balanceOf(address(this))
                : token.balanceOf(addresses.getAddress("DEPLOYER_EOA"));

            token.transfer(address(owner), balance);
        }
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO"))
    {
        /// STATICCALL -- not recorded for the run stage
        address timelockVault = addresses.getAddress("BRAVO_VAULT");
        address token = addresses.getAddress("BRAVO_VAULT_TOKEN");
        uint256 balance = Token(token).balanceOf(
            addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO")
        );

        Vault(timelockVault).whitelistToken(token, true);

        /// CALLS -- mutative and recorded
        Token(token).approve(timelockVault, balance);
        Vault(timelockVault).deposit(token, balance);
    }

    function simulate() public override {
        /// Call parent simulate function to check if there are actions to execute
        super.simulate();

        address governanceToken = addresses.getAddress(
            "PROTOCOL_GOVERNANCE_TOKEN"
        );
        address proposer = addresses.getAddress("DEPLOYER_EOA");

        /// Dev is proposer and executor
        _simulateActions(governanceToken, proposer);
    }

    function validate() public view override {
        Vault timelockVault = Vault(addresses.getAddress("BRAVO_VAULT"));
        Token token = Token(addresses.getAddress("BRAVO_VAULT_TOKEN"));

        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO");

        uint256 balance = token.balanceOf(address(timelockVault));
        (uint256 amount, ) = timelockVault.deposits(
            address(token),
            address(timelock)
        );
        assertEq(amount, balance);

        assertTrue(timelockVault.tokenWhitelist(address(token)));

        assertEq(token.balanceOf(address(timelockVault)), token.totalSupply());
    }
}
