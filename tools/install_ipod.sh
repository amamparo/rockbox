#!/bin/bash
#             __________               __   ___.
#   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
#   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
#   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
#   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
#                     \/            \/     \/    \/            \/
#
# Install Rockbox to a connected iPod
#
# This script:
# 1. Detects a connected iPod via diskutil
# 2. Mounts it if needed
# 3. Extracts rockbox.zip to local cache (if newer)
# 4. Syncs .rockbox to iPod using rsync (fast incremental updates)
# 5. Installs third-party themes from themes/thirdparty/*.zip
# 6. Ejects the iPod

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$ROOT_DIR/output"
ZIP_FILE="$OUTPUT_DIR/rockbox.zip"
CACHE_DIR="$OUTPUT_DIR/.rockbox-cache"
THEMES_DIR="$ROOT_DIR/themes/thirdparty"
THEMES_CACHE_DIR="$OUTPUT_DIR/.themes-cache"

# Check if rockbox.zip exists
if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: $ZIP_FILE not found"
    echo "Run 'make build' first to create the firmware package"
    exit 1
fi

# Extract to local cache if zip is newer than cache
update_cache() {
    if [ ! -d "$CACHE_DIR/.rockbox" ] || [ "$ZIP_FILE" -nt "$CACHE_DIR/.rockbox" ]; then
        echo "Updating local cache..."
        rm -rf "$CACHE_DIR"
        mkdir -p "$CACHE_DIR"
        unzip -q -o "$ZIP_FILE" -d "$CACHE_DIR"
        touch "$CACHE_DIR/.rockbox"  # Update timestamp for future comparisons
    else
        echo "Local cache is up to date"
    fi
}

# Extract theme zips to cache if newer, then sync to iPod
install_themes() {
    if [ ! -d "$THEMES_DIR" ]; then
        return 0
    fi

    local theme_zips=("$THEMES_DIR"/*.zip)
    if [ ! -e "${theme_zips[0]}" ]; then
        return 0
    fi

    echo "Installing third-party themes..."
    mkdir -p "$THEMES_CACHE_DIR"

    for theme_zip in "${theme_zips[@]}"; do
        local theme_name
        theme_name=$(basename "$theme_zip" .zip)
        local theme_cache="$THEMES_CACHE_DIR/$theme_name"

        # Extract if zip is newer than cache
        if [ ! -d "$theme_cache" ] || [ "$theme_zip" -nt "$theme_cache" ]; then
            echo "  Extracting $theme_name..."
            rm -rf "$theme_cache"
            mkdir -p "$theme_cache"
            unzip -q -o "$theme_zip" -d "$theme_cache"
            touch "$theme_cache"
        fi

        # Sync theme to iPod (no --delete, we want to merge)
        # Theme zips contain a .rockbox folder, so sync its contents
        echo "  Syncing $theme_name..."
        rsync -a --progress "$theme_cache/.rockbox/" "$MOUNT_POINT/.rockbox/"
    done
}

# Find iPod disk identifier
# Look for Apple_HFS or Windows_FAT32 partitions on iPod devices
find_ipod() {
    # diskutil list shows all disks; iPods typically have "Apple_HFS" or "Windows_FAT32"
    # partition with "IPOD" in the name, or we can identify by the disk structure
    # iPods have a small firmware partition followed by a larger data partition

    # First, try to find by volume name containing "IPOD" (case insensitive)
    local disk_info
    disk_info=$(diskutil list 2>/dev/null)

    # Look for mounted iPod volumes
    local ipod_disk=""

    # Check all external physical disks for iPod-like structure
    for disk in $(diskutil list | grep "^/dev/disk" | grep "external, physical" | awk '{print $1}' | sed 's/://'); do
        # iPods typically have partition 1 as firmware and partition 2 as data
        # Check if this disk has an Apple_HFS or Windows_FAT32 partition that could be an iPod
        if diskutil info "${disk}s2" &>/dev/null; then
            local vol_name
            vol_name=$(diskutil info "${disk}s2" 2>/dev/null | grep "Volume Name:" | sed 's/.*Volume Name: *//')
            if [ -n "$vol_name" ]; then
                # Found a candidate - external disk with a second partition
                ipod_disk="${disk}s2"
                echo "$ipod_disk"
                return 0
            fi
        fi
    done

    return 1
}

# Get current mount point of a disk
get_mount_point() {
    local disk="$1"
    diskutil info "$disk" 2>/dev/null | grep "Mount Point:" | sed 's/.*Mount Point: *//'
}

# Main logic
echo "Looking for iPod..."

IPOD_DISK=$(find_ipod) || {
    echo "Error: No iPod detected"
    echo "Please connect your iPod and try again"
    exit 1
}

echo "Found iPod at $IPOD_DISK"

# Check current mount status
CURRENT_MOUNT=$(get_mount_point "$IPOD_DISK")

if [ -z "$CURRENT_MOUNT" ]; then
    # Not mounted, use direct mount
    echo "iPod not mounted, mounting..."
    MOUNT_POINT="/Volumes/IPOD"
    sudo mkdir -p "$MOUNT_POINT"
    if sudo mount -t msdos "$IPOD_DISK" "$MOUNT_POINT"; then
        CURRENT_MOUNT="$MOUNT_POINT"
        # Disable Spotlight indexing
        touch "$MOUNT_POINT/.metadata_never_index" 2>/dev/null || true
    fi
fi

if [ -z "$CURRENT_MOUNT" ]; then
    echo "Error: Failed to mount iPod"
    exit 1
fi

MOUNT_POINT="$CURRENT_MOUNT"
echo "iPod mounted at $MOUNT_POINT"

# Update local cache from zip
update_cache

# Sync to iPod using rsync (only transfers changed files)
# Exclude user-generated files that should be preserved
echo "Syncing .rockbox to iPod..."
rsync -a --delete \
    --exclude='config.cfg' \
    --exclude='config.cfg.*' \
    --exclude='.resume.cfg' \
    --exclude='.resume.cfg.*' \
    --exclude='.playlist_control' \
    --exclude='.playlist_control.*' \
    --exclude='database_*.tcd' \
    --exclude='database_idx.tcd' \
    --exclude='playername.txt' \
    --exclude='battery_bench.txt' \
    "$CACHE_DIR/.rockbox" "$MOUNT_POINT/"

# Verify sync succeeded
if [ ! -d "$MOUNT_POINT/.rockbox" ]; then
    echo "Error: Sync failed - .rockbox directory not found"
    exit 1
fi

# Install third-party themes
install_themes

echo "Rockbox installed successfully"

# Eject the iPod
echo "Ejecting iPod..."
if ! diskutil eject "$IPOD_DISK" 2>/dev/null; then
    # Finder often holds the volume open; try unmount force then eject
    echo "Normal eject failed, trying force unmount..."
    diskutil unmount force "$MOUNT_POINT" 2>/dev/null || true
    if ! diskutil eject "$IPOD_DISK" 2>/dev/null; then
        echo "Warning: Could not eject iPod. Close any Finder windows showing the iPod and eject manually."
        exit 0
    fi
fi

echo "Done! You can safely disconnect your iPod."
