#!/bin/bash

# Add selected files to PepBox Shelf via URL scheme
# This script is called by Alfred with file paths as arguments

# Build the URL with all file paths
url="pepbox://add?target=shelf"

for file in "$@"; do
    # URL-encode the path safely using stdin (handles quotes and special chars)
    encoded_path=$(echo -n "$file" | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=''))")
    url="${url}&path=${encoded_path}"
done

# Open the URL to trigger PepBox
open "$url"
