# Forge Proposal Simulator

Forge Proposal Simulator (FPS) converts privileged Solidity calls into
governance actions and runs those actions on a fork. Proposal contracts keep
deployment logic, calldata construction, simulation, and post-execution checks
in one reviewable program.

FPS includes proposal types for:

- Safe multisigs using MultiSend
- OpenZeppelin `TimelockController`
- Compound Governor Bravo
- OpenZeppelin Governor with timelock execution

The base lifecycle runs `deploy()`, `preBuildMock()`, `build()`, `simulate()`,
`validate()`, and `print()`. Address JSON persistence is an optional final
step. Each stage can be controlled with an environment flag.

## Start here

{% content-ref url="./guides/introduction.md" %}
[Install FPS and create a proposal](./guides/introduction.md)
{% endcontent-ref %}

{% content-ref url="./overview/use-cases.md" %}
[Choose a governance proposal type](./overview/use-cases.md)
{% endcontent-ref %}

{% content-ref url="./overview/architecture" %}
[Review the architecture and lifecycle](./overview/architecture)
{% endcontent-ref %}
