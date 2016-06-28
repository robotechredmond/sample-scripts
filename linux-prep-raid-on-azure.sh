#!/bin/bash

# Create backup copy of fstab
cp /etc/fstab /etc/fstab.original

# Enumerate data disks attached to VM 
# Leverages udev rules for Azure storage devices located at https://github.com/Azure/WALinuxAgent/blob/2.0/config/66-azure-storage.rules
attached=`basename -a $(find /sys/class/block -name 'sd[a-z]')`
reserved=`basename -a $(readlink -f /dev/disk/azure/root /dev/disk/azure/resource)`
datadisks=(${attached[@]/$reserved})

# Set value to be used for filesystem mount point folder
mp='data1'

# Set value to be used for filesystem label - max length 16 chars
fslabel=$(hostname)-$mp

# Set value for filesystem barriers - 0 if using Premium Storage w/ ReadOnly Caching or NoCache; 1 otherwise
b=0

# Set value for initial RAID command string used to span multiple data disks
RAID_CMD="mdadm --create /dev/md${#datadisks[@]} --level 0 --raid-devices ${#datadisks[@]} "

# Loop through each data disk, fdisk and add to RAID command string
i=0
for d in "${datadisks[@]}"; do
    disk="/dev/${d}"
    (echo n; echo p; echo 1; echo ; echo ; echo t; echo fd; echo p; echo w;) | fdisk ${disk}
    RAID_CMD+="${disk}1 "
    i=$[$i+1]
done

# Build RAID device
eval "$RAID_CMD"

# Format and label filesystem
mkfs.ext4 /dev/md${#datadisks[@]} -L ${fslabel}

# Set value of UUID for new filesystem
uuid=$(blkid -p /dev/md${#datadisks[@]} | grep -oP '[-a-z0-9]{36}')

# Create mount point folder
mkdir -p /media/${mp}

# Add new filesystem to working copy of fstab
echo "UUID=${uuid} /media/${mp} ext4 defaults,noatime,barrier=${b} 0 0" >> /etc/fstab

# Mount all unmounted filesystems
mount -a

# After initial provisioning, use these commands to obtain disk device or UUID of filesystem based on label
disk=$(blkid -L ${fslabel})
uuid=$(blkid | grep "LABEL=\"${fslabel}\"" | grep -oP '[-a-z0-9]{36}')