#!/bin/bash

# README Standardization Script
# Converts all README files to README.adoc format and eliminates duplicates

REPOS_DIR="${REPOS_DIR:-/var/mnt/eclipse/repos}"
LOG_FILE="$HOME/Desktop/readme_standardization.log"
BACKUP_DIR="$HOME/Desktop/readme_backups"

# --- Ownership safety guard ---
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ownership_guard.sh
source "${_SCRIPT_DIR}/lib/ownership_guard.sh"

if ! command -v pandoc >/dev/null 2>&1; then
    echo "Error: pandoc is not installed. Please install it to use this script."
    exit 1
fi

echo "Starting README standardization process..."
echo "$(date) - Starting README standardization" > "$LOG_FILE"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Creating backups of existing README files..."
find "$REPOS_DIR" -maxdepth 2 -name "README*" -type f | while read readme_file; do
    repo_name=$(basename $(dirname "$readme_file"))
    file_name=$(basename "$readme_file")
    
    # Backup original file
    cp "$readme_file" "$BACKUP_DIR/${repo_name}_${file_name}"
    echo "Backed up: $file_name from $repo_name" >> "$LOG_FILE"
done

echo "" >> "$LOG_FILE"
echo "Processing repositories..." >> "$LOG_FILE"

# Process each repository
find "$REPOS_DIR"/*/ -maxdepth 0 -type d | while read repo; do
    if [[ ! -d "$repo/.git" ]]; then
        continue
    fi

    repo_name=$(basename "$repo")

    # --- Ownership filter ---
    if ! repo_allowed "$repo"; then
        echo "Skipping: $repo_name (owner not in allowlist)" >> "$LOG_FILE"
        continue
    fi

    echo "Processing: $repo_name" >> "$LOG_FILE"
    
    # Check what README files exist
    md_file="$repo/README.md"
    adoc_file="$repo/README.adoc"
    
    if [[ -f "$md_file" && -f "$adoc_file" ]]; then
        # Both exist - need to merge/decide
        echo "  ✗ Both README.md and README.adoc exist" >> "$LOG_FILE"
        
        # Compare sizes - keep the more substantial one
        md_lines=$(wc -l < "$md_file")
        adoc_lines=$(wc -l < "$adoc_file")
        
        if [[ $md_lines -gt $adoc_lines ]]; then
            echo "  Converting README.md to README.adoc (more content)" >> "$LOG_FILE"
            # Convert markdown to asciidoc
            pandoc "$md_file" -o "$adoc_file" -f markdown -t asciidoc
            rm "$md_file"
        else
            echo "  Keeping README.adoc (more content), removing README.md" >> "$LOG_FILE"
            rm "$md_file"
        fi
        
    elif [[ -f "$md_file" ]]; then
        # Only README.md exists - convert to adoc
        echo "  Converting README.md to README.adoc" >> "$LOG_FILE"
        pandoc "$md_file" -o "$adoc_file" -f markdown -t asciidoc
        rm "$md_file"
        
    elif [[ -f "$adoc_file" ]]; then
        # Only README.adoc exists - good
        echo "  ✓ README.adoc already exists" >> "$LOG_FILE"
    else
        # No README exists - create basic one
        echo "  Creating new README.adoc" >> "$LOG_FILE"
        
        # Analyze repository to create appropriate README
        language="Unknown"
        if [[ -f "$repo/mix.exs" ]]; then language="Elixir"
        elif [[ -f "$repo/Cargo.toml" ]]; then language="Rust"
        elif [[ -f "$repo/package.json" ]]; then language="JavaScript"
        elif [[ -f "$repo/stack.yaml" || -f "$repo/*.cabal" ]]; then language="Haskell"
        elif [[ -f "$repo/Project.toml" ]]; then language="Julia"
        fi
        
        cat > "$adoc_file" << EOF
= $repo_name
:toc: preamble
:icons: font

== Overview

**$language implementation of [purpose based on repo name].**

[Brief description to be completed]

== Features

* [Feature 1]
* [Feature 2]
* [Feature 3]

== Quick Start

[Installation and basic usage]

== License

SPDX-License-Identifier: PMPL-1.0-or-later

Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
EOF
    fi
done

echo "" >> "$LOG_FILE"
echo "$(date) - Standardization process completed" >> "$LOG_FILE"
echo "All README files have been standardized to README.adoc format" >> "$LOG_FILE"
echo "Backups are available in: $BACKUP_DIR"

echo "README standardization completed!"
echo "Backups saved to: $BACKUP_DIR"
echo "Log saved to: $LOG_FILE"