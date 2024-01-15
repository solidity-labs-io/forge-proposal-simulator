# External Functions

The `Proposal.sol` file contains a set of functions that all governance models inherit. To create a Proposal compatible with FPS, you must inherit one of the governance models, such as `MultisigProposal.sol,` and override the needed functions. We recommended that you override the `name()`, `description()` and `getCalldata()` functions.

-   `function name() external`: Override this function with a state variable to define the proposal name
-   `function description() external` Override this function to define the proposal description
-   `function getCalldata() external`: Retrieves any generated governance proposal calldata.

Both of these functions should not be overridden as they perform key actions.

-   `function run(Addresses, address) external`: Simulates proposal execution against a forked mainnet or locally and can be used in integration tests or scripts.
-   Same as above, but with more granular control over which actions to run

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

-   `function getProposalActionSteps() external`: Retrieves the sequence of actions for a proposal.
