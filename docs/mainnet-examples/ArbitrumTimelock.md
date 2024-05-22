# Arbitrum Timelock Proposal

## Overview

This is an mainnet example of FPS where FPS is used to simulate proposals for arbitrum timelock on L1. This example upgrades the weth gateway on L1. This proposal deploys new implementation contract `ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION` and the governance action contract `ARBITRUM_GAC_UPGRADE_WETH_GATEWAY`. Then timelock uses `upgradeExecutor` to upgrade the Weth gateway. Proposer for the L1 timelock should always be `arbitrum bridge`.

The following contract is present in the [mocks folder](../../mocks/MockTimelockProposal.sol).

Let's go through each of the functions that are overridden.

-   `name()`: Define the name of your proposal.

```solidity
function name() public pure override returns (string memory) {
    return "ARBITRUM_L1_TIMELOCK_MOCK";
}
```

-   `description()`: Provide a detailed description of your proposal.

```solidity
function description() public pure override returns (string memory) {
    return "Mock proposal that upgrades the weth gateway";
}
```

-   `deploy()`: This example demonstrates the deployment of new MockUpgrade which will be
    used as new implementation to Weth Gateway Proxy and new GAC contract for the upgrade.

```solidity
function deploy() public override {
    // Deploy new weth gateway implementation if not already deployed
    if (!addresses.isAddressSet("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION")) {
        // In a real case, this function would be responsable for
        // deployig the a new implementation contract instead of using a mock
        address l1NFTBridgeImplementation = address(new MockUpgrade());

        addresses.addAddress(
            "ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION",
            l1NFTBridgeImplementation,
            true
        );
    }

    // Deploy new gac contract for gateway upgrade if not already deployed
    if (!addresses.isAddressSet("ARBITRUM_GAC_UPGRADE_WETH_GATEWAY")) {
        address gac = address(new GovernanceActionUpgradeWethGateway());
        addresses.addAddress("ARBITRUM_GAC_UPGRADE_WETH_GATEWAY", gac, true);
    }
}
```

-   `afterDeployMock()`: Post-deployment mock actions. Such actions can include pranking, etching, etc. In this example we are setting new `outBox` for `Arbitrim bridge` using `vm.store` foundry cheatcode.

```solidity
function afterDeployMock() public override {
    // Deploy new mockOutBox address
    address mockOutbox = address(new MockOutbox());

    // This is a workaround to replace mainnet outBox to new deployed one for testing purpose only
    vm.store(
        addresses.getAddress("ARBITRUM_BRIDGE"),
        bytes32(uint256(5)),
        bytes32(uint256(uint160(mockOutbox)))
    );
}
```

-   `build()`: Set the necessary actions for your proposal, [Refer](../overview/architecture/proposal-functions.md#build-function). In this example, `ARBITRUM_L1_WETH_GATEWAY_PROXY` is upgraded to new implementation. The actions should be written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. `caller` address is passed into `buildModifier`, it will call the actions in `build`. Caller is the arbitrum timelock in this example. `buildModifier` is necessary modifier for `build` function and will not work without it.

```solidity
function build() public override buildModifier(address(timelock)) {
    /// STATICCALL -- not recorded for the run stage

    // get upgrage executor address
    IUpgradeExecutor upgradeExecutor = IUpgradeExecutor(
        addresses.getAddress("ARBITRUM_L1_UPGRADE_EXECUTOR")
    );

    /// CALLS -- mutative and recorded

    // upgrade weth gateway using gac contract to new deployed implementation
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

-   `simulate()`: Execute the proposal actions outlined in the `build()` step. This function performs a call to `_simulateActions` from the inherited `TimelockProposal` contract. Internally, `_simulateActions()` simulates a call to Timelock [scheduleBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L291) and [executeBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L385) with the calldata generated from the actions set up in the build step.

```solidity
function simulate() public override {
    // Proposer must be arbitrum bridge
    address proposer = addresses.getAddress("ARBITRUM_BRIDGE");

    // Executor can be anyone
    address executor = address(1);

    // Simulate the actions in `build` function
    _simulateActions(proposer, executor);
}
```

-   `validate()`: It validates implementation is upgraded correctly.

```solidity
function validate() public override {
    // Get proxy address
    IProxy proxy = IProxy(
        addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_PROXY")
    );

    // implementation() caller must be the owner
    vm.startPrank(addresses.getAddress("ARBITRUM_L1_PROXY_ADMIN"));

    // Ensure implementation is upgraded to new deployed implementation.
    require(
        proxy.implementation() ==
            addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION"),
        "Proxy implementation not set"
    );
    vm.stopPrank();
}
```

-   `run()`: Sets environment for running the proposal. [Refer](../overview/architecture/proposal-functions.md#run-function) It sets `addresses`, `primaryForkId` and `timelock` and calls `super.run()` to run proposal lifecycle. In this function, `primaryForkId` is set to `mainnet` and selecting the fork for running proposal. Next `addresses` object is set by reading `addresses.json` file. `addresses` contract state is persisted accross forks using `vm.makePersistent()`. Timelock is set using `setTimelock` that will be used to check onchain calldata and simulate the proposal.

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

    // Set timelock. This address is used for proposal simulation and check on
    // chain proposal state.
    timelock = ITimelockController(
        addresses.getAddress("ARBITRUM_L1_TIMELOCK")
    );

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
forge script mocks/MockTimelockProposal.sol:MockTimelockProposal --fork-url mainnet
```

All required addresses should be in the Addresses.json file including `DEPLOYER_EOA` address which will deploy the new contracts. If these don't align, the script execution will fail.

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
