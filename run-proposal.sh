#!/bin/bash

# Navigate to the /examples directory
cd ./examples

# Check for staged files
STAGED_FILES=$(git diff --cached --name-only)

cd ..

# If there are staged files, loop through them and execute your command
if [[ ! -z "$STAGED_FILES" ]]; then
    for file in $STAGED_FILES; do
        echo "Executing 'forge script' for staged file: $file"
        forge script "$file"
    done
else
    echo "No staged changes detected in /examples."
fi
