# Optimism multisig Proposal

## Overview

This is an mainnet example of FPS where FPS is used to make proposals for optimism multisig on mainnet. This example upgrades L1 NFT Bridge contract. Optimism multisig calls `upgrade` on proxy contract to upgrade implementation to a new `MockUpgrade`.

The following contract is present in the [mocks/](../../mocks/) folder.

Let's go through each of the functions that are overridden.

-   `name()`: Define the name of your proposal.

```solidity
function name() public pure override returns (string memory) {
    return "OPTIMISM_MULTISIG_MOCK";
}
```

-   `description()`: Provide a detailed description of your proposal.

```solidity
function description() public pure override returns (string memory) {
    return "Mock proposal that upgrade the L1 NFT Bridge";
}
```

-   `deploy()`: This example demonstrates the deployment of new MockUpgrade which will be
    used as new implementation to proxy.

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

-   `build()`: Set the necessary actions for your proposal. [Refer](../overview/architecture/proposal-functions.md#build-function). In this example, L1 NFT Bridge is upgraded to new implementation. The actions
    should be written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. `caller` address is passed into `buildModifier` that will call actions in `build`. Caller is optimism multisig for this example. `buildModifier` is necessary modifier for `build` function and will not work without it.

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

-   `simulate()`: Execute the proposal actions outlined in the `build()` step. This
    function performs a call to `_simulateActions()` from the inherited
    `MultisigProposal` contract. Internally, `_simulateActions()` simulates a call to the [Multicall3](https://www.multicall3.com/) contract with the calldata generated from the actions set up in the build step.

```solidity
function simulate() public override {
    // get multisig address
    address multisig = addresses.getAddress("OPTIMISM_MULTISIG");

    // simulate all actions in 'build' functions through multisig
    _simulateActions(multisig);
}
```

-   `validate()`: It validates implementation is upgraded correctly.

```solidity
function validate() public override {
    // get proxy address
    IProxy proxy = IProxy(addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_PROXY"));

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

-   `run()`: Sets environment for running the proposal. [Refer](../overview/architecture/proposal-functions.md#run-function) It sets `addresses`, `primaryForkId` and calls `super.run()` to run proposal lifecycle. In this function, `primaryForkId` is set to `mainnet` and selecting the fork for running proposal. Next `addresses` object is set by reading `addresses.json` file. `addresses` contract state is persisted accross forks using `vm.makePersistent()`.
    containing addresses to be used in proposal that are fetched from `Addresses.json`.

```solidity
function run() public override {
    // Create and select mainnet fork for proposal execution.
    primaryForkId = vm.createFork("mainnet");
    vm.selectFork(primaryForkId);

    // Set addresses object reading addresses from json file.
    addresses = new Addresses(
        vm.envOr("ADDRESSES_PATH", string("./addresses/Addresses.json"))
    );

    // Make 'addresses' state persist across selected fork.
    vm.makePersistent(address(addresses));

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
forge script mocks/MockMultisigProposal.sol --fork-url mainnet
```

All required addresses should be in the Addresses.json file including `DEPLOYER_EOA` address which will deploy the new contracts. If these don't align, the script execution will fail.

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
