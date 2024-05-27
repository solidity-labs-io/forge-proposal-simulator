# Getting Set Up

## Step 1: Add Dependency

Add `forge-proposal-simulator` to your project using Forge:

```sh
forge install https://github.com/solidity-labs-io/forge-proposal-simulator.git
```

## Step 2: Remapping

Update your `remappings.txt` to include:

```sh
echo @forge-proposal-simulator=lib/forge-proposal-simulator/ >> remappings.txt
```

## Step 3: Addresses File

Create a JSON file following the standard on [Addresses](../overview/architecture/addresses.md). We recommend keeping the addresses file in a separate folder, for example, `./addresses/Addresses.json`. Once you have the file, you should allow read access in `foundry.toml`.

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
-   [Governor OZ proposal](../guides/governor-oz-proposal.md)

## Step 5: Run Proposal and Tests

For guidance, documentation, and examples of how to create and simulate a proposal, refer to the [Guides](../guides/introduction.md) and [Integration Tests](../testing/integration-tests.md) sections. These explain the [Governor Bravo Proposal](https://github.com/solidity-labs-io/fps-example-repo/src/proposals/simple-vault-bravo/BravoProposal_01.sol), [Multisig Proposal](https://github.com/solidity-labs-io/fps-example-repo/simple-vault-multisig/src/proposals/MultisigProposal_01.sol), [Timelock Proposal](https://github.com/solidity-labs-io/fps-example-repo/src/proposals/simple-vault-timelock/TimelockProposal_01.sol) and [Governor OZ proposal](https://github.com/solidity-labs-io/fps-example-repo/src/proposals/simple-vault-governor-oz/GovernorOZProposal_01.sol) contracts from the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo). The example repository contains other snippets and usage guides demonstrating each of the proposal types in the forge-proposal-simulator repo.
