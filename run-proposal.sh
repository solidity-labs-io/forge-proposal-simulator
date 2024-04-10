#!/bin/bash

# Assuming PR_CHANGED_FILES contains paths of files changed in the PR
CHANGED_FILES=$PR_CHANGED_FILES

# If there are changed files, loop through them and execute your command
if [[ ! -z "$CHANGED_FILES" ]]; then
    # Splitting the file paths into an array
    IFS=' ' read -r -a files_array <<< "$CHANGED_FILES"

    for file in "${files_array[@]}"; do
        # Execute only if the file is within the /examples directory
        if [[ $file == examples/* ]]; then
            echo "Executing 'forge script' for changed file: $file"
            forge script "$file" || echo "Failed to execute script on $file"
        fi
    done
else
    echo "No PR changes detected in /examples."
fi

