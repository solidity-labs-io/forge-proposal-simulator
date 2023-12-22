# Overview

This library is a powerful tool for developers aiming to test governance proposals in a simulated environment before deploying them to the mainnet.

## Design Philosophy

This library is primarily intended to help protocols in creating and validating governance proposals. Its main focus is on ensuring that any changes in the state are compatible and work seamlessly with the existing code and storage structures on the mainnet. Its versatility makes it easily adaptable to various governance models. Using this tool, developers can identify and eliminate potential issues that may arise in governance proposals, thereby enhancing the reliability and effectiveness of their governance processes.

### A proposal has the following external functions

-   `function name() external`: Override this function to define the name of the proposal

-   `function description() external`: Override this function to define the description of the proposal

-   `function run(Address, address) external`: This function simulates proposal execution against a forked mainnet or locally and should be used in integration tests or scripts. It is not meant to be overridden.

-   Same as above, but with more granular control over which actions to run.

```solidity
function run(
    Addresses addresses,
    address deployer,
    bool deploy,
    bool afterDeploy,
    bool build,
    bool run,
    bool teardown,
    bool validate
) external;
```

-   `function getProposalActionSteps() external`: Retrieves the sequence of actions for a proposal. Do not override.

-   `function getCalldata() external`: Retrieves any generated governance proposal calldata.

### A proposal has the following internal functions

The following functions are optional and executed in their listing order. Override them in your proposal contract as needed. You can control their execution when using the run function with granular action control.

-   `function _deploy(Addresses, address) internal`: Defines new contract deployments.

-   `function _afterDeploy(Addresses, address) internal`: Specifies post-deployment actions.

-   `function _build(Addresses) internal`: Creates the proposal actions.

-   `function _run(Addresses, address) internal`: Executes the proposal actions.

-   `function _teardown(Addresses, address) internal`: Define actions to be taken after running the proposal.

-   `function _validate(Addresses) internal`: Validates the state post-execution, ensuring correct setup of state variables and proposal targets.

Actions in the system are either loosely or decoupled, with build and run being exceptions, requiring sequential execution.

## Addresses Contract

The Addresses contract stores the addresses of deployed contracts, facilitating their access in proposal contracts and recording them post-execution.
Deployed contract addresses, along with their names and networks, should be listed in a json file in the following format:

```json
{
    "addr": "0x1234567890123456789012345678901234567890",
    "name": "ADDRESS_NAME",
    "chainId": 1234
}
```

Contracts with identical names are acceptable provided they are deployed on different networks. Duplicates on the same network are not allowed and `Addresses.sol` prevents by reverting during construction.

## Usage

1. Integrate this library into your protocol repository as a submodule:

    ```bash
    forge install https://github.com/solidity-labs-io/forge-proposal-simulator.git
    ```

2. For testing a governance proposal, create a contract inheriting one of the proposal types from our [proposalTypes](./proposals/proposalTypes) directory. Omit any actions that are not relevant to your proposal. Explore our [mocks](./mocks) for practical examples.

3. Generate a JSON file listing the addresses and names of your deployed contracts. Refer to [Addresses.sol](./addresses/Address.sol) for details.

4. Develop a test to execute your proposal that invokes `testProposals()`on [TestProposals](./proposals/TestProposals.sol).
   For guidance, check out the sample tests in our [test/integration](./test/integration) directory.
