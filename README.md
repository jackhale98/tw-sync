# TaskWarrior and TimeWarrior Multi-Machine Setup Guide

This guide covers setting up TaskWarrior with Google Cloud sync and TimeWarrior with Git sync on a new machine.

## Prerequisites

- Git installed
- Google Cloud CLI installed
- TaskWarrior 3.3.0+ installed
- TimeWarrior installed

## Part 1: TaskWarrior Setup with Google Cloud Sync

1. Create a new GCP project and bucket (if not already done):
   - Visit Google Cloud Console
   - Create a new project
   - Create a new Cloud Storage bucket with default settings

2. Authenticate with Google Cloud:
```bash
gcloud config set project YOUR_PROJECT_NAME
gcloud auth application-default login
```

3. Configure TaskWarrior:
```bash
# Set up encryption (use the same secret across all machines)
task config sync.encryption_secret "your-secret-here"

# Configure GCP bucket
task config sync.gcp.bucket "your-bucket-name"
```

4. For Alternative Service Account Setup:
   - Create a custom role with these permissions:
     - storage.buckets.create
     - storage.buckets.get
     - storage.buckets.update
     - storage.objects.create
     - storage.objects.delete
     - storage.objects.get
     - storage.objects.list
     - storage.objects.update
   - Create a service account with this role
   - Download JSON credentials
   - Configure TaskWarrior with credential path:
```bash
task config sync.gcp.credential_path "/absolute/path/to/credentials.json"
```

5. Configure Recurrence:
   - On primary machine:
```bash
task config recurrence on
```
   - On secondary machines:
```bash
task config recurrence off
```

6. Perform initial sync:
```bash
task sync
```

## Part 2: TimeWarrior Setup with Git Sync

1. Create necessary directories:
```bash
mkdir -p ~/.config/timewarrior/extensions
mkdir -p ~/.local/share/timewarrior
```

2. Set up Git repository in data directory:
```bash
cd ~/.local/share/timewarrior

# Create .gitignore
cat > .gitignore << EOL
*.lock
*.tmp
*.log
/timewarrior.cfg
EOL

# Initialize repository
git init
git add .gitignore
git commit -m "Initial commit"

# Add remote (replace with your repository URL)
git remote add origin git@github.com:jackhale98/tw-sync.git
git branch -M main
git push -u origin main
```

3. Install sync hook:
```bash
# Create the hook file
cat > ~/.config/timewarrior/extensions/on-modify.sync << 'EOL'
#!/bin/bash

# Configuration
DATA_DIR="${HOME}/.local/share/timewarrior"
CHANGES_BEFORE_SYNC=5
CHANGE_COUNT_FILE="${DATA_DIR}/.git/unsynced_changes"
LOCK_FILE="${DATA_DIR}/.git/sync.lock"
LOG_FILE="${DATA_DIR}/sync.log"

# Ensure we're in the data directory
cd "${DATA_DIR}" || exit 1

# Initialize change counter if it doesn't exist
if [ ! -f "$CHANGE_COUNT_FILE" ]; then
    echo "0" > "$CHANGE_COUNT_FILE"
fi

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to perform sync
do_sync() {
    # Check for lock file
    if [ -f "$LOCK_FILE" ]; then
        lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE")))
        if [ $lock_age -gt 300 ]; then  # 5 minutes timeout
            log_message "Removing stale lock file"
            rm "$LOCK_FILE"
        else
            log_message "Sync already in progress, skipping"
            return 1
        fi
    fi

    # Create lock file
    touch "$LOCK_FILE"

    # Perform sync
    log_message "Starting sync"
    
    # Check for local changes
    if [[ $(git status --porcelain) ]]; then
        log_message "Committing local changes"
        git add .
        git commit -m "Auto-sync $(date)" >> "$LOG_FILE" 2>&1
    fi

    # Setup upstream if needed
    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
        log_message "Setting up upstream branch"
        git branch --set-upstream-to=origin/main main >> "$LOG_FILE" 2>&1
    fi

    # Pull changes
    log_message "Pulling remote changes"
    git pull origin main >> "$LOG_FILE" 2>&1
    
    # Push changes
    log_message "Pushing changes"
    if git push origin main >> "$LOG_FILE" 2>&1; then
        log_message "Sync completed successfully"
        echo "0" > "$CHANGE_COUNT_FILE"
    else
        log_message "Sync failed"
    fi

    # Remove lock file
    rm "$LOCK_FILE"
}

# Increment change counter
count=$(cat "$CHANGE_COUNT_FILE")
count=$((count + 1))
echo $count > "$CHANGE_COUNT_FILE"

log_message "Increment change counter to $count"

# Check if we should sync
if [ $count -ge $CHANGES_BEFORE_SYNC ]; then
    (
        sleep 2
        do_sync
    ) &
fi

# Pass-through any arguments to support hook chaining
if [ -n "$1" ]; then
    exec "$@"
fi
EOL

# Make hook executable
chmod +x ~/.config/timewarrior/extensions/on-modify.sync
```

4. Create sync script:
```bash
cat > ~/.local/share/timewarrior/sync.sh << 'EOL'
#!/bin/bash
cd "${HOME}/.local/share/timewarrior" || exit 1

# Debug output
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
EOL

chmod +x ~/.local/share/timewarrior/sync.sh
```

5. Add convenience alias (for Fish shell):
```bash
# Add to ~/.config/fish/config.fish
function timew-sync
    ~/.local/share/timewarrior/sync.sh
end
```

## Usage

1. TaskWarrior:
   - Sync automatically happens on task modifications
   - Manual sync: `task sync`

2. TimeWarrior:
   - Automatic sync after every 5 changes via hook
   - Manual sync: `timew-sync`

## Troubleshooting

1. If TimeWarrior sync fails:
   - Check sync.log in ~/.local/share/timewarrior/
   - Ensure no timer is running
   - Run manual sync to see detailed output

2. If TaskWarrior sync fails:
   - Check encryption secret matches across machines
   - Verify GCP credentials and permissions
   - Run `task diagnostics` for detailed information
