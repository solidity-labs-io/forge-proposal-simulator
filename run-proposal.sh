#!/bin/bash

CHANGED_FILES=$PR_CHANGED_FILES

if [[ ! -z "$CHANGED_FILES" ]]; then
    IFS=' ' read -r -a files_array <<< "$CHANGED_FILES"

    for file in "${files_array[@]}"; do
        if [[ $file == examples/* ]]; then
            output=$(forge script "$file" 2>&1)
            clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
            json_output=$(jq -n --arg file "$file" --arg output "$clean_output" '{file: $file, output: $output}')
            # Encode to base64
            base64_output=$(echo "$json_output" | base64 | tr -d '\n')
            echo "$base64_output"
            break
        fi
    done
else
    echo "No PR changes detected in /examples."
fi
