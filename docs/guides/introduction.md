# Guides

FPS records proposal actions from Solidity calls, encodes them for a governance system, simulates the governance lifecycle, and validates the resulting state. Use the proposal base contract that matches the executor:

1. [Safe multisig](./multisig-proposal.md)
2. [OpenZeppelin TimelockController](./timelock-proposal.md)
3. [Governor Bravo](./governor-bravo-proposal.md)
4. [OpenZeppelin Governor](./oz-governor-proposal.md)

The examples use the `Vault` and `Token` contracts from the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/tree/main/src/mocks/vault). They are tutorial fixtures.

## Install FPS

Install the repository with Forge:

```sh
forge install solidity-labs-io/forge-proposal-simulator
```

Add this remapping:

```text
@forge-proposal-simulator/=lib/forge-proposal-simulator/
```

## Configure addresses

`Addresses` reads one JSON file per chain. The filename is the numeric chain ID, such as `addresses/11155111.json` for Sepolia. Pass the directory and every chain used by the proposal to the constructor:

```solidity
uint256[] memory chainIds = new uint256[](1);
chainIds[0] = 11155111;

setAddresses(new Addresses("./addresses", chainIds));
```

Each JSON entry has this shape:

```json
{
  "addr": "0x<ADDRESS>",
  "name": "DEPLOYER_EOA",
  "isContract": false
}
```

Grant Foundry read access to the directory. Use `read-write` when `DO_UPDATE_ADDRESS_JSON=true`:

```toml
[profile.default]
fs_permissions = [{ access = "read-write", path = "./addresses" }]
```

See [Addresses](../overview/architecture/addresses.md) for chain-specific lookups, updates, removals, and persistence.

## Configure the deployer

`Proposal.run()` reads `DEPLOYER_EOA` from `Addresses` and wraps `deploy()` in `vm.startBroadcast(deployer)`. Store the matching key in Foundry's keystore:

```sh
cast wallet import "$WALLET_NAME" --interactive
cast wallet address --account "$WALLET_NAME"
```

The sender passed to `forge script` must equal `DEPLOYER_EOA`. The account needs enough native currency for deployments when the script is broadcast.

## Proposal lifecycle

`Proposal.run()` executes enabled stages in this order:

1. `deploy()` inside a broadcast, followed by `addresses.printJSONChanges()`
2. `preBuildMock()`
3. `build()`
4. `simulate()`
5. `validate()`
6. `print()`
7. `addresses.updateJson()` when JSON persistence is enabled

Apply `buildModifier(executor)` to `build()`. FPS starts a prank as `executor`, takes a state snapshot, records the state diff, runs the Solidity calls, and restores the snapshot. Direct `Call` accesses from `executor` become ordered proposal actions. Static calls, subcalls, and calls involving `Addresses` or the Foundry VM are excluded from the action list. Recorded storage writes, ETH transfers, and ERC-20 `transfer` and `transferFrom` calls are retained for `print()`.

FPS rejects actions with a zero target, actions with neither calldata nor ETH value, and duplicate actions with the same target, value, and calldata.

The constructor reads these environment flags:

| Flag | Default | Effect |
| --- | --- | --- |
| `DEBUG` | `false` | Print governance-specific diagnostic logs. |
| `DO_DEPLOY` | `true` | Run `deploy()` inside a broadcast from `DEPLOYER_EOA`. |
| `DO_PRE_BUILD_MOCK` | `true` | Run `preBuildMock()` before action recording. |
| `DO_BUILD` | `true` | Record actions and state changes from `build()`. |
| `DO_SIMULATE` | `true` | Execute the recorded proposal through the governance model. |
| `DO_VALIDATE` | `true` | Run post-execution assertions in `validate()`. |
| `DO_PRINT` | `true` | Print the description, actions, recorded changes, and governance calldata. |
| `DO_UPDATE_ADDRESS_JSON` | `false` | Persist address additions, changes, and removals to the per-chain JSON files. |

Flags compose. For example, this command builds and prints calldata without broadcasting deployments or running the simulation:

```sh
DO_DEPLOY=false DO_SIMULATE=false DO_VALIDATE=false forge script path/to/Proposal.sol:ProposalContract -vvvv
```

Use `forge test` for integration tests and `forge script` for proposal scripts. The [integration-test guide](../testing/integration-tests.md) covers the test setup.

## Examples

The governance guides use this action sequence:

1. Deploy a `Vault` and `Token`.
2. Transfer ownership and the token supply to the governance executor.
3. Whitelist the token.
4. Approve the vault.
5. Deposit the token supply.

For protocol deployments, see the mainnet examples:

1. [Arbitrum Timelock](../mainnet-examples/ArbitrumTimelock.md)
2. [Compound Governor Bravo](../mainnet-examples/CompoundGovernorBravo.md)
3. [ENS OpenZeppelin Governor](../mainnet-examples/ENSOzGovernor.md)
4. [Optimism Safe](../mainnet-examples/OptimismMultisig.md)

The [custom proposal guide](./customizing-proposal.md) shows a two-fork Arbitrum governance simulation.
