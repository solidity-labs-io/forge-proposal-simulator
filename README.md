# Forge Proposal Simulator

Forge Proposal Simulator (FPS) records privileged Solidity calls as governance
actions, encodes them for a supported governance system, and executes them on a
fork for validation.

FPS includes proposal types for Safe multisigs, OpenZeppelin
`TimelockController`, Compound Governor Bravo, and OpenZeppelin Governor. See
the [documentation](https://solidity-labs.gitbook.io/forge-proposal-simulator/)
for complete guides and mainnet examples.

## Install

Install FPS as a Foundry dependency:

```sh
forge install solidity-labs-io/forge-proposal-simulator
```

Add this entry to `remappings.txt`:

```text
@forge-proposal-simulator/=lib/forge-proposal-simulator/
```

Imports can then reference the repository root:

```solidity
import {
    MultisigProposal
} from "@forge-proposal-simulator/src/proposals/MultisigProposal.sol";
import {
    Addresses
} from "@forge-proposal-simulator/addresses/Addresses.sol";
```

## Configure addresses

FPS loads one JSON file per chain from an address directory. For example,
`./addresses/1.json` stores mainnet entries and `./addresses/11155111.json`
stores Sepolia entries. The proposal passes the directory and the chain IDs to
the `Addresses` constructor.

Grant Foundry read access to the directory:

```toml
[profile.default]
fs_permissions = [{ access = "read", path = "./addresses" }]
```

Use `read-write` when `DO_UPDATE_ADDRESS_JSON=true` will persist changes:

```toml
[profile.default]
fs_permissions = [{ access = "read-write", path = "./addresses" }]
```

See [Addresses](docs/overview/architecture/addresses.md) for the JSON schema,
constructor setup, registry operations, and persistence behavior.

## Write and run a proposal

Choose the proposal type for the target governance system:

- [Safe multisig](docs/guides/multisig-proposal.md)
- [OpenZeppelin timelock](docs/guides/timelock-proposal.md)
- [Governor Bravo](docs/guides/governor-bravo-proposal.md)
- [OpenZeppelin Governor](docs/guides/oz-governor-proposal.md)

A proposal configures its fork and address registry in `run()`, defines direct
privileged calls in `build()`, and checks the executed state in `validate()`.
The base lifecycle runs `deploy()`, `preBuildMock()`, `build()`, `simulate()`,
`validate()`, and `print()`, followed by optional address JSON persistence.

Use the [introduction](docs/guides/introduction.md) for project setup and the
[integration test guide](docs/testing/integration-tests.md) to execute a
proposal from a test suite.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for repository checks and pull request
requirements.

## License

FPS is available under the [MIT License](LICENSE). The software is provided
without warranty. Users are responsible for reviewing proposal code, generated
calldata, and execution results before submitting transactions.
