# Optimism Multisig Proposal

## Overview

This is a mainnet example of FPS where FPS is used to make proposals for the Optimism Multisig on mainnet. This example upgrades the L1 NFT Bridge contract. The Optimism Multisig calls `upgrade` on the proxy contract to upgrade the implementation to a new `MockUpgrade`.

The following contract is present in the [mocks/](../../mocks/) folder.

Let's go through each of the functions that are overridden:

-   `name()`: Defines the name of your proposal.

    ```solidity
    function name() public pure override returns (string memory) {
        return "OPTIMISM_MULTISIG_MOCK";
    }
    ```

-   `description()`: Provides a detailed description of your proposal.

    ```solidity
    function description() public pure override returns (string memory) {
        return "Mock proposal that upgrades the L1 NFT Bridge";
    }
    ```

-   `deploy()`: This example demonstrates the deployment of the new MockUpgrade, which will be used as the new implementation for the proxy.

    ```solidity
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
    ```

    Since these changes do not persist from runs themselves, after the contracts are deployed, the user must update the Addresses.json file with the newly deployed contract addresses.

-   `build()`: Add actions to the proposal contract. [See build function](../overview/architecture/proposal-functions.md#build-function). In this example, the L1 NFT Bridge is upgraded to a new implementation. The actions should be written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. The The `caller` address is passed into `buildModifier` that will call actions in `build`. The caller is the Optimism Multisig for this example. `buildModifier` is a necessary modifier for the `build` function and will not work without it.

    ```solidity
    function build()
        public
        override
        buildModifier(addresses.getAddress("OPTIMISM_MULTISIG"))
    {
        /// STATICCALL -- not recorded for the run stage
        IProxyAdmin proxy = IProxyAdmin(
            addresses.getAddress("OPTIMISM_PROXY_ADMIN")
        );

        /// CALLS -- mutative and recorded
        proxy.upgrade(
            addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_PROXY"),
            addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION")
        );
    }
    ```

-   `run()`: Sets up the environment for running the proposal. [See run function](../overview/architecture/proposal-functions.md#run-function). This sets `addresses`, `primaryForkId`, and calls `super.run()` to run the entire proposal. In this example, `primaryForkId` is set to `mainnet` and selecting the fork for running the proposal. Next, the `addresses` object is set by reading `addresses.json` file. The `addresses` contract state is persistent across forks by using foundry's `vm.makePersistent()` cheatcode.

    ```solidity
    function run() public override {
        // Create and select mainnet fork for proposal execution.
        primaryForkId = vm.createFork("mainnet");
        vm.selectFork(primaryForkId);

        // Set addresses object reading addresses from JSON file.
        addresses = new Addresses(
            vm.envOr("ADDRESSES_PATH", string("./addresses/Addresses.json"))
        );

        // Make 'addresses' state persist across selected fork.
        vm.makePersistent(address(addresses));

        // Call the run function of parent contract 'Proposal.sol'.
        super.run();
    }
    ```

-   `simulate()`: Executes the proposal actions outlined in the `build()` step. This function performs a call to `_simulateActions()` from the inherited `MultisigProposal` contract. Internally, `_simulateActions()` simulates a call to the [Multicall3](https://www.multicall3.com/) contract with the calldata generated from the actions set up in the build step.

    ```solidity
    function simulate() public override {
        // get multisig address
        address multisig = addresses.getAddress("OPTIMISM_MULTISIG");

        // simulate all actions in 'build' functions through multisig
        _simulateActions(multisig);
    }
    ```

-   `validate()`: Validates that the implementation is upgraded correctly.

    ```solidity
    function validate() public override {
        // get proxy address
        IProxy proxy = IProxy(
            addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_PROXY")
        );

        // implementation() caller must be the owner
        vm.startPrank(addresses.getAddress("OPTIMISM_PROXY_ADMIN"));

        // ensure implementation is upgraded
        require(
            proxy.implementation() ==
                addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION"),
            "Proxy implementation not set"
        );
        vm.stopPrank();
    }
    ```

## Setting Up Your Deployer Address

The deployer address is the one used to broadcast the transactions deploying the proposal contracts. Ensure your deployer address has enough funds from the faucet to cover deployment costs on the testnet. We prioritize security when it comes to private key management. To avoid storing the private key as an environment variable, we use Foundry's cast tool. Ensure the cast address is the same as the Deployer address.

If there are no wallets in the `~/.foundry/keystores/` folder, create one by executing:

```sh
cast wallet import ${wallet_name} --interactive
```

## Running the Proposal

```sh
forge script mocks/MockMultisigProposal.sol --fork-url mainnet
```

All required addresses should be in the Addresses.json file, including the `DEPLOYER_EOA` address, which will deploy the new contracts. If these don't align, the script execution will fail.

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
