# Arbitrum Timelock Proposal

[`MockTimelockProposal`](../../mocks/MockTimelockProposal.sol) upgrades the
Arbitrum L1 WETH gateway proxy on a mainnet fork. It deploys a mock gateway
implementation and a governance action contract (GAC), then schedules the
Upgrade Executor call through the Arbitrum L1 Timelock.

Arbitrum's L1 Upgrade Executor owns upgrade rights for Arbitrum contracts on
Ethereum. Its `execute` function runs a GAC with `delegatecall`. Production GACs
must therefore follow Arbitrum's
[delegatecall safety requirements](https://github.com/ArbitrumFoundation/governance/blob/main/src/gov-action-contracts/README.md).
The action contract in this example is intentionally minimal.

## Proposal setup

The concrete `run()` function owns fork and adapter setup. `Proposal.run()`
starts after the fork, address registry, and timelock are configured.

```solidity
function run() public override {
    setPrimaryForkId(vm.createSelectFork("mainnet"));

    uint256[] memory chainIds = new uint256[](1);
    chainIds[0] = 1;

    addresses = new Addresses(
        vm.envOr("ADDRESSES_PATH", string("./addresses")), chainIds
    );

    setTimelock(addresses.getAddress("ARBITRUM_L1_TIMELOCK"));

    super.run();
}
```

The inherited lifecycle then calls `deploy()`, `preBuildMock()`, `build()`,
`simulate()`, `validate()`, and `print()` according to the environment flags.
Address JSON persistence runs last when `DO_UPDATE_ADDRESS_JSON=true`. See
[Proposal functions](../overview/architecture/proposal-functions.md) for the
shared lifecycle.

## Metadata

`name()` identifies the proposal in FPS. `description()` is also part of this
adapter's timelock salt, so changing it changes the operation hash.

```solidity
function name() public pure override returns (string memory) {
    return "ARBITRUM_L1_TIMELOCK_MOCK";
}

function description() public pure override returns (string memory) {
    return "Mock proposal that upgrades the weth gateway";
}
```

## Deployment

`deploy()` reuses registry entries when they are already set. New deployments
are recorded as contract addresses.

```solidity
function deploy() public override {
    if (!addresses.isAddressSet("ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION"))
    {
        address mockUpgrade = address(new MockUpgrade());

        addresses.addAddress(
            "ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION", mockUpgrade, true
        );
    }

    if (!addresses.isAddressSet("ARBITRUM_GAC_UPGRADE_WETH_GATEWAY")) {
        address gac = address(new GovernanceActionUpgradeWethGateway());
        addresses.addAddress("ARBITRUM_GAC_UPGRADE_WETH_GATEWAY", gac, true);
    }
}
```

The shared runner broadcasts `deploy()` from `DEPLOYER_EOA`. A normal script
run prints the new registry entries without writing them. Set
`DO_UPDATE_ADDRESS_JSON=true` to write them to the per-chain JSON file.

## Pre-build mock

The L1 Timelock accepts scheduling messages from its counterpart governance
path. On the fork, `preBuildMock()` installs a `MockOutbox` in the bridge's
outbox storage slot so the bridge reports the expected L2 sender. This mutation
prepares the fork and is not recorded as a proposal action.

```solidity
function preBuildMock() public override {
    address mockOutbox = address(new MockOutbox());

    vm.store(
        addresses.getAddress("ARBITRUM_BRIDGE"),
        bytes32(uint256(5)),
        bytes32(uint256(uint160(mockOutbox)))
    );
}
```

## Build

`buildModifier` executes the Solidity call as the timelock, records direct
calls from that caller, captures state and transfer changes, and reverts the
fork to its pre-build snapshot. Here it records one call to the L1 Upgrade
Executor. The executor delegates to the GAC, which calls the L1 ProxyAdmin.

```solidity
function build() public override buildModifier(address(timelock)) {
    IUpgradeExecutor upgradeExecutor = IUpgradeExecutor(
        addresses.getAddress("ARBITRUM_L1_UPGRADE_EXECUTOR")
    );

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

## Timelock calldata and simulation

`TimelockProposal` represents every proposal as an OpenZeppelin
`TimelockController` batch:

- `getCalldata()` encodes `scheduleBatch` with the recorded targets, values,
  and payloads.
- `getExecuteCalldata()` encodes `executeBatch` with the same batch.
- `predecessor` defaults to `bytes32(0)` and can be set by the proposal.
- The salt is `keccak256(abi.encode(description()))`.
- The schedule delay is the current value of `timelock.getMinDelay()`.
- `getProposalId()` computes `hashOperationBatch` and returns the hash when
  `isOperation(hash)` or `isOperationPending(hash)` is true. It returns zero
  otherwise.

These fields match the OpenZeppelin
[batch operation model](https://docs.openzeppelin.com/contracts/4.x/api/governance#TimelockController).

The example supplies the accounts authorized by the deployed Arbitrum
Timelock. `_simulateActions` schedules an unscheduled operation as the bridge,
warps by the minimum delay, then executes an unfinished operation as the
executor.

```solidity
function simulate() public override {
    // Proposer must be arbitrum bridge
    address proposer = addresses.getAddress("ARBITRUM_BRIDGE");

    // Executor can be anyone
    address executor = address(1);

    _simulateActions(proposer, executor);
}
```

## Validation

The transparent proxy exposes `implementation()` to its admin. Validation
therefore reads the implementation while pranking the ProxyAdmin address.

```solidity
function validate() public override {
    IProxy proxy =
        IProxy(addresses.getAddress("ARBITRUM_L1_WETH_GATEWAY_PROXY"));

    vm.startPrank(addresses.getAddress("ARBITRUM_L1_PROXY_ADMIN"));
    require(
        proxy.implementation()
            == addresses.getAddress(
                "ARBITRUM_L1_WETH_GATEWAY_IMPLEMENTATION"
            ),
        "Proxy implementation not set"
    );
    vm.stopPrank();
}
```

## Run the proposal

The `mainnet` RPC alias must be configured in `foundry.toml` or supplied by the
environment. `ADDRESSES_PATH` defaults to `./addresses`.

```sh
forge script mocks/MockTimelockProposal.sol:MockTimelockProposal \
  --fork-url mainnet
```

The default output contains:

- the two deployed registry entries;
- the Upgrade Executor action and payload;
- recorded storage changes, including the WETH gateway implementation slot;
- `scheduleBatch` calldata; and
- `executeBatch` calldata.

Use the printed schedule and execute payloads with the L1 Timelock. Review the
targets, values, payloads, predecessor, salt, and operation hash as one unit.
