---
description: >-
    The Forge Proposal Simulator (FPS) offers a versatile solution for protocols with trusted actors to create and validate governance proposals.
---

# Architecture

<img src="../../assets/diagram.svg" alt="FPS design architecture" class="gitbook-drawing">

The diagram illustrates the architecture of the Forge Proposal Simulator. It is
composed of various components that interact with each other to simulate,
execute and test governance proposals.

## Proposal Generic Contract

At its core, the FPS features a **Proposal Contract**. This contract defines
[external](external-functions.md) and [internal](internal-functions.md)
functions, customizable by the protocol utilizing FPS. The `run` function serve as the entry point to execute a proposal.

## Governance Specific Contracts

FPS accommodates different Governance types (e.g., Timelock, Multisig) through specialized contracts. These Governance Specific Contracts inherit from the Proposal Contract, tailoring their functions to unique governance requirements.

## Proposal Specific Contract

Protocols using FPS must create their own Proposal Specific Contracts, conforming to FPS standards. These contracts override functions relevant to the particular proposal, such as `deploy()` and `afterDeployMock()` for proposals involving new contract deployments. For more details, refer to [internal functions](internal-functions.md).

## Post Proposal Check

Protocols should implement a [Post Proposal Check](https://github.com/solidity-labs-io/fps-example-repo/blob/feat/test-cleanup/test/bravo/BravoPostProposalCheck.sol) contract. This contract is tasked with deploying Proposal instances and invoking `proposal.run()` for simulation purposes. Integration tests should inherit from `Post Proposal Check`.

{% content-ref url="external-functions.md" %}
[external-functions.md](external-functions.md)
{% endcontent-ref %}

{% content-ref url="internal-functions.md" %}
[internal-functions.md](internal-functions.md)
{% endcontent-ref %}

{% content-ref url="addresses.md" %}
[addresses.md](addresses.md)
{% endcontent-ref %}
