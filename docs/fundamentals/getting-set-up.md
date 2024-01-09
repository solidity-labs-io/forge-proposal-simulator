# Getting set up

### Step 1: Add library as a dependency to your project

```sh
forge install https://github.com/solidity-labs-io/forge-proposal-simulator.git
```

### Step 2: Remapping

Add the follow remapping to your `remappings.txt` file:

```txt
@forge-proposal-simulator=/lib/forge-proposal-simulator/
```

### Step 3: Create your first proposal following FPS standard by inheriting one of the proposal models

Check implementation guides on [Multisig
Proposal](../guides/multisig-proposal.md) and [Timelock Proposal](../guides/timelock-proposal.md)

### Step 4: Addresses file

Creates a JSON file following the standard on [Addresses](../overview/architecture/addresses.md)

### Step 5: Using FPS on your Scripts and Tests

Create scripts and/or tests. Check [Guides](../guides/multisig-proposal.md) and [Integration Tests](../testing/integration-tests.md).
