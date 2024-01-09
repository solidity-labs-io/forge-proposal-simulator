# Internal functions

The following functions are optional and executed in their listing order. Override them in your proposal contract as needed. You can control their execution using the run function with granular action control.

-   `function _deploy(Addresses, address) internal`: Defines new contract deployments. Newly deployed contracts must be added to the `Addresses` contract instance through the setters methods.
-   `function _afterDeploy(Addresses, address) internal`: Specifies post-deployment actions such as wiring contracts together, revoking ownership, or calling setter functions as the deployer.
-   `function _build(Addresses) internal`: Creates the proposal actions and saves them to storage in the proposal contract.
-   `function _run(Addresses, address) internal`: Executes the saved proposal actions from the \_build step.
-   `function _teardown(Addresses, address) internal`: Define actions to be taken after running the proposal. For example, suppose a protocol has many timelocks and multisigs. In that case, this framework only supports running one proposal at a time, so before running validate, you can prank as the other timelock in this step and perform a needed action.
-   `function _validate(Addresses) internal`: Validates the state post-execution, ensuring the correct setup of state variables and proposal targets.

Actions in the system are loosely coupled, with build and run being exceptions, requiring sequential execution.
