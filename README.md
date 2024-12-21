# Flexible TimeWarrior Setup Guide

## Directory Detection Script

First, create a script to detect and manage TimeWarrior directories:

```bash
# Save as detect-timew-dirs.sh
#!/bin/bash

# Function to detect TimeWarrior directories
detect_timew_dirs() {
    # Check for XDG directories first
    if [ -d "${HOME}/.local/share/timewarrior" ]; then
        DATA_DIR="${HOME}/.local/share/timewarrior"
        CONFIG_DIR="${HOME}/.config/timewarrior"
    # Fall back to legacy directory
    elif [ -d "${HOME}/.timewarrior" ]; then
        DATA_DIR="${HOME}/.timewarrior"
        CONFIG_DIR="${HOME}/.timewarrior"
    else
        # If neither exists, prefer XDG structure
        DATA_DIR="${HOME}/.local/share/timewarrior"
        CONFIG_DIR="${HOME}/.config/timewarrior"
    fi

    # Create directories if they don't exist
    mkdir -p "${DATA_DIR}"
    mkdir -p "${CONFIG_DIR}/extensions"

    # Export variables for use in other scripts
    echo "DATA_DIR=${DATA_DIR}"
    echo "CONFIG_DIR=${CONFIG_DIR}"
}

# Execute and store results
detect_timew_dirs > ~/.timewarrior-dirs

# Source the results
source ~/.timewarrior-dirs
```

## Updated Sync Hook

```bash
# Save as timewarrior-sync-hook.sh
#!/bin/bash

# Source directory configuration
source ~/.timewarrior-dirs

# If directories file doesn't exist, create it
if [ ! -f ~/.timewarrior-dirs ]; then
    $(dirname $0)/detect-timew-dirs.sh
    source ~/.timewarrior-dirs
fi

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

## Updated Setup Instructions

1. First, detect and set up directories:
```bash
# Download and make the detection script executable
curl -o ~/detect-timew-dirs.sh https://your-script-location/detect-timew-dirs.sh
chmod +x ~/detect-timew-dirs.sh

# Run the detection script
~/detect-timew-dirs.sh

# Source the directory configuration
source ~/.timewarrior-dirs

# Verify directories
echo "Data Directory: $DATA_DIR"
echo "Config Directory: $CONFIG_DIR"
```

2. Set up Git repository in the data directory:
```bash
cd "${DATA_DIR}"

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

3. Install the sync hook:
```bash
# Install hook to the detected config directory
cp timewarrior-sync-hook.sh "${CONFIG_DIR}/extensions/on-modify.sync"
chmod +x "${CONFIG_DIR}/extensions/on-modify.sync"
```

4. Create sync script in the data directory:
```bash
cat > "${DATA_DIR}/sync.sh" << 'EOL'
#!/bin/bash

# Source directory configuration
source ~/.timewarrior-dirs

# If directories file doesn't exist, create it
if [ ! -f ~/.timewarrior-dirs ]; then
    $(dirname $0)/detect-timew-dirs.sh
    source ~/.timewarrior-dirs
fi

cd "${DATA_DIR}" || exit 1

# Debug output
echo "Using TimeWarrior data directory: ${DATA_DIR}"
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

chmod +x "${DATA_DIR}/sync.sh"
```

5. Add Fish shell alias that works with either directory structure:
```fish
# Add to ~/.config/fish/config.fish
function timew-sync
    # Source directory configuration
    source ~/.timewarrior-dirs
    
    # If directories file doesn't exist, create it
    if not test -f ~/.timewarrior-dirs
        ~/detect-timew-dirs.sh
        source ~/.timewarrior-dirs
    end
    
    # Run sync script from detected data directory
    $DATA_DIR/sync.sh
end
```

## Migration Between Directory Structures

If you need to migrate from one directory structure to another:

1. Stop any running timers
2. Run sync on both machines to ensure all data is synchronized
3. On the machine you want to change:
```bash
# Backup current data
cp -r ~/.timewarrior ~/.timewarrior-backup  # if using old structure
# or
cp -r ~/.local/share/timewarrior ~/.timewarrior-backup  # if using new structure

# Run detection script
~/detect-timew-dirs.sh
source ~/.timewarrior-dirs

# Clone repository to new location if different
git clone git@github.com:jackhale98/tw-sync.git "${DATA_DIR}"
```

## Troubleshooting

1. If you're unsure which directories are being used:
```bash
cat ~/.timewarrior-dirs
```

2. If the sync isn't working:
```bash
# Verify directory structure
source ~/.timewarrior-dirs
echo "Data Dir: $DATA_DIR"
echo "Config Dir: $CONFIG_DIR"

# Check if directories exist
ls -la $DATA_DIR
ls -la $CONFIG_DIR/extensions

# Check Git status
cd $DATA_DIR
git status
```

3. If the hook isn't working:
```bash
# Verify hook installation
ls -la $CONFIG_DIR/extensions/on-modify.sync
```

This flexible setup will:
- Automatically detect and use the correct directory structure
- Work consistently across different machines
- Make it easy to migrate between directory structures
- Provide clear feedback about which directories are being used

Would you like me to add any additional scenarios or troubleshooting steps?
