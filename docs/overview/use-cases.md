---
description: >-
    FPS is compatible with the Openzeppelin Timelock, Compound Governor Bravo,
     and GnosisSafe Multisig wallet contracts. The project is open source and
     we encourage submissions of different types of actions.
---

# Use cases

### Openzeppelin Timelock Controller

FPS facilitates testing Timelock governance proposals, it supports creation
of both scheduling and execution calldata. Developers can simulate the
entire proposal, including scheduling, delays and execution. Read
the [Timelock Proposal](../guides/timelock-proposal.md) documentation to
learn how to integrate with the Openzeppelin Timelock Controller.

### Gnosis Safe Multisig

For Gnosis Safe Multisig support, FPS generates and simulates the Multicall
calldata. This allows developers to check protocol health after proposal
execution. FPS uses Foundry cheat codes to simulate actions from the actual
Multisig address, mirroring real-world proposal execution as much as possible. Calldata
generated from this module can be used directly in Gnosis Safe's UI. Check the
[Multisig Proposal](../guides/multisig-proposal.md) documentation to learn how to integrate FPS with a Gnosis Safe Multisig.

### Compound Governor Bravo

For Compound Governor Bravo, FPS generates and simulates the
proposal creation, voting, queuing and execution.
This enables simulation throughout the entire proposal lifecycle for governor and timelock systems.
View the [Governor Bravo Proposal](../guides/governor-bravo-proposal.md) documentation to learn
how to integrate with Compound Governor Bravo contracts.
