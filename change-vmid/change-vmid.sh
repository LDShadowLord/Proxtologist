#!/bin/bash

# Arguments
OLD_ID=$1
NEW_ID=$2
STORAGE=$3
COMMIT=false
DESTROY=false

# Check for flags
for arg in "$@"; do
    if [ "$arg" == "--commit" ]; then COMMIT=true; fi
    if [ "$arg" == "--destroy" ]; then DESTROY=true; fi
done

if [[ -z "$OLD_ID" || -z "$NEW_ID" || -z "$STORAGE" ]]; then
    echo "Usage: $0 <OLD_ID> <NEW_ID> <TARGET_STORAGE> [--commit] [--destroy]"
    exit 1
fi

run_cmd() {
    if [ "$COMMIT" = true ]; then
        echo " [EXEC] $*"
        "$@"
    else
        echo " [DRY-RUN] $*"
    fi
}

# 1. Validation
if ! qm status "$OLD_ID" >/dev/null 2>&1; then echo "Error: Source VM $OLD_ID not found."; exit 1; fi
if qm status "$NEW_ID" >/dev/null 2>&1; then echo "Error: Target VMID $NEW_ID already exists."; exit 1; fi

VM_STATUS=$(qm status "$OLD_ID")
if [[ "$COMMIT" = true && "$VM_STATUS" =~ "status: running" ]]; then
    echo "FATAL ERROR: VM $OLD_ID is still running."
    exit 1
fi

echo "--- ZFS Migration Analysis: $OLD_ID -> $NEW_ID ---"

# 2. Extract Network Configurations
NET_CONFIGS=$(qm config "$OLD_ID" | grep -E '^net[0-9]+:')

# 3. Identify and Orphan Data Disks
echo "Step 1: Orphaning data disks..."
RAW_DISK_LINES=$(qm config "$OLD_ID" | grep -E '^(scsi|virtio|ide|sata)[0-9]+:')

ATTACH_LIST=""
while read -r LINE; do
    [ -z "$LINE" ] && continue
    BUS=$(echo "$LINE" | cut -d: -f1)
    FULL_CONFIG=$(echo "$LINE" | cut -d: -f2- | xargs)
    VOL_ID=$(echo "$FULL_CONFIG" | cut -d, -f1)
    
    echo "  -> Found $BUS: $VOL_ID"
    run_cmd qm unlink "$OLD_ID" --idlist "$BUS"
    ATTACH_LIST+="$BUS|$FULL_CONFIG"$'\n'
done <<< "$RAW_DISK_LINES"

# 4. Clone VM Shell
VM_NAME=$(qm config "$OLD_ID" | grep "name:" | awk '{print $2}')
echo "Step 2: Cloning shell and system disks to '$STORAGE'..."
run_cmd qm clone "$OLD_ID" "$NEW_ID" --name "$VM_NAME" --storage "$STORAGE"

# 5. ZFS Rename and Reattach
echo "Step 3: Renaming ZVOLs and reattaching..."
while IFS='|' read -r BUS FULL_CONFIG; do
    [ -z "$BUS" ] && continue
    
    # Example: local-zfs:vm-100-disk-1
    OLD_VOL_ID=$(echo "$FULL_CONFIG" | cut -d, -f1)
    STORAGE_NAME=$(echo "$OLD_VOL_ID" | cut -d: -f1)
    OLD_DISK_NAME=$(echo "$OLD_VOL_ID" | cut -d: -f2)
    
    # Generate new disk name
    NEW_DISK_NAME=$(echo "$OLD_DISK_NAME" | sed "s/vm-$OLD_ID/vm-$NEW_ID/")
    NEW_VOL_ID="$STORAGE_NAME:$NEW_DISK_NAME"
    
    # Get the ZFS pool/path (e.g., rpool/data)
    ZFS_BASE_PATH=$(zfs list -H -o name | grep "$OLD_DISK_NAME" | xargs dirname)

    echo "  -> Renaming ZFS: $ZFS_BASE_PATH/$OLD_DISK_NAME to $NEW_DISK_NAME"
    run_cmd zfs rename "$ZFS_BASE_PATH/$OLD_DISK_NAME" "$ZFS_BASE_PATH/$NEW_DISK_NAME"
    
    # Reconstruct the Proxmox config string with the NEW volume name but OLD settings (ssd=1, etc)
    NEW_FULL_CONFIG=$(echo "$FULL_CONFIG" | sed "s|$OLD_VOL_ID|$NEW_VOL_ID|")
    
    echo "  -> Attaching to $NEW_ID: $NEW_FULL_CONFIG"
    run_cmd qm set "$NEW_ID" --"$BUS" "$NEW_FULL_CONFIG"
done <<< "$ATTACH_LIST"

# 6. Restore MAC Addresses
echo "Step 4: Syncing Network/MAC configuration..."
while read -r LINE; do
    [ -z "$LINE" ] && continue
    NET_ID=$(echo "$LINE" | cut -d: -f1)
    NET_VAL=$(echo "$LINE" | cut -d: -f2- | xargs)
    run_cmd qm set "$NEW_ID" --"$NET_ID" "$NET_VAL"
done <<< "$NET_CONFIGS"

# 7. Optional Cleanup
if [[ "$DESTROY" = true ]]; then
    echo "Step 5: Destroying old VM shell ($OLD_ID)..."
    run_cmd qm destroy "$OLD_ID"
fi

echo "--- Migration Complete ---"
