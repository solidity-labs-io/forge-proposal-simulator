# Safe Multisig Proposal

`MultisigProposal` packs recorded actions into Safe MultiSend calldata and prints the fields required for a Safe transaction. The complete example is [`MultisigProposal_01`](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/simple-vault-multisig/MultisigProposal_01.sol).

## Proposal contract

Inherit `MultisigProposal`, select the fork, and initialize `Addresses` before calling `super.run()`:

```solidity
contract MultisigProposal_01 is MultisigProposal {
    function name() public pure override returns (string memory) {
        return "MULTISIG_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Multisig proposal mock";
    }

    function run() public override {
        setPrimaryForkId(vm.createSelectFork("sepolia"));

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 11155111;
        setAddresses(new Addresses("./addresses", chainIds));

        super.run();
    }
}
```

### Deploy contracts

The example deploys a vault and token, then transfers their ownership and the token supply to the Safe:

```solidity
function deploy() public override {
    address multisig = addresses.getAddress("DEV_MULTISIG");

    if (!addresses.isAddressSet("MULTISIG_VAULT")) {
        Vault multisigVault = new Vault();
        addresses.addAddress("MULTISIG_VAULT", address(multisigVault), true);
        multisigVault.transferOwnership(multisig);
    }

    if (!addresses.isAddressSet("MULTISIG_TOKEN")) {
        Token token = new Token();
        addresses.addAddress("MULTISIG_TOKEN", address(token), true);
        token.transferOwnership(multisig);

        uint256 balance = token.balanceOf(address(this)) > 0
            ? token.balanceOf(address(this))
            : token.balanceOf(addresses.getAddress("DEPLOYER_EOA"));
        token.transfer(multisig, balance);
    }
}
```

### Build actions

Use the Safe as the caller passed to `buildModifier`:

```solidity
function build()
    public
    override
    buildModifier(addresses.getAddress("DEV_MULTISIG"))
{
    address multisig = addresses.getAddress("DEV_MULTISIG");
    address multisigVault = addresses.getAddress("MULTISIG_VAULT");
    address token = addresses.getAddress("MULTISIG_TOKEN");
    uint256 balance = Token(token).balanceOf(multisig);

    Vault(multisigVault).whitelistToken(token, true);
    Token(token).approve(multisigVault, balance);
    Vault(multisigVault).deposit(token, balance);
}
```

FPS records the direct `Call` accesses in order, captures state and transfer changes, and restores the pre-build snapshot. See [Proposal functions](../overview/architecture/proposal-functions.md#build-function) for the recording rules.

### Select the action operation

Every recorded action uses the same Safe operation. The default is `Call`:

```solidity
function isDelegateCall() public view virtual returns (bool) {
    return false;
}
```

Override it when every action must run as `DelegateCall`:

```solidity
function isDelegateCall() public pure override returns (bool) {
    return true;
}
```

Delegatecalled target code executes in the Safe's storage context. Use this mode only for contracts designed for Safe delegatecall execution.

### Simulate the Safe transaction

Call `_simulateActions()` with the Safe address:

```solidity
function simulate() public override {
    _simulateActions(addresses.getAddress("DEV_MULTISIG"));
}
```

The helper saves the Safe's runtime bytecode, installs a modified Safe v1.4.1 runtime that bypasses signature checks, calls `execTransaction(...)`, and restores the original runtime. Safe storage remains in place during the call.

The simulated `execTransaction(...)` uses the values from `getSafeTransaction()`. `safeTxGas`, `baseGas`, and `gasPrice` are zero. `gasToken` and `refundReceiver` are the zero address, and `signatures` is empty. The call is sent as the Safe address so the nested actions execute with the same caller context as the submitted transaction.

### Validate state

The example checks ownership, vault configuration, deposit accounting, and final balances:

```solidity
function validate() public view override {
    Vault multisigVault = Vault(addresses.getAddress("MULTISIG_VAULT"));
    Token token = Token(addresses.getAddress("MULTISIG_TOKEN"));
    address multisig = addresses.getAddress("DEV_MULTISIG");

    uint256 balance = token.balanceOf(address(multisigVault));
    (uint256 amount,) =
        multisigVault.deposits(address(token), multisig);

    assertEq(amount, balance);
    assertTrue(multisigVault.tokenWhitelist(address(token)));
    assertEq(balance, token.totalSupply());
    assertEq(token.owner(), multisig);
    assertEq(multisigVault.owner(), multisig);
    assertFalse(multisigVault.paused());
}
```

## MultiSend encoding

`getCalldata()` packs each action with Safe's transaction format:

```text
uint8 operation | address target | uint256 value | uint256 dataLength | bytes data
```

It concatenates the packed actions and returns `multiSend(bytes)` calldata. The inner `operation` is `0` for the default call mode and `1` when `isDelegateCall()` returns `true`.

Use `getSafeTransaction()` for the outer Safe transaction:

| Field | Call actions | Delegatecall actions |
| --- | --- | --- |
| `to` | `MultiSendCallOnly` (`0x40A2aCCbd92BCA938b02010E17A5b8929b49130D`) | `MultiSend` (`0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761`) |
| `value` | `0` | `0` |
| `data` | `multiSend(bytes)` calldata | `multiSend(bytes)` calldata |
| `operation` | `1` (`DelegateCall`) | `1` (`DelegateCall`) |

The outer Safe transaction always delegatecalls the selected MultiSend contract. `MultiSendCallOnly` accepts call actions. Standard `MultiSend` is required when the packed actions use delegatecall.

Safe transactions have no numeric proposal registry, so `getProposalId()` reverts with `Not implemented`.

## Run the example

Create a Sepolia Safe at [app.safe.global](https://app.safe.global/) and record its address in `addresses/11155111.json`:

```json
[
  {
    "addr": "0x<SAFE_ADDRESS>",
    "name": "DEV_MULTISIG",
    "isContract": true
  },
  {
    "addr": "0x<DEPLOYER_ADDRESS>",
    "name": "DEPLOYER_EOA",
    "isContract": false
  }
]
```

Run the proposal:

```sh
forge script \
  src/proposals/simple-vault-multisig/MultisigProposal_01.sol:MultisigProposal_01 \
  --fork-url sepolia \
  --account "$WALLET_NAME" \
  --sender "$WALLET_ADDRESS" \
  --broadcast --slow -vvvv
```

The output includes deployed-address changes, recorded actions, storage and transfer changes, and the `to`, `value`, `data`, and `operation` fields for the Safe transaction. Enter those four fields in the Safe transaction builder. Set `DO_UPDATE_ADDRESS_JSON=true` to persist the vault and token addresses when the address directory has write permission.
