#!/bin/bash

# Maintenance script for TimeWarrior Git repository
# Run this monthly or when repo seems sluggish

echo "Starting TimeWarrior Git repository maintenance..."

# Ensure we're in the right directory
cd "${HOME}/.local/share/timewarrior" || exit 1

# Stop any running timers
timew stop

# Verify repository
echo "Verifying repository..."
git fsck --full

# Prune old objects
echo "Pruning old objects..."
git prune --expire=now

# Optimize repository
echo "Optimizing repository..."
git gc --aggressive --prune=now

# Clean up unnecessary files
git clean -fd

# Recalculate repository size
size=$(du -sh .git | cut -f1)
echo "Repository size after maintenance: $size"

echo "Maintenance complete!"
