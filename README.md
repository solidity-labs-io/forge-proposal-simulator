# Overview

The Forge Proposal Simulator (FPS) offers a framework for creating secure governance proposals and deployment scripts, enhancing safety, and ensuring protocol health throughout the proposal lifecycle. The major benefits of using this tool are standardization of proposals, safe calldata generation, and preventing deployment parameterization and governance action bugs.

For guidance on how to use the library please check FPS [documentation](https://solidity-labs.gitbook.io/forge-proposal-simulator/)

## Usage

### Step 1: Add Dependency

Add `forge-proposal-simulator` to your project using Forge:

```sh
forge install https://github.com/solidity-labs-io/forge-proposal-simulator.git
```

### Step 2: Remapping

Update your remappings.txt to include:

```txt
@forge-proposal-simulator=lib/forge-proposal-simulator/
```

### Step 3: Addresses File

Create a JSON file following the standard on
[Addresses](docs/overview/architecture/addresses.md). We recommend keeping the
addresses file in a separate folder, for example `./addresses/addresses.json`.
Once the file is created, be sure to allow read access to `addresses.json` inside of `foundry.toml`.

```toml
[profile.default]
...
fs_permissions = [{ access = "read", path = "./addresses/addresses.json"}]
```

### Step 4: Create a Proposal

Create a proposal. Choose a model that fits your needs:

-   [Multisig Proposal](docs/guides/multisig-proposal.md)
-   [Timelock Proposal](docs/guides/timelock-proposal.md)

### Step 5: Implement Scripts and Tests

Create scripts and/or tests. Check [Guides](docs/guides/multisig-proposal.md) and [Integration Tests](docs/testing/integration-tests.md).

## Contribute

There are many ways you can participate and help build high quality software. Check out the [contribution guide](CONTRIBUTING.md)!

## License

Forge Proposal Simulator is made available under the MIT License, which disclaims all warranties in relation to the project and which limits the liability of those that contribute and maintain the project. As set out further in the Terms, you acknowledge that you are solely responsible for any use of Forge Proposal Simulator contracts and you assume all risks associated with any such use. The authors make no warranties about the safety, suitability, reliability, timeliness, and accuracy of the software.

Further license details can be found in [LICENSE](LICENSE).
