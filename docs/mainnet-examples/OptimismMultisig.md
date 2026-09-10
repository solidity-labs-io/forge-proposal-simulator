# Optimism Safe Proposal

[`MockMultisigProposal`](../../mocks/MockMultisigProposal.sol) upgrades the
Optimism L1 ERC-721 bridge proxy on a mainnet fork. The address registry uses
the historical `NFT_BRIDGE` labels for this contract. Optimism's current
[Superchain Registry](https://github.com/ethereum-optimism/superchain-registry/blob/main/superchain/extra/addresses/addresses.json)
lists the same L1 ERC-721 bridge proxy, ProxyAdmin, and ProxyAdmin owner used by
the example.

The proposal produces the transaction fields for a Safe batch and simulates
that transaction from the configured `OPTIMISM_MULTISIG`.

## Proposal setup

The concrete `run()` function selects the fork and constructs the address
registry before entering `Proposal.run()`.

```solidity
function run() public override {
    setPrimaryForkId(vm.createSelectFork("mainnet"));

    uint256[] memory chainIds = new uint256[](1);
    chainIds[0] = 1;

    addresses = new Addresses(
        vm.envOr("ADDRESSES_PATH", string("./addresses")), chainIds
    );

    super.run();
}
```

The inherited lifecycle calls `deploy()`, `preBuildMock()`, `build()`,
`simulate()`, `validate()`, and `print()` according to the environment flags.
Address JSON persistence runs last when `DO_UPDATE_ADDRESS_JSON=true`. See
[Proposal functions](../overview/architecture/proposal-functions.md) for the
shared lifecycle.

## Metadata

```solidity
function name() public pure override returns (string memory) {
    return "OPTMISM_MULTISIG_MOCK";
}

function description() public pure override returns (string memory) {
    return "Mock proposal that upgrade the L1 NFT Bridge";
}
```

`OPTMISM_MULTISIG_MOCK` preserves the identifier in the example contract,
including its spelling.

## Deployment

`deploy()` creates a mock implementation when the registry does not already
contain one.

```solidity
function deploy() public override {
    if (!addresses.isAddressSet("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION")) {
        address mockUpgrade = address(new MockUpgrade());

        addresses.addAddress(
            "OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION", mockUpgrade, true
        );
    }
}
```

The shared runner broadcasts `deploy()` from `DEPLOYER_EOA`. A normal script
run prints the added address. Set `DO_UPDATE_ADDRESS_JSON=true` to persist it to
the per-chain JSON file.

## Build

The Safe owns the ProxyAdmin, so `buildModifier` records the call with the Safe
as `msg.sender`. It captures the implementation slot change and restores the
pre-build fork state before simulation.

```solidity
function build()
    public
    override
    buildModifier(addresses.getAddress("OPTIMISM_MULTISIG"))
{
    IProxyAdmin proxy =
        IProxyAdmin(addresses.getAddress("OPTIMISM_PROXY_ADMIN"));

    proxy.upgrade(
        addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_PROXY"),
        addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION")
    );
}
```

## Safe batch encoding

`MultisigProposal.getCalldata()` encodes every action in the Safe MultiSend
packed format:

```text
operation (1 byte)
to        (20 bytes)
value     (32 bytes)
data size (32 bytes)
data      (data size bytes)
```

It concatenates the entries and wraps them in `multiSend(bytes)`. This layout
matches Safe's
[MultiSend contract](https://github.com/safe-fndn/safe-smart-account/blob/main/contracts/libraries/MultiSend.sol).

`isDelegateCall()` controls the operation byte for every inner action. Its
default value is `false`, so this proposal encodes the ProxyAdmin action as
`CALL` (`0`). A proposal that overrides it to return `true` encodes every inner
action as `DELEGATECALL` (`1`). Mixed inner operation types require a custom
adapter.

`getSafeTransaction()` returns the four fields required for this batch:

| Field | Default call proposal | Delegatecall proposal |
| --- | --- | --- |
| `to` | `SAFE_MULTISEND_CALL_ONLY_CONTRACT` | `SAFE_MULTISEND_CONTRACT` |
| `value` | `0` | `0` |
| `data` | `getCalldata()` | `getCalldata()` |
| `operation` | `DELEGATECALL` (`1`) | `DELEGATECALL` (`1`) |

The outer Safe transaction uses delegatecall so MultiSend executes in the
Safe's context. `MultiSendCallOnly` rejects inner delegatecalls, which is why
FPS selects the full MultiSend contract when `isDelegateCall()` returns
`true`. See Safe's
[MultiSendCallOnly implementation](https://github.com/safe-fndn/safe-smart-account/blob/main/contracts/libraries/MultiSendCallOnly.sol).

`MultisigProposal.getProposalId()` is unimplemented and reverts with
`"Not implemented"`.

## Simulation

The example delegates to the inherited Safe simulator:

```solidity
function simulate() public override {
    address multisig = addresses.getAddress("OPTIMISM_MULTISIG");

    _simulateActions(multisig);
}
```

`_simulateActions()` performs these steps:

1. Save the Safe proxy's runtime bytecode.
2. Replace it with the modified Safe v1.4.1 runtime stored in
   `Constants.SAFE_RUNTIME_BYTECODE`. This runtime bypasses signature checks.
3. Call `execTransaction` as the Safe itself with the fields from
   `getSafeTransaction()`. The gas and payment fields are zero, the token and
   receiver are zero addresses, and the signature bytes are empty.
4. Restore the original runtime bytecode.
5. Bubble up a revert from the Safe transaction.

The replacement changes runtime code for the duration of the call and retains
the Safe proxy's storage. Proposal effects therefore land in the same storage
context used by an executed Safe transaction.

## Validation

The transparent proxy exposes `implementation()` to its admin. Validation
reads the implementation while pranking the ProxyAdmin address.

```solidity
function validate() public override {
    IProxy proxy =
        IProxy(addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_PROXY"));

    vm.startPrank(addresses.getAddress("OPTIMISM_PROXY_ADMIN"));
    require(
        proxy.implementation()
            == addresses.getAddress(
                "OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION"
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
forge script mocks/MockMultisigProposal.sol:MockMultisigProposal \
  --fork-url mainnet
```

The default output prints the deployed registry entry, the ProxyAdmin action,
the recorded implementation slot change, and the Safe transaction fields.
Enter the printed `to`, `value`, `data`, and `operation` in the Safe interface
and verify the decoded inner action before collecting signatures.
