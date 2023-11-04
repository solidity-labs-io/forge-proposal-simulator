# Overview

This is a standard template for creating and managing a smart contract system with foundry. It provides scaffolding for both managing and creating system deployments and governance proposals.

## Design Philosophy

This template aims to create a system to generate governance proposals and deployments in a unified framework so that integration and unit tests can leverage the system exactly as it will exist once deployed on mainnet. This way, entire categories of bugs can be eliminated such as deploy script errors and governance proposal errors.

A proposal type has multiple actions.

```
    function deploy(Addresses, address) external;

    function afterDeploy(Addresses, address) external;

    function afterDeploySetup(Addresses) external;

    function build(Addresses) external;

    function run(Addresses, address) external;

    function teardown(Addresses, address) external;

    function validate(Addresses, address) external;

    function printProposalActionSteps() external;
```

`Deploy`, creates a new smart contract on whichever network the script is pointed at.

`After deploy` actions such as wiring deployed contracts together, calling initialize, etc.

`After deploy setup` is any setup that needs to be done after all contracts have been deployed and wired together, such as sending funds to a contract using forge's `deal` function. This step is usually only done for simulations and not run when a proposal is broadcast to a network.

`Build` the proposal. This is where the proposal calldata is built.

`Run` the proposal. This is where the proposal execution is simulated against a chainforked mainnet.

`Teardown` the proposal. This is where any post proposal state changes are made if needed. This is a step that should only run when simulating a proposal, it should never be run during a script broadcast.

`Validation` of the state after the proposal is run. This is where all deployed or modified contracts are checked to ensure they are in the correct state. For a deployment, this is where the deployed contract is checked to ensure all state variables were properly set. For a proposal, this is where the proposal targets are checked to ensure they are in the correct state. For a proposal that does a deployment and governance proposal/action, both the deployed contract(s) and the proposal target(s) are checked.

`Print proposal action steps` This is a helper function to print out the steps that will be taken when a proposal is run. This step also logs any governance proposal calldata that is generated.

Each action type in the system is loosely coupled or decoupled. Actions build and run are tightly coupled. If run is called, build must be called first. If build is called, run should be called after. All other actions are decoupled, but run sequentially in their declaration order.

## Usage

To deploy a new system, create a new contract that inherits the [Proposal](./proposals/proposalTypes/Proposal.sol) contract and implements the [IProposal](./proposals/proposalTypes/IProposal.sol) interface. Any actions that are unneeded should be left blank. 


Before running the script, environment variables should be set. The following environment variables are used in the system, all of them set to true by default:

```
DEBUG
DO_DEPLOY
DO_AFTER_DEPLOY
DO_AFTER_DEPLOY_SETUP
DO_BUILD
DO_RUN
DO_TEARDOWN
DO_VALIDATE
DO_PRINT
```

to change them, set only the unneeded actions to false in the shell before running the script:
```
export DEBUG=false
export DO_DEPLOY=false
export DO_AFTER_DEPLOY=false
export DO_AFTER_DEPLOY_SETUP=false
export DO_BUILD=false
export DO_RUN=false
export DO_TEARDOWN=false
export DO_VALIDATE=false
export DO_PRINT=false
```

Actions build, run, teardown, validate and print will never be run when a proposal is broadcast to a network. They are only run when simulating a proposal or after the braodcast has been run.

If deploying a new system, the following environment variables must be set. 

- `ETH_RPC_URL` rpc provider endpoint.
- `DEPLOYER_KEY` is the private key encoded in hex and should be 64 characters. 
- `ETHERSCAN_API_KEY` is the etherscan api key used to verify the deployed contracts on etherscan after it is deployed.

Then, once the proposal has been created, run the following command to deploy the system/generate the calldata for the proposal and validate if the flag is set to true:

```
forge script PathToProposal.sol:ProposalContractName \
    -vvvv \
    --rpc-url $ETH_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify
```

## Addresses Contract

The addresses contract is a contract that stores all the addresses of the deployed contracts. It is used to pass the addresses of the deployed contracts to the proposal contract. It is also used to store the addresses of the deployed contracts after the proposal has been run.

Deployed contract addresses, as well as their name and respective networks are stored in the [Addresses.json](./addresses/Addresses.json) file.

Contracts with the same name can be stored in the Addresses.json as long as there is no overlap in the networks they are deployed on. For example, if there is a contract named `Foo` that is deployed on mainnet and a contract named `Foo` that is deployed on rinkeby, both can be stored in the Addresses.json file. However, if there is a contract named `Foo` that is deployed on mainnet twice, only one of them can be stored in the `Addresses.json` file, otherwise there will be a revert during construction.
