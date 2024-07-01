# Forge Proposal Simulator

## Overview

The Forge Proposal Simulator (FPS) offers a framework for creating secure governance proposals and deployment scripts, enhancing safety, and ensuring protocol health throughout the proposal lifecycle. The major benefits of using this tool are standardization of proposals, programmatic calldata generation, prevention of deployment parameterization and governance action bugs.

1. **Standardized Governance**: This standardization simplifies the review process and enables thorough testing of proposed changes against the current state of the protocol. It ensures the protocol's stability post-implementation. With FPS, every protocol modification undergoes rigorous checks through an integrated test suite, confirming the protocol's integrity from proposal creation to execution.

2. **Safe Calldata Generation**: Enhance proposal security by generating and verifying calldata programmatically out of the box. Using FPS, developers can easily test their proposals within a forked environment before posting them on-chain. This introduces an extra layer of security for governance. Technical signers can quickly access proposal calldata through a standard method in the proposal contract. This allows for easy retrieval of calldata, which can then be checked against the data proposed in the governance contracts.

3. **Preventing Governance Bugs**: Mistakes happen often in governance. This tool offers testing of contracts in their post governance proposal state, helping to mitigate risks.

4. **Preventing Deployment Script Bugs**: Developers can now easily test their deployment scripts with integration tests, making it simple to leverage this tool's capabilities to help eliminate an entire category of bugs.

## Quick links

{% content-ref url="./overview/use-cases.md" %}
[Use cases](./overview/use-cases.md)
{% endcontent-ref %}

{% content-ref url="./overview/architecture" %}
[Architecture](./overview/architecture)
{% endcontent-ref %}

## Get Started

{% content-ref url="./guides/introduction.md" %}
[Introduction](./guides/introduction.md)
{% endcontent-ref %}
