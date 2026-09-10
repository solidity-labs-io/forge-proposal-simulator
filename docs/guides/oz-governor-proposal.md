# OpenZeppelin Governor Proposal

`OZGovernorProposal` encodes recorded actions for an OpenZeppelin Governor and simulates proposal creation, voting, timelock queueing, and execution. The complete example is [`OZGovernorProposal_01`](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/simple-vault-governor-oz/OZGovernorProposal_01.sol).

## Proposal contract

Inherit `OZGovernorProposal`, select the fork, initialize `Addresses`, and set the Governor before calling `super.run()`:

```solidity
contract OZGovernorProposal_01 is OZGovernorProposal {
    function name() public pure override returns (string memory) {
        return "OZ_GOVERNOR_PROPOSAL";
    }

    function description() public pure override returns (string memory) {
        return "OZ Governor proposal mock 1";
    }

    function run() public override {
        setPrimaryForkId(vm.createSelectFork("sepolia"));

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 11155111;
        setAddresses(new Addresses("./addresses", chainIds));

        setGovernor(addresses.getAddress("OZ_GOVERNOR"));
        super.run();
    }
}
```

The inherited simulation expects the Governor to implement the `GovernorVotes` and `GovernorTimelockControl` interfaces used by FPS.

### Deploy contracts

The example deploys a vault and token, then transfers their ownership and the token supply to the Governor's timelock:

```solidity
function deploy() public override {
    address owner = addresses.getAddress("OZ_GOVERNOR_TIMELOCK");

    if (!addresses.isAddressSet("OZ_GOVERNOR_VAULT")) {
        Vault ozGovernorVault = new Vault();
        addresses.addAddress(
            "OZ_GOVERNOR_VAULT", address(ozGovernorVault), true
        );
        ozGovernorVault.transferOwnership(owner);
    }

    if (!addresses.isAddressSet("OZ_GOVERNOR_VAULT_TOKEN")) {
        Token token = new Token();
        addresses.addAddress(
            "OZ_GOVERNOR_VAULT_TOKEN", address(token), true
        );
        token.transferOwnership(owner);

        uint256 balance = token.balanceOf(address(this)) > 0
            ? token.balanceOf(address(this))
            : token.balanceOf(addresses.getAddress("DEPLOYER_EOA"));
        token.transfer(owner, balance);
    }
}
```

### Build actions

The timelock executes successful Governor proposals, so use it as the caller passed to `buildModifier`:

```solidity
function build()
    public
    override
    buildModifier(addresses.getAddress("OZ_GOVERNOR_TIMELOCK"))
{
    address timelock = addresses.getAddress("OZ_GOVERNOR_TIMELOCK");
    address ozGovernorVault = addresses.getAddress("OZ_GOVERNOR_VAULT");
    address token = addresses.getAddress("OZ_GOVERNOR_VAULT_TOKEN");
    uint256 balance = Token(token).balanceOf(timelock);

    Vault(ozGovernorVault).whitelistToken(token, true);
    Token(token).approve(ozGovernorVault, balance);
    Vault(ozGovernorVault).deposit(token, balance);
}
```

FPS records these calls in order, captures their state and transfer changes, and restores the pre-build snapshot. See [Proposal functions](../overview/architecture/proposal-functions.md#build-function) for the recording rules.

### Simulate governance

`OZGovernorProposal.simulate()` reads the voting token through `GovernorVotes.token()`. It gives a synthetic proposer the larger of the current quorum and proposal threshold, delegates those votes, and advances through these states:

```text
Pending -> Active -> Succeeded -> Queued -> Executed
```

The simulation:

1. Calls `propose(targets, values, calldatas, description)`.
2. Confirms the returned ID equals `hashProposal(...)`.
3. Advances by `votingDelay()` and casts a support vote.
4. Advances by `votingPeriod()` and confirms the proposal succeeded.
5. Warps by `governor.proposalEta(proposalId) + 1`, then queues the proposal
   with its description hash.
6. Advances by `TimelockController.getMinDelay()` and executes the proposal
   through the Governor.

Override `simulate()` when the Governor uses different voting, queueing, or execution extensions.

### Validate state

Put protocol assertions in `validate()`. The example checks the timelock's ownership, vault configuration, deposit accounting, and balances:

```solidity
function validate() public view override {
    Vault ozGovernorVault =
        Vault(addresses.getAddress("OZ_GOVERNOR_VAULT"));
    Token token =
        Token(addresses.getAddress("OZ_GOVERNOR_VAULT_TOKEN"));
    address timelock = addresses.getAddress("OZ_GOVERNOR_TIMELOCK");

    uint256 balance = token.balanceOf(address(ozGovernorVault));
    (uint256 amount,) =
        ozGovernorVault.deposits(address(token), timelock);

    assertEq(amount, balance);
    assertTrue(ozGovernorVault.tokenWhitelist(address(token)));
    assertEq(balance, token.totalSupply());
    assertEq(token.owner(), timelock);
    assertEq(ozGovernorVault.owner(), timelock);
    assertFalse(ozGovernorVault.paused());
}
```

## Calldata and proposal lookup

`getCalldata()` returns calldata for:

```solidity
propose(
    address[] targets,
    uint256[] values,
    bytes[] calldatas,
    string description
)
```

OpenZeppelin identifies the proposal with:

```solidity
governor.hashProposal(
    targets,
    values,
    calldatas,
    keccak256(abi.encodePacked(description()))
);
```

`getProposalId()` computes that hash and calls `governor.state(proposalId)`. It returns the hash when `state()` succeeds and `0` when `state()` reverts, which indicates that the Governor does not recognize the proposal.

Queueing and execution use the same targets, values, calldatas, and description hash. A description change therefore changes the proposal ID.

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

Deploy the tutorial voting token, timelock, and Governor with [`DeployOZGovernor`](https://github.com/solidity-labs-io/fps-example-repo/blob/main/script/DeployOZGovernor.s.sol):

```sh
DO_BUILD=false DO_SIMULATE=false DO_PRINT=false \
  forge script script/DeployOZGovernor.s.sol:DeployOZGovernor \
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
    "name": "OZ_GOVERNOR_TIMELOCK",
    "isContract": true
  },
  {
    "addr": "0x<GOVERNANCE_TOKEN_ADDRESS>",
    "name": "OZ_GOVERNOR_GOVERNANCE_TOKEN",
    "isContract": true
  },
  {
    "addr": "0x<GOVERNOR_ADDRESS>",
    "name": "OZ_GOVERNOR",
    "isContract": true
  },
  {
    "addr": "0x<DEPLOYER_ADDRESS>",
    "name": "DEPLOYER_EOA",
    "isContract": false
  }
]
```

The deployment grants the Governor the timelock proposer role. Run the vault proposal:

```sh
forge script \
  src/proposals/simple-vault-governor-oz/OZGovernorProposal_01.sol:OZGovernorProposal_01 \
  --fork-url sepolia \
  --account "$WALLET_NAME" \
  --sender "$WALLET_ADDRESS" \
  --broadcast --slow -vvvv
```

The output includes deployed-address changes, recorded actions, storage and transfer changes, and Governor proposal calldata. Set `DO_UPDATE_ADDRESS_JSON=true` to persist the vault and token addresses when the address directory has write permission.
