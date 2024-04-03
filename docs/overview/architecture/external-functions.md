# External Functions

The `Proposal.sol` file contains a set of functions that all governance models inherit. To create a Proposal compatible with FPS, you must inherit one of the governance models, such as `MultisigProposal.sol,` and override the needed functions. We recommended that you override the `name()`, `description()` and `getCalldata()` functions.

-   `function description() external` Override this function to define the proposal description
-   `function getCalldata() external`: Retrieves any generated governance proposal calldata.

Both of these functions should not be overridden as they perform key actions.

-   `function run() external`: Simulates proposal execution against a forked mainnet or locally and can be used in integration tests or scripts.
-   `function getProposalActions() external`: Retrieves the sequence of actions for a proposal.
