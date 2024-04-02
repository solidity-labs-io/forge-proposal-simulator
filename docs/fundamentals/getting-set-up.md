# Getting set up

## Step 1: Add Dependency

Add `forge-proposal-simulator` to your project using Forge:

```sh
forge install https://github.com/solidity-labs-io/forge-proposal-simulator.git
```

## Step 2: Remapping

Update your remappings.txt to include:

```txt
@forge-proposal-simulator=lib/forge-proposal-simulator/
```

## Step 3: Addresses File

Create a JSON file following the standard on
[Addresses](../overview/architecture/addresses.md). We recommend to keep the
addresses file in a separate folder, for example `./addresses/addresses.json`.
Once you have the file, you should allow read access on `foundry.toml`.

```toml
[profile.default]
...
fs_permissions = [{ access = "read", path = "./addresses/Addresses.json"}]
```

## Step 4: Create a Proposal

Create a proposal. Choose a model that fits your needs:

- [Multisig Proposal](../guides/multisig-proposal.md)
- [Timelock Proposal](../guides/timelock-proposal.md)
- [Bravo Proposal](../guides/governor-bravo-proposal.md)

## Step 5: Implement Scripts and Tests

Create scripts and/or tests. For guidance and best practices, refer to the [Guides](../guides/README.md) and [Integration Tests](../testing/integration-tests.md) sections.

Additionally, the [FPS example repo](https://github.com/solidity-labs-io/fps-example-repo) can be consulted for practical examples and further insights.
