# Compound Governor Bravo Proposal

[`MockBravoProposal`](../../mocks/MockBravoProposal.sol) records a two-action
proposal against the Compound III WETH Configurator on a mainnet fork. It sets
the borrow and supply utilization kinks to `0.75e18`.

This mock validates the updated Configurator values. A production Compound III
proposal that changes these parameters must also call `deployAndUpgradeTo` on
the CometProxyAdmin as described in the
[Compound III governance documentation](https://docs.compound.finance/governance/).

## Proposal setup

The concrete `run()` function selects the fork and configures the shared
objects before entering `Proposal.run()`.

```solidity
function run() public override {
    setPrimaryForkId(vm.createSelectFork("mainnet"));

    uint256[] memory chainIds = new uint256[](1);
    chainIds[0] = 1;

    setAddresses(
        new Addresses(
            vm.envOr("ADDRESSES_PATH", string("./addresses")), chainIds
        )
    );

    setGovernor(addresses.getAddress("COMPOUND_GOVERNOR_BRAVO"));

    super.run();
}
```

The inherited lifecycle calls `deploy()`, `preBuildMock()`, `build()`,
`simulate()`, `validate()`, and `print()` according to the environment flags.
This example does not override `deploy()` or `preBuildMock()`. See
[Proposal functions](../overview/architecture/proposal-functions.md) for the
shared lifecycle.

## Metadata

The description is passed to Governor Bravo's `propose` function and is used
when FPS searches for a matching onchain proposal.

```solidity
uint64 public kink = 0.75 * 1e18;

function name() public pure override returns (string memory) {
    return "ADJUST_WETH_IR_CURVE";
}

function description() public pure override returns (string memory) {
    return
        "Mock proposal that adjust IR Curve for Compound v3 WETH on Mainnet";
}
```

## Build

Compound's Timelock is the authorized caller for the Configurator. Passing that
address to `buildModifier` records the two direct `Call` accesses in source order, then
restores the pre-build fork state. Registry reads and static calls are excluded
from the action list.

```solidity
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
```

The inherited `getCalldata()` encodes:

```solidity
propose(
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    string description
)
```

FPS uses empty signature strings because each recorded `calldata` already
contains its function selector.

## Proposal lookup

`GovernorBravoProposal.getProposalId()` searches from
`governor.proposalCount()` down to proposal 1. For each proposal it loads
`targets`, `values`, `signatures`, and `calldatas` with `getActions`, combines
them with the local description, and compares the resulting encoded `propose`
calldata with `getCalldata()`. The first match is returned. A search with no
match returns zero.

## Lifecycle simulation

The inherited `simulate()` runs the Governor Bravo lifecycle on the fork:

1. It rewrites the legacy Compound Timelock admin slot to the configured
   Governor Bravo. This supports the old governor address used by the fixture.
2. It gives `address(1)` enough COMP voting power to meet the larger of the
   proposal threshold and quorum, delegates the votes, and advances one block.
3. It submits the encoded proposal and checks the `Pending` state.
4. It advances through the voting delay, casts a `For` vote, advances through
   the voting period, and checks the `Succeeded` state.
5. It queues the proposal, warps by the Timelock delay, executes it, and checks
   the `Executed` state.

The simulation exercises `Pending`, `Active`, `Succeeded`, `Queued`, and
`Executed` in order.

## Validation

Validation reads the Configurator after execution and checks both stored kink
values.

```solidity
function validate() public view override {
    ICompoundConfigurator configurator = ICompoundConfigurator(
        addresses.getAddress("COMPOUND_CONFIGURATOR")
    );
    address comet = addresses.getAddress("COMPOUND_COMET");

    ICompoundConfigurator.Configuration memory config =
        configurator.getConfiguration(comet);
    assertEq(config.supplyKink, kink);
    assertEq(config.borrowKink, kink);
}
```

## Run the proposal

The `mainnet` RPC alias must be configured in `foundry.toml` or supplied by the
environment. `ADDRESSES_PATH` defaults to `./addresses`. `DEPLOYER_EOA` remains
required while `DO_DEPLOY` uses its default value of `true`, even though this
example's `deploy()` implementation is empty. Set `DO_DEPLOY=false` to skip the
broadcast stage.

```sh
forge script mocks/MockBravoProposal.sol:MockBravoProposal \
  --fork-url mainnet
```

The default output prints the two Configurator actions, their recorded storage
changes, and the Governor Bravo `propose` calldata. Check the action order and
the empty `signatures` entries before submitting the payload.
