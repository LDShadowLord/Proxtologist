# Proxtologist
## For when Proxmox is a pain in the ass

## Scripts
Smart Migrate - SM
	Dynamically works out if an ID is a VM or an LXC, and uses the appropriate command and options to migrate.
	This must be run on the machine you are migrating FROM.
	Usage: $0 -i <vmid> -t <target_node> [-s <target_storage>] [-n <migration_network>]
	Target Storage must be what it is called in Proxmox, not a directory.
	Migration Network is not supported in LXC migrations.

Change VM ID
	Change the ID of a VM without cloning data, by detaching disks and attaching them to a cloned shell.
	Only works for ZFS based systems. Probably doesn't work with Snapshots, not tested.
	By default, does no action.
	Usage: $0 <OLD_ID> <NEW_ID> <TARGET_STORAGE> [--commit] [--destroy]
	Target Storage must be what it is called in Proxmox, not a directory.
	To create a new VM, you must run --commit to perform the action.
	--Destroy can be provided to delete the original VM once complete.

Start VMs
	Waits for an iSCSI target to become available, then starts VMs one-by-one if they have the "autostart" tag.
	Must be run on each machine in the cluster.
	Designed to be run from an autostart service script (provided).
	Modify the variables in the script to match your own iSCSI/tag environment.