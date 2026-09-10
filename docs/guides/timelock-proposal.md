# Timelock Proposal

`TimelockProposal` encodes recorded actions as an OpenZeppelin `TimelockController` batch. The complete example is [`TimelockProposal_01`](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/simple-vault-timelock/TimelockProposal_01.sol).

## Proposal contract

Inherit `TimelockProposal`, define the proposal metadata, configure the fork and registry in `run()`, and set the timelock before calling `super.run()`.

```solidity
contract TimelockProposal_01 is TimelockProposal {
    function name() public pure override returns (string memory) {
        return "TIMELOCK_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Timelock proposal mock";
    }

    function run() public override {
        setPrimaryForkId(vm.createSelectFork("sepolia"));

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 11155111;
        setAddresses(new Addresses("./addresses", chainIds));

        setTimelock(addresses.getAddress("PROTOCOL_TIMELOCK"));
        super.run();
    }
}
```

The fork must be selected before current-chain calls such as `addresses.getAddress("PROTOCOL_TIMELOCK")`.

### Deploy contracts

`deploy()` runs inside the broadcast started by `Proposal.run()`. Add deployed contracts to `Addresses` with the correct contract flag. Make deployment conditional so a later run can use the persisted address.

```solidity
function deploy() public override {
    if (!addresses.isAddressSet("TIMELOCK_VAULT")) {
        Vault timelockVault = new Vault();
        addresses.addAddress("TIMELOCK_VAULT", address(timelockVault), true);
        timelockVault.transferOwnership(address(timelock));
    }

    if (!addresses.isAddressSet("TIMELOCK_TOKEN")) {
        Token token = new Token();
        addresses.addAddress("TIMELOCK_TOKEN", address(token), true);
        token.transferOwnership(address(timelock));

        uint256 balance = token.balanceOf(address(this)) > 0
            ? token.balanceOf(address(this))
            : token.balanceOf(addresses.getAddress("DEPLOYER_EOA"));
        token.transfer(address(timelock), balance);
    }
}
```

The balance branch supports both script execution, where `DEPLOYER_EOA` receives the initial supply, and tests, where the proposal contract can be the token deployer.

### Build actions

Pass the timelock address to `buildModifier`. Write calls in execution order:

```solidity
function build() public override buildModifier(address(timelock)) {
    address timelockVault = addresses.getAddress("TIMELOCK_VAULT");
    address token = addresses.getAddress("TIMELOCK_TOKEN");
    uint256 balance = Token(token).balanceOf(address(timelock));

    Vault(timelockVault).whitelistToken(token, true);
    Token(token).approve(timelockVault, balance);
    Vault(timelockVault).deposit(token, balance);
}
```

FPS records the three direct `Call` accesses as proposal actions, then restores the pre-build snapshot. Read [Proposal functions](../overview/architecture/proposal-functions.md#build-function) for the recording rules and duplicate-action check.

### Simulate the timelock

Call `_simulateActions()` with accounts that have the proposer and executor roles:

```solidity
function simulate() public override {
    address dev = addresses.getAddress("DEPLOYER_EOA");
    _simulateActions(dev, dev);
}
```

The helper performs the following steps:

1. Compute `salt` as `keccak256(abi.encode(description()))`.
2. Compute the operation hash with `hashOperationBatch(targets, values, payloads, predecessor, salt)`.
3. Call `scheduleBatch(...)` when the operation is not already registered.
4. Advance time by `timelock.getMinDelay()`.
5. Call `executeBatch(...)` when the operation is not already complete.

`predecessor` defaults to `bytes32(0)`. Set it in the derived proposal when the operation depends on another timelock operation.

### Validate state

Put post-execution assertions in `validate()`. The example verifies ownership, the vault configuration, the deposited amount, and the final token balances:

```solidity
function validate() public view override {
    Vault timelockVault = Vault(addresses.getAddress("TIMELOCK_VAULT"));
    Token token = Token(addresses.getAddress("TIMELOCK_TOKEN"));

    uint256 balance = token.balanceOf(address(timelockVault));
    (uint256 amount,) =
        timelockVault.deposits(address(token), address(timelock));

    assertEq(amount, balance);
    assertTrue(timelockVault.tokenWhitelist(address(token)));
    assertEq(balance, token.totalSupply());
    assertEq(token.owner(), address(timelock));
    assertEq(timelockVault.owner(), address(timelock));
    assertFalse(timelockVault.paused());
}
```

## Calldata and proposal lookup

`getCalldata()` returns `scheduleBatch(address[],uint256[],bytes[],bytes32,bytes32,uint256)` calldata. Its final arguments are `predecessor`, the description-derived salt, and the current minimum delay.

`getExecuteCalldata()` returns `executeBatch(address[],uint256[],bytes[],bytes32,bytes32)` calldata for the same batch.

`getProposalId()` calculates the operation hash and returns it as a `uint256` when the timelock recognizes the operation. It returns `0` for an unknown operation. Enable `DEBUG=true` to print the hash and simulation diagnostics.

## Run the example

The example repository defines a Sepolia RPC endpoint named `sepolia`. Create `addresses/11155111.json` with the deployer first:

```json
[
  {
    "addr": "0x<DEPLOYER_ADDRESS>",
    "name": "DEPLOYER_EOA",
    "isContract": false
  }
]
```

Deploy the tutorial timelock with [`DeployTimelock`](https://github.com/solidity-labs-io/fps-example-repo/blob/main/script/DeployTimelock.s.sol):

```sh
DO_BUILD=false DO_SIMULATE=false DO_PRINT=false \
  forge script script/DeployTimelock.s.sol:DeployTimelock \
  --fork-url sepolia \
  --account "$WALLET_NAME" \
  --sender "$WALLET_ADDRESS" \
  --broadcast --slow -vvvv
```

Add the printed deployment to the same file:

```json
{
  "addr": "0x<TIMELOCK_ADDRESS>",
  "name": "PROTOCOL_TIMELOCK",
  "isContract": true
}
```

Run the proposal:

```sh
forge script \
  src/proposals/simple-vault-timelock/TimelockProposal_01.sol:TimelockProposal_01 \
  --fork-url sepolia \
  --account "$WALLET_NAME" \
  --sender "$WALLET_ADDRESS" \
  --broadcast --slow -vvvv
```

The output includes address additions, the three recorded actions, storage and transfer changes, schedule calldata, and execute calldata. Set `DO_UPDATE_ADDRESS_JSON=true` to persist the deployed vault and token. That option requires write access to `./addresses`.
