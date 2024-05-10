// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {GovernorBravoProposal} from "@proposals/GovernorBravoProposal.sol";

import {ICompoundConfigurator} from "@interface/ICompoundConfigurator.sol";

import {Addresses} from "@addresses/Addresses.sol";

contract MockBravoProposal is GovernorBravoProposal {
    // @notice new kink value
    uint64 public kink = 750000000000000000;

    function name() public pure override returns (string memory) {
        return "ADJUST_WETH_IR_CURVE";
    }

    function description() public pure override returns (string memory) {
        return
            "Mock proposal that adjust IR Curve for Compound v3 WETH on Mainnet";
    }

    function run() public override {
        setAddresses(
            new Addresses(
                vm.envOr("ADDRESSES_PATH", string("./addresses/Addresses.json"))
            )
        );

        vm.makePersistent(address(addresses));

        setGovernor(addresses.getAddress("COMPOUND_GOVERNOR_BRAVO"));

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

        /// CALLS -- mutative and recorded
        configurator.setBorrowKink(comet, kink);
        configurator.setSupplyKink(comet, kink);
    }

    function simulate() public override {
        address governanceToken = addresses.getAddress("COMP_TOKEN");
        address proposer = addresses.getAddress("COMPOUND_PROPOSER");

        _simulateActions(governanceToken, proposer);
    }

    function validate() public view override {
        ICompoundConfigurator configurator = ICompoundConfigurator(
            addresses.getAddress("COMPOUND_CONFIGURATOR")
        );
        address comet = addresses.getAddress("COMPOUND_COMET");

        ICompoundConfigurator.Configuration memory config = configurator
            .getConfiguration(comet);
        assertEq(config.supplyKink, kink);
        assertEq(config.borrowKink, kink);
    }
}
