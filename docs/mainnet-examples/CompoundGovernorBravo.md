# Compound Governor Bravo Proposal

## Overview

This serves as a mainnet example of FPS, where FPS is utilized to propose adjustments for the Compound Governor Bravo. No deployments are included in this example. Specifically, this example sets Comet's borrow and supply kink to 0.75 \* 1e18 through the Compound Configurator.

The contract outlined below is located in the [mocks folder](../../mocks/MockBravoProposal.sol).

Let's examine each of the functions that are overridden:

-   `name()`: Specifies the name of the proposal.

    ```solidity
    function name() public pure override returns (string memory) {
        return "ADJUST_WETH_IR_CURVE";
    }
    ```

-   `description()`: Offers a detailed description of the proposal.

    ```solidity
    function description() public pure override returns (string memory) {
        return
            "Mock proposal to adjust the IR Curve for Compound v3 WETH on Mainnet";
    }
    ```

-   `build()`: Add actions to the proposal contract. In this instance, borrow and supply kink are set through the configurator by Bravo's timelock. The actions should be written in Solidity code and in the order they are intended to be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. The `caller` address is passed into `buildModifier`, which will call actions in `build`. In this example, the caller is Governor's timelock. The `buildModifier` is a necessary modifier for the `build` function and will not function without it. For further reading, see the [build function](../overview/architecture/proposal-functions.md#build-function).

    ```solidity
    function build()
        public
        override
        buildModifier(addresses.getAddress("COMPOUND_TIMELOCK_BRAVO"))
    {
        /// STATICCALL -- not recorded for the run stage

        // get configurator address
        ICompoundConfigurator configurator = ICompoundConfigurator(
            addresses.getAddress("COMPOUND_CONFIGURATOR")
        );

        // get comet address
        address comet = addresses.getAddress("COMPOUND_COMET");

        /// CALLS -- mutative and recorded

        // set borrow kink to 0.75 * 1e18
        configurator.setBorrowKink(comet, kink);

        // set supply kink to 0.75 * 1e18
        configurator.setSupplyKink(comet, kink);
    }
    ```

-   `run()`: Sets up the environment for running the proposal. This sets `addresses`, `primaryForkId`, and `governor`, and then calls `super.run()` to run the entire proposal. In this example, `primaryForkId` is set to `mainnet`, selecting the fork for running the proposal. Next, the `addresses` object is set by reading the JSON file. The Governor Bravo contract to test is set using `setGovernor`. This will be used to check onchain calldata and simulate the proposal. For further reading, see the [run function](../overview/architecture/proposal-functions.md#run-function).

    ```solidity
    function run() public override {
        // Create and select the mainnet fork for proposal execution.
        primaryForkId = vm.createFork("mainnet");
        vm.selectFork(primaryForkId);

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 1;
        // Set the addresses object by reading addresses from the JSON file.
        setAddresses(
            new Addresses(
                vm.envOr("ADDRESSES_PATH", string("./addresses")), chainIds
            )
        );

        // Set Governor Bravo. This address is used for proposal simulation and checking the on-chain proposal state.
        setGovernor(addresses.getAddress("COMPOUND_GOVERNOR_BRAVO"));

        // Call the run function of the parent contract 'Proposal.sol'.
        super.run();
    }
    ```

-   `validate()`: Validates that the supply and borrow kink are set correctly.

    ```solidity
    function validate() public view override {
        // get configurator address
        ICompoundConfigurator configurator = ICompoundConfigurator(
            addresses.getAddress("COMPOUND_CONFIGURATOR")
        );

        // get comet address
        address comet = addresses.getAddress("COMPOUND_COMET");

        // get comet configuration
        ICompoundConfigurator.Configuration memory config = configurator
            .getConfiguration(comet);

        // ensure supply kink is set to 0.75 * 1e18
        assertEq(config.supplyKink, kink);

        // ensure borrow kink is set to 0.75 * 1e18
        assertEq(config.borrowKink, kink);
    }
    ```

## Running the Proposal

```sh
forge script mocks/MockBravoProposal.sol --fork-url mainnet
```

All required addresses should be in the JSON file, including the `DEPLOYER_EOA` address, which will deploy the new contracts. If these do not align, the script execution will fail.

The script will output the following:

```sh
== Logs ==

---------------- Proposal Description ----------------
  Mock proposal that adjust IR Curve for Compound v3 WETH on Mainnet

------------------ Proposal Actions ------------------
  1). calling COMPOUND_CONFIGURATOR @0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3 with 0 eth and 0x5bfb8373000000000000000000000000a17581a9e3356d9a858b789d68b4d866e593ae940000000000000000000000000000000000000000000000000a688906bd8b0000 data.
  target: COMPOUND_CONFIGURATOR @0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3
payload
  0x5bfb8373000000000000000000000000a17581a9e3356d9a858b789d68b4d866e593ae940000000000000000000000000000000000000000000000000a688906bd8b0000


  2). calling COMPOUND_CONFIGURATOR @0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3 with 0 eth and 0x058e4155000000000000000000000000a17581a9e3356d9a858b789d68b4d866e593ae940000000000000000000000000000000000000000000000000a688906bd8b0000 data.
  target: COMPOUND_CONFIGURATOR @0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3
payload
  0x058e4155000000000000000000000000a17581a9e3356d9a858b789d68b4d866e593ae940000000000000000000000000000000000000000000000000a688906bd8b0000



----------------- Proposal Changes ---------------


 COMPOUND_CONFIGURATOR @0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3:

 State Changes:
  Slot: 0x81786960a4c38938c01fafa8d0783bc04e719c248eafc32d7335695ed80183a0
  -  0x0bcbce7f1b15000000000000000000000de0b6b3a76400000041b9a6e8584000
  +  0x0a688906bd8b000000000000000000000de0b6b3a76400000041b9a6e8584000
  Slot: 0x81786960a4c38938c01fafa8d0783bc04e719c248eafc32d7335695ed801839f
  -  0x000000000bcbce7f1b150000e2c1f54aff6b38fd9df7a69f22cb5fd3ba09f030
  +  0x000000000a688906bd8b0000e2c1f54aff6b38fd9df7a69f22cb5fd3ba09f030


------------------ Proposal Calldata ------------------
  0xda95691a00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003600000000000000000000000000000000000000000000000000000000000000002000000000000000000000000316f9708bb98af7da9c68c1c3b5e79039cd336e3000000000000000000000000316f9708bb98af7da9c68c1c3b5e79039cd336e3000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000445bfb8373000000000000000000000000a17581a9e3356d9a858b789d68b4d866e593ae940000000000000000000000000000000000000000000000000a688906bd8b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044058e4155000000000000000000000000a17581a9e3356d9a858b789d68b4d866e593ae940000000000000000000000000000000000000000000000000a688906bd8b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000424d6f636b2070726f706f73616c20746861742061646a75737420495220437572766520666f7220436f6d706f756e642076332057455448206f6e204d61696e6e6574000000000000000000000000000000000000000000000000000000000000
```
