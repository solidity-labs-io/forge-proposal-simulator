# Contributing

Use [GitHub issues](https://github.com/solidity-labs-io/forge-proposal-simulator/issues/new)
for bug reports and feature proposals. Search open and closed issues before
filing a new one. Include the affected proposal type, reproduction steps, and
the expected behavior.

Discuss non-trivial code changes with the maintainers in an issue before
opening a pull request. Small fixes and documentation corrections can go
directly to a pull request.

## Local checks

Initialize dependencies and install the Solidity linter:

```sh
git submodule update --init --recursive
npm install
```

Run the checks used by the repository:

```sh
npm run lint
forge fmt --check
forge build
forge test
```

The integration tests fork mainnet and require a working `mainnet` endpoint in
`foundry.toml` or an equivalent Foundry configuration. Tests for
`Addresses.updateJson()` write to files under `addresses/`, so inspect the
working tree after running the suite.

Keep changes scoped to the issue. Add or update tests for behavior changes, and
update the relevant guide when a public function, environment flag, command,
or generated payload changes.

Issues labeled
[good first issue](https://github.com/solidity-labs-io/forge-proposal-simulator/labels/good%20first%20issue)
are intended for new contributors.
