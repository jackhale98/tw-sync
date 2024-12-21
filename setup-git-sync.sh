#!/bin/bash

# Setup script for TimeWarrior Git configuration
# Save as ~/.local/share/timewarrior/setup-git-sync.sh

DATA_DIR="${HOME}/.local/share/timewarrior"

# Ensure we're in the data directory
cd "${DATA_DIR}" || exit 1

# Initialize git repo if it doesn't exist
if [ ! -d ".git" ]; then
    git init

    # Simple .gitignore
    cat > .gitignore << EOL
*.lock
*.tmp
*.log
/timewarrior.cfg
EOL

    # Initial commit
    git add .gitignore
    git commit -m "Initial TimeWarrior sync setup"
fi

# Create sync script
cat > sync.sh << EOL
#!/bin/bash

# Sync script for TimeWarrior data directory
cd "\${HOME}/.local/share/timewarrior" || exit 1

# Debug output
echo "Current git status:"
git status

# Check if timer is running
active_timer=\$(timew get dom.active 2>/dev/null)
if [[ "\$active_timer" != "0" ]]; then
    echo "Warning: Timer currently running. Stop it before syncing."
    exit 1
fi

# Add and commit any changes
if [[ \$(git status --porcelain) ]]; then
    git add .
    git commit -m "Update timewarrior data \$(date)"
fi

# Simple pull then push
git pull origin main
git push origin main

EOL

chmod +x sync.sh

echo "Git configuration complete!"
echo "Next steps:"
echo "1. Add your remote repository:"
echo "   git remote add origin <your-repo-url>"
echo "2. Push initial commit:"
echo "   git push -u origin main"
echo "3. On other machines, clone the repository:"
echo "   git clone <your-repo-url> ~/.local/share/timewarrior"
