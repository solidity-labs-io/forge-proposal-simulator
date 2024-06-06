# Guides

FPS is designed to be loosely coupled, making it easy to integrate into any governance model. Each of these governance models have their unique
specifications. To accommodate the unique requirements of different governance systems, FPS introduces proposal-specific contracts. Each contract is designed to align with their respective governance model. There are mainnet examples added as well for each governance model. These examples highlight how these models are implemented for existing real world projects for proposal simulation.

## Setting Up Your Deployer Address

Before going through guides and mainnet examples to understand each proposal through examples, ensure deployer address is already setup. The deployer address is the one used to broadcast the transactions deploying the proposal contracts. Ensure your deployer address has enough funds from the faucet to cover deployment costs on the testnet. We prioritize security when it comes to private key management. To avoid storing the private key as an environment variable, we use Foundry's cast tool. Ensure cast address is same as Deployer address.

If there are no wallets in the `~/.foundry/keystores/` folder, create one by executing:

```sh
cast wallet import ${wallet_name} --interactive
```
## Executing Proposals
Before proceeding with the guides, make sure to have a cleaned Addresses.json file with read permissions set to `foundry.toml` in your preferred location. Each guide includes a proposal simulation section that provides detailed explanations of the proposal execution steps.

There are two methods for executing proposals:
1. **Using `forge test`**: Detailed information on this method can be found in the [integration-tests.md](../testing/integration-tests.md) section.
2. **Using `forge script`**: All the guides employs this method.


## Validated Governance Models

This framework have been validated through successful integration with leading governance
models. FPS has been tested and confirmed to be compatible with:

1. [Gnosis Safe Multisig](./multisig-proposal.md)
2. [Openzeppelin Timelock Controller](./timelock-proposal.md)
3. [Governor Bravo](./governor-bravo-proposal.md)
4. [Governor OZ](./governor-oz-proposal.md)

## Customized Governance Models

The framework can be customized to meet unique protocol requirements for simulating the proposal flow. An [example](./customizing-proposal.md) has been provided using Arbitrum Proposal flow to demonstrate FPS flexibility.

## Example Contracts

The [Mocks folder](https://github.com/solidity-labs-io/fps-example-repo/tree/main/src/mocks) includes contracts used in the guides mentioned
above for demonstration purposes. Examples include the [Vault](https://github.com/solidity-labs-io/fps-example-repo/blob/feat/test-cleanup/src/mocks/Vault.sol)
and [Token](https://github.com/solidity-labs-io/fps-example-repo/blob/feat/test-cleanup/src/mocks/Token.sol) contracts. It is important to understand that these contracts are intended solely for demonstration and are not for production use due to their lack of validation, testing, and audits. Their sole purpose is to illustrate the deployment process and the setup of protocol parameters within proposals within the forge proposal simulator.

## Known issues

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
