# Overview

The Forge Proposal Simulator (FPS) offers a framework for creating secure governance proposals and deployment scripts, enhancing safety, and ensuring protocol health throughout the proposal lifecycle. The major benefits of using this tool are standardization of proposals, safe calldata generation, and preventing deployment and governance action bugs.

For guidance on tool usage, please read the [documentation](https://solidity-labs.gitbook.io/forge-proposal-simulator/).

## Usage

### Proposal Simulation

#### Step 1: Install

Add `forge-proposal-simulator` to your project using Forge:

```sh
forge install https://github.com/solidity-labs-io/forge-proposal-simulator.git
```

#### Step 2: Set Remappings

Update your remappings.txt to include:

```txt
@forge-proposal-simulator=lib/forge-proposal-simulator/
```

#### Step 3: Create Addresses File

Create a JSON file following the instructions provided in
[Addresses.md](docs/overview/architecture/addresses.md). We recommend keeping the
addresses file in a separate folder, for example `./addresses/addresses.json`.
Once the file is created, be sure to allow read access to `addresses.json` inside of `foundry.toml`.

```toml
[profile.default]
...
fs_permissions = [{ access = "read", path = "./addresses/addresses.json"}]
```

#### Step 4: Create a Proposal

Choose a model that fits your needs:

-   [Multisig Proposal](docs/guides/multisig-proposal.md)
-   [Timelock Proposal](docs/guides/timelock-proposal.md)
-   [Governor Bravo Proposal](docs/guides/governor-bravo-proposal.md)

#### Step 5: Implement Scripts and Tests

Create scripts and/or tests. Check [Guides](docs/guides/multisig-proposal.md) and [Integration Tests](docs/testing/integration-tests.md).

### Type Checking

Type checking allows verification of deployed bytecode on any contracts with the bytecode present in local artifacts. With this feature, developer `A` can easily deploy some contracts, and developer `B` can verify `A`'s deployments by simply running the type checking script. Additionaly, `A` can also use this feature to verify their own deployments. `A` can take the following steps:

- Follow the steps 1 to 3 on [Proposal Simulation](#proposal-simulation) section
- Add the deployed contracts to `Addresses.json`. 
- Create a `TypeCheckAddresses.json` file following the instructions provided in [type-check.md](docs/guides/type-check.md).
- Enter `lib/forge-proposal-simulator/typescript` directory and install npm packages.
``` bash
cd lib/forge-proposal-simulator/typescript && npm i
```
- Run the following command at forge-proposal-simulator root to type check all contracts added in `TypeCheckAddresses.json`.

```bash
cd ../ && forge script script/TypeCheck.s.sol:TypeCheck --ffi --fork-url sepolia
```

## Contribute

There are many ways you can participate and help build the next version of FPS. Check out the [contribution guide](CONTRIBUTING.md)!

## License

Forge Proposal Simulator is made available under the MIT License, which disclaims all warranties in relation to the project and which limits the liability of those that contribute and maintain the project. As set out further in the Terms, you acknowledge that you are solely responsible for any use of Forge Proposal Simulator contracts and you assume all risks associated with any such use. The authors make no warranties about the safety, suitability, reliability, timeliness, and accuracy of the software.

Further license details can be found in [LICENSE](LICENSE).
