#!/bin/sh

#-------------------------------------------------------------------------
# Copyright (c) Microsoft.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#--------------------------------------------------------------------------

# set bash script options

set -o nounset

# determine source OS distro release; provision new Azure VMs with same OS distro release

cat /etc/issue
uname –-all

# install same versions of packages on source and target OS
# apt-get update updates the list of available packages and their versions, but it does not install or upgrade any packages.
# apt-get upgrade actually installs newer versions of the packages you have. After updating the lists, the package manager knows about available updates for the software you have installed. This is why you first want to update.

sudo apt-get update
sudo apt-get upgrade

# install rsync and screen packages

sudo apt-get install rsync
sudo apt-get install screen

# add common user on both source and target VMs

sudo groupadd -g 500 AzureAdmin
sudo useradd -u 500 -g 500 -m -s /bin/bash AzureAdmin
sudo passwd AzureAdmin 

# start a screen session

sudo screen -S AzureMigration

# define list of files to exclude - OS files that contain state of the VM, rather than application state or data
# this list of files can vary based on OS distro release

EXCLUDEFILE=/tmp/exclude.file
EXCLUDELIST='/boot /etc/fstab /etc/hostname /etc/issue /etc/hosts /etc/sudoers /etc/networks /etc/network/* /etc/resolv.conf /etc/ssh/* /etc/sysctl.conf /etc/mtab /etc/udev/rules.d/* /lock /net /tmp' 
EXCLUDEPATH=$(echo $EXCLUDELIST | sed 's/\ /\\n/g') 
echo -e $EXCLUDEPATH > $EXCLUDEFILE 
find / -name '*cloud-init*' >> $EXCLUDEFILE 
find / -name '*cloud-config*' >> $EXCLUDEFILE 
find / -name '*cloud-final*' >> $EXCLUDEFILE

# stop services during migration to prevent changes

sudo service apache2 stop

# rsync files from source to target VM

sudo -s
TARGETVM="target_vm_public_ip_address"
rsync --rsh="ssh" --exclude-from="$EXCLUDEFILE" --rsync-path="sudo rsync" --verbose --progress -rlpEAXogDtSzhPx / AzureAdmin@$TARGETVM:/ 
rsync --rsh="ssh" --exclude-from="$EXCLUDEFILE" --rsync-path="sudo rsync" --verbose --progress -crlpEAXogDtSzhPx / AzureAdmin@$TARGETVM:/

# connect to VM and restart

ssh AzureAdmin@$TARGETVM 
sudo shutdown -r now

# confirm that target VM starts correctly
