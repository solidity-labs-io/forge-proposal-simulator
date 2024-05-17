# Getting set up

## Step 1: Add Dependency

Add `forge-proposal-simulator` to your project using Forge:

```sh
forge install https://github.com/solidity-labs-io/forge-proposal-simulator.git
```

## Step 2: Remapping

Update your remappings.txt to include:

```sh
echo @forge-proposal-simulator=lib/forge-proposal-simulator/ >> remappings.txt
```

## Step 3: Addresses File

Create a JSON file following the standard on
[Addresses](../overview/architecture/addresses.md). We recommend to keep the
addresses file in a separate folder, for example `./addresses/Addresses.json`.
Once you have the file, you should allow read access on `foundry.toml`.

```toml
[profile.default]
...
fs_permissions = [{ access = "read", path = "./addresses/Addresses.json"}]
```

## Step 4: Create a Proposal

Create a proposal. Choose a model that fits your needs:

-   [Multisig Proposal](../guides/multisig-proposal.md)
-   [Timelock Proposal](../guides/timelock-proposal.md)
-   [Bravo Proposal](../guides/governor-bravo-proposal.md)

## Step 5: Run proposal and Tests

For guidance and best practices on how to create and simulate a proposal, refer to the [Guides](../guides/introduction.md) and [Integration Tests](../testing/integration-tests.md) sections. These guides explain the [BravoProposal_01](https://github.com/solidity-labs-io/fps-example-repo/src/proposals/BravoProposal_01.sol), [MultisigProposal_01](https://github.com/solidity-labs-io/fps-example-repo/src/proposals/MultisigProposal_01.sol), [TimelockProposal_01](https://github.com/solidity-labs-io/fps-example-repo/src/proposals/TimelockProposal_01.sol) contracts from the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo). Additionally, there are more examples for each of the proposal types on the repo.
