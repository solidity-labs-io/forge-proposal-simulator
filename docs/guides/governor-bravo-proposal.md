# Governor Bravo Proposal

`GovernorBravoProposal` converts recorded actions into `GovernorBravoDelegate.propose(...)` calldata and simulates the complete voting and timelock lifecycle. The complete example is [`BravoProposal_01`](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/simple-vault-bravo/BravoProposal_01.sol).

## Proposal contract

Inherit `GovernorBravoProposal` and set the Governor Bravo contract before calling `super.run()`:

```solidity
contract BravoProposal_01 is GovernorBravoProposal {
    function name() public pure override returns (string memory) {
        return "BRAVO_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Bravo proposal mock";
    }

    function run() public override {
        setPrimaryForkId(vm.createSelectFork("sepolia"));

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 11155111;
        setAddresses(new Addresses("./addresses", chainIds));

        setGovernor(addresses.getAddress("PROTOCOL_GOVERNOR"));
        super.run();
    }
}
```

Select the fork before using current-chain address lookups.

### Deploy contracts

The example deploys a vault and token, then transfers their ownership and the token supply to the Governor Bravo timelock:

```solidity
function deploy() public override {
    address owner = addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO");

    if (!addresses.isAddressSet("BRAVO_VAULT")) {
        Vault bravoVault = new Vault();
        addresses.addAddress("BRAVO_VAULT", address(bravoVault), true);
        bravoVault.transferOwnership(owner);
    }

    if (!addresses.isAddressSet("BRAVO_VAULT_TOKEN")) {
        Token token = new Token();
        addresses.addAddress("BRAVO_VAULT_TOKEN", address(token), true);
        token.transferOwnership(owner);

        uint256 balance = token.balanceOf(address(this)) > 0
            ? token.balanceOf(address(this))
            : token.balanceOf(addresses.getAddress("DEPLOYER_EOA"));
        token.transfer(owner, balance);
    }
}
```

`Proposal.run()` broadcasts this stage from `DEPLOYER_EOA` when `DO_DEPLOY=true`.

### Build actions

Use the Governor Bravo timelock as the caller passed to `buildModifier`:

```solidity
function build()
    public
    override
    buildModifier(addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO"))
{
    address timelock = addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO");
    address bravoVault = addresses.getAddress("BRAVO_VAULT");
    address token = addresses.getAddress("BRAVO_VAULT_TOKEN");
    uint256 balance = Token(token).balanceOf(timelock);

    Vault(bravoVault).whitelistToken(token, true);
    Token(token).approve(bravoVault, balance);
    Vault(bravoVault).deposit(token, balance);
}
```

The state-diff recorder retains the three direct `Call` accesses in order and restores the fork to its pre-build state. See [Proposal functions](../overview/architecture/proposal-functions.md#build-function) for the action filters.

### Simulate governance

`GovernorBravoProposal.simulate()` supplies a synthetic proposer with the larger of `quorumVotes()` and `proposalThreshold()`, delegates the votes, and advances through these states:

```text
Pending -> Active -> Succeeded -> Queued -> Executed
```

The simulation submits `propose(...)`, casts a support vote, advances by the voting delay and voting period, queues the proposal, advances by the timelock delay, and executes it.

Before those steps, the implementation writes the Governor address to slot `0` of the timelock. This supports the legacy Compound timelock layout used by the simulator and handles deployments where the current timelock admin no longer matches the configured Governor. Override `simulate()` for a Governor Bravo deployment whose timelock stores its admin elsewhere.

### Validate state

`validate()` runs after execution. The example checks the timelock's ownership, vault configuration, deposit accounting, and balances:

```solidity
function validate() public view override {
    Vault bravoVault = Vault(addresses.getAddress("BRAVO_VAULT"));
    Token token = Token(addresses.getAddress("BRAVO_VAULT_TOKEN"));
    address timelock = addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO");

    uint256 balance = token.balanceOf(address(bravoVault));
    (uint256 amount,) = bravoVault.deposits(address(token), timelock);

    assertEq(amount, balance);
    assertTrue(bravoVault.tokenWhitelist(address(token)));
    assertEq(balance, token.totalSupply());
    assertEq(token.owner(), timelock);
    assertEq(bravoVault.owner(), timelock);
    assertFalse(bravoVault.paused());
}
```

## Calldata and proposal lookup

`getCalldata()` returns calldata for:

```solidity
propose(
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    string description
)
```

FPS supplies an empty string for every entry in `signatures` and stores each complete function call in `calldatas`.

`getProposalId()` scans from `governor.proposalCount()` down to proposal `1`. For each proposal it reads `getActions(id)`, reconstructs the `propose(...)` calldata with the local description, and compares the calldata hashes. It returns the newest matching proposal ID or `0` when no proposal matches. `DEBUG=true` prints a matching ID.

## Run the example

Create `addresses/11155111.json` with `DEPLOYER_EOA`:

```json
[
  {
    "addr": "0x<DEPLOYER_ADDRESS>",
    "name": "DEPLOYER_EOA",
    "isContract": false
  }
]
```

Deploy the mock timelock, governance token, and Governor Bravo with [`DeployGovernorBravo`](https://github.com/solidity-labs-io/fps-example-repo/blob/main/script/DeployGovernorBravo.s.sol):

```sh
DO_BUILD=false DO_SIMULATE=false DO_PRINT=false \
  forge script script/DeployGovernorBravo.s.sol:DeployGovernorBravo \
  --fork-url sepolia \
  --account "$WALLET_NAME" \
  --sender "$WALLET_ADDRESS" \
  --broadcast --slow -vvvv
```

Add the printed addresses under these names:

```json
[
  {
    "addr": "0x<TIMELOCK_ADDRESS>",
    "name": "PROTOCOL_TIMELOCK_BRAVO",
    "isContract": true
  },
  {
    "addr": "0x<GOVERNANCE_TOKEN_ADDRESS>",
    "name": "PROTOCOL_GOVERNANCE_TOKEN",
    "isContract": true
  },
  {
    "addr": "0x<GOVERNOR_ADDRESS>",
    "name": "PROTOCOL_GOVERNOR",
    "isContract": true
  },
  {
    "addr": "0x<DEPLOYER_ADDRESS>",
    "name": "DEPLOYER_EOA",
    "isContract": false
  }
]
```

The deployment queues `setPendingAdmin(PROTOCOL_GOVERNOR)` on the timelock.
Read `eta` from its `QueueTransaction` event, wait until that timestamp, and
run [`InitializeBravo`](https://github.com/solidity-labs-io/fps-example-repo/blob/main/script/InitializeBravo.s.sol).
Replace the example `ETA` value with the event value:

```sh
ETA=1700000000 \
DO_BUILD=false DO_SIMULATE=false DO_PRINT=false \
  forge script script/InitializeBravo.s.sol:InitializeBravo \
  --fork-url sepolia \
  --account "$WALLET_NAME" \
  --sender "$WALLET_ADDRESS" \
  --broadcast --slow -vvvv
```

Add the printed `PROTOCOL_GOVERNOR_ALPHA` address to the JSON file. The initialization script executes the queued admin change and calls `_initiate(...)` on the Governor.

Run the vault proposal:

```sh
forge script \
  src/proposals/simple-vault-bravo/BravoProposal_01.sol:BravoProposal_01 \
  --fork-url sepolia \
  --account "$WALLET_NAME" \
  --sender "$WALLET_ADDRESS" \
  --broadcast --slow -vvvv
```

The output includes deployed-address changes, recorded actions, state and transfer changes, and `propose(...)` calldata. Set `DO_UPDATE_ADDRESS_JSON=true` to persist the vault and token addresses when the address directory has write permission.
