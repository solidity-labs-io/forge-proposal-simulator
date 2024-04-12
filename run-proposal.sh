#!/bin/bash

# PR_CHANGED_FILES contains paths of files changed in the PR
CHANGED_FILES=$PR_CHANGED_FILES

if [[ ! -z "$CHANGED_FILES" ]]; then
    # Splitting the file paths into an array
    IFS=' ' read -r -a files_array <<< "$CHANGED_FILES"

    echo "[" > output.json
    first=true
    for file in "${files_array[@]}"; do
        # Execute only if the file is within the /examples directory
        if [[ $file == examples/* ]]; then
            echo "Executing 'forge script' for Proposal: $file"
            # Running forge script and capturing output
            output=$(forge script "$file" 2>&1)
            # Strip ANSI escape codes
            clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
            # Convert to JSON using jq
            if [[ $first == true ]]; then
                first=false
            else
                echo "," >> output.json
            fi
            echo -n '{"file":"'${file}'", "output":' >> output.json
            echo -n "$(jq -aRs . <<< "$clean_output")" >> output.json
            echo -n '}' >> output.json
        fi
    done
    echo "]" >> output.json # Close JSON array properly
else
    echo "No PR changes detected in /examples."
fi
