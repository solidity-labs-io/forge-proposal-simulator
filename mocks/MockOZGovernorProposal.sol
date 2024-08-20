// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {OZGovernorProposal} from "@proposals/OZGovernorProposal.sol";

import {Addresses} from "@addresses/Addresses.sol";

import {MockUpgrade} from "@mocks/MockUpgrade.sol";

interface IControllable {
    function setController(address controller, bool enabled) external;

    function controllers(address) external view returns (bool);
}

// @notice This is a mock proposal that uses ENS to demostrate OZ Governor proposal type.
// Inspired on https://www.tally.xyz/gov/ens/proposal/4208408830555077285685632645423534041634535116286721240943655761928631543220
contract MockOZGovernorProposal is OZGovernorProposal {
    function name() public pure override returns (string memory) {
        return "UPGRADE_DNSSEC_SUPPORT";
    }

    function description() public pure override returns (string memory) {
        return
        "Call setController on the Root contract at root.ens.eth, passing in the address of the new DNS registrar";
    }

    function run() public override {
        setPrimaryForkId(vm.createSelectFork("mainnet"));

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 1;

        setAddresses(
            new Addresses(
                vm.envOr("ADDRESSES_PATH", string("./addresses")), chainIds
            )
        );

        setGovernor(addresses.getAddress("ENS_GOVERNOR"));

        super.run();
    }

    function deploy() public override {
        if (!addresses.isAddressSet("ENS_DNSSEC")) {
            // In a real case, this function would be responsable for
            // deployig the DNSSEC contract instead of using a mock
            address dnsSec = address(new MockUpgrade());

            addresses.addAddress("ENS_DNSSEC", dnsSec, true);
        }
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("ENS_TIMELOCK"))
    {
        /// STATICCALL -- not recorded for the run stage
        IControllable control = IControllable(addresses.getAddress("ENS_ROOT"));
        address dnsSec = addresses.getAddress("ENS_DNSSEC");

        /// CALLS -- mutative and recorded
        control.setController(dnsSec, true);
    }

    function validate() public view override {
        IControllable control = IControllable(addresses.getAddress("ENS_ROOT"));
        address dnsSec = addresses.getAddress("ENS_DNSSEC");

        assertTrue(control.controllers(dnsSec));
    }
}
