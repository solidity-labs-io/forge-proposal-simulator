// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {GovernorBravoProposal} from "@proposals/GovernorBravoProposal.sol";

import {IGovernorAlpha} from "@interface/IGovernorBravo.sol";
import {ICompoundConfigurator} from "@interface/ICompoundConfigurator.sol";

import {Addresses} from "@addresses/Addresses.sol";

import {Vault} from "@mocks/Vault.sol";
import {Token} from "@mocks/Token.sol";

contract MockBravoProposal is GovernorBravoProposal {
    function name() public pure override returns (string memory) {
        return "ADJUST_WETH_IR_CURVE";
    }

    function description() public pure override returns (string memory) {
        return
            "Mock proposal that adjust IR Curve for Compound v3 WETH on Mainnet";
    }

    function run() public override {
        addresses = new Addresses(
            vm.envOr("ADDRESSES_PATH", string("./addresses/Addresses.json"))
        );
        vm.makePersistent(address(addresses));

        governor = IGovernorAlpha(addresses.getAddress("GOVERNOR_BRAVO"));

        super.run();
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("COMPOUND_TIMELOCK_BRAVO"))
    {
        /// STATICCALL -- not recorded for the run stage

        ICompoundConfigurator configurator = ICompoundConfigurator(
            addresses.getAddress("COMPOUND_CONFIGURATOR")
        );
        address comet = addresses.getAddress("COMPOUND_COMET");
        uint64 kink = 850000000000000000;

        /// CALLS -- mutative and recorded
        configurator.setBorrowKink(comet, kink);
        configurator.setSupplyKink(comet, kink);
    }

    function simulate() public override {
        /// Call parent simulate function to check if there are actions to execute
        super.simulate();

        address governanceToken = addresses.getAddress("COMP_TOKEN");
        address proposer = addresses.getAddress("COMPOUND_PROPOSER");

        /// Dev is proposer and executor
        _simulateActions(governanceToken, proposer);
    }

    function validate() public view override {
        ICompoundConfigurator configurator = ICompoundConfigurator(
            addresses.getAddress("COMPOUND_CONFIGURATOR")
        );
        address comet = addresses.getAddress("COMPOUND_COMET");
        uint64 kink = 850000000000000000;

        ICompoundConfigurator.Configuration memory config = configurator
            .getConfiguration(comet);
        assertEq(config.supplyKink, kink);
        assertEq(config.borrowKink, kink);
    }
}
