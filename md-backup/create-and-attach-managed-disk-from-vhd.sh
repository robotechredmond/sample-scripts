#!/usr/bin/env bash

VM_NAMES=(vm0 vm1 vm2 vm3 vm4 vm5 vm6 vm7 vm8 vm9 vm10 vm11 vm12 vm13 vm14 vm15 vm16 vm17 vm18 vm19)

RESOURCE_GROUP="azcat-mongo-md-centos-dr"
VHD_URL="https://drmongomddrsnapshots.blob.core.windows.net/mongo-cluster-1/vm2-datadisk1_2017.05.03-18.31.51_Premium_LRS.vhd"

DATA_DISK_SUFFIX=datadisk2

#
# To create multiple managed disks (concurrently), the source must be a snapshot
#
SNAPSHOT_NAME=${DATA_DISK_SUFFIX}_snapshot
echo "create snapshot from VHD"
time snapshot_result=$(az snapshot create -g $RESOURCE_GROUP -n $SNAPSHOT_NAME --source $VHD_URL)
echo "create shapshot result:$snapshot_result"

#
# Now create and attach managed disks (concurrently) from the snapshot
#
echo "creating disks"
for vm in "${VM_NAMES[@]}"
do
  DATA_DISK="${vm}-${DATA_DISK_SUFFIX}"
  {
  echo "${vm}: creating $DATA_DISK using snapshot $SNAPSHOT_NAME";
  time result=$(az disk create -g $RESOURCE_GROUP -n $DATA_DISK --source $SNAPSHOT_NAME);
  echo "${vm}: create disk result\n:$result";
  echo "${vm}: attaching disk $DATA_DISK";
  time result=$(az vm disk attach --vm-name $vm -g $RESOURCE_GROUP --disk $DATA_DISK);
  echo "${vm}: attaching disk $DATA_DISK to vm $vm result:$result";
  } &
done
wait
echo "done"
