# Initial Configuration
This is purely what I do to my own machines, and is neither a guide nor a recommendation.

## External Scripts
### Community Scripts
```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
```

### TrueNAS PVE Integration
Will be replaced by the upcoming Official TrueNAS solution.
```sh
bash <(curl -sSL https://raw.githubusercontent.com/WarlockSyno/truenasplugin/alpha/install.sh)
```

## Native Commands
### Increase SSD Lifespan
Also ensure that all disks are set to discard=1,ssd=1 to improve thin-disk performance
```
zfs set autotrim=on rpool
```
