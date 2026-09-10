# Custom proposal types

Create a governance-specific proposal type when the standard encoders and
simulation paths do not match the target system. The custom type should keep
the common `Proposal` lifecycle, action recorder, validation hooks, and output,
then override the payload and simulation functions that differ.

The
[`ArbitrumProposal`](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/arbitrum/ArbitrumProposal.sol)
adapter in `fps-example-repo` extends `OZGovernorProposal` across Arbitrum and
Ethereum forks. It models the following path:

1. Submit, vote, queue, and execute the proposal through the Arbitrum
   OpenZeppelin Governor and its L2 timelock.
2. Call the ArbSys precompile to send the L1 Timelock schedule payload.
3. Schedule and execute the operation through the L1 Timelock.
4. For an L2 destination, decode the retryable-ticket event and execute the
   resulting call back on the Arbitrum fork.

The adapter uses mocks for the cross-chain transport. It skips proof creation,
message confirmation, and retryable-ticket delivery delays. The
[Arbitrum governance repository](https://github.com/ArbitrumFoundation/governance/tree/main/docs)
documents the production lifecycle and deployed governance contracts.

## Define the execution chain

The adapter supports Ethereum, Arbitrum One, and Arbitrum Nova destinations:

```solidity
enum ProposalExecutionChain {
    ETH,
    ARB_ONE,
    ARB_NOVA
}

ProposalExecutionChain internal executionChain;
uint256 public ethForkId;

function setEthForkId(uint256 _forkId) public {
    ethForkId = _forkId;
}
```

Concrete proposals set `executionChain` in their constructor. The linked
[`ArbitrumProposal_01`](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/arbitrum/ArbitrumProposal_01.sol)
targets Arbitrum One:

```solidity
constructor() {
    executionChain = ProposalExecutionChain.ARB_ONE;
}
```

## Configure both forks

The proposal loads the Ethereum and Arbitrum address files, keeps the registry
persistent across fork changes, creates both forks, and selects the Arbitrum
fork before entering the base lifecycle:

```solidity
function run() public override {
    uint256[] memory chainIds = new uint256[](2);
    chainIds[0] = 1;
    chainIds[1] = 42161;

    addresses = new Addresses("./addresses", chainIds);
    vm.makePersistent(address(addresses));

    setPrimaryForkId(vm.createFork("arbitrum"));
    setEthForkId(vm.createFork("ethereum"));

    vm.selectFork(primaryForkId);
    setGovernor(addresses.getAddress("ARBITRUM_L2_CORE_GOVERNOR"));

    super.run();
}
```

`primaryForkId` is the governance fork and final execution fork for an
Arbitrum destination. `ethForkId` is the L1 settlement fork. Every function
that changes forks must select the expected fork again before returning.

The address directory needs `1.json` and `42161.json`. The adapter reads these
labels:

| Chain | Required labels |
| --- | --- |
| Ethereum | `ARBITRUM_BRIDGE`, `ARBITRUM_L1_TIMELOCK` |
| Arbitrum | `ARBITRUM_SYS`, `ARBITRUM_L2_CORE_GOVERNOR`, `ARBITRUM_L2_UPGRADE_EXECUTOR`, `ARBITRUM_ALIASED_L1_TIMELOCK` |

The concrete upgrade proposal also uses the appropriate ProxyAdmin, proxy,
implementation, and governance-action contract labels.

## Mock cross-chain system contracts

`preBuildMock()` prepares both forks before action recording. On Ethereum it
installs a `MockArbOutbox` address in the Bridge storage used by the example.
On Arbitrum it etches `MockArbSys` runtime code at the ArbSys precompile
address:

```solidity
function preBuildMock() public override {
    vm.selectFork(ethForkId);
    address mockOutbox = address(new MockArbOutbox());
    vm.store(
        addresses.getAddress("ARBITRUM_BRIDGE"),
        bytes32(uint256(5)),
        bytes32(uint256(uint160(mockOutbox)))
    );

    vm.selectFork(primaryForkId);
    address arbSys = address(new MockArbSys());
    vm.makePersistent(arbSys);
    vm.etch(addresses.getAddress("ARBITRUM_SYS"), arbSys.code);
}
```

`MockArbSys.sendTxToL1(...)` calls the supplied target in the local EVM. The
later settlement phase schedules the same payload on the Ethereum fork.
`MockArbOutbox.l2ToL1Sender()` returns the expected L2 timelock so the Bridge
authorization check succeeds.

## Validate the recorded action

This adapter permits one recorded action. It uses the base validity rules and
requires zero ETH value for the `ARB_ONE` path:

```solidity
function _validateActions() internal view override {
    require(actions.length == 1, "Arbitrum proposals must have a single action");
    require(actions[0].target != address(0), "Invalid target for proposal");
    require(
        (actions[0].arguments.length == 0 && actions[0].value > 0)
            || actions[0].arguments.length > 0,
        "Invalid arguments for proposal"
    );

    if (executionChain == ProposalExecutionChain.ARB_ONE) {
        require(actions[0].value == 0, "Value must be 0 for L2 execution");
    }
}
```

`Proposal._validateAction(...)` still checks for duplicates while the action
is recorded. `_validateActions()` applies the adapter's batch constraint after
recording and whenever the wrapped action is requested.

## Build the L1 schedule payload

The adapter's public function is named `getScheduleTimelockCaldata()`. Its
spelling matches the current example source.

For an Ethereum destination, the L1 Timelock operation uses the recorded
target, value, and calldata. For an Arbitrum destination, it uses
`RETRYABLE_TICKET_MAGIC` as the target and encodes:

- the Arbitrum One or Nova Inbox
- `ARBITRUM_L2_UPGRADE_EXECUTOR`
- zero call value
- placeholder maximum gas and gas price values
- the recorded action calldata

The operation has a zero predecessor, a
`keccak256(abi.encodePacked(description()))` salt, and the adapter's three-day
minimum delay:

```solidity
scheduleCalldata = abi.encodeWithSelector(
    ITimelockController.schedule.selector,
    executionChain == ProposalExecutionChain.ETH
        ? actions[0].target
        : RETRYABLE_TICKET_MAGIC,
    actions[0].value,
    executionChain == ProposalExecutionChain.ETH
        ? actions[0].arguments
        : abi.encode(
            inbox,
            addresses.getAddress("ARBITRUM_L2_UPGRADE_EXECUTOR"),
            0,
            0,
            0,
            actions[0].arguments
        ),
    bytes32(0),
    keccak256(abi.encodePacked(description())),
    3 days
);
```

## Wrap the Governor action

`OZGovernorProposal.getCalldata()` calls `getProposalActions()`. The adapter
overrides that function so the Governor sees a single call to ArbSys. That
call sends the encoded schedule operation to the L1 Timelock:

```solidity
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

    bytes memory sendToL1 = abi.encodeWithSelector(
        MockArbSys.sendTxToL1.selector,
        addresses.getAddress("ARBITRUM_L1_TIMELOCK", 1),
        getScheduleTimelockCaldata()
    );

    targets = new address[](1);
    values = new uint256[](1);
    arguments = new bytes[](1);
    targets[0] = addresses.getAddress("ARBITRUM_SYS");
    arguments[0] = sendToL1;
}
```

The original recorded action remains in `actions[0]`. The override changes the
arrays returned to the Governor encoder.

## Extend simulation

The custom `simulate()` first calls its `_simulateGovernorProposal()` helper on
the Arbitrum fork. The helper follows the OpenZeppelin Governor path used by
FPS: create voting power, delegate, propose, vote, queue, wait for the L2
timelock, and execute. It assigns ten times the initial quorum or threshold to
cover Arbitrum's dynamic quorum after the synthetic delegation checkpoint.

The adapter then:

1. Selects `ethForkId` and pranks as `ARBITRUM_BRIDGE`.
2. Calls the L1 Timelock schedule payload.
3. Decodes the `CallScheduled` log to recover the execute arguments.
4. Advances time by three days and calls `timelock.execute(...)`.
5. Checks whether the scheduled target was `RETRYABLE_TICKET_MAGIC`.
6. For that target, decodes the L2 destination and calldata from the emitted
   bridge log, selects `primaryForkId`, and calls the destination as
   `ARBITRUM_ALIASED_L1_TIMELOCK`.

The description must remain unchanged across Governor hashing, L1 scheduling,
and L1 execution because each step derives its salt or description hash from
the same bytes.

## Implement a concrete proposal

`ArbitrumProposal_01` deploys a mock implementation and governance-action
contract. Its `build()` records one call to the L2 Upgrade Executor from the
aliased L1 Timelock:

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

`validate()` checks that the WETH gateway proxy points to the new
implementation.

The current example repository also includes
[`ArbitrumProposal_02`](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/arbitrum/ArbitrumProposal_02.sol),
which targets Ethereum. It sets `executionChain` to `ETH`, selects `ethForkId`
for deployment and the recorded Upgrade Executor call, and returns to
`primaryForkId` before Governor simulation. Its `validate()` selects Ethereum
to inspect the upgraded L1 WETH gateway, then restores the Arbitrum fork.

Run the current example as a dry-run simulation:

```sh
forge script \
  src/proposals/arbitrum/ArbitrumProposal_01.sol:ArbitrumProposal_01 \
  -vvvv
```

Configure `arbitrum` and `ethereum` RPC aliases in `foundry.toml`. Review the
wrapped Governor action, the inner L1 Timelock schedule operation, and the
final execution calldata separately.
