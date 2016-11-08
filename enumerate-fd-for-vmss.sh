#!/bin/bash

# List Fault Domains for each Azure Virtual Machine Scale Set VM instance

rgName='resource-group-name' 
vmssName='vm-scale-set-name'
subscriptionName='subscription-name'

azure login

azure account set "$subscriptionName"

vmssvmlist=$(azure vmssvm list $rgName $vmssName --json | jq -r '. [].instanceId')

for vmssvmid in $vmssvmlist
do
    echo -n "$vmssvmid: "
    azure vmssvm get-instance-view $rgName $vmssName $vmssvmid --json | jq -r '.platformFaultDomain''
done
