#!/bin/bash

# Proxmox SM - Smart Migrate
# Written by Gemini
# Usage: sm -i <vmid> -t <target_node> [-s <storage>] [-n <network>]

RED='\033[0;31m'
NC='\033[0m'

usage() {
    echo "Usage: $0 -i <vmid> -t <target_node> [-s <target_storage>] [-n <migration_network>]"
    exit 1
}

while getopts "i:t:s:n:" opt; do
    case $opt in
        i) VMID="$OPTARG" ;;
        t) TARGET="$OPTARG" ;;
        s) STORAGE="$OPTARG" ;;
        n) NETWORK="$OPTARG" ;;
        *) usage ;;
    esac
done

[[ -z "$VMID" || -z "$TARGET" ]] && usage

if [ -f "/etc/pve/lxc/${VMID}.conf" ]; then
    TYPE="LXC"
    CMD=("pct" "migrate" "$VMID" "$TARGET")
    [[ -n "$STORAGE" ]] && CMD+=("--target-storage" "$STORAGE")
    [[ -n "$NETWORK" ]] && echo -e "${RED}Warning: pct does not support CLI migration networks. Ignoring -n.${NC}"
elif [ -f "/etc/pve/qemu-server/${VMID}.conf" ]; then
    TYPE="VM"
    CMD=("qm" "migrate" "$VMID" "$TARGET")
    [[ -n "$STORAGE" ]] && CMD+=("--targetstorage" "$STORAGE")
    [[ -n "$NETWORK" ]] && CMD+=("--migration_network" "$NETWORK")
else
    echo -e "${RED}Error: ID ${VMID} not found.${NC}"
    exit 1
fi

echo "Running: ${CMD[*]}"
"${CMD[@]}"