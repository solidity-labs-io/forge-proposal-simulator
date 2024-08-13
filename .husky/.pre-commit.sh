#!/bin/bash

# Temporary file to hold list of staged .sol files
STAGED_SOL_FILES=$(mktemp)
# Temporary file to hold list of all staged files for formatting
STAGED_FILES=$(mktemp)

# List staged .sol files ignoring deleted files

# List only renamed .sol files
git diff --cached --name-status -- '*.sol' | grep -v '^D' | grep -E '^R' | cut -f3 > "$STAGED_SOL_FILES"
# Append .sol files ignoring renamed and deleted files
git diff --cached --name-status -- '*.sol' | grep -v '^D' | grep -E '^[^R]' | cut -f2 >> "$STAGED_SOL_FILES"

# List all staged files ignoring deleted files

# List only renamed files
git diff --cached --name-status | grep -v '^D' | grep -E '^R' | cut -f3 > "$STAGED_FILES"
# Append all staged files ignoring renamed and deleted files
git diff --cached --name-status | grep -v '^D' | grep -E '^[^R]' | cut -f2 >> "$STAGED_FILES"

# Run Solhint on staged .sol files, if any
if [ -s "$STAGED_SOL_FILES" ]; then
    # If there are staged .sol files, run Solhint on them
    SOLHINT_OUTPUT=$(cat "$STAGED_SOL_FILES" | xargs npx solhint --config ./.solhintrc)
    SOLHINT_EXIT_CODE=$?

    if [ $SOLHINT_EXIT_CODE -ne 0 ]; then
        echo "Solhint errors detected:"
        echo "$SOLHINT_OUTPUT"
        rm "$STAGED_SOL_FILES" "$STAGED_FILES"
        exit $SOLHINT_EXIT_CODE
    else
        # Re-add the .sol files to include any automatic fixes by Solhint
        cat "$STAGED_SOL_FILES" | xargs git add
    fi
fi

# Run forge fmt and check for errors on staged files
if [ -s "$STAGED_FILES" ]; then
    # Note: Run forge fmt to automatically fix formatting
    FMT_OUTPUT=$(cat "$STAGED_FILES" | xargs forge fmt)
    FMT_EXIT_CODE=$?

    if [ $FMT_EXIT_CODE -ne 0 ]; then
        echo "Forge fmt formatting errors detected:"
        echo "$FMT_OUTPUT"
        rm "$STAGED_SOL_FILES" "$STAGED_FILES"
        exit $FMT_EXIT_CODE
    else
        # Re-add the files to include any formatting changes by forge fmt
        cat "$STAGED_FILES" | xargs git add
    fi
fi

# Clean up
rm "$STAGED_SOL_FILES" "$STAGED_FILES"

# If we reach this point, either there were no issues or only warnings.
# Warnings are allowed, so we exit successfully.
exit 0
