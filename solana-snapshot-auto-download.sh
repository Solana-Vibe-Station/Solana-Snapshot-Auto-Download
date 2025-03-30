#!/bin/bash

### Configuration ### CHANGE THESE TO MATCH YOUR ENVIRONMENT ###

SNAPSHOT_DIR="/var/solana/data/ledger"   # Change this to your Solana node snapshot directory
RPC_NODE="http://10.10.5.38:8899"        # Change this to your preferred RPC node
LOG_FILE="/home/solana/validator.log"    # Change this to your preferred log file
MAX_SLOT_DIFF=1000                       # Maximum slot difference before downloading a new snapshot

SNAPSHOT_FILE_PATTERN="snapshot-*.tar.bz2"  # Pattern to match snapshot files

# Colors for output (only used if running in terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - ${message}" | tee -a "$LOG_FILE"
}

# Function to check if directory exists
check_directory() {
    if [ ! -d "$SNAPSHOT_DIR" ]; then
        log_message "${RED}Error: Directory $SNAPSHOT_DIR does not exist${NC}"
        mkdir -p "$SNAPSHOT_DIR" || {
            log_message "${RED}Failed to create directory $SNAPSHOT_DIR${NC}"
            exit 1
        }
        log_message "${GREEN}Created directory $SNAPSHOT_DIR${NC}"
    fi
}

# Function to find the most recent snapshot
find_latest_snapshot() {
    local latest_snapshot=$(find "$SNAPSHOT_DIR" -name "$SNAPSHOT_FILE_PATTERN" -type f -printf '%T+ %p\n' | sort -r | head -n1)
    echo "$latest_snapshot"
}

# Function to get current slot from RPC
get_current_slot() {
    local slot=$(curl -s "$RPC_NODE" -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq -r '.result')
    if [ -z "$slot" ]; then
        log_message "${RED}Failed to get current slot from RPC node${NC}"
        return 1
    fi
    echo "$slot"
}

# Function to extract slot from snapshot filename
extract_slot_from_filename() {
    local filename="$1"
    local slot=$(echo "$filename" | grep -oP 'snapshot-\K\d+')
    echo "$slot"
}

# Function to check if snapshot needs updating
check_snapshot_needs_update() {
    local snapshot_path="$1"
    if [ -z "$snapshot_path" ]; then
        return 0  # No snapshot exists, needs update
    fi

    local filename=$(basename "$snapshot_path")
    local snapshot_slot=$(extract_slot_from_filename "$filename")
    local current_slot=$(get_current_slot)
    
    if [ -z "$snapshot_slot" ] || [ -z "$current_slot" ]; then
        return 0  # Error getting slots, should update
    fi

    local slot_diff=$((current_slot - snapshot_slot))
    if [ "$slot_diff" -gt "$MAX_SLOT_DIFF" ]; then
        return 0  # Snapshot is too old
    fi

    return 1  # Snapshot is current
}

# Function to download new snapshot
download_snapshot() {
    log_message "${YELLOW}Downloading new snapshot...${NC}"
    
    # Get the latest snapshot slot from RPC
    local slot=$(get_current_slot)
    if [ -z "$slot" ]; then
        return 1
    fi

    # Download the snapshot with original filename
    log_message "${YELLOW}Downloading snapshot...${NC}"
    if wget --trust-server-names "$RPC_NODE/snapshot.tar.bz2" -P "$SNAPSHOT_DIR"; then
        log_message "${GREEN}Successfully downloaded new snapshot${NC}"
    else
        log_message "${RED}Failed to download snapshot${NC}"
        return 1
    fi

    # Always download the incremental snapshot with original filename
    log_message "${YELLOW}Downloading incremental snapshot...${NC}"
    if wget --trust-server-names "$RPC_NODE/incremental-snapshot.tar.bz2" -P "$SNAPSHOT_DIR"; then
        log_message "${GREEN}Successfully downloaded incremental snapshot${NC}"
    else
        log_message "${RED}Failed to download incremental snapshot${NC}"
        return 1
    fi

    return 0
}

# Function to download incremental snapshot
download_incremental_snapshot() {
    log_message "${YELLOW}Downloading incremental snapshot...${NC}"
    if wget --trust-server-names "$RPC_NODE/incremental-snapshot.tar.bz2" -P "$SNAPSHOT_DIR"; then
        log_message "${GREEN}Successfully downloaded incremental snapshot${NC}"
    else
        log_message "${RED}Failed to download incremental snapshot${NC}"
    fi
}

# Function to display snapshot status
display_snapshot_status() {
    local current_slot=$(get_current_slot)
    local snapshot_slot=$(extract_slot_from_filename "$(basename "$1")")
    local slot_diff=$((current_slot - snapshot_slot))
    log_message "${GREEN}Snapshot is current (${slot_diff} slots behind)${NC}"
}

# Main script
log_message "${YELLOW}Starting Solana snapshot check...${NC}"

# Check if directory exists
check_directory

# Find latest snapshot
latest_snapshot=$(find_latest_snapshot)
if [ -z "$latest_snapshot" ]; then
    log_message "${YELLOW}No snapshots found. Downloading new snapshot...${NC}"
    download_snapshot
    exit 0
fi

# Extract just the file path from the find output
snapshot_path=$(echo "$latest_snapshot" | cut -d' ' -f2-)

# Check if snapshot needs updating
if check_snapshot_needs_update "$snapshot_path"; then
    log_message "${YELLOW}Snapshot needs updating. Downloading new snapshot...${NC}"
    download_snapshot
else
    display_snapshot_status "$snapshot_path"
    download_incremental_snapshot
fi 
