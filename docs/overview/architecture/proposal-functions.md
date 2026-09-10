# Proposal functions

[`Proposal.sol`](../../../src/proposals/Proposal.sol) defines the common
lifecycle and records governance actions. A protocol proposal inherits one of
the governance-specific proposal contracts and implements the hooks needed for
that proposal.

## Configure `run()`

The protocol proposal owns fork selection and dependency setup. Configure them
before calling `super.run()`:

```solidity
function run() public override {
    setPrimaryForkId(vm.createSelectFork("mainnet"));

    uint256[] memory chainIds = new uint256[](1);
    chainIds[0] = 1;

    setAddresses(
        new Addresses(
            vm.envOr("ADDRESSES_PATH", string("./addresses")),
            chainIds
        )
    );
    setGovernor(addresses.getAddress("PROTOCOL_GOVERNOR"));

    super.run();
}
```

`vm.createSelectFork(...)` creates and selects the fork. The base `run()` does
not select `primaryForkId`. `setPrimaryForkId(...)` records the fork ID for
tests and custom proposal logic.

Timelock proposals call `setTimelock(...)`. Governor Bravo and OpenZeppelin
Governor proposals call `setGovernor(...)`. Multisig proposals read the Safe
address when building and simulating.

## Lifecycle

`Proposal.run()` executes these stages in order:

1. `deploy()`
2. `preBuildMock()`
3. `build()`
4. `simulate()`
5. `validate()`
6. `print()`
7. `addresses.updateJson()` when enabled

The constructor reads these environment flags:

| Variable | Default | Behavior |
| --- | --- | --- |
| `DEBUG` | `false` | Prints governance-specific diagnostic values. |
| `DO_DEPLOY` | `true` | Runs deployment calls inside a Foundry broadcast section. |
| `DO_PRE_BUILD_MOCK` | `true` | Applies fork-only setup before action recording. |
| `DO_BUILD` | `true` | Records direct privileged calls as proposal actions. |
| `DO_SIMULATE` | `true` | Executes the actions through the governance system. |
| `DO_VALIDATE` | `true` | Runs post-execution assertions. |
| `DO_PRINT` | `true` | Prints the description, actions, changes, and final payload. |
| `DO_UPDATE_ADDRESS_JSON` | `false` | Persists registry mutations to per-chain JSON files. |

Set flags in the command environment:

```sh
DO_DEPLOY=false DO_SIMULATE=false forge script path/to/Proposal.sol:Proposal
```

Later stages may depend on earlier output. For example, `simulate()` needs the
actions populated by `build()`, and `validate()` usually expects simulation to
have executed them.

### `deploy()`

Override `deploy()` for contracts that must exist before action construction:

```solidity
function deploy() public override {
    if (!addresses.isAddressSet("NEW_IMPLEMENTATION")) {
        NewImplementation implementation = new NewImplementation();
        addresses.addAddress(
            "NEW_IMPLEMENTATION", address(implementation), true
        );
    }
}
```

The base runner looks up `DEPLOYER_EOA`, calls
`vm.startBroadcast(deployer)`, runs `deploy()`, prints address additions and
replacements, and stops the broadcast. `forge script` remains a dry run unless
the CLI command includes `--broadcast` and credentials for `DEPLOYER_EOA`.

### `preBuildMock()`

Use `preBuildMock()` for fork state required to construct or simulate the
proposal, such as `vm.store`, `vm.etch`, token balances, or role setup. These
changes are local to the Foundry execution and are excluded from the generated
governance actions because recording starts afterward.

<a id="build-function"></a>

### `build()`

Write privileged calls as Solidity statements and attach
`buildModifier(caller)`:

```solidity
function build()
    public
    override
    buildModifier(addresses.getAddress("PROTOCOL_TIMELOCK"))
{
    address implementation = addresses.getAddress("NEW_IMPLEMENTATION");
    proxyAdmin.upgrade(address(proxy), implementation);
}
```

The modifier performs this sequence:

1. Prank as `caller`.
2. Save the EVM state with `vm.snapshotState()`.
3. Start Foundry state-diff recording.
4. Execute the `build()` body.
5. Stop recording and the prank.
6. Restore the snapshot with `vm.revertToState(...)`.
7. Record state-slot changes and ETH or ERC-20 transfers from the diff.
8. Convert direct `Call` accesses from `caller` into `Action` entries.
9. Run action validation hooks.

Static calls and subcalls are excluded from the action list. Calls to the
`Addresses` registry and Foundry VM are also excluded. The recorded state and
transfer changes describe the intended build execution even though the
snapshot is restored before simulation.

The default `_validateAction(...)` rejects an action whose target, value, and
calldata all match an earlier action. Override it to add per-action checks and
call `super._validateAction(...)` to retain duplicate detection.
`_validateActions()` is an empty batch-level hook for ordering or aggregate
constraints.

### `simulate()`

`simulate()` executes the recorded actions through the selected governance
path:

- `TimelockProposal` supplies `_simulateActions(proposer, executor)` for batch
  scheduling and execution after the minimum delay.
- `GovernorBravoProposal` runs proposal creation, voting, queueing, and
  timelock execution.
- `OZGovernorProposal` runs proposal creation, voting, queueing, and execution
  through the Governor's timelock.
- `MultisigProposal` supplies `_simulateActions(safe)`, which executes the
  generated Safe transaction using temporary runtime replacement.

Timelock and multisig protocol proposals implement `simulate()` and call the
provided helper with protocol-specific actors. The two Governor proposal types
provide a complete default implementation that can be overridden when the
target Governor differs from the expected interfaces.

### `validate()`

Override `validate()` with assertions against the post-simulation fork state:

```solidity
function validate() public view override {
    assertEq(token.owner(), expectedOwner);
}
```

Keep expected values in the proposal contract or derive them from the address
registry. Validation runs after governance execution by default.

### `print()`

The default output includes:

- the proposal description
- each action's description, labeled target, and calldata
- recorded ETH and ERC-20 transfers
- each written storage slot with its old and new value
- governance calldata or Safe transaction fields

Governance-specific contracts override `_printProposalCalldata()` when they
have multiple payloads or structured transaction fields. Timelock proposals
print schedule and execute calldata. Multisig proposals print `to`, `value`,
`data`, and `operation`.

## Proposal metadata and actions

Every protocol proposal implements `name()` and `description()`:

```solidity
function name() public pure override returns (string memory) {
    return "UPGRADE_TOKEN";
}

function description() public pure override returns (string memory) {
    return "Upgrade the token proxy to implementation v2";
}
```

`getProposalActions()` returns parallel `targets`, `values`, and `arguments`
arrays. It requires at least one action, a nonzero target for every action, and
either nonempty calldata or a positive ETH value.

`getCalldata()` is implemented by the governance-specific proposal type:

- Timelock uses `scheduleBatch(...)`, with separate execute calldata available
  from `getExecuteCalldata()`.
- Governor Bravo uses `propose(address[],uint256[],string[],bytes[],string)`.
- OpenZeppelin Governor uses
  `propose(address[],uint256[],bytes[],string)`.
- Safe multisig uses `multiSend(bytes)` and exposes the outer transaction with
  `getSafeTransaction()`.

`getProposalId()` checks for an existing matching proposal or operation.
Timelock derives the operation hash from actions, predecessor, and description
salt. Governor Bravo scans existing proposal actions. OpenZeppelin Governor
uses `hashProposal(...)` and checks whether `state(...)` accepts the result.
Safe multisig leaves proposal lookup unimplemented.

See the governance-specific [guides](../../guides/introduction.md) for payload
fields and simulation requirements.
