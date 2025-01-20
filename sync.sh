#!/bin/bash

<<<<<<< HEAD
# Sync script for TimeWarrior data directory
cd "${HOME}/.local/share/timewarrior" || exit 1

# Debug output
=======
# Source directory configuration
source ~/.timewarrior-dirs

cd "${DATA_DIR}" || exit 1

# Debug output
echo "Using TimeWarrior data directory: ${DATA_DIR}"
>>>>>>> 81f2f61 (Update timewarrior data Mon Dec 23 14:28:13 EST 2024)
echo "Current git status:"
git status

# Check if timer is running
active_timer=$(timew get dom.active 2>/dev/null)
if [[ "$active_timer" != "0" ]]; then
    echo "Warning: Timer currently running. Stop it before syncing."
    exit 1
fi

# Add and commit any changes
if [[ $(git status --porcelain) ]]; then
    git add .
    git commit -m "Update timewarrior data $(date)"
fi

# Simple pull then push
git pull origin main
git push origin main
<<<<<<< HEAD

=======
>>>>>>> 81f2f61 (Update timewarrior data Mon Dec 23 14:28:13 EST 2024)
