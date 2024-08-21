# Guides

FPS is designed to be loosely coupled, making it easy to integrate into any governance model. Each of these governance models have their unique specifications. To accommodate the unique requirements of different governance systems, FPS introduces governance-specific contracts. Each contract is designed to align with their respective governance model. There are mainnet examples added as well for each governance model.

## Getting Set Up

### Step 1: Add Dependency

Add `forge-proposal-simulator` to your project using Forge:

```sh
forge install https://github.com/solidity-labs-io/forge-proposal-simulator.git
```

### Step 2: Remapping

Update your `remappings.txt` to include:

```sh
echo @forge-proposal-simulator=lib/forge-proposal-simulator/ >> remappings.txt
```

### Step 3: Addresses File

Create a JSON file following the standard on [Addresses](../overview/architecture/addresses.md). It is recommended to keep the JSON file in a separate folder, for example, `./addresses/31337.json`. The name of the JSON file should be the same as the network id. If there are multiple networks, addresses should be added in the JSON files corresponding to their network. Be sure to allow read access for this file in `foundry.toml`.

```toml
[profile.default]
...
fs_permissions = [{ access = "read", path = "./addresses/31337.json"}]
```

### Step 4: Setting Up Your Deployer Address

The deployer address is the one used to broadcast the transactions deploying the proposal contracts. Ensure your deployer address has enough funds from the faucet to cover deployment costs on the testnet. Security is prioritized when it comes to private key management. To avoid storing the private key as an environment variable foundry's cast tool is used. Ensure cast address is the same as deployer address.

If there are no wallets in the `~/.foundry/keystores/` folder, create one by executing:

```sh
cast wallet import ${wallet_name} --interactive
```

## Executing Proposals

Before proceeding with the guides, make sure to have a cleaned JSON file with read permissions set to `foundry.toml` in your preferred location. Each guide includes a proposal simulation section that provides detailed explanations of the proposal execution steps.

There are two methods for executing proposals:

1. **Using `forge test`**: Detailed information on this method can be found in the [integration-tests.md](../testing/integration-tests.md) section.
2. **Using `forge script`**: All the guides employs this method.

Ensure that the ${wallet_name} and ${wallet_address} accurately match the wallet details saved in `~/.foundry/keystores/` at the time of proposal simulation through `forge script`. It's essential to verify that ${wallet_address} is correctly listed as the deployer address in the JSON file. Failure to align these details will result in script execution failure. If a password was provide to the wallet, the script will prompt for the password before broadcasting the proposal.

## Validated Governance Models

This framework has been validated through successful integration with leading governance models. FPS has been tested and confirmed to be compatible with governance models specified below. Guides below explain how FPS can be used to simulate governance proposals.

1. [Gnosis Safe Multisig](./multisig-proposal.md)
2. [Openzeppelin Timelock Controller](./timelock-proposal.md)
3. [Governor Bravo](./governor-bravo-proposal.md)
4. [OZ Governor](./oz-governor-proposal.md)

Each guide drafts a proposal to perform the following steps:

1. deploy new instances of `Vault` and `Token`
2. mint tokens to governance contract
3. transfer ownerships of `Vault` and `Token` to respective governance contract
4. whitelist `Token` on `Vault`
5. approve and deposit all tokens into `Vault`

Above `Token` and `Vault` contracts can be found in the fps-example-repo [mocks folder](https://github.com/solidity-labs-io/fps-example-repo/tree/main/src/mocks/vault). Clone the fps-example-repo repo before proceeding with the respective guides. It is important to understand that these contracts are intended solely for demonstration and are not for production use due to their lack of validation, testing, and audits. Their sole purpose is to illustrate the deployment process and the setup of protocol parameters within proposals within the forge proposal simulator.

## Customized Governance Models

The framework can be customized to meet unique protocol requirements for simulating the proposal flow. An [example](./customizing-proposal.md) has been provided using Arbitrum Proposal flow to demonstrate FPS flexibility.

## Mainnet examples

Mainnet examples highlight how each of the FPS governance models can be easily implemented for existing real world projects for proposal simulation.

1. [Arbitrum Timelock](../mainnet-examples/ArbitrumTimelock.md)
2. [Compound Governor Bravo](../mainnet-examples/CompoundGovernorBravo.md)
3. [ENS OZ Governor](../mainnet-examples/ENSOzGovernor.md)
4. [Optimism Multisig](../mainnet-examples/OptimismMultisig.md)
