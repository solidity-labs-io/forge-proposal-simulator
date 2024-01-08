# Forge Proposal Simulator

## Overview

The Forge Proposal Simulator (FPS) offers a framework for creating secure governance proposals and deployment scripts, enhancing safety, and ensuring protocol health throughout the proposal lifecycle. The major benefits of using this tool are standardization of proposals, safe calldata generation, and preventing deployment parameterization and governance action bugs.

1. **Standardized Governance**: FPS standardizes the creation of governance proposals. This standardization simplifies the review process and enables thorough testing of proposed changes against the current state of the protocol. It ensures the protocol's stability post-implementation. With FPS, every protocol modification experiences rigorous checks through an integrated test suite, confirming the protocol's integrity from proposal creation to execution.
2. **Safe Calldata Generation**: This framework enhances proposal security by generating and verifying calldata out of the box for both GnosisSafe Multisignature Wallets and Openzeppelin Timelocks. With this calldata and scaffolding, it allows for easy simulation within a forked environment to confirm the proposal is bug-free, ensuring they are ready for deployment. This introduces an extra layer of security for governance. Technical signers can quickly access proposal calldata through a standard method on the proposal contract. This allows for easy retrieval of calldata, which can then be checked against what is proposed in the governance contracts.
3. **Preventing Governance Bugs**: Mistakes happen often in governance. This tool offers testing of contracts in their post-deployment state, mitigating such risks.
4. **Preventing Deployment Script Bugs:** The framework allows developers to easily test their deployment scripts with integration tests, making it simple to leverage this tools capabilities to completely eliminate an entire category of bugs.

\


## Quick links

{% content-ref url="overview/use-cases.md" %}
[use-cases.md](overview/use-cases.md)
{% endcontent-ref %}

{% content-ref url="overview/architecture/" %}
[architecture](overview/architecture/)
{% endcontent-ref %}

## Get Started

{% content-ref url="fundamentals/getting-set-up.md" %}
[getting-set-up.md](fundamentals/getting-set-up.md)
{% endcontent-ref %}
