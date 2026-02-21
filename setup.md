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
cat << 'EOF' > /etc/systemd/system/newt.service 
[Unit]
Description=Newt
After=network.target

[Service]
ExecStart=/usr/local/bin/newt --id <yourid> --secret <your_secret> --endpoint <your_endpoint_>
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl enable newt.service --now
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

### Do native ZFS Snapshots
```
apt install zfsnap
crontab -e 
58 */6 * * * /usr/sbin/zfSnap -d -a 14d -r rpool/ROOT
```
