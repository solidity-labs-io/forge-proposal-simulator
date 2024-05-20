# Print Calldata on Pull Requests

## Overview

The following guide explains how to create a Github Action that prints the
proposal output on PRs. The output includes calldata, newly deployed addresses,
changed addresses, and proposal actions. Once the action is executed, the output
will be printed in a comment on the PR. It's worth noting that if a PR touches
multiple proposals, the comment will only contain the output of the first
proposal that the "Get Changed Files" step finds.

## Creating the Workflow

```yaml
name: "CI"

env:
    FOUNDRY_PROFILE: "ci"

on:
    workflow_dispatch:
    pull_request:
    push:
        branches:
            - "main"

    run-proposal:
        permissions:
            pull-requests: write
        runs-on: ubuntu-latest
        steps:
            - name: Checkout code
              uses: actions/checkout@v3
              with:
                  submodules: "recursive"

            - name: "Install Foundry"
              uses: "foundry-rs/foundry-toolchain@v1"

            - name: Get Changed Files
              id: files
              uses: jitterbit/get-changed-files@v1
              with:
                  format: "space-delimited"

            - name: Set PR_CHANGED_FILES
              run: echo "PR_CHANGED_FILES=${{ steps.files.outputs.all }}" >> $GITHUB_ENV

            - name: Set DEBUG flag
              run: echo "DEBUG=true" >> $GITHUB_ENV

            - name: Set PROPOSALS_FOLDER
              run: echo "PROPOSALS_FOLDER=examples" >> $GITHUB_ENV

            - name: Run Proposals
              id: run_proposals
              run: |
                  output=$(./run-proposal.sh)
                  echo "result=${output}" >> $GITHUB_ENV

            - name: Decode and Comment PR with Proposal Output
              if: env.result
              run: |
                  echo "${{ env.result }}" | base64 -d > decoded_output.json
              shell: bash

            - name: Use Decoded Output
              uses: actions/github-script@v6
              with:
                  github-token: ${{ secrets.GITHUB_TOKEN }}
                  script: |
                      const fs = require('fs');
                      const output = JSON.parse(fs.readFileSync('decoded_output.json', 'utf8'));
                      const prNumber = context.payload.pull_request.number;
                      github.rest.issues.createComment({
                        ...context.repo,
                        issue_number: prNumber,
                        body: `### Proposal output for ${output.file}:\n\`\`\`\n${output.output}\n\`\`\``
                      });
```

To create the workflow, follow these steps:

1. Copy the code above and paste it into a new file named `run-proposal.yml` in the `.github/workflows` folder.
2. Change the `PROPOSALS_FOLDER` to the folder where the proposals are located.
3. Add Forge Proposal Simulator path before the `run-proposal.sh` script: `lib/forge-proposal-simulator/run-proposal.sh`.
4. In case you have proposal names different then `*Proposal_1.sol` copy the script in your repository and customise it as needed. Update the path in step 3 to `./run-proposal.sh`
5. Check the repository settings and make sure Read and Write Permissions
   are enabled on the Worflow Permissions section.

Whenever a Pull Request that involves a Proposal is created, the action will automatically execute and display the output of the proposal in a comment on the PR. This enables the developer to locally run the proposal and validate whether the output corresponds with the one shown on the PR.

## Example implementation

The above workflow has been implemented in [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/.github/workflows/run-latest-proposal.yml).