# Compound Governor Bravo Proposal

## Overview

This is an mainnet example of FPS where FPS is used to make proposals for compound governor bravo. No deployments in this example. This example sets comet's borrow and supply kink to 0.75 \* 1e18 through compound configurator.

The following contract is present in the [mocks/](../../mocks/) folder.

Let's go through each of the functions that are overridden.

-   `name()`: Define the name of your proposal.

```solidity
function name() public pure override returns (string memory) {
    return "ADJUST_WETH_IR_CURVE";
}
```

-   `description()`: Provide a detailed description of your proposal.

```solidity
function description() public pure override returns (string memory) {
    return "Mock proposal that adjust IR Curve for Compound v3 WETH on Mainnet";
}
```

-   `build()`: Set the necessary actions for your proposal. [Refer](../overview/architecture/proposal-functions.md#build-function). In this example, borrow and supply kink is set through configurator by timelock bravo. The actions should be written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. `caller` address is passed into `buildModifier` that will call actions in `build`. Caller is governor's timelock in this example. `buildModifier` is necessary modifier for `build` function and will not work without it.

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

        // get commet address
        address comet = addresses.getAddress("COMPOUND_COMET");

        /// CALLS -- mutative and recorded

        // set borrow kink to 0.75 * 1e18
        configurator.setBorrowKink(comet, kink);

        // set supply kink to 0.75 * 1e18
        configurator.setSupplyKink(comet, kink);
    }
    ```

-   `validate()`: It validates that supply and borrow kink is set correctly.

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

-   `run()`: Sets environment for running the proposal. [Refer](../overview/architecture/proposal-functions.md#run-function) It sets `addresses`, `primaryForkId` and `governor` and calls `super.run()` to run proposal lifecycle. In this function, `primaryForkId` is set to `mainnet` and selecting the fork for running proposal. Next `addresses` object is set by reading `addresses.json` file. `addresses` contract state is persisted accross forks using `vm.makePersistent()`. governor bravo is set using `setGovernor` that will be used to check onchain calldata and simulate the proposal.

```solidity
function run() public override {
    // Create and select mainnet fork for proposal execution.
    primaryForkId = vm.createFork("mainnet");
    vm.selectFork(primaryForkId);

    // Set addresses object reading addresses from json file.
    setAddresses(
        new Addresses(
            vm.envOr("ADDRESSES_PATH", string("./addresses/Addresses.json"))
        )
    );

    // Make 'addresses' state persist across selected fork.
    vm.makePersistent(address(addresses));

    // Set governor bravo. This address is used for proposal simulation and check on
    // chain proposal state.
    setGovernor(addresses.getAddress("COMPOUND_GOVERNOR_BRAVO"));

    // Call the run function of parent contract 'Proposal.sol'.
    super.run();
}
```

## Setting Up Your Deployer Address

The deployer address is the one used to broadcast the transactions deploying the proposal contracts. Ensure your deployer address has enough funds from the faucet to cover deployment costs on the testnet. We prioritize security when it comes to private key management. To avoid storing the private key as an environment variable, we use Foundry's cast tool. Ensure cast address is same as Deployer address.

If you're missing a wallet in `~/.foundry/keystores/`, create one by executing:

```sh
cast wallet import ${wallet_name} --interactive
```

## Running the Proposal

```sh
forge script mocks/MockBravoProposal.sol --fork-url mainnet
```

All required addresses should be in the Addresses.json file including `DEPLOYER_EOA` address which will deploy the new contracts. If these don't align, the script execution will fail.

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
