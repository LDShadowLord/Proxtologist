# Filesystem Shenanigans
## I can't migrate/replicate because my two file systems are named differently
For replication, try the pve-zfsync command.
```
pve-zsync create --source 397 --dest 192.168.1.202:rpool/data --verbose --maxsnap 1 --name OPNSense_Replication [--skip] # Sets the replication up
pve-zsync list																											 # See the configured Replications
pve-zsync destroy --source 397 --name OPNSense_Replication																 # Destroy a replication job
nano /etc/cron.d/pve-zsync																								 # You can adjust the timings. Default is every 15 minutes.
```

# PCIe Shenanigans
## It keeps saying 'failed to setup container for group **: Failed to set group container: Invalid argument'
Assuming you're running ZFS (You should be):
```
nano /etc/kernel/cmdline
replace existing line with:
root=ZFS=rpool/ROOT/pve-1 boot=zfs quiet intel_iommu=on,relax_rmrr vfio_iommu_type1.allow_unsafe_interrupts=1 iommu=pt intremap=no_x2apic_optout

proxmox-boot-tool refresh
update-initramfs -u -k all
```