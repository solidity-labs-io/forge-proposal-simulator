# External Functions

The `Proposal.sol` file contains a set of functions that all governance models inherit. To create a Proposal compatible with FPS, you must inherit one of the governance models, such as `MultisigProposal.sol,` and override the needed functions. We recommended that you override the `name()`, `description()`, `getCalldata()` and `checkOnChainCalldata()` functions.

-   `function description() public` Override this function to define the proposal description
-   `function getCalldata() public`: Retrieves any generated governance proposal calldata.
-   `function checkOnChainCalldata() public`: Check if there are any on-chain proposal that matches the proposal calldata

Both of these functions should not be overridden as they perform key actions.

-   `function run() public`: Simulates proposal execution against a forked mainnet or locally and can be used in integration tests or scripts.
-   `function getProposalActions() public`: Retrieves the sequence of actions for a proposal.
