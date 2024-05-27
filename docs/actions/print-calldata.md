# Print Calldata on Pull Requests

## Overview

The following guide explains how to create a GitHub Action that prints the proposal output on PRs. The output includes calldata, newly deployed addresses, changed addresses, and proposal actions. Once the action is executed, the output will be printed in a comment on the PR. It's worth noting that if a PR touches multiple proposals, the comment will only contain the output of the first proposal that the "Get Changed Files" step finds.

## Creating the Workflow

```yaml
name: "Run Latest Proposal"

env:
    FOUNDRY_PROFILE: "ci"

on: [pull_request]

jobs:
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
              run: echo "PROPOSALS_FOLDER=src/proposals" >> $GITHUB_ENV

            - name: List and Delete Previous Comments
              uses: actions/github-script@v6
              with:
                  github-token: ${{ secrets.GITHUB_TOKEN }}
                  script: |
                      const issue_number = context.payload.pull_request.number;
                      const comments = await github.rest.issues.listComments({
                        ...context.repo,
                        issue_number: issue_number
                      });

                      const actionComments = comments.data.filter(comment => comment.user.login === 'github-actions[bot]');

                      if (actionComments.length === 0) {
                        return;
                      }
                      for (const comment of actionComments) {
                        await github.rest.issues.deleteComment({
                          ...context.repo,
                          comment_id: comment.id,
                        });
                      }

            - name: Run Proposal
              run: ./run-proposal.sh

            - name: Comment PR with Proposal Output
              uses: actions/github-script@v6
              with:
                  github-token: ${{ secrets.GITHUB_TOKEN }}
                  script: |
                      const fs = require('fs');
                      if (fs.existsSync('output.json')) {
                          const output = JSON.parse(fs.readFileSync('output.json', 'utf8'));
                          const prNumber = context.payload.pull_request.number;
                          github.rest.issues.createComment({
                             ...context.repo,
                             issue_number: prNumber,
                             body: `### Proposal output for ${output.file}:\n\`\`\`\n${output.output}\n\`\`\``
                             });
                       }
```

To create the workflow, follow these steps:

1. Copy the code above and paste it into a new file named `run-proposal.yml` in the `.github/workflows` folder.
2. Change the `PROPOSALS_FOLDER` to the folder where the proposals are located.
3. Add the Forge Proposal Simulator path before the `run-proposal.sh` script: `lib/forge-proposal-simulator/run-proposal.sh`.
4. In case you have proposal names different from `*Proposal_1.sol`, copy the script into your repository and customize it as needed. Update the path in step 3 to `./run-proposal.sh`.
5. Check the repository settings and make sure Read and Write Permissions are enabled in the Workflow Permissions section.

Whenever a Pull Request that involves a proposal is created, the action will automatically execute and display the output of the proposal in a comment on the PR. This enables the developer to locally run the proposal and validate whether the output corresponds with the one shown on the PR.

## Example implementation

The above workflow has been implemented in [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/.github/workflows/run-latest-proposal.yml).
