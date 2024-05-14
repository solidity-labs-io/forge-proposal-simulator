# Internal functions

This section details optional internal functions offered by FPS. These functions
allow for a significant level of customization and can be overridden in your
proposal contract as needed.

-   `function deploy() public`: Defines new contract deployments. Newly deployed contracts must be added to the `Addresses` contract instance through the setters methods.
-   `function afterDeployMock() public`: Specifies post-deployment actions. Such actions can include wiring contracts together, transferring ownership rights, or invoking setter functions as the deployer.
-   `function build() public`: Creates the proposal actions and saves them to storage in the proposal contract.
-   `function simulate() public`: Executes the actions that were previously saved during the `_build` step. It's dependent on the successful execution of the `_build` function. Without calling `_build` first, the `_run` function becomes ineffectual as there would be no predefined actions to execute.
-   `function validate() public`: Validates the state post-execution. It ensures that the contracts variables and proposal targets are set up correctly.

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
