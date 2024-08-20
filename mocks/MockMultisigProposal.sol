// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Addresses} from "@addresses/Addresses.sol";

import {MultisigProposal} from "@proposals/MultisigProposal.sol";

import {IProxy} from "@interface/IProxy.sol";
import {IProxyAdmin} from "@interface/IProxyAdmin.sol";

import {MockUpgrade} from "@mocks/MockUpgrade.sol";

contract MockMultisigProposal is MultisigProposal {
    function name() public pure override returns (string memory) {
        return "OPTMISM_MULTISIG_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Mock proposal that upgrade the L1 NFT Bridge";
    }

    function run() public override {
        setPrimaryForkId(vm.createSelectFork("mainnet"));

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 1;

        addresses = new Addresses(
            vm.envOr("ADDRESSES_PATH", string("./addresses")), chainIds
        );

        super.run();
    }

    function deploy() public override {
        if (!addresses.isAddressSet("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION")) {
            address mockUpgrade = address(new MockUpgrade());

            addresses.addAddress(
                "OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION", mockUpgrade, true
            );
        }
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("OPTIMISM_MULTISIG"))
    {
        IProxyAdmin proxy =
            IProxyAdmin(addresses.getAddress("OPTIMISM_PROXY_ADMIN"));

        proxy.upgrade(
            addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_PROXY"),
            addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION")
        );
    }

    function simulate() public override {
        address multisig = addresses.getAddress("OPTIMISM_MULTISIG");

        _simulateActions(multisig);
    }

    function validate() public override {
        IProxy proxy =
            IProxy(addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_PROXY"));

        // implementation() caller must be the owner
        vm.startPrank(addresses.getAddress("OPTIMISM_PROXY_ADMIN"));
        require(
            proxy.implementation()
                == addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION"),
            "Proxy implementation not set"
        );
        vm.stopPrank();
    }
}
