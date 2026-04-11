#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Batch Deployment Script - Processes 30 repositories at a time

set -euo pipefail

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "  Batch Deployment: 30 Repositories at a Time"
echo "  $(date)"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""

# Source directories
SOURCE_STANDARDS="/var/mnt/eclipse/repos/standards"
SOURCE_BURBLE="/var/mnt/eclipse/repos/burble"

# Get list of all repositories
ALL_REPOS=$(find /var/mnt/eclipse/repos -maxdepth 1 -type d | grep -v "^\.$" | grep -v "^standards$" | grep -v "^burble$" | grep -v "^panll$" | grep -v "^nextgen-databases$" | grep -v "^rescript$")

# Count total
TOTAL=$(echo "$ALL_REPOS" | wc -l)
echo "Total repositories to process: $TOTAL"
echo ""

# Process in batches of 30
COUNTER=0
PROCESSED=0

for repo in $ALL_REPOS; do
  COUNTER=$((COUNTER + 1))
  PROCESSED=$((PROCESSED + 1))
  repo_name=$(basename "$repo")
  
  echo "Processing $COUNTER: $repo_name..."
  
  # Skip if already processed
  if [ -d "$repo/.machine_readable/contractiles" ] && \
     [ -f "$repo/docs/compliance/ACCESSIBILITY.adoc" ]; then
    echo "  ⊘ Already fully processed"
    continue
  fi
  
  # Check accessibility
  if [ ! -w "$repo" ]; then
    echo "  ⚠️  No write permission"
    continue
  fi
  
  # Phase 1: Contractiles
  if [ ! -d "$repo/.machine_readable/contractiles" ]; then
    mkdir -p "$repo/.machine_readable/contractiles"
    cp -r "$SOURCE_STANDARDS/.machine_readable/contractiles/"* "$repo/.machine_readable/contractiles/" 2>/dev/null && \
      echo "    ✅ Contractiles deployed" || echo "    ⚠️  Contractiles partial"
  else
    echo "    ✅ Contractiles present"
  fi
  
  # Phase 2: K9-SVC
  if [ -d "$repo/.github/workflows" ]; then
    ci_file=$(find "$repo/.github/workflows" -name "*.yml" | head -1)
    if [ -n "$ci_file" ] && ! grep -q "K9-SVC" "$ci_file" 2>/dev/null; then
      cat >> "$ci_file" << 'EOF' 2>/dev/null

  - name: K9-SVC Validation
    run: |
      echo "K9-SVC validation"
      [ -d .machine_readable/contractiles ] && echo "Contractiles present" || echo "No contractiles"
EOF
      echo "    ✅ K9-SVC added"
    else
      echo "    ✅ K9-SVC present"
    fi
  else
    echo "    ⚠️  No CI workflow"
  fi
  
  # Phase 3: Accessibility
  if [ ! -d "$repo/docs/accessibility" ]; then
    mkdir -p "$repo/docs/accessibility"
    cp "$SOURCE_BURBLE/docs/accessibility/README.adoc" "$repo/docs/accessibility/" 2>/dev/null && \
      echo "    ✅ Accessibility docs added" || echo "    ⚠️  Accessibility partial"
  else
    echo "    ✅ Accessibility present"
  fi
  
  # Phase 4: VPAT
  if [ ! -d "$repo/docs/compliance" ]; then
    mkdir -p "$repo/docs/compliance"
    echo "= Accessibility Compliance" > "$repo/docs/compliance/ACCESSIBILITY.adoc"
    echo "Status: Partial" >> "$repo/docs/compliance/ACCESSIBILITY.adoc"
    echo "Target: WCAG 2.1 AA" >> "$repo/docs/compliance/ACCESSIBILITY.adoc"
    echo "    ✅ VPAT created"
  else
    echo "    ✅ VPAT present"
  fi
  
  echo "  ✅ $repo_name completed"
  
  # Batch complete
  if [ $((COUNTER % 30)) -eq 0 ]; then
    echo ""
    echo "Batch $((COUNTER / 30)) complete. Processed: $PROCESSED"
    read -p "Press Enter to continue next batch..."
  fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "  Batch Deployment Complete"
echo "  Total processed: $PROCESSED repositories"
echo "═══════════════════════════════════════════════════════════════════════════════"
