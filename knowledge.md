# Filesystem Shenanigans
## I can't migrate/replicate because my two file systems are named differently
For replication, try the pve-zsync command.
```
apt install pve-zsync
pve-zsync sync --source 200 --dest 192.168.1.202:rpool/data --verbose --maxsnap 1 --name LuggageTN_Replication2 [--skip] # Sets the replication up
pve-zsync list																											 # See the configured Replications
pve-zsync destroy --source 200 --name LuggageTN_Replication																 # Destroy a replication job
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

## You want to blacklist a PCI Device WITHOUT blacklisting all drivers
This is probably for SATA Reasons.
```
lspci -nn -k
search for your target device(s) and look for a number like [1028:1f4b] and the driver(s) in use
echo "softdep megaraid_sas pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "options vfio-pci ids=1028:1f4b" >> /etc/modprobe.d/vfio.conf
echo "options vfio-pci ids=8086:0953" >> /etc/modprobe.d/vfio.conf
update-initramfs -u -k all
```

## MeshCentral
```
meshcmd amtconfig --user admin --pass "your-password" --url "wss://meshcentral.domain/apf.ashx" --id 'use-single-quotes-find-me-in-the-install-path' --dnssuffix "domain"
```

# NVMe Shenanigans
## Machine randomly fences itself, locks up, or throws NVMe controller timeouts (APST Bug)
This happens on Samsung PM9A1 / 980 Pro (and several other consumer/OEM NVMe drives) under Linux. The drive aggressively drops into deep power-saving sleep (Power State 4) after just 100ms of idle. When sudden burst writes hit it, the controller crashes (`Device not ready; aborting reset, CSTS=0x1`), wedges ZFS in D-state, and causes the Proxmox HA watchdog to fence the node.

Fix it by disabling Autonomous Power State Transitions (APST):
```
nano /etc/kernel/cmdline
# append to the existing line:
nvme_core.default_ps_max_latency_us=0

proxmox-boot-tool refresh
update-initramfs -u -k all
reboot
```

Check if APST is disabled after reboot:
```
nvme get-feature /dev/nvme0 -f 0x0c -H
# Should show "Autonomous Power State Transition Enable (APSTE): Disabled" (or Current value: 0x0)
```

