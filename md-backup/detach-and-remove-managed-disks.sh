#!/usr/bin/env bash

VM_NAMES=(vm0 vm1 vm2 vm3 vm4 vm5 vm6 vm7 vm8 vm9 vm10 vm11 vm12 vm13 vm14 vm15 vm16 vm17 vm18 vm19)
RESOURCE_GROUP="azcat-mongo-md-centos-dr"

#
#usage: az vm disk detach [-h] [--output {json,tsv,table,jsonc}] [--verbose]
#                         [--debug] [--query JMESPATH] --vm-name NAME
#                         --resource-group RESOURCE_GROUP_NAME --name DISK_NAME

#usage: az disk delete [-h] [--output {json,tsv,table,jsonc}] [--verbose]
#                      [--debug] [--query JMESPATH]
#                      [--resource-group RESOURCE_GROUP_NAME]
#                      [--ids RESOURCE_ID [RESOURCE_ID ...]] [--name NAME]

DATA_DISK_SUFFIX=datadisk2

echo "detaching disks ..."
for vm in "${VM_NAMES[@]}"
do
  {
  DATA_DISK="${vm}-${DATA_DISK_SUFFIX}";

  echo "detaching disk $DATA_DISK from vm $vm";
  time result=$(az vm disk detach --vm-name $vm -g $RESOURCE_GROUP --name $DATA_DISK);  
  echo "detach disk $DATA_DISK result:$result";
  } &
done

wait

echo "deleteing disks ..."
for vm in "${VM_NAMES[@]}"
do
  sleep 5
  {
  DATA_DISK="${vm}-${DATA_DISK_SUFFIX}";

  echo "deleting disk $DATA_DISK";
  time result=$(az disk delete --resource-group $RESOURCE_GROUP --name $DATA_DISK);  
  echo "delete disk $DATA_DISK result:$result";
  } &
done

wait

echo "done"
