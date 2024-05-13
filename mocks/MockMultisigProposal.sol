// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {console} from "@forge-std/console.sol";
import {Addresses} from "@addresses/Addresses.sol";

import {MultisigProposal} from "@proposals/MultisigProposal.sol";

import {Vault} from "@mocks/Vault.sol";

interface ProxyAdmin {
    function upgrade(address proxy, address implementation) external;
}

interface Proxy {
    function implementation() external view returns (address);
}

contract MockMultisigProposal is MultisigProposal {
    function name() public pure override returns (string memory) {
        return "OPTMISM_MULTISIG_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Mock proposal that upgrade the L1 NFT Bridge";
    }

    function run() public override {
        addresses = new Addresses(
            vm.envOr("ADDRESSES_PATH", string("./addresses/Addresses.json"))
        );
        vm.makePersistent(address(addresses));

        super.run();
    }

    function deploy() public override {
        if (!addresses.isAddressSet("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION")) {
            address l1NFTBridgeImplementation = address(new Vault());

            addresses.addAddress(
                "OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION",
                l1NFTBridgeImplementation,
                true
            );
        }
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("OPTIMISM_MULTISIG"))
    {
        ProxyAdmin proxy = ProxyAdmin(
            addresses.getAddress("OPTIMISM_PROXY_ADMIN")
        );

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
        Proxy proxy = Proxy(
            addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_PROXY")
        );

        vm.prank(addresses.getAddress("OPTIMISM_PROXY_ADMIN"));
        require(
            proxy.implementation() ==
                addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION"),
            "Proxy implementation not set"
        );
    }
}
