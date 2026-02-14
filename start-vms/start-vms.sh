#!/bin/bash
#
# This script waits for the iSCSI target to be ready, then finds
# and starts all local VMs/CTs tagged with a specific tag.
#
# REQUIRES: apt install jq
#

# --- Configuration ---
# The tag to look for on VMs/CTs
AUTOSTART_TAG="autostart"

# The command to poll
POLL_COMMAND="/usr/sbin/iscsiadm -m discovery -t sendtargets -p 192.168.1.200"

# The exact output we are waiting for
EXPECTED_OUTPUT="192.168.1.200:3260,1 iqn.2005-10.org.freenas.ctl:ankh"

# --- Delays (in seconds) ---
PRE_POLL_DELAY=30       # Wait after service start before polling
POST_POLL_DELAY=30      # Wait after iSCSI is ready before starting
POLL_INTERVAL=10        # Time between failed poll attempts
START_DELAY=10          # Time between starting each VM/CT

# --- Paths to binaries ---
LOGGER="/usr/bin/logger"
PVESH="/usr/bin/pvesh"
JQ="/usr/bin/jq"
QM="/usr/sbin/qm"
PCT="/usr/sbin/pct"

# --- Script Logic ---

$LOGGER "start-vms.sh: Service initiated."

# 0. Prerequisite check
if ! command -v $JQ &> /dev/null; then
    $LOGGER "start-vms.sh: FATAL ERROR: 'jq' is not installed. Please run 'apt install jq'. Exiting."
    exit 1
fi

# 1. Initial 30-second wait
$LOGGER "start-vms.sh: Waiting $PRE_POLL_DELAY seconds before polling iSCSI target..."
sleep $PRE_POLL_DELAY

# 2. Polling loop
$LOGGER "start-vms.sh: Starting to poll for iSCSI target..."
while true; do
    # Capture both stdout and stderr
    current_output=$($POLL_COMMAND 2>&1)

    if [ "$current_output" == "$EXPECTED_OUTPUT" ]; then
        $LOGGER "start-vms.sh: SUCCESS! iSCSI target is ready."
        break
    else
        $LOGGER "start-vms.sh: iSCSI not ready. (Got: '$current_output'). Retrying in $POLL_INTERVAL seconds..."
        sleep $POLL_INTERVAL
    fi
done

# 3. Post-success 30-second wait
$LOGGER "start-vms.sh: Waiting $POST_POLL_DELAY seconds before starting resources."
sleep $POST_POLL_DELAY

# 4. Get local node name and resources
LOCAL_NODE=$(hostname -s)
$LOGGER "start-vms.sh: Local node name is '$LOCAL_NODE'. Fetching cluster resources..."

CLUSTER_RESOURCES=$($PVESH get /cluster/resources --type vm --output-format json)
if [ -z "$CLUSTER_RESOURCES" ]; then
    $LOGGER "start-vms.sh: FATAL ERROR: Could not fetch cluster resources from API. Exiting."
    exit 1
fi

# 5. Find and Start Tagged VMs
$LOGGER "start-vms.sh: Searching for local VMs with tag '$AUTOSTART_TAG'..."

# Get a list of VMIDs to start
# This filter:
# 1. Defaults .tags to "" if null (// "")
# 2. Splits the tag string "tag1;tag2" into an array ["tag1", "tag2"]
# 3. Checks if *any* element in the array exactly matches the $tag
VM_IDS_TO_START=( $(echo "$CLUSTER_RESOURCES" | $JQ -r \
    --arg node "$LOCAL_NODE" \
    --arg tag "$AUTOSTART_TAG" \
    '.[] | select(.type == "qemu" and .node == $node and ((.tags // "") | split(";") | any(. == $tag))) | .vmid') )

for vmid in "${VM_IDS_TO_START[@]}"; do
    $LOGGER "start-vms.sh: Starting VM $vmid..."
    $QM start $vmid
    
    $LOGGER "start-vms.sh: Waiting $START_DELAY seconds..."
    sleep $START_DELAY
done

# 6. Find and Start Tagged Containers
$LOGGER "start-vms.sh: Searching for local CTs with tag '$AUTOSTART_TAG'..."

# Get a list of CTIDs to start
CT_IDS_TO_START=( $(echo "$CLUSTER_RESOURCES" | $JQ -r \
    --arg node "$LOCAL_NODE" \
    --arg tag "$AUTOSTART_TAG" \
    '.[] | select(.type == "lxc" and .node == $node and ((.tags // "") | split(";") | any(. == $tag))) | .vmid') )

for ctid in "${CT_IDS_TO_START[@]}"; do
    $LOGGER "start-vms.sh: Starting CT $ctid..."
    $PCT start $ctid
    
    $LOGGER "start-vms.sh: Waiting $START_DELAY seconds..."
    sleep $START_DELAY
done

$LOGGER "start-vms.sh: All tagged local resources started. Script finished."

