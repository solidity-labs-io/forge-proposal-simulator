# Customizing Proposals

## Overview

The framework is designed to be flexible and loosely coupled, as explained at the end of [proposal functions](../overview/architecture/proposal-functions.md#flexibility). However, in some cases, additional customization may be required. Currently, FPS supports four types of proposals, each of which can be further customized to meet specific requirements. This guide will explore an example where the OZ Governor proposal type is customized to implement Arbitrum cross-chain proposals. Arbitrum's governance process involves the use of an OZ governor with a timelock extension on Arbitrum L2 and a simple timelock on L1. The proposal's path is determined by whether it is targeting L1 or L2. Regardless of whether its final destination is an L2 contract, every Arbitrum proposal must go through a settlement process on Layer 1.

The following steps from 1 to 5 are equal no matter which chain the proposal final contract target is deployed:

1. Proposal is created on L2 Governor
2. Proposal is voted on and passes
3. Proposal is queued on L2 timelock
4. Proposal is executed on L2 timelock after the delay, and therefore initiates a bridge request to L1 inbox by calling the ArbSys precompiled contract
5. After the bridge delay of 1 week, anyone can call the Bridge contract on L1 using the merkle proof generated for the proposal calldata, effectively scheduling the proposal on the L1 Timelock
6. Once the proposal is scheduled on the L1 Timelock, there is a three-day delay before it becomes executable. When executed, it can follow two different paths. If the target is an L1 contract, the proposal follows the standard OpenZeppelin Timelock path. For L2 proposals, identified by the target being a Retryable Ticket Magic address, a call to the L1 inbox generates the L2 ticket. Once it is bridged to L2, anyone can execute the ticket. The ticket is responsible for calling the final contract target, which, for proposals that are Arbitrum contract upgrades, will be the Arbitrum Upgrade Executor Contract.

Read more about Arbitrum Governance [here](https://docs.arbitrum.foundation/gentle-intro-dao-governance).

It is worth noting that the Arbitrum governance process has its own specifications and is not a straightforward implementation of the OZ Governor contract. Therefore, it is not possible to directly use the OZ Governor proposal type to simulate an Arbitrum proposal. Customization is needed to accommodate FPS for creating and testing Arbitrum proposals. Thanks to FPS flexibility, this is possible without much extra effort.

## Extending FPS for accommodate Arbitrum Governance

The [Arbitrum Proposal Type](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/arbitrum/ArbitrumProposal.sol) demonstrates the framework's flexibility. Let's go through each of its functions:

- `setEthForkId(uint256)`: used to create the Ethereum fork using Foundry as Arbitrum Governance is cross-chain. This function will be set by the child proposal.

  ```solidity
  /// @notice set eth fork id
  function setEthForkId(uint256 _forkId) public {
      ethForkId = _forkId;
  }
  ```

- `preBuildMock()`: deploys the `MockOutBox` contract and points on the `Arbitrum Bridge` with the help of the `vm.store` foundry cheatcode. Additionally, it embeds the `MockArbSys` bytecode at the `Arbitrum sys` contract address. As previously mentioned in the overview section, the calldata for the L2 proposal needs to be a call to the `sendTxToL1` on the ArbSys precompiled contract. This call requires the L1 timelock contract address as the first parameter and the L1 timelock schedule calldata as the second parameter. The `MockArbOutbox` is employed to replicate off-chain actions. The bridge ensures that the schedule was initiated by the L2 timelock by calling `l1ToL2Sender` in the outbox contract. This ensures that the bridge verification is successful, even though no genuine off-chain actions have been executed. These two mock functionalities are crucial for the arbitrum proposal flow, and here, it can be observed how FPS simplifies the simulation of such a complex proposal flow.

  ```solidity
  /// @title MockArbSys
  /// @notice a mocked version of the Arbitrum pre-compiled system contract, add additional methods as needed
  contract MockArbSys {
      uint256 public ticketId;

      function sendTxToL1(
          address _l1Target,
          bytes memory _data
      ) external payable returns (uint256) {
          (bool success, ) = _l1Target.call(_data);
          require(success, "Arbsys: sendTxToL1 failed");
          return ++ticketId;
      }
  }

  // @title MockArbOutbox
  // @notice Mock arbitrum outbox to return L2 timelock on l2ToL1Sender call
  contract MockArbOutbox {
      function l2ToL1Sender() external pure returns (address) {
          return 0x34d45e99f7D8c45ed05B5cA72D54bbD1fb3F98f0;
      }
  }

  /// @notice mock arb sys precompiled contract on L2
  ///         mock outbox on mainnet
  function preBuildMock() public override {
      // switch to mainnet fork to mock arb outbox
      vm.selectFork(ethForkId);
      address mockOutbox = address(new MockArbOutbox());

      vm.store(
          addresses.getAddress("ARBITRUM_BRIDGE"),
          bytes32(uint256(5)),
          bytes32(uint256(uint160(mockOutbox)))
      );

      vm.selectFork(primaryForkId);

      address arbsys = address(new MockArbSys());
      vm.makePersistent(arbsys);

      vm.etch(addresses.getAddress("ARBITRUM_SYS"), address(arbsys).code);
  }
  ```

- `_validateActions()`: Validates proposal actions. An arbitrum proposal should have a single action. This method checks that there is only one action in the proposal and the target contract is not the zero address. Furthermore, it also checks that there are no actions without arguments and value, and if the execution chain is `L2`, no `ETH` is transferred (value = 0).

  ```solidity
  /// @notice Arbitrum proposals should have a single action
  function _validateActions() internal view override {
      uint256 actionsLength = actions.length;

      require(
          actionsLength == 1,
          "Arbitrum proposals must have a single action"
      );

      require(actions[0].target != address(0), "Invalid target for proposal");
      /// if there are no args and no eth, the action is not valid
      require(
          (actions[0].arguments.length == 0 && actions[0].value > 0) ||
              actions[0].arguments.length > 0,
          "Invalid arguments for proposal"
      );

      // Value is ignored on L2 proposals
      if (executionChain == ProposalExecutionChain.ARB_ONE) {
          require(actions[0].value == 0, "Value must be 0 for L2 execution");
      }
  }
  ```

- `getScheduleTimelockCaldata()`: This function returns calldata to schedule proposal actions on the L1 timelock. Calldata is generated based on the execution chain where the proposal will be executed. If the execution chain is the L1, then the build target is the target contract but if the execution chain is L2 chain then target is `RETRYABLE_TICKET_MAGIC` contract and the build target is encoded in the calldata along with the inbox contract address.

  ```solidity
  /// @notice get the calldata to schedule the timelock on L1
  ///         the L1 schedule calldata must be the calldata for all arbitrum proposals
  function getScheduleTimelockCaldata()
      public
      view
      returns (bytes memory scheduleCalldata)
  {
      // address only used if is a L2 proposal
      address inbox;

      if (executionChain == ProposalExecutionChain.ARB_ONE) {
          inbox = arbOneInbox;
      } else if (executionChain == ProposalExecutionChain.ARB_NOVA) {
          inbox = arbNovaInbox;
      }

      scheduleCalldata = abi.encodeWithSelector(
          ITimelockController.schedule.selector,
          // if the action is to be executed on l1, the target is the actual
          // target, otherwise it is the magic value that tells that the
          // proposal must be relayed back to l2
          executionChain == ProposalExecutionChain.ETH
              ? actions[0].target
              : RETRYABLE_TICKET_MAGIC, // target
          actions[0].value, // value
          executionChain == ProposalExecutionChain.ETH
              ? actions[0].arguments
              : abi.encode( // these are the retryable data params
                      // the inbox contract used, should be arb one or nova
                      inbox,
                      addresses.getAddress("ARBITRUM_L2_UPGRADE_EXECUTOR"), // the upgrade executor on the l2 network
                      0, // no value in this upgrade
                      0, // max gas - will be filled in when the retryable is actually executed
                      0, // max fee per gas - will be filled in when the retryable is actually executed
                      actions[0].arguments // calldata created on the build function
                  ),
          bytes32(0), // no predecessor
          keccak256(abi.encodePacked(description())), // salt is prop description
          minDelay // delay for this proposal
      );
  }
  ```

- `getProposalActions()`: This function returns proposal actions to propose on arbitrum governor. Arbitrum proposals must have a single action which must be a call to ArbSys address with the L1 timelock schedule calldata.

  ```solidity
  /// @notice get proposal actions
  /// @dev Arbitrum proposals must have a single action which must be a call
  /// to ArbSys address with the l1 timelock schedule calldata
  function getProposalActions()
      public
      view
      override
      returns (
          address[] memory targets,
          uint256[] memory values,
          bytes[] memory arguments
      )
  {
      _validateActions();

      // inner calldata must be a call to schedule on L1Timelock
      bytes memory innerCalldata = getScheduleTimelockCaldata();

      targets = new address[](1);
      values = new uint256[](1);
      arguments = new bytes[](1);

      bytes memory callData = abi.encodeWithSelector(
          MockArbSys.sendTxToL1.selector,
          addresses.getAddress("ARBITRUM_L1_TIMELOCK", 1),
          innerCalldata
      );

      // Arbitrum proposals target must be the ArbSys precompiled address
      targets[0] = addresses.getAddress("ARBITRUM_SYS");
      values[0] = 0;
      arguments[0] = callData;
  }
  ```

- `simulate()`: Executes the proposal actions outlined in the `build()` step. Initial steps to simulate a proposal are the same as `simulate()` method in [OZ Governor Proposal](./oz-governor-proposal.md) as Arbitrum also uses OZ Governor with timelock for L2 governance. `super.simulate()` is called at the start of the method. Next, further steps for the proposal simulation are added. These steps can be understood by going through the overview section of this guide and the code snippet below with inline comments.

  ```solidity
  /// @notice override the OZGovernorProposal simulate function to handle
  ///         the proposal L1 settlement
  function simulate() public override {
      // First part of Arbitrum Governance proposal path follows the OZ
      // Governor with TimelockController extension
      super.simulate();

      // Second part of Arbitrum Governance proposal path is the proposal
      // settlement on the L1 network
      bytes memory scheduleCalldata = getScheduleTimelockCaldata();

      // switch fork to mainnet
      vm.selectFork(ethForkId);

      // prank as the bridge
      vm.startPrank(addresses.getAddress("ARBITRUM_BRIDGE"));

      address l1TimelockAddress = addresses.getAddress(
          "ARBITRUM_L1_TIMELOCK"
      );

      ITimelockController timelock = ITimelockController(l1TimelockAddress);

      address target;
      uint256 value;
      bytes memory data;
      bytes32 predecessor;

      {
          // Start recording logs so we can create the execute calldata using the
          // CallSchedule log data
          vm.recordLogs();

          // Call the schedule function on the L1 timelock
          l1TimelockAddress.functionCall(scheduleCalldata);

          // Stop recording logs
          Vm.Log[] memory entries = vm.getRecordedLogs();

          // Get the execute parameters from schedule call logs
          (target, value, data, predecessor, ) = abi.decode(
              entries[0].data,
              (address, uint256, bytes, bytes32, uint256)
          );

          // warp to the future to execute the proposal
          vm.warp(block.timestamp + minDelay);
      }

      vm.stopPrank();

      {
          // Start recording logs so we can get the TxToL2 log data
          vm.recordLogs();

          // execute the proposal
          timelock.execute(
              target,
              value,
              data,
              predecessor,
              keccak256(abi.encodePacked(description()))
          );

          // Stop recording logs
          Vm.Log[] memory entries = vm.getRecordedLogs();

          // If is a retriable ticket, we need to execute on L2
          if (target == RETRYABLE_TICKET_MAGIC) {
              // entries index 2 is TxToL2
              // topic with index 2 is the l2 target address
              address to = address(uint160(uint256(entries[2].topics[2])));

              bytes memory l2Calldata = abi.decode(entries[2].data, (bytes));

              // Switch back to primary fork, must be either Arb One or Arb Nova
              vm.selectFork(primaryForkId);

              // Perform the low-level call
              vm.prank(addresses.getAddress("ARBITRUM_ALIASED_L1_TIMELOCK"));
              bytes memory returndata = to.functionCall(l2Calldata);

              if (DEBUG && returndata.length > 0) {
                  console.log("Target %s called on L2 and returned:", to);
                  console.logBytes(returndata);
              }
          }
      }
  }
  ```

## Proposal contract

Two proposals were added to the fps-example-repo. First, [ArbitrumPorposal_01](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/arbitrum/ArbitrumProposal_01.sol) which is an Arbitrum proposal that executes on L2. Second, [ArbitrumPorposal_02](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/arbitrum/ArbitrumProposal_02.sol) which is an arbitrum proposal that executes on L1. Let's first have a look at `ArbitrumPorposal_02` by going through the code snippets:

- `constructor()`: Execution chain is set to ethereum mainnet in constructor.

  ```solidity
  constructor() {
      executionChain = ProposalExecutionChain.ETH;
  }
  ```

- `name()`: Defines the name of the proposal.

  ```solidity
  function name() public pure override returns (string memory) {
      return "ARBITRUM_PROPOSAL_02";
  }
  ```

- `description()`: Provides a detailed description of the proposal.

  ```solidity
  function description() public pure override returns (string memory) {
      return "This proposal upgrades the L1 weth gateway";
  }
  ```

- `deploy()`: This function deploys any necessary contracts. In this example the new weth gateway implementation contract and the GAC contract are deployed on L1. Once deployed, these contracts are added to the `Addresses` contract by calling `addAddress()`.

  ```solidity
  function deploy() public override {
      if (
          !addresses.isAddressSet("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION")
      ) {
          address mockUpgrade = address(new MockUpgrade());

          addresses.addAddress(
              "ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION",
              mockUpgrade,
              true
          );
      }

      if (!addresses.isAddressSet("PROXY_UPGRADE_ACTION")) {
          address gac = address(new MockProxyUpgradeAction());

          addresses.addAddress("PROXY_UPGRADE_ACTION", gac, true);
      }
  }
  ```

- `build()`: Add the needed actions to update the Arbitrum WETH Gateway on L1. For more in-depth information on how this process operates behind the scenes, please refer to the [build function](../overview/architecture/proposal-functions.md#build-function).

  ```solidity
  function build()
      public
      override
      buildModifier(addresses.getAddress("ARBITRUM_L1_TIMELOCK", 1))
  {
      // select etherem mainnet fork as this proposal upgrades weth gateway on L1
      vm.selectFork(ethForkId);

      IUpgradeExecutor upgradeExecutor = IUpgradeExecutor(
          addresses.getAddress("ARBITRUM_L1_UPGRADE_EXECUTOR")
      );

      upgradeExecutor.execute(
          addresses.getAddress("PROXY_UPGRADE_ACTION"),
          abi.encodeWithSelector(
              MockProxyUpgradeAction.perform.selector,
              addresses.getAddress("ARBITRUM_L1_PROXY_ADMIN"),
              addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_PROXY"),
              addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION")
          )
      );

      vm.selectFork(primaryForkId);
  }
  ```

- `run()`: Serves as the entrypoint for executing the proposal by `forge script`. In this example, 'primaryForkId' is configured as 'Arbitrum' to execute the proposal on L2. Subsequently, 'ethForkId' is also set as every Arbitrum proposal must undergo a settlement process on L1, regardless of the final execution chain target. The address of the Arbitrum L2 governor's contract is set using 'setGovernor' to simulate the proposal. This address will be used later to verify on-chain calldata and simulate the proposal. For further reading, see the [run function](../overview/architecture/proposal-functions.md#run-function).

  ```solidity
  function run() public override {
      string memory addressesFolderPath = "./addresses";
      uint256[] memory chainIds = new uint256[](2);
      chainIds[0] = 1;
      chainIds[1] = 42161;
      addresses = new Addresses(addressesFolderPath, chainIds);
      vm.makePersistent(address(addresses));

      setPrimaryForkId(vm.createFork("arbitrum"));

      setEthForkId(vm.createFork("ethereum"));

      /// select arbitrum fork to set governor address
      vm.selectFork(primaryForkId);

      setGovernor(addresses.getAddress("ARBITRUM_L2_CORE_GOVERNOR"));

      /// select ethereum mainnet fork as contracts are deployed on ethereum mainnet
      vm.selectFork(ethForkId);

      super.run();
  }
  ```

- `validate()`: This final step validates the system in its post-execution state. It ensures that gateway proxy is upgraded to new implementation on L1. Only the proxy owner can call `implementation()` method to check its implementation address.

  ```solidity
  function validate() public override {
      vm.selectFork(ethForkId);

      IProxy proxy = IProxy(
          addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_PROXY")
      );

      // implementation() caller must be the owner
      vm.startPrank(addresses.getAddress("ARBITRUM_L1_PROXY_ADMIN"));
      require(
          proxy.implementation() ==
              addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION"),
          "Proxy implementation not set"
      );

      vm.stopPrank();

      vm.selectFork(primaryForkId);
  }
  ```

Now let's have a look at `ArbitrumProposal_02`:

- `constructor()`: Execution chain is set to arbitrum one chain in constructor.

  ```solidity
  constructor() {
      executionChain = ProposalExecutionChain.ARB_ONE;
  }
  ```

- `name()`: Defines the name of the proposal.

  ```solidity
  function name() public pure override returns (string memory) {
      return "ARBITRUM_PROPOSAL_01";
  }
  ```

- `description()`: Provides a detailed description of the proposal.

  ```solidity
  function description() public pure override returns (string memory) {
      return "This proposal upgrades the L2 weth gateway";
  }
  ```

- `deploy()`: This function deploys any necessary contracts. In this example the new weth gateway implementation contract and the GAC contract are deployed on L2. Once deployed, these contracts are added to the `Addresses` contract by calling `addAddress()`.

  ```solidity
  function deploy() public override {
      if (
          !addresses.isAddressSet("ARBITRUM_L2_WETH_GATEWAY_IMPLEMENTATION")
      ) {
          address mockUpgrade = address(new MockUpgrade());

          addresses.addAddress(
              "ARBITRUM_L2_WETH_GATEWAY_IMPLEMENTATION",
              mockUpgrade,
              true
          );
      }

      if (!addresses.isAddressSet("PROXY_UPGRADE_ACTION")) {
          address gac = address(new MockProxyUpgradeAction());
          addresses.addAddress("PROXY_UPGRADE_ACTION", gac, true);
      }
  }
  ```

- `build()`: Add the needed actions to update the Arbitrum WETH Gateway on L2. For more in-depth information on how this process operates behind the scenes, please refer to the [build function](../overview/architecture/proposal-functions.md#build-function).

  ```solidity
  function build()
      public
      override
      buildModifier(addresses.getAddress("ARBITRUM_ALIASED_L1_TIMELOCK"))
  {
      IUpgradeExecutor upgradeExecutor = IUpgradeExecutor(
          addresses.getAddress("ARBITRUM_L2_UPGRADE_EXECUTOR")
      );

      upgradeExecutor.execute(
          addresses.getAddress("PROXY_UPGRADE_ACTION"),
          abi.encodeWithSelector(
              MockProxyUpgradeAction.perform.selector,
              addresses.getAddress("ARBITRUM_L2_PROXY_ADMIN"),
              addresses.getAddress("ARBITRUM_L2_WETH_GATEWAY_PROXY"),
              addresses.getAddress("ARBITRUM_L2_WETH_GATEWAY_IMPLEMENTATION")
          )
      );
  }
  ```

- `run()`: Serves as the entrypoint for executing the proposal by `forge script`. In this example, 'primaryForkId' is configured as 'Arbitrum' to execute the proposal on L2. Subsequently, 'ethForkId' is also set as every Arbitrum proposal must undergo a settlement process on L1, regardless of the final execution chain target. The address of the Arbitrum L2 governor's contract is set using 'setGovernor' to simulate the proposal. This address will be used later to verify on-chain calldata and simulate the proposal. For further reading, see the [run function](../overview/architecture/proposal-functions.md#run-function).

  ```solidity
  function run() public override {
      string memory addressesFolderPath = "./addresses";
      uint256[] memory chainIds = new uint256[](2);
      chainIds[0] = 1;
      chainIds[1] = 42161;
      addresses = new Addresses(addressesFolderPath, chainIds);
      vm.makePersistent(address(addresses));

      setPrimaryForkId(vm.createFork("arbitrum"));

      setEthForkId(vm.createFork("ethereum"));

      vm.selectFork(primaryForkId);

      setGovernor(addresses.getAddress("ARBITRUM_L2_CORE_GOVERNOR"));

      super.run();
  }
  ```

- `validate()`: This final step validates the system in its post-execution state. It ensures that gateway proxy is upgraded to new implementation. Only proxy owner can call `implementation()` method to check implementation.

  ```solidity
  function validate() public override {
      IProxy proxy = IProxy(
          addresses.getAddress("ARBITRUM_L2_WETH_GATEWAY_PROXY")
      );

      // implementation() caller must be the owner
      vm.startPrank(addresses.getAddress("ARBITRUM_L2_PROXY_ADMIN"));
      require(
          proxy.implementation() ==
              addresses.getAddress("ARBITRUM_L2_WETH_GATEWAY_IMPLEMENTATION"),
          "Proxy implementation not set"
      );
      vm.stopPrank();
  }
  ```

## Proposal Simulation

### Setting Up the Addrsses JSON Files

Copy all address arbitrum address from [1.json](https://github.com/solidity-labs-io/fps-example-repo/blob/main/addresses/1.json). Your `1.json` file should follow this structure:

```json
[
  {
    "addr": "0xE6841D92B0C345144506576eC13ECf5103aC7f49",
    "name": "ARBITRUM_L1_TIMELOCK",
    "isContract": true
  },
  {
    "addr": "0x3ffFbAdAF827559da092217e474760E2b2c3CeDd",
    "name": "ARBITRUM_L1_UPGRADE_EXECUTOR",
    "isContract": true
  },
  {
    "addr": "0x9aD46fac0Cf7f790E5be05A0F15223935A0c0aDa",
    "name": "ARBITRUM_L1_PROXY_ADMIN",
    "isContract": true
  },
  {
    "addr": "0xd92023e9d9911199a6711321d1277285e6d4e2db",
    "name": "ARBITRUM_L1_WETH_GATEWAY_PROXY",
    "isContract": true
  },
  {
    "addr": "0x8315177aB297bA92A06054cE80a67Ed4DBd7ed3a",
    "name": "ARBITRUM_BRIDGE",
    "isContract": true
  },
  {
    "addr": "0x2c9c0F10E3F8820544522df210dFb0A2BbC75147",
    "name": "DEPLOYER_EOA",
    "isContract": false
  }
]
```

Copy all arbitrum address from [42161.json](https://github.com/solidity-labs-io/fps-example-repo/blob/main/addresses/42161.json). Your `42161.json` file should follow this structure:

```json
[
  {
    "addr": "0x34d45e99f7D8c45ed05B5cA72D54bbD1fb3F98f0",
    "name": "ARBITRUM_L2_TIMELOCK",
    "isContract": true
  },
  {
    "addr": "0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827",
    "name": "ARBITRUM_L2_UPGRADE_EXECUTOR",
    "isContract": true
  },
  {
    "addr": "0xd570aCE65C43af47101fC6250FD6fC63D1c22a86",
    "name": "ARBITRUM_L2_PROXY_ADMIN",
    "isContract": true
  },
  {
    "addr": "0x6c411aD3E74De3E7Bd422b94A27770f5B86C623B",
    "name": "ARBITRUM_L2_WETH_GATEWAY_PROXY",
    "isContract": true
  },
  {
    "addr": "0xf07DeD9dC292157749B6Fd268E37DF6EA38395B9",
    "name": "ARBITRUM_L2_CORE_GOVERNOR",
    "isContract": true
  },
  {
    "addr": "0x0000000000000000000000000000000000000064",
    "name": "ARBITRUM_SYS",
    "isContract": true
  },
  {
    "addr": "0xf7951d92b0c345144506576ec13ecf5103ac905a",
    "name": "ARBITRUM_ALIASED_L1_TIMELOCK",
    "isContract": false
  },
  {
    "addr": "0x2c9c0F10E3F8820544522df210dFb0A2BbC75147",
    "name": "DEPLOYER_EOA",
    "isContract": false
  }
]
```

### Running the Proposal

```sh
forge script src/proposals/arbitrum/Arbitrum_Proposal_01.sol --sender -vvvv
```

The script will output the following:

```sh
== Logs ==


--------- Addresses added ---------
  {
          "addr": "0x6801E4888A91180238A8c36594EC65797eC2dDDf",
          "isContract": true,
          "name": "ARBITRUM_L2_WETH_GATEWAY_IMPLEMENTATION"
},
  {
          "addr": "0xA98deC0C8e0326756C956033bbF091081986d0eD",
          "isContract": true,
          "name": "PROXY_UPGRADE_ACTION"
}

---------------- Proposal Description ----------------
  This proposal upgrades the L2 weth gateway

------------------ Proposal Actions ------------------
  1). calling ARBITRUM_L2_UPGRADE_EXECUTOR @0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827 with 0 eth and 0x1cff79cd000000000000000000000000a98dec0c8e0326756c956033bbf091081986d0ed00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000064e17f52e9000000000000000000000000d570ace65c43af47101fc6250fd6fc63d1c22a860000000000000000000000006c411ad3e74de3e7bd422b94a27770f5b86c623b0000000000000000000000006801e4888a91180238a8c36594ec65797ec2dddf00000000000000000000000000000000000000000000000000000000 data.
  target: ARBITRUM_L2_UPGRADE_EXECUTOR @0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827
payload
  0x1cff79cd000000000000000000000000a98dec0c8e0326756c956033bbf091081986d0ed00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000064e17f52e9000000000000000000000000d570ace65c43af47101fc6250fd6fc63d1c22a860000000000000000000000006c411ad3e74de3e7bd422b94a27770f5b86c623b0000000000000000000000006801e4888a91180238a8c36594ec65797ec2dddf00000000000000000000000000000000000000000000000000000000



----------------- Proposal Changes ---------------


 ARBITRUM_L2_UPGRADE_EXECUTOR @0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827:

 State Changes:
  Slot: 0x0000000000000000000000000000000000000000000000000000000000000097
  -  0x0000000000000000000000000000000000000000000000000000000000000001
  +  0x0000000000000000000000000000000000000000000000000000000000000002
  Slot: 0x0000000000000000000000000000000000000000000000000000000000000097
  -  0x0000000000000000000000000000000000000000000000000000000000000002
  +  0x0000000000000000000000000000000000000000000000000000000000000001


 ARBITRUM_L2_WETH_GATEWAY_PROXY @0x6c411aD3E74De3E7Bd422b94A27770f5B86C623B:

 State Changes:
  Slot: 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
  -  0x000000000000000000000000806421d09cdb253aa9d128a658e60c0b95effa01
  +  0x0000000000000000000000006801e4888a91180238a8c36594ec65797ec2dddf


------------------ Proposal Calldata ------------------
  0x7d5e81e2000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000004c00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000344928c169a000000000000000000000000e6841d92b0c345144506576ec13ecf5103ac7f49000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000002c401d5062a000000000000000000000000a723c008e76e379c55599d2e4d93879beafda79c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000009c33e8e47a5438b554b45b782bed73248b78e26754b37292265f0b4a3ede7874000000000000000000000000000000000000000000000000000000000003f48000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000004dbd4fc535ac27206064b68ffcf827b0a60bab3f000000000000000000000000cf57572261c7c2bcf21ffd220ea7d1a27d40a82700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000e41cff79cd000000000000000000000000a98dec0c8e0326756c956033bbf091081986d0ed00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000064e17f52e9000000000000000000000000d570ace65c43af47101fc6250fd6fc63d1c22a860000000000000000000000006c411ad3e74de3e7bd422b94a27770f5b86c623b0000000000000000000000006801e4888a91180238a8c36594ec65797ec2dddf00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a546869732070726f706f73616c20757067726164657320746865204c322077657468206761746577617900000000000000000000000000000000000000000000
```

A DAO member can check whether the calldata proposed on the governance matches the calldata from the script exeuction. It is crucial to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON files when proposal is run without the `DO_UPDATE_ADDRESS_JSON` flag set to true.

The proposal script will deploy the contracts in `deploy()` method and will generate actions calldata for each individual action along with proposal calldata for the proposal. The proposal can be proposed manually using `cast send` with the calldata generated above.
