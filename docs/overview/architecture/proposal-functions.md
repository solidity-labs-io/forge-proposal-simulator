The `Proposal.sol` file contains a set of functions that all governance models inherit. There are three governance models bravo, multisig, timelock already implemented in the repo. To create a Proposal compatible with FPS, you can inherit one of the governance models, such as `MultisigProposal.sol,` and override the needed functions, or you can create a new governance model in your repository that inherits the `Proposal` contract and then a proposal can be created using this new governance model. Following is the list of functions:

-   `function description() public` Override this function to define the proposal description. This function should be overriden at the final proposal level.

-   `function getCalldata() public`: Retrieves any generated governance proposal calldata. This function should be overriden at the final proposal level.

-   `function checkOnChainCalldata() public`: Check if there are any on-chain proposal that matches the proposal calldata. This function should be overriden at the governance contract level.

-   `function run() public`: Simulates proposal execution against a forked mainnet or locally and can be used in integration tests or scripts. This function can be overridden at the final proposal level where it can be used to set the environment, for eg: addresses object, primary fork id. Make sure to call the `run()` from the Proposal contract as it performs key actions.

-   `function getProposalActions() public`: Retrieves the sequence of actions for a proposal. This function should not be overridden in most of the cases.


The following functions allow for a significant level of customization and can be overridden in your proposal contract as needed.

-   `function deploy() public`: Defines new contract deployments. Newly deployed contracts must be added to the `Addresses` contract instance through the setters methods. This function should be overridden only when there are deployments to be made in the proposal.

-   `function afterDeployMock() public`: Specifies post-deployment actions. Such actions can include wiring contracts together, transferring ownership rights, or invoking setter functions as the deployer.

-   `function build() public`: Creates the proposal actions and saves them to storage in the proposal contract.

-   `function simulate() public`: Executes the actions that were previously saved during the `build` step. It's dependent on the successful execution of the `build` function. Without calling `build` first, the `_run` function becomes ineffectual as there would be no predefined actions to execute.

-   `function validate() public`: Validates the state post-execution. It ensures that the contracts variables and proposal targets are set up correctly.

-   `function print() public`: Print proposal description, actions and calldata


The actions in FPS are designed to be loosely coupled for flexible
implementation, with the exception of the build and run functions, which require
sequential execution. This design choice offers developers significant
flexibility and power in tailoring the system to their specific needs. For
example, a developer may choose to only execute the deploy and validate
functions, bypassing the others. This could be suitable in situations where only
initial deployment and final validation are necessary, without the need for
intermediate steps. Alternatively, a developer might opt to simulate a proposal
by executing only the build and run functions, omitting the deploy step if there
is no need to deploy new contracts. FPS empowers developers
with the ability to selectively execute functions based on their unique
requirements.
