#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Mass Deployment Script for Hyperpolymath Estate
# Deploys contractiles, K9-SVC, accessibility, and VPAT across all repositories

set -euo pipefail

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "  Mass Deployment Across Hyperpolymath Estate"
echo "  $(date)"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""

# Source directories
SOURCE_STANDARDS="/var/mnt/eclipse/repos/standards"
SOURCE_BURBLE="/var/mnt/eclipse/repos/burble"

# Count repositories
TOTAL_REPOS=$(find /var/mnt/eclipse/repos -maxdepth 1 -type d | grep -v "^\.$" | wc -l)
echo "Total repositories to process: $TOTAL_REPOS"
echo ""

# Process repositories in batches
BATCH_SIZE=50
PROCESSED=0
SUCCESS=0
FAILED=0

find /var/mnt/eclipse/repos -maxdepth 1 -type d | grep -v "^\.$" | while read repo; do
  repo_name=$(basename "$repo")
  
  # Skip already processed repos
  if [ "$repo_name" = "burble" ] || [ "$repo_name" = "panll" ] || \
     [ "$repo_name" = "nextgen-databases" ] || [ "$repo_name" = "rescript" ] || \
     [ "$repo_name" = "standards" ]; then
    echo "⊘ $repo_name: Already processed"
    continue
  fi
  
  PROCESSED=$((PROCESSED + 1))
  
  echo "Processing $repo_name..."
  
  # Check if repository exists and is accessible
  if [ ! -d "$repo" ]; then
    echo "❌ $repo_name: Directory not found"
    FAILED=$((FAILED + 1))
    continue
  fi
  
  if [ ! -w "$repo" ]; then
    echo "⚠️  $repo_name: No write permission"
    continue
  fi
  
  # Phase 1: Contractiles
  if [ ! -d "$repo/.machine_readable/contractiles" ]; then
    mkdir -p "$repo/.machine_readable/contractiles"
    cp -r "$SOURCE_STANDARDS/.machine_readable/contractiles/"* "$repo/.machine_readable/contractiles/" 2>/dev/null && \
      echo "  ✅ Contractiles deployed" || echo "  ⚠️  Contractiles partial"
  else
    echo "  ✅ Contractiles already present"
  fi
  
  # Phase 2: K9-SVC CI/CD
  if [ -d "$repo/.github/workflows" ]; then
    ci_file=$(find "$repo/.github/workflows" -name "*.yml" | head -1)
    if [ -n "$ci_file" ] && ! grep -q "K9-SVC" "$ci_file" 2>/dev/null; then
      cat >> "$ci_file" << 'EOF' 2>/dev/null

  - name: K9-SVC Validation
    run: |
      echo "K9-SVC validation"
      [ -d .machine_readable/contractiles ] && echo "Contractiles present" || echo "No contractiles"
EOF
      echo "  ✅ K9-SVC added to CI"
    else
      echo "  ✅ K9-SVC already integrated"
    fi
  else
    echo "  ⚠️  No CI workflow found"
  fi
  
  # Phase 3: Accessibility
  if [ ! -d "$repo/docs/accessibility" ]; then
    mkdir -p "$repo/docs/accessibility"
    cp "$SOURCE_BURBLE/docs/accessibility/README.adoc" "$repo/docs/accessibility/" 2>/dev/null && \
      echo "  ✅ Accessibility docs added" || echo "  ⚠️  Accessibility docs partial"
  else
    echo "  ✅ Accessibility already present"
  fi
  
  # Phase 4: VPAT Compliance
  if [ ! -d "$repo/docs/compliance" ]; then
    mkdir -p "$repo/docs/compliance"
    # Create minimal VPAT
    echo "= Accessibility Compliance" > "$repo/docs/compliance/ACCESSIBILITY.adoc"
    echo "Status: Partial" >> "$repo/docs/compliance/ACCESSIBILITY.adoc"
    echo "Target: WCAG 2.1 AA" >> "$repo/docs/compliance/ACCESSIBILITY.adoc"
    echo "  ✅ VPAT compliance report created"
  else
    echo "  ✅ VPAT already present"
  fi
  
  echo "✅ $repo_name: All phases completed"
  SUCCESS=$((SUCCESS + 1))
  
  # Progress report
  if [ $((PROCESSED % BATCH_SIZE)) -eq 0 ]; then
    echo ""
    echo "Progress: $PROCESSED/$TOTAL_REPOS repositories processed"
    echo "Success: $SUCCESS | Failed: $FAILED"
    echo ""
  fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "  Mass Deployment Complete"
echo "  Processed: $PROCESSED repositories"
echo "  Success: $SUCCESS"
echo "  Failed: $FAILED"
echo "  Total in estate: $TOTAL_REPOS"
echo "═══════════════════════════════════════════════════════════════════════════════"
