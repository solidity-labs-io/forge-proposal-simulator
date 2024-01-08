---
description: >-
  FPS is compatible with the Openzeppelin Timelock and GnosisSafe Multisig
  wallet contracts. The project is open source and we encourage submissions of
  different types of actions.
---

# Use cases

### Timelock Governance

FPS facilitates testing Timelock governance proposals, it supports both scheduling and execution calldatas. Developers can simulate the proposal timeline, including scheduling, delays, and execution calls. This feature allows for checks at each stage—before, during, and after the execution of each transaction —ensuring the protocol behaves as intended at every step. Check [Broken link](broken-reference "mention")to learn how to integrate with an Openzeppelin Timelock.

### Multisig Governance

For Gnosis Safe Multisig Governance, FPS generates and simulates the Multicall calldata. This allows developers to check protocol health after proposal execution. FPS uses Foundry cheat codes to simulate actions from the actual Multisig Governance address, mirroring real-world proposal execution. Calldata generated from this module can be used directly in Gnosis Safe's UI. Check [multisig-proposal.md](../guides/multisig-proposal.md "mention") to learn how to integrate with FPS within a Multisig Governance.

### Governor Bravo

TBD

### Governor Charlie

TBD
