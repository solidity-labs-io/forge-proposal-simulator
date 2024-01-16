# Guides

FPS is designed to be loosely coupled, making it easy to integrate into any
governance model. Each of these governance models have their unique
specifications. To accommodate the unique requirements of different governance systems, FPS
introduces [proposal-specific](proposals/) contracts. Each contract is designed to align with their respective governance model.

## Validated Governance Models

This framework have been validated through successful integration with leading governance
models. FPS has been tested and confirmed to be compatible with:

1. [Gnosis Safe Multisig](./multisig-proposal.md)
2. [Openzeppelin Timelock Controller](./timelock-proposal.md)

## Example Contracts

The [Examples folder](examples/) includes contracts used in the guides mentioned
above for demonstration purposes. Examples include [Vault](examples/Vault.sol)
and [MockToken](examples/MockToken.sol). It is important to understand that
these contracts are intended solely for demonstration and are not recommended for production use due to their lack of validation and audit processes. Their primary purpose is to illustrate the deployment process and the setup of protocol parameters within proposals.

For practical examples and additional insights, the [FPS example repo](https://github.com/solidity-labs-io/fps-example-repo) is also available for consultation.

## Know issues

Be aware of the following issues:

### Error: Failed to deploy script

```sh
Error:
Failed to deploy script:
Execution reverted: EvmError: Revert
```

If you encounter this error when running `forge script`, consider the following troubleshooting steps:

1. **Duplicate Contract Addresses:** Ensure there are no duplicate contract addresses in the `addresses.json` file for the same chain.
2. **Proposal Contract Logic:** Execution reversion can occur due to flaws in
   the proposal contract logic. It is recommended to deploy the proposal
   contract within the `PostProposalCheck` contract and then running with `forge test` for clearer error messages and easier debugging.
