# Compound Governor Bravo Proposal

## Overview

This is an mainnet example of FPS where FPS is used to make proposals for compound governor bravo. No deployments in this example. This example sets comet's borrow and supply kink to 0.75 \* 1e18 through compound configurator.

The following contract is present in the [mocks/](../../mocks/) folder.

```solidity
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { GovernorBravoProposal } from "@proposals/GovernorBravoProposal.sol";

import { ICompoundConfigurator } from "@interface/ICompoundConfigurator.sol";

import { Addresses } from "@addresses/Addresses.sol";

contract MockBravoProposal is GovernorBravoProposal {
    // @notice new kink value
    uint64 public kink = 0.75 * 1e18;

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
```

Let's go through each of the functions that are overridden.

-   `name()`: Define the name of your proposal.
-   `description()`: Provide a detailed description of your proposal.
-   `run()`: Sets environment for running the proposal. It sets `addresses` and `governor`. `addresses` is address object
    containing addresses to be used in proposal that are fetched from `Addresses.json`. `governor` is the address of the compound governor bravo contract.
-   `build()`: Set the necessary actions for your proposal. In this example, borrow and
    supply kink is set through configurator by timelock bravo. The actions should be
    written in solidity code and in the order they should be executed. Any calls (except to
    the Addresses object) will be recorded and stored as actions to execute in the run
    function. `caller` address is passed into `buildModifier` that will call actions in
    `build`. Caller is governor's timelock in this example.
-   `validate()`: It validates that supply and borrow kink is set correctly.

## Running the Proposal

```sh
forge script mocks/MockBravoProposal.sol --fork-url mainnet
```

It's crucial to ensure all required address is correctly listed in the Addresses.json file. If these don't align, the script execution will fail.

The script will output the following:

```sh
== Logs ==

---------------- Proposal Description ----------------
  Mock proposal that adjust IR Curve for Compound v3 WETH on Mainnet

------------------ Proposal Actions ------------------
  1). calling 0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3 with 0 eth and 0x5bfb8373000000000000000000000000a17581a9e3356d9a858b789d68b4d866e593ae940000000000000000000000000000000000000000000000000a688906bd8b0000 data.
  target: 0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3
payload
  0x5bfb8373000000000000000000000000a17581a9e3356d9a858b789d68b4d866e593ae940000000000000000000000000000000000000000000000000a688906bd8b0000


  2). calling 0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3 with 0 eth and 0x058e4155000000000000000000000000a17581a9e3356d9a858b789d68b4d866e593ae940000000000000000000000000000000000000000000000000a688906bd8b0000 data.
  target: 0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3
payload
  0x058e4155000000000000000000000000a17581a9e3356d9a858b789d68b4d866e593ae940000000000000000000000000000000000000000000000000a688906bd8b0000




------------------ Proposal Calldata ------------------
  0xda95691a00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003600000000000000000000000000000000000000000000000000000000000000002000000000000000000000000316f9708bb98af7da9c68c1c3b5e79039cd336e3000000000000000000000000316f9708bb98af7da9c68c1c3b5e79039cd336e3000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000445bfb8373000000000000000000000000a17581a9e3356d9a858b789d68b4d866e593ae940000000000000000000000000000000000000000000000000a688906bd8b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044058e4155000000000000000000000000a17581a9e3356d9a858b789d68b4d866e593ae940000000000000000000000000000000000000000000000000a688906bd8b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000424d6f636b2070726f706f73616c20746861742061646a75737420495220437572766520666f7220436f6d706f756e642076332057455448206f6e204d61696e6e6574000000000000000000000000000000000000000000000000000000000000
```
