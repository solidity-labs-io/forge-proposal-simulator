# Optimism multisig Proposal

## Overview

This is an mainnet example of FPS where FPS is used to make proposals for optimism multisig on mainnet. This example upgrades L1 NFT Bridge contract. Optimism multisig calls `upgrade` on proxy contract to upgrade implementation to a new `MockUpgrade`.

The following contract is present in the [mocks/](../../mocks/) folder.

```solidity
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { Addresses } from "@addresses/Addresses.sol";

import { MultisigProposal } from "@proposals/MultisigProposal.sol";

import { IProxy } from "@interface/IProxy.sol";
import { IProxyAdmin } from "@interface/IProxyAdmin.sol";

import { MockUpgrade } from "@mocks/MockUpgrade.sol";

contract MockMultisigProposal is MultisigProposal {
    function name() public pure override returns (string memory) {
        return "OPTIMISM_MULTISIG_MOCK";
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
            address l1NFTBridgeImplementation = address(new MockUpgrade());

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
        IProxyAdmin proxy = IProxyAdmin(
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
        IProxy proxy = IProxy(
            addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_PROXY")
        );

        // implementation() caller must be the owner
        vm.startPrank(addresses.getAddress("OPTIMISM_PROXY_ADMIN"));
        require(
            proxy.implementation() ==
                addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION"),
            "Proxy implementation not set"
        );
        vm.stopPrank();
    }
}
```

Let's go through each of the functions that are overridden.

-   `name()`: Define the name of your proposal.
-   `description()`: Provide a detailed description of your proposal.
-   `deploy()`: This example demonstrates the deployment of new MockUpgrade which will be
    used as new implementation to proxy.
-   `run()`: Sets environment for running the proposal. It sets `addresses`. `addresses` is address object
    containing addresses to be used in proposal that are fetched from `Addresses.json`.
-   `build()`: In this example, L1 NFT Bridge is upgraded to new implementation. The actions
    should be written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. `caller` address is passed into `buildModifier` that will call actions in `build`. Caller is optimism multisig for this example.
-   `simulate()`: Execute the proposal actions outlined in the `build()` step. This
    function performs a call to `_simulateActions()` from the inherited
    `MultisigProposal` contract. Internally, `_simulateActions()` simulates a call to the [Multicall3](https://www.multicall3.com/) contract with the calldata generated from the actions set up in the build step.
-   `validate()`: It validates implementation is upgraded correctly.

## Running the Proposal

```sh
forge script mocks/MockMultisigProposal.sol --fork-url mainnet
```

All required addresses should be in the Addresses.json file. If these don't align, the script execution will fail.

The script will output the following:

```sh
== Logs ==

---------------- Proposal Description ----------------
  Mock proposal that upgrade the L1 NFT Bridge

------------------ Proposal Actions ------------------
  1). calling 0x543bA4AADBAb8f9025686Bd03993043599c6fB04 with 0 eth and 0x99a88ec40000000000000000000000005a7749f83b81b301cab5f48eb8516b986daef23d000000000000000000000000ae2af01232a6c4a4d3012c5ec5b1b35059caf10d data.
  target: 0x543bA4AADBAb8f9025686Bd03993043599c6fB04
payload
  0x99a88ec40000000000000000000000005a7749f83b81b301cab5f48eb8516b986daef23d000000000000000000000000ae2af01232a6c4a4d3012c5ec5b1b35059caf10d




------------------ Proposal Calldata ------------------
  0x174dea71000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000543ba4aadbab8f9025686bd03993043599c6fb04000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000004499a88ec40000000000000000000000005a7749f83b81b301cab5f48eb8516b986daef23d000000000000000000000000ae2af01232a6c4a4d3012c5ec5b1b35059caf10d00000000000000000000000000000000000000000000000000000000
```
