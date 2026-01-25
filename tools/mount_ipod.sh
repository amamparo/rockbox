#!/bin/bash
#             __________               __   ___.
#   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
#   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
#   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
#   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
#                     \/            \/     \/    \/            \/
#
# Detect and mount an iPod, saving the mount point for other scripts
#
# Usage:
#   ./mount_ipod.sh           - Mount iPod and save mount point
#   ./mount_ipod.sh --get     - Print current mount point (if mounted)
#   ./mount_ipod.sh --eject   - Eject the iPod
#
# The mount point is saved to output/.ipod_mount for use by other scripts.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$ROOT_DIR/output"
MOUNT_FILE="$OUTPUT_DIR/.ipod_mount"

# Find iPod disk identifier
# Look for external physical disks with iPod-like partition structure
find_ipod_disk() {
    # Check all external physical disks
    for disk in $(diskutil list | grep "^/dev/disk" | grep "external, physical" | awk '{print $1}' | sed 's/://'); do
        # iPods typically have partition 1 as firmware and partition 2 as data
        if diskutil info "${disk}s2" &>/dev/null; then
            local vol_name
            vol_name=$(diskutil info "${disk}s2" 2>/dev/null | grep "Volume Name:" | sed 's/.*Volume Name: *//')
            if [ -n "$vol_name" ]; then
                echo "${disk}s2"
                return 0
            fi
        fi
    done
    return 1
}

# Get current mount point of a disk
get_disk_mount_point() {
    local disk="$1"
    diskutil info "$disk" 2>/dev/null | grep "Mount Point:" | sed 's/.*Mount Point: *//'
}

# Find mounted iPod by looking for .rockbox directory
find_mounted_ipod() {
    # Check common mount points first
    for mount in /Volumes/IPOD /Volumes/iPod /Volumes/ROCKBOX; do
        if [ -d "$mount/.rockbox" ]; then
            echo "$mount"
            return 0
        fi
    done

    # Search all volumes
    for mount in /Volumes/*; do
        if [ -d "$mount/.rockbox" ]; then
            echo "$mount"
            return 0
        fi
    done

    return 1
}

# Save mount point to file
save_mount_point() {
    local mount_point="$1"
    mkdir -p "$OUTPUT_DIR"
    echo "$mount_point" > "$MOUNT_FILE"
}

# Get saved mount point
get_saved_mount_point() {
    if [ -f "$MOUNT_FILE" ]; then
        local saved
        saved=$(cat "$MOUNT_FILE")
        # Verify it's still valid
        if [ -d "$saved/.rockbox" ]; then
            echo "$saved"
            return 0
        fi
    fi
    return 1
}

# Eject the iPod
do_eject() {
    local mount_point=""

    # Try saved mount point first
    if [ -f "$MOUNT_FILE" ]; then
        mount_point=$(cat "$MOUNT_FILE")
    fi

    # Find the disk
    local ipod_disk
    if ! ipod_disk=$(find_ipod_disk); then
        echo "No iPod found to eject"
        rm -f "$MOUNT_FILE"
        return 0
    fi

    echo "Ejecting iPod..."
    if ! diskutil eject "$ipod_disk" 2>/dev/null; then
        echo "Normal eject failed, trying force unmount..."
        if [ -n "$mount_point" ]; then
            diskutil unmount force "$mount_point" 2>/dev/null || true
        fi
        if ! diskutil eject "$ipod_disk" 2>/dev/null; then
            echo "Warning: Could not eject iPod. Close any Finder windows and eject manually."
            return 1
        fi
    fi

    rm -f "$MOUNT_FILE"
    echo "iPod ejected successfully"
}

# Main mount logic
do_mount() {
    echo "Looking for iPod..."

    # First, check if already mounted
    local mount_point
    if mount_point=$(find_mounted_ipod); then
        echo "iPod already mounted at $mount_point"
        save_mount_point "$mount_point"
        return 0
    fi

    # Find the iPod disk
    local ipod_disk
    if ! ipod_disk=$(find_ipod_disk); then
        echo "Error: No iPod detected"
        echo "Please connect your iPod and try again"
        return 1
    fi

    echo "Found iPod at $ipod_disk"

    # Check if disk is already mounted somewhere
    mount_point=$(get_disk_mount_point "$ipod_disk")

    if [ -z "$mount_point" ]; then
        # Not mounted, mount it
        echo "Mounting iPod..."
        mount_point="/Volumes/IPOD"
        sudo mkdir -p "$mount_point"
        if ! sudo mount -t msdos "$ipod_disk" "$mount_point"; then
            echo "Error: Failed to mount iPod"
            return 1
        fi
        # Disable Spotlight indexing
        touch "$mount_point/.metadata_never_index" 2>/dev/null || true
    fi

    echo "iPod mounted at $mount_point"
    save_mount_point "$mount_point"
}

# Handle arguments
case "${1:-}" in
    --get)
        if mount_point=$(get_saved_mount_point); then
            echo "$mount_point"
        elif mount_point=$(find_mounted_ipod); then
            save_mount_point "$mount_point"
            echo "$mount_point"
        else
            echo "Error: iPod not mounted. Run 'make mount' first." >&2
            exit 1
        fi
        ;;
    --eject)
        do_eject
        ;;
    "")
        do_mount
        ;;
    *)
        echo "Usage: $0 [--get|--eject]"
        exit 1
        ;;
esac
