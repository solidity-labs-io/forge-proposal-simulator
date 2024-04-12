#!/bin/bash

CHANGED_FILES=$PR_CHANGED_FILES

if [[ ! -z "$CHANGED_FILES" ]]; then
    IFS=' ' read -r -a files_array <<< "$CHANGED_FILES"

    for file in "${files_array[@]}"; do
        if [[ $file == examples/* ]]; then
            output=$(forge script "$file" 2>&1)
            # Removal of ANSI Escape Codes
            clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
            
            # Extracting the relevant part of the output
            selected_output=$(echo "$clean_output" | awk '
            /--------- Addresses added after running proposal ---------/,/---------------- Proposal Description ----------------/ {
                print
                next
            }
            /---------------- Proposal Description ----------------/,/------------------ Proposal Actions ------------------/ {
                print
                next
            }
            /------------------ Proposal Actions ------------------/,/------------------ Proposal Calldata ------------------/ {
                print
                next
            }
            /------------------ Proposal Calldata ------------------/ {
                print
                next
            }
            ')

            json_output=$(jq -n --arg file "$file" --arg output "$selected_output" '{file: $file, output: $output}')

            # Encode to base64 to ensure safe passage through environment variables
            base64_output=$(echo "$json_output" | base64 | tr -d '\n')
            echo "$base64_output"
            break
        fi
    done
else
    echo "No PR changes detected in /examples."
fi
