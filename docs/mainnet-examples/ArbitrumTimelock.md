# Arbitrum Timelock Proposal

## Overview

This example showcases how FPS can be utilized for simulating proposals for the Arbitrum timelock on L1. Specifically, it upgrades the WETH gateway on L1. The proposal involves deploying a new implementation contract `ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION` and a governance action contract `ARBITRUM_GAC_UPGRADE_WETH_GATEWAY`. Then, the timelock employs `upgradeExecutor` to upgrade the WETH gateway. The proposer for the L1 timelock should always be the Arbitrum bridge.

The relevant contract can be found in the [mocks folder](../../mocks/MockTimelockProposal.sol).

Let's review each of the overridden functions:

-   `name()`: Defines the name of the proposal.

    ```solidity
    function name() public pure override returns (string memory) {
        return "ARBITRUM_L1_TIMELOCK_MOCK";
    }
    ```

-   `description()`: Provides a detailed description of the proposal.

    ```solidity
    function description() public pure override returns (string memory) {
        return "Mock proposal for upgrading the WETH gateway";
    }
    ```

-   `deploy()`: This function demonstrates the deployment of a new MockUpgrade, which will be used as the new implementation for the WETH Gateway Proxy and a new GAC contract for the upgrade.

    ```solidity
    function deploy() public override {
        // Deploy new WETH gateway implementation if not already deployed
        if (
            !addresses.isAddressSet("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION")
        ) {
            // In a real case, this function would be responsible for
            // deploying a new implementation contract instead of using a mock
            address l1NFTBridgeImplementation = address(new MockUpgrade());

            addresses.addAddress(
                "ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION",
                l1NFTBridgeImplementation,
                true
            );
        }

        // Deploy new GAC contract for gateway upgrade if not already deployed
        if (!addresses.isAddressSet("ARBITRUM_GAC_UPGRADE_WETH_GATEWAY")) {
            address gac = address(new GovernanceActionUpgradeWethGateway());
            addresses.addAddress(
                "ARBITRUM_GAC_UPGRADE_WETH_GATEWAY",
                gac,
                true
            );
        }
    }
    ```

    Since these changes do not persist from runs themselves, after the contracts are deployed, the user must update the Addresses.json file with the newly deployed contract addresses.

-   `afterDeployMock()`: Post-deployment mock actions, such as setting a new `outBox` for `Arbitrum bridge` using `vm.store` foundry cheatcode.

    ```solidity
    function afterDeployMock() public override {
        // Deploy new mockOutBox address
        address mockOutbox = address(new MockOutbox());

        // This is a workaround to replace the mainnet outBox with the newly deployed one for testing purposes only
        vm.store(
            addresses.getAddress("ARBITRUM_BRIDGE"),
            bytes32(uint256(5)),
            bytes32(uint256(uint160(mockOutbox)))
        );
    }
    ```

-   `build()`: Add actions to the proposal contract. [See build function](../overview/architecture/proposal-functions.md#build-function). In this example, `ARBITRUM_L1_WETH_GATEWAY_PROXY` is upgraded to the new implementation. The actions should be written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. The The `caller` address is passed into `buildModifier`; it will call the actions in `build`. The caller is the Arbitrum timelock in this example. `buildModifier` is a necessary modifier for the `build` function and will not work without it.

    ```solidity
    function build() public override buildModifier(address(timelock)) {
        /// STATICCALL -- not recorded for the run stage

        // Get upgrade executor address
        IUpgradeExecutor upgradeExecutor = IUpgradeExecutor(
            addresses.getAddress("ARBITRUM_L1_UPGRADE_EXECUTOR")
        );

        /// CALLS -- mutative and recorded

        // Upgrade WETH gateway using GAC contract to the newly deployed implementation
        upgradeExecutor.execute(
            addresses.getAddress("ARBITRUM_GAC_UPGRADE_WETH_GATEWAY"),
            abi.encodeWithSelector(
                GovernanceActionUpgradeWethGateway.upgradeWethGateway.selector,
                addresses.getAddress("ARBITRUM_L1_PROXY_ADMIN"),
                addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_PROXY"),
                addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION")
            )
        );
    }
    ```

-   `run()`: Sets up the environment for running the proposal. [See run function](../overview/architecture/proposal-functions.md#run-function). This sets `addresses`, `primaryForkId`, and `timelock` and calls `super.run()` to run the entire proposal. In this example, `primaryForkId` is set to `mainnet` and the fork for running the proposal is selected. Next, the `addresses` object is set by reading the `addresses.json` file. The `addresses` contract state is persistent across forks by using foundry's `vm.makePersistent()` cheatcode. The timelock address to simulate the proposal through is set using `setTimelock`. This will be used to check onchain calldata and simulate the proposal.

    ```solidity
    function run() public override {
        // Create and select the mainnet fork for proposal execution
        primaryForkId = vm.createFork("mainnet");
        vm.selectFork(primaryForkId);

        // Set the addresses object by reading addresses from the json file
        addresses = new Addresses(
            vm.envOr("ADDRESSES_PATH", string("./addresses/Addresses.json"))
        );

        // Make the 'addresses' state persist across the selected fork
        vm.makePersistent(address(addresses));

        // Set the timelock. This address is used for proposal simulation and checking on-chain proposal state
        timelock = ITimelockController(
            addresses.getAddress("ARBITRUM_L1_TIMELOCK")
        );

        // Call the run function of the parent contract 'Proposal.sol'
        super.run();
    }
    ```

-   `simulate()`: Executes the proposal actions outlined in the `build()` step. This function performs a call to `_simulateActions` from the inherited `TimelockProposal` contract. Internally, `_simulateActions()` simulates a call to Timelock [scheduleBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L291) and [executeBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L385) with the calldata generated from the actions set up in the build step.

    ```solidity
    function simulate() public override {
        // Proposer must be the Arbitrum bridge
        address proposer = addresses.getAddress("ARBITRUM_BRIDGE");

        // Executor can be anyone
        address executor = address(1);

        // Simulate the actions in the `build` function
        _simulateActions(proposer, executor);
    }
    ```

-   `validate()`: Validates that the implementation is upgraded correctly.

    ```solidity
    function validate() public override {
        // Get proxy address
        IProxy proxy = IProxy(
            addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_PROXY")
        );

        // Ensure implementation is upgraded to the newly deployed implementation
        require(
            proxy.implementation() ==
                addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION"),
            "Proxy implementation not set"
        );
    }
    ```

## Setting Up Your Deployer Address

The deployer address is the one used to broadcast the transactions deploying the proposal contracts. Ensure your deployer address has enough funds from the faucet to cover deployment costs on the testnet. We prioritize security when it comes to private key management. To avoid storing the private key as an environment variable, we use Foundry's cast tool. Ensure the cast address is the same as the deployer address.

If there are no wallets in the `~/.foundry/keystores/` folder, create one by executing:

```sh
cast wallet import ${wallet_name} --interactive
```

## Running the Proposal

```sh
forge script mocks/MockTimelockProposal.sol:MockTimelockProposal --fork-url mainnet
```

All required addresses should be in the Addresses.json file, including `DEPLOYER_EOA` address, which will deploy the new contracts. If these don't align, the script execution will fail.

The script will output the following:

```sh
== Logs ==


--------- Addresses added ---------
  {
          'addr': '0x714CB817EfD08fEe91558b07A924a87C3587F3C1',
          'chainId': 1,
          'isContract': true ,
          'name': 'ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION'
},
  {
          'addr': '0x56a0dFA59fD02284D1b39327CfE92251051Da6bb',
          'chainId': 1,
          'isContract': true ,
          'name': 'ARBITRUM_GAC_UPGRADE_WETH_GATEWAY'
}

---------------- Proposal Description ----------------
  Mock proposal that upgrades the weth gateway

------------------ Proposal Actions ------------------
  1). calling 0x3ffFbAdAF827559da092217e474760E2b2c3CeDd with 0 eth and 0x1cff79cd00000000000000000000000056a0dfa59fd02284d1b39327cfe92251051da6bb0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006409b461c10000000000000000000000009ad46fac0cf7f790e5be05a0f15223935a0c0ada000000000000000000000000d92023e9d9911199a6711321d1277285e6d4e2db000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c100000000000000000000000000000000000000000000000000000000 data.
  target: 0x3ffFbAdAF827559da092217e474760E2b2c3CeDd
payload
  0x1cff79cd00000000000000000000000056a0dfa59fd02284d1b39327cfe92251051da6bb0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006409b461c10000000000000000000000009ad46fac0cf7f790e5be05a0f15223935a0c0ada000000000000000000000000d92023e9d9911199a6711321d1277285e6d4e2db000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c100000000000000000000000000000000000000000000000000000000




------------------ Schedule Calldata ------------------
  0x8f2a0bb000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000000050deb3e0ef55ff1976003bef5ca1a251beebbeb0d17ef15e6340ea825bbfe8e8000000000000000000000000000000000000000000000000000000000003f48000000000000000000000000000000000000000000000000000000000000000010000000000000000000000003fffbadaf827559da092217e474760e2b2c3cedd000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000e41cff79cd00000000000000000000000056a0dfa59fd02284d1b39327cfe92251051da6bb0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006409b461c10000000000000000000000009ad46fac0cf7f790e5be05a0f15223935a0c0ada000000000000000000000000d92023e9d9911199a6711321d1277285e6d4e2db000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000


------------------ Execute Calldata ------------------
  0xe38335e500000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000050deb3e0ef55ff1976003bef5ca1a251beebbeb0d17ef15e6340ea825bbfe8e800000000000000000000000000000000000000000000000000000000000000010000000000000000000000003fffbadaf827559da092217e474760e2b2c3cedd000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000e41cff79cd00000000000000000000000056a0dfa59fd02284d1b39327cfe92251051da6bb0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006409b461c10000000000000000000000009ad46fac0cf7f790e5be05a0f15223935a0c0ada000000000000000000000000d92023e9d9911199a6711321d1277285e6d4e2db000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
```
