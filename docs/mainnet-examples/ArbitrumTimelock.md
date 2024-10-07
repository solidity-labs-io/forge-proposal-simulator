# Arbitrum Timelock Proposal

## Overview

This example showcases how FPS can be utilized for simulating proposals for the Arbitrum timelock on mainnet. Specifically, it upgrades the WETH gateway on L1. The proposal involves deploying a new implementation contract `ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION` and a governance action contract `ARBITRUM_GAC_UPGRADE_WETH_GATEWAY`. Then, the timelock employs `upgradeExecutor` to upgrade the WETH gateway. The proposer for the L1 timelock should always be the Arbitrum bridge.

The relevant contract can be found in the [mocks folder](../../mocks/MockTimelockProposal.sol).

Let's review each of the overridden functions:

- `name()`: Defines the name of the proposal.

  ```solidity
  function name() public pure override returns (string memory) {
      return "ARBITRUM_L1_TIMELOCK_MOCK";
  }
  ```

- `description()`: Provides a detailed description of the proposal.

  ```solidity
  function description() public pure override returns (string memory) {
      return "Mock proposal for upgrading the WETH gateway";
  }
  ```

- `deploy()`: This function demonstrates the deployment of a new MockUpgrade, which will be used as the new implementation for the WETH Gateway Proxy and a new GAC contract for the upgrade.

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

- `preBuildMock()`: Post-deployment mock actions, such as setting a new `outBox` for `Arbitrum bridge` using `vm.store` foundry cheatcode.

  ```solidity
  function preBuildMock() public override {
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

- `build()`: Add actions to the proposal contract. In this example, `ARBITRUM_L1_WETH_GATEWAY_PROXY` is upgraded to the new implementation. The actions should be written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. The `caller` address is passed into `buildModifier`; it will call the actions in `build`. The caller is the Arbitrum timelock in this example. The `buildModifier` is a necessary modifier for the `build` function and will not work without it. For further reading, see the [build function](../overview/architecture/proposal-functions.md#build-function).

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

- `run()`: Sets up the environment for running the proposal, and executes all proposal actions. This sets `addresses`, `primaryForkId`, and `timelock` and calls `super.run()` to run the entire proposal. In this example, `primaryForkId` is set to `mainnet` and the fork for running the proposal is selected. Next, the `addresses` object is set by reading the JSON file. The timelock contract to test is set using `setTimelock`. This will be used to check onchain calldata and simulate the proposal. For further reading, see the [run function](../overview/architecture/proposal-functions.md#run-function).

  ```solidity
  function run() public override {
      // Create and select the mainnet fork for proposal execution
      primaryForkId = vm.createFork("mainnet");
      vm.selectFork(primaryForkId);

      uint256[] memory chainIds = new uint256[](1);
      chainIds[0] = 1;
      // Set the addresses object by reading addresses from the json file
      addresses = new Addresses(
          vm.envOr("ADDRESSES_PATH", string("./addresses")), chainIds
      );

      // Set the timelock. This address is used for proposal simulation and checking on-chain proposal state
      setTimelock(addresses.getAddress("ARBITRUM_L1_TIMELOCK"));

      // Call the run function of the parent contract 'Proposal.sol'
      super.run();
  }
  ```

- `simulate()`: Executes the proposal actions outlined in the `build()` step. This function performs a call to `_simulateActions` from the inherited `TimelockProposal` contract. Internally, `_simulateActions()` simulates a call to Timelock [scheduleBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L291) and [executeBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L385) with the calldata generated from the actions set up in the build step.

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

- `validate()`: Validates that the implementation is upgraded correctly.

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

## Running the Proposal

```sh
forge script mocks/MockTimelockProposal.sol:MockTimelockProposal --fork-url mainnet
```

All required addresses should be in the JSON file, including `DEPLOYER_EOA` address, which will deploy the new contracts. If these do not align, the script execution will fail.

The script will output the following:

```sh
== Logs ==


--------- Addresses added ---------
  {
          "addr": "0x714CB817EfD08fEe91558b07A924a87C3587F3C1",
          "isContract": true,
          "name": "ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION"
},
  {
          "addr": "0x56a0dFA59fD02284D1b39327CfE92251051Da6bb",
          "isContract": true,
          "name": "ARBITRUM_GAC_UPGRADE_WETH_GATEWAY"
}

---------------- Proposal Description ----------------
  Mock proposal that upgrades the weth gateway

------------------ Proposal Actions ------------------
  1). calling ARBITRUM_L1_UPGRADE_EXECUTOR @0x3ffFbAdAF827559da092217e474760E2b2c3CeDd with 0 eth and 0x1cff79cd00000000000000000000000056a0dfa59fd02284d1b39327cfe92251051da6bb0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006409b461c10000000000000000000000009ad46fac0cf7f790e5be05a0f15223935a0c0ada000000000000000000000000d92023e9d9911199a6711321d1277285e6d4e2db000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c100000000000000000000000000000000000000000000000000000000 data.
  target: ARBITRUM_L1_UPGRADE_EXECUTOR @0x3ffFbAdAF827559da092217e474760E2b2c3CeDd
payload
  0x1cff79cd00000000000000000000000056a0dfa59fd02284d1b39327cfe92251051da6bb0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006409b461c10000000000000000000000009ad46fac0cf7f790e5be05a0f15223935a0c0ada000000000000000000000000d92023e9d9911199a6711321d1277285e6d4e2db000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c100000000000000000000000000000000000000000000000000000000



----------------- Proposal Changes ---------------


 ARBITRUM_L1_UPGRADE_EXECUTOR @0x3ffFbAdAF827559da092217e474760E2b2c3CeDd:

 State Changes:
  Slot: 0x0000000000000000000000000000000000000000000000000000000000000097
  -  0x0000000000000000000000000000000000000000000000000000000000000001
  +  0x0000000000000000000000000000000000000000000000000000000000000002
  Slot: 0x0000000000000000000000000000000000000000000000000000000000000097
  -  0x0000000000000000000000000000000000000000000000000000000000000002
  +  0x0000000000000000000000000000000000000000000000000000000000000001


 ARBITRUM_L1_WETH_GATEWAY_PROXY @0xd92023E9d9911199a6711321D1277285e6d4e2db:

 State Changes:
  Slot: 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
  -  0x0000000000000000000000004b8e9b3f253e68837bf719997b1eeb9e8f1960e2
  +  0x000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c1


------------------ Schedule Calldata ------------------
  0x8f2a0bb000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000000050deb3e0ef55ff1976003bef5ca1a251beebbeb0d17ef15e6340ea825bbfe8e8000000000000000000000000000000000000000000000000000000000003f48000000000000000000000000000000000000000000000000000000000000000010000000000000000000000003fffbadaf827559da092217e474760e2b2c3cedd000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000e41cff79cd00000000000000000000000056a0dfa59fd02284d1b39327cfe92251051da6bb0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006409b461c10000000000000000000000009ad46fac0cf7f790e5be05a0f15223935a0c0ada000000000000000000000000d92023e9d9911199a6711321d1277285e6d4e2db000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000


------------------ Execute Calldata ------------------
  0xe38335e500000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000050deb3e0ef55ff1976003bef5ca1a251beebbeb0d17ef15e6340ea825bbfe8e800000000000000000000000000000000000000000000000000000000000000010000000000000000000000003fffbadaf827559da092217e474760e2b2c3cedd000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000e41cff79cd00000000000000000000000056a0dfa59fd02284d1b39327cfe92251051da6bb0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006409b461c10000000000000000000000009ad46fac0cf7f790e5be05a0f15223935a0c0ada000000000000000000000000d92023e9d9911199a6711321d1277285e6d4e2db000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
```

It is crucial to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON files when proposal is run without the `DO_UPDATE_ADDRESS_JSON` flag set to true.
