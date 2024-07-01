# Print Calldata on Pull Requests

## Overview

The following guide explains how to create a GitHub Action that prints the proposal output on PRs. The output includes calldata, newly deployed addresses, changed addresses, and proposal actions. Once the action is executed, the output will be printed in a comment on the PR. It's worth noting that if a PR touches multiple proposals, the comment will only contain the output of the proposal with the greatest number.

## Creating the Workflow

To create the workflow, follow these steps:

1. Copy the code from [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/blob/main/.github/workflows/run-latest-proposal.yml) and paste it into a new file named `run-proposal.yml` in the `.github/workflows` folder.
2. Change the `PROPOSALS_FOLDER` to the folder where the proposals are located.
3. Add the Forge Proposal Simulator path before the `run-proposal.sh` script: `lib/forge-proposal-simulator/run-proposal.sh`.
4. In case the proposal names are different from `*Proposal_1.sol`, copy the [script](https://github.com/solidity-labs-io/fps-example-repo/blob/main/run-proposal.sh) into your repository and customize it as needed. Update the path in step 3 to `./run-proposal.sh`.
5. Check the Github repository settings and make sure Read and Write Permissions are enabled in the Workflow Permissions section.

Whenever a Pull Request that involves a proposal is created, the action will automatically execute and display the output of the proposal in a comment on the PR. This enables the developer to locally run the proposal and validate whether the output corresponds with the one shown on the PR.

## Example implementation

The above workflow has been implemented in [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/.github/workflows/run-latest-proposal.yml).
