# Overview

The Forge Proposal Simulator is a tool for developers working on smart contract governance. Its main goal is to offer a simulated environment for testing and validating governance proposals before deployment on the mainnet. This library is compatible with Timelock Governance and Multisig Governance contracts (so far), making it a versatile tool. One of the key features that sets the Forge Proposal Simulator apart from others is its ability to generate proposal call data and check the protocol's state before and after executing the call data. By simulating the execution in a forked environment, developers can ensure that the proposal is free of bugs and ready for deployment.

## Use cases

### Timelock Governance 
The simulator allows developers to test the time-delayed execution of governance proposals. It creates both the schedule and the execution calldata required for Timelock proposals. The library can also simulate the proposal schedule, proposal delay, and the execution function call. Developers can perform checks before, during, and after each step to ensure that the protocol behaves as intended at every step.

### Multisig Governance

In the case of Multisig Governance, the library generates the necessary Multicall calldata and executes it against a simulated environment, such as a fork of the mainnet. Developers can perform checks before and after the calldata execution. A significant feature is the use of Foundry cheat codes to perform a prank on the actual Multisig Governance address. This allows developers to mimic the real-world execution environment of the proposal within the governance structure.

## Design Philosophy

Forge Proposal Simulator helps protocols with trusted actors create and validate governance proposals. Its main focus is on structuring and standardizing state changes to ensure they work as intended. Its versatility makes it easily adaptable to any governance model. Using this tool, developers can identify and eliminate entire categories of bugs that may arise in governance proposals, enhancing the reliability and security of their upgrades.

### A proposal has the following external functions

-   `function name() external`: Override this function to define the proposal name

-   `function description() external`: Override this function to define the proposal description

-   `function run(Address, address) external`: Simulates proposal execution against a forked mainnet or locally and can be used in integration tests or scripts. Do not override.

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

Contracts with identical names are acceptable if deployed on different networks. Duplicates on the same network are not allowed and Addresses.sol prevents by reverting during construction.

## Usage

1. Integrate this library into your protocol repository as a submodule:

    ```bash
    forge install https://github.com/solidity-labs-io/forge-proposal-simulator.git
    ```

2. For testing a governance proposal, create a contract inheriting one of the proposal types from our [proposalTypes](./proposals/proposalTypes) directory. Omit any actions that are not relevant to your proposal. Explore our [mocks](./mocks) for practical examples.

3. Generate a JSON file listing the addresses and names of your deployed contracts. Refer to [Addresses.sol](./addresses/Address.sol) for details.

4. Develop a test to execute your proposal that invokes `testProposals()`on [TestProposals](./proposals/TestProposals.sol).
   For guidance, check out the sample tests in our [test/integration](./test/integration) directory.
