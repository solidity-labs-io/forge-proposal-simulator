# Addresses

`Addresses` is the chain-aware registry used by proposal contracts. It loads
named entries from per-chain JSON files, labels the addresses in Foundry, and
tracks additions, replacements, and removals made during a run.

## Files and constructor

The constructor accepts a directory and the chain IDs to load:

```solidity
uint256[] memory chainIds = new uint256[](2);
chainIds[0] = 1;
chainIds[1] = 11155111;

Addresses addresses = new Addresses("./addresses", chainIds);
```

Each requested chain ID maps to `<directory>/<chain-id>.json`. Every requested
file must exist and contain an array with this schema:

```json
[
  {
    "addr": "0x1111111111111111111111111111111111111111",
    "name": "PROTOCOL_TIMELOCK",
    "isContract": true
  },
  {
    "addr": "0x2222222222222222222222222222222222222222",
    "name": "DEPLOYER_EOA",
    "isContract": false
  }
]
```

A multi-chain directory has one file per loaded network:

```text
addresses/
├── 1.json
├── 11155111.json
└── 31337.json
```

Grant Foundry access in `foundry.toml`:

```toml
[profile.default]
fs_permissions = [{ access = "read", path = "./addresses" }]
```

Use `read-write` when the run may call `updateJson()`:

```toml
[profile.default]
fs_permissions = [{ access = "read-write", path = "./addresses" }]
```

## Registry checks

Loading a file or adding an entry requires a unique name and address within its
chain ID. Adds and changes reject the zero address and chain ID zero. A change
requires an existing name and a different address. A removal requires the
currently stored address as an explicit argument.

Current limitation: `changeAddress()` does not update the reverse-address
index. After a replacement, the previous address remains reserved and the new
address is not reserved against another `addAddress()` call. Treat replacement
addresses as unique at the proposal level until the registry implementation is
fixed.

When an entry targets `block.chainid`, `isContract` must match the address code:
contract entries require code and non-contract entries require no code. Entries
for other chain IDs are stored without a code check. Select the intended fork
before constructing the registry when current-chain validation is required.

## Read entries

Use the overload without a chain ID for `block.chainid`:

```solidity
address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
bool exists = addresses.isAddressSet("PROTOCOL_TIMELOCK");
bool isContract = addresses.isAddressContract("PROTOCOL_TIMELOCK");
```

Use the chain ID overload for another loaded network:

```solidity
address timelock = addresses.getAddress("PROTOCOL_TIMELOCK", 1);
bool exists = addresses.isAddressSet("PROTOCOL_TIMELOCK", 1);
```

`getAddress` reverts when the name is unset. `isAddressContract` reads only the
current chain ID.

## Add, change, and remove entries

Add an entry on the current chain or an explicit chain:

```solidity
addresses.addAddress("NEW_IMPLEMENTATION", implementation, true);
addresses.addAddress("L2_MESSENGER", messenger, 10, true);
```

Replace an existing entry while preserving its name:

```solidity
addresses.changeAddress("IMPLEMENTATION", implementation, true);
addresses.changeAddress("L2_MESSENGER", messenger, 10, true);
```

Remove an entry by name, expected address, and chain ID:

```solidity
addresses.removeAddress("OLD_IMPLEMENTATION", oldImplementation, 1);
```

The expected address prevents removal when the registry has already changed.
After removal, both the name and address can be reused on that chain.

## Recorded changes

Registry mutations are available as parallel arrays:

```solidity
(
    string[] memory addedNames,
    uint256[] memory addedChainIds,
    address[] memory addedAddresses
) = addresses.getRecordedAddresses();

(
    string[] memory changedNames,
    uint256[] memory changedChainIds,
    address[] memory oldAddresses,
    address[] memory newAddresses
) = addresses.getChangedAddresses();

(
    string[] memory removedNames,
    uint256[] memory removedChainIds
) = addresses.getRemovedAddresses();
```

Clear each mutation log independently:

```solidity
addresses.resetRecordingAddresses();
addresses.resetChangedAddresses();
addresses.resetRemovedAddresses();
```

`printJSONChanges()` prints additions and replacements collected during the
run. `Proposal.run()` calls it immediately after `deploy()` while the broadcast
section is active. This output is diagnostic rather than canonical JSON: the
current implementation prints `isContract: true` for every entry, reports
replacement chain IDs as `block.chainid`, and omits removals.

## Persist files

`updateJson()` rewrites every per-chain file listed in the constructor from the
registry's persisted entries. It writes added and replaced addresses and drops
removed entries. Only constructor-provided chain IDs are written, so include
every chain whose file must be updated.

Two current edge cases require manual review. A replacement writes the new
address but retains the entry's original `isContract` value. Removing the last
entry for a chain renders `]` instead of an empty JSON array. Do not persist a
replacement that changes the contract flag or an empty chain file until those
implementation defects are fixed.

The proposal lifecycle calls `updateJson()` when
`DO_UPDATE_ADDRESS_JSON=true`. The default is `false`. Keep write permission
disabled for review and simulation jobs that should leave the checkout
unchanged.

## Proposal setup

Create the registry after selecting the proposal fork, then pass it to the
proposal before calling `super.run()`:

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

    super.run();
}
```

Governance-specific setup, such as `setGovernor(...)` or `setTimelock(...)`,
belongs before `super.run()` in the same function.
