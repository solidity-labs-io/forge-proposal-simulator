# Print Proposal Output on Pull Requests

The [`fps-example-repo` workflow](https://github.com/solidity-labs-io/fps-example-repo/blob/main/.github/workflows/run-latest-proposal.yml) runs the latest changed proposal and posts its output on the pull request. The comment contains the proposal actions, recorded state and transfer changes, calldata or Safe transaction fields, and any following Forge output.

## Add the Workflow

1. Copy [`run-latest-proposal.yml`](https://github.com/solidity-labs-io/fps-example-repo/blob/main/.github/workflows/run-latest-proposal.yml) to `.github/workflows/run-latest-proposal.yml` in the consuming repository.
2. Set `PROPOSALS_FOLDER` to the repository-relative directory containing proposal source files.
3. Set the `Run Proposal` command to `lib/forge-proposal-simulator/run-proposal.sh` when FPS is installed at the standard Foundry path.
4. Keep the job-level `pull-requests: write` permission. The repository or organization must allow GitHub Actions to write pull-request comments.

The relevant workflow settings are:

```yaml
on: [pull_request]

jobs:
  run-proposal:
    permissions:
      pull-requests: write
    runs-on: ubuntu-latest
    steps:
      # Checkout, Foundry installation, and changed-file collection run first.

      - name: Set PR_CHANGED_FILES
        run: echo "PR_CHANGED_FILES=${{ steps.files.outputs.all }}" >> "$GITHUB_ENV"

      - name: Set DEBUG flag
        run: echo "DEBUG=true" >> "$GITHUB_ENV"

      - name: Set PROPOSALS_FOLDER
        run: echo "PROPOSALS_FOLDER=src/proposals" >> "$GITHUB_ENV"

      - name: Run Proposal
        run: lib/forge-proposal-simulator/run-proposal.sh
```

Use the complete example workflow for its checkout, Foundry installation, changed-file collection, previous-comment cleanup, and comment-posting steps.

The linked workflow currently pins `actions/checkout@v3`,
`jitterbit/get-changed-files@v1`, and `actions/github-script@v6`. Review those
action versions against the consuming repository's dependency policy before
copying the file.

The example cleanup step deletes every pull-request comment authored by `github-actions[bot]`. Restrict its filter if other workflows post comments under that account.

The `pull_request` event gives workflows from forked pull requests a read-only `GITHUB_TOKEN`. Those runs cannot post or delete comments. Keep this workflow on `pull_request`. A `pull_request_target` workflow would execute untrusted proposal code with the base repository's token.

## Proposal Filename Contract

`run-proposal.sh` reads two environment variables:

- `PR_CHANGED_FILES`: a space-delimited list of files changed by the pull request.
- `PROPOSALS_FOLDER`: the repository-relative proposal directory.

Changed proposals must end with `Proposal_<number>.sol`, for example `MultisigProposal_07.sol`. When a pull request changes several matching files, the script runs the file with the greatest numeric suffix:

```bash
forge script "$selected_file"
```

The shipped selector compares suffixes with Bash arithmetic. Zero-padded
suffixes containing `8` or `9`, such as `_08` and `_09`, are parsed as invalid
octal numbers. Use unpadded suffixes or update the copied script to force
base-10 parsing before the sequence reaches those values. The current `_01`
and `_02` examples are accepted. The script also assumes every changed
Solidity file under `PROPOSALS_FOLDER` follows the numeric proposal convention.
Repositories that keep helper contracts in that folder should harden the
selector before adopting the workflow.

The script removes ANSI color codes, extracts output beginning at the `Proposal Actions` heading, and writes the selected filename and output to `output.json`. The workflow reads that file and creates the pull-request comment. If the proposal does not reach the expected output heading, the generated comment directs the reviewer to the CI logs.

Proposal names that do not follow the numeric suffix convention require a repository-specific selector. Copy [`run-proposal.sh`](https://github.com/solidity-labs-io/fps-example-repo/blob/main/run-proposal.sh) to the consuming repository, update its matching and ordering logic, and change the workflow command to:

```yaml
- name: Run Proposal
  run: ./run-proposal.sh
```

Keep the copied script executable and commit its file mode:

```bash
chmod +x run-proposal.sh
git add run-proposal.sh
```

`DEBUG=true` enables proposal-type diagnostics during simulation. The base `print()` stage remains enabled by default and produces the sections consumed by the script. If a repository overrides `DO_PRINT`, keep it enabled in this workflow.
