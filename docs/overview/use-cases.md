# Use cases

The framework is compatible with OpenZeppelin Timelock, Compound Governor Bravo, OZ Governor, and GnosisSafe Multisig wallet contracts. We encourage the submission of pull requests to accommodate different governance models.

### OpenZeppelin Timelock Controller

The [Timelock Proposal](../guides/timelock-proposal.md) facilitates the creation of the scheduling and execution of calldata. It also allows developers to test the calldata by simulating the entire proposal lifecycle, from submission to execution, using foundry cheat codes to bypass the delay period.

### Gnosis Safe Multisig

The [Multisig Proposal](../guides/multisig-proposal.md) generates and simulates the Multicall calldata. This allows developers to check protocol health after calldata execution by using Foundry cheat codes to simulate actions from the actual Multisig address. Calldata generated from this module can be used directly in Gnosis Safe's UI.

### Compound Governor Bravo

The [Governor Bravo Proposal](../guides/governor-bravo-proposal.md) facilitates the creation of the governor `propose` calldata. It also allows developers to test the calldata by simulating the entire proposal lifecycle, from proposing, voting, queuing, and finally executing.

### OZ Governor

Similar to Compound Governor Bravo, [OZ Governor Proposal](../guides/oz-governor-proposal.md) simulates the entire proposal lifecycle for the governor with a timelock controller extension.
