#!/bin/bash

# Assuming PR_CHANGED_FILES contains paths of files changed in the PR
CHANGED_FILES=$PR_CHANGED_FILES

# If there are changed files, loop through them and execute your command
if [[ ! -z "$CHANGED_FILES" ]]; then
    # Splitting the file paths into an array
    IFS=' ' read -r -a files_array <<< "$CHANGED_FILES"

    echo "[" > output.json
    for file in "${files_array[@]}"; do
        # Execute only if the file is within the /examples directory
        if [[ $file == examples/* ]]; then
            echo "Executing 'forge script' for Proposal: $file"
            # Running forge script and capturing output
            output=$(forge script "$file" 2>&1)
            jq -R -s '{file: "'$file'", output: .}' <<< "$output" >> output.json
            if [[ $? -ne 0 ]]; then
                echo '{"file":"'$file'", "error":"Failed to execute script"}' >> output.json
            fi
            echo "," >> output.json
        fi
    done
    echo "{}]" >> output.json # Close JSON array with an empty object to handle trailing commas
else
    echo "No PR changes detected in /examples."
fi
