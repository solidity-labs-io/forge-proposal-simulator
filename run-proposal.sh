#!/bin/bash

CHANGED_FILES=$PR_CHANGED_FILES

# Check for changed files
if [[ ! -z "$CHANGED_FILES" ]]; then
    # Splitting the file paths into an array
    IFS=' ' read -r -a files_array <<< "$CHANGED_FILES"

    for file in "${files_array[@]}"; do
        # Execute only if the file is within the /examples directory
        if [[ $file == examples/* ]]; then
            echo "Executing 'forge script' for Proposal: $file"
            # Running forge script and capturing output
            output=$(forge script "$file" 2>&1)
            # Strip ANSI escape codes
            clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
            # Convert to JSON using jq, ensuring correct JSON output
            json_output=$(jq -n --arg file "$file" --arg output "$clean_output" '{file: $file, output: $output}')
            # Encode the JSON output in base64 to safely pass to GitHub Actions
            echo $(echo "$json_output" | base64)
            break  # Exit the loop after processing the first file
        fi
    done
else
    echo "No PR changes detected in /examples."
fi
