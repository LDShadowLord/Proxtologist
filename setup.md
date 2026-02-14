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

### Newt Installation
For Pangolin Users (Like Myself)
```
curl -fsSL https://static.pangolin.net/get-newt.sh | bash
```

### Meshcentral Installation
For Meshcentral Users... obviously.
```
Not sharing this link. Get the one from your Meshcentral app. It's specific to the group anyway.
```

## Native Commands
### Increase SSD Lifespan
Also ensure that all VM disks are set to discard=1,ssd=1 to improve thin-disk performance
```
zfs set autotrim=on rpool
```
