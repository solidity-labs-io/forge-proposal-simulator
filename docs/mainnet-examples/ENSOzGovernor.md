# ENS OpenZeppelin Governor Proposal

[`MockOZGovernorProposal`](../../mocks/MockOZGovernorProposal.sol) models the
executed ENS proposal
[[EP5.1] Upgrade DNSSEC support](https://www.tally.xyz/gov/ens/proposal/4208408830555077285685632645423534041634535116286721240943655761928631543220).
It deploys `MockUpgrade` as the replacement registry entry, records a call that
enables that address as an ENS Root controller, and simulates the ENS Governor
lifecycle on a mainnet fork.

The deployed object is a test double. The production EP5.1 action enabled the
new DNS registrar at `0xb32cB5677a7C971689228EC835800432B339bA2B`.

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

    setGovernor(addresses.getAddress("ENS_GOVERNOR"));

    super.run();
}
```

The inherited lifecycle calls `deploy()`, `preBuildMock()`, `build()`,
`simulate()`, `validate()`, and `print()` according to the environment flags.
Address JSON persistence runs last when `DO_UPDATE_ADDRESS_JSON=true`. See
[Proposal functions](../overview/architecture/proposal-functions.md) for the
shared lifecycle.

## Metadata

OpenZeppelin Governor includes the description hash in the proposal ID. Keep
the submitted description byte-for-byte consistent with the reviewed payload.

```solidity
function name() public pure override returns (string memory) {
    return "UPGRADE_DNSSEC_SUPPORT";
}

function description() public pure override returns (string memory) {
    return "Call setController on the Root contract at root.ens.eth, passing in the address of the new DNS registrar";
}
```

## Deployment

`deploy()` creates the test double only when `ENS_DNSSEC` is absent from the
registry.

```solidity
function deploy() public override {
    if (!addresses.isAddressSet("ENS_DNSSEC")) {
        address dnsSec = address(new MockUpgrade());

        addresses.addAddress("ENS_DNSSEC", dnsSec, true);
    }
}
```

The shared runner broadcasts `deploy()` from `DEPLOYER_EOA`. A normal script
run prints the added address. Set `DO_UPDATE_ADDRESS_JSON=true` to persist it to
the per-chain JSON file.

## Build

The ENS Timelock is the authorized caller for the Root contract. Passing it to
`buildModifier` records `setController` as the proposal action and restores the
fork to its pre-build state before simulation.

```solidity
function build()
    public
    override
    buildModifier(addresses.getAddress("ENS_TIMELOCK"))
{
    /// STATICCALL -- not recorded for the run stage
    IControllable control = IControllable(addresses.getAddress("ENS_ROOT"));
    address dnsSec = addresses.getAddress("ENS_DNSSEC");

    /// CALLS -- mutative and recorded
    control.setController(dnsSec, true);
}
```

The action mirrors EP5.1's `setController(newDnsRegistrar, true)` call while
using the mock deployment as `newDnsRegistrar`.

## Proposal hashing and lookup

`OZGovernorProposal.getCalldata()` encodes the standard Governor entry point:

```solidity
propose(
    address[] targets,
    uint256[] values,
    bytes[] calldatas,
    string description
)
```

The proposal ID is:

```solidity
governor.hashProposal(
    targets,
    values,
    calldatas,
    keccak256(abi.encodePacked(description()))
);
```

`getProposalId()` calls `governor.state(proposalId)`. It returns the hash when
that call succeeds and zero when the governor rejects the unknown ID. ENS
executable proposals use a Governor and Timelock flow documented in the
[ENS governance process](https://docs.ens.domains/dao/governance/process/).

## Lifecycle simulation

The inherited `simulate()` runs the OpenZeppelin Governor lifecycle:

1. It loads the voting token from the Governor, gives `address(1)` enough votes
   to meet the larger of the proposal threshold and quorum, and delegates those
   votes.
2. It submits the proposal, recomputes the proposal hash, and checks the
   returned ID and `Pending` state.
3. It advances through the voting delay, casts a `For` vote, advances through
   the voting period, and checks the `Succeeded` state.
4. It warps by `governor.proposalEta(proposalId) + 1`, queues the proposal with
   its description hash, and checks the `Queued` state.
5. It loads the Governor's Timelock, warps by its minimum delay, executes the
   proposal, and checks the `Executed` state.

Queueing and execution use the same targets, values, calldatas, and description
hash that produced the proposal ID.

## Validation

Validation checks the post-execution controller mapping.

```solidity
function validate() public view override {
    IControllable control = IControllable(addresses.getAddress("ENS_ROOT"));
    address dnsSec = addresses.getAddress("ENS_DNSSEC");

    assertTrue(control.controllers(dnsSec));
}
```

## Run the proposal

The `mainnet` RPC alias must be configured in `foundry.toml` or supplied by the
environment. `ADDRESSES_PATH` defaults to `./addresses`.

```sh
forge script mocks/MockOZGovernorProposal.sol:MockOZGovernorProposal \
  --fork-url mainnet
```

The default output prints the deployed registry entry, the ENS Root action,
the recorded controller mapping change, and the Governor `propose` calldata.
Check the description and every proposal array before submitting the payload.
