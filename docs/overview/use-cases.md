# Use cases

Select the proposal type that matches the contract which receives the final
governance transaction.

## Safe multisig

[Multisig proposals](../guides/multisig-proposal.md) encode recorded actions in
Safe MultiSend format. The output contains the `to`, `value`, `data`, and
`operation` fields required by a Safe transaction. Simulation temporarily
installs a compatible Safe runtime at the configured Safe address and executes
the same MultiSend payload.

## OpenZeppelin TimelockController

[Timelock proposals](../guides/timelock-proposal.md) generate
`scheduleBatch(...)` and `executeBatch(...)` calldata. Simulation schedules the
operation as the configured proposer, advances time by `getMinDelay()`, and
executes it as the configured executor.

## Compound Governor Bravo

[Governor Bravo proposals](../guides/governor-bravo-proposal.md) generate
`propose(...)` calldata with empty signature strings and full action calldata.
Simulation creates voting power on the fork, then runs the proposal through
Pending, Active, Succeeded, Queued, and Executed states.

## OpenZeppelin Governor

[OpenZeppelin Governor proposals](../guides/oz-governor-proposal.md) generate
`propose(...)` calldata and derive the proposal ID with `hashProposal(...)`.
Simulation delegates voting power, votes, queues the successful proposal, waits
for the attached timelock, and executes the action batch.

Create a custom proposal type when the target governance system requires a
different payload or lifecycle. The [customization guide](../guides/customizing-proposal.md)
uses Arbitrum governance as an example.
