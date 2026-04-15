#!/bin/bash

# Simple Markdown to Asciidoc Converter
# Handles basic markdown elements for README conversion

convert_markdown_to_adoc() {
    local md_file="$1"
    local adoc_file="$2"
    
    # Read the markdown file
    local content=$(cat "$md_file")
    
    # Basic conversions
    content=$(echo "$content" | sed 's/^# /== /g')  # Headers
    content=$(echo "$content" | sed 's/^## /=== /g')
    content=$(echo "$content" | sed 's/^### /==== /g')
    content=$(echo "$content" | sed 's/\*\*([^*]*)\*\*/\\*\1\\*/g')  # Bold
    content=$(echo "$content" | sed 's/\*([^*]*)\*/_\1_/g')  # Italic
    content=$(echo "$content" | sed 's/`([^`]*)`/\`\1\`/g')  # Code
    content=$(echo "$content" | sed 's/!\[([^\]]*)\]([^(]*)/image:\2[\1]/g')  # Images
    content=$(echo "$content" | sed 's/\[([^\]]*)\]([^(]*)/link:\2[\1]/g')  # Links
    
    # Write to adoc file
    echo "= $(basename $(dirname "$md_file"))" > "$adoc_file"
    echo ":toc: preamble" >> "$adoc_file"
    echo ":icons: font" >> "$adoc_file"
    echo "" >> "$adoc_file"
    echo "$content" >> "$adoc_file"
}

# Find all remaining README.md files and convert them
REPOS_DIR="${REPOS_DIR:-/var/mnt/eclipse/repos}"
find "$REPOS_DIR" -maxdepth 2 -name "README.md" -type f | while read md_file; do
    repo_dir=$(dirname "$md_file")
    adoc_file="$repo_dir/README.adoc"
    
    echo "Converting: $md_file"
    convert_markdown_to_adoc "$md_file" "$adoc_file"
    
    # Remove the original markdown file
    rm "$md_file"
    echo "  → Created: $adoc_file"
done

echo "Conversion complete!"