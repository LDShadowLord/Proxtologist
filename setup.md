# Initial Configuration
This is purely what I do to my own machines, and is neither a guide nor a recommendation.

## External Scripts
### Community Scripts
```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
```

### TrueNAS PVE Integration
Use the APT Install Solution to make it cleaner and keep it up to date.
```sh
bash <(curl -sSL https://raw.githubusercontent.com/truenas/truenas-proxmox-plugin/refs/heads/main/install.sh)
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
ExecStart=/usr/local/bin/newt --id dhgdg --secret dgdgdg --endpoint https://dgdgdgdg
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
zpool set autotrim=on rpool
```

### Do native ZFS Snapshots
This does snapshots of the Proxmox Host (No VM's included)
You can then replicate these to TrueNAS or another system of your choice for backup purpoises.
```
apt install zfsnap
crontab -e 
58 */6 * * * /usr/sbin/zfSnap -d -a 14d -r rpool/ROOT
```

### Add ZSync for native replication via CLI
```
apt install pve-zsync
```

#### To add to TrueNAS you gotta do this:
Information stolen from: https://wiki.familybrown.org/pve-replication
If this is the **first** machine in a cluster you're configuring, then you need to copy a freshly generated SSH Keypair Public Key and do a
```
do this on the PVE host
echo "public key here" >> /root/.ssh/authorized_keys
```

### Adding back to the cluster
So you nuked your install and want to rejoin the cluster.
```
(on another machine in the cluster)
pvecm delnode <hostname>
rm -rf /etc/pve/nodes/<hostname>
(rejoin to cluster here)
(on the newly added machine)
pvecm updatecerts
```