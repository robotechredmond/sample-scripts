#!/bin/bash

# Sample demonstration script to provision new VM in specific Azure Fault Domain - No warranties expressed or implied

# set bash script options
set -o nounset

# Sign-in to Azure
azure login

# Switch to ARM configuration mode
azure config mode arm

# Select Azure Subscription
subscriptionIds=$(azure account list --json | jq -r '.[] | .id')
echo Select Azure Subscription:
select subscriptionId in $subscriptionIds; do
    azure account set $subscriptionId
    if [[ $? == 0 ]]; then
        break
    fi
done

# Select Azure Region
locationNames=$(azure location list --json | jq -r '.[] | .name')
echo Select Azure Region:
select locationName in $locationNames; do
    if [[ $? == 0 ]]; then
        break
    fi
done

# Select Azure Resource Group
rgNames=$(azure group list --json | jq -r '.[] | .name')
echo Select Azure Resource Group:
select rgName in $rgNames; do
    if [[ $? == 0 ]]; then
        break
    fi
done

# Select Azure Availability Set
asNames=$(azure availset list $rgName --json | jq -r '.[] | .name')
echo Select Azure Availability Set:
select asName in $asNames; do
    fdCount=$(azure availset show $rgName $asName --json | jq -r '.platformFaultDomainCount')
    if [[ $? == 0 ]]; then
        break
    fi
done

# Select Fault Domain
fdList=$(seq 0 1 $((fdCount-1)))
echo Select Azure Fault Domain:
select fd in $fdList; do
    if [[ $? == 0 ]]; then
        break
    fi
done

# Select Azure Virtual Network
vnetNames=$(azure network vnet list $rgName --json | jq -r '.[] | .name')
echo Select Azure Virtual Network:
select vnetName in $vnetNames; do
    if [[ $? == 0 ]]; then
        break
    fi
done

# Select Azure VNET Subnet
subnetNames=$(azure network vnet subnet list $rgName $vnetName --json | jq -r '.[] | .name')
echo Select Azure Virtual Network Subnet:
select subnetName in $subnetNames; do
    subnetId=$(azure network vnet subnet show $rgName $vnetName $subnetName --json | jq -r '.id')
    if [[ $? == 0 ]]; then
        break
    fi
done

# Enter VM Name Prefix
read -p "Enter VM Name Prefix: " vmNamePrefix

# Enter VM Admin username
read -p "Enter VM Admin username: " vmUser

# Enter VM Admin password
read -s -p "Enter VM Admin password: " vmPwd

# Set options that are common to all VMs being provisioned
vmImage='OpenLogic:CentOS:7.2:latest'
vmSize='Standard_D1'
vmOs='Linux'
vmStorageSku='LRS'
vmStorageKind='Storage'

# Provision Virtual Machines until new VM is in desired FD

vmNum=0
vmNames=()
vmNameInFd=""

while true
do 
    ((vmNum++))
    vmName="${vmNamePrefix}${vmNum}"
    vmStorageName="${vmName}sa"
    vmNicName="${vmName}-nic-0"
    vmNames[$vmNum]=""
    azure storage account create --resource-group ${rgName} ${vmStorageName} --location ${locationName} --sku-name ${vmStorageSku} --kind ${vmStorageKind}
    azure network nic create --resource-group ${rgName} --name ${vmNicName} --subnet-id ${subnetId} --location ${locationName}
    azure vm create --resource-group ${rgName} --name ${vmName} --location ${locationName} --storage-account-name ${vmStorageName} --os-type ${vmOs} --image-urn ${vmImage} --admin-username ${vmUser} --admin-password ${vmPwd} --vm-size ${vmSize} --nic-name ${vmNicName} --availset-name ${asName}
    if [[ $? == 0 ]]; then
        vmNames[$vmNum]=${vmName}
        vmFd=$(azure vm get-instance-view ${rgName} ${vmName} --json | jq -r '.instanceView.platformFaultDomain')
        if [[ $vmFd == $fd ]]; then
            vmNameInFd=${vmName}
            break
        fi
    fi
done

# Cleanup resources for new VMs that are not in desired FD

while [ $vmNum -gt 1 ]
do
    ((vmNum--))
    vmName="${vmNames[$vmNum]}"
    if [[ ${vmName} ]]; then
        vmStorageName="${vmName}sa"
        vmNicName="${vmName}-nic-0"
        while true
        do
            azure vm delete --resource-group ${rgName} --name ${vmName} --quiet
            if [[ $? == 0 ]]; then
                break
            fi
        done
        while true
        do
            azure storage account delete --resource-group ${rgName} ${vmStorageName} --quiet
            if [[ $? == 0 ]]; then
                break
            fi
        done
        while true
        do
            azure network nic delete --resource-group ${rgName} --name ${vmNicName} --quiet
            if [[ $? == 0 ]]; then
                break
            fi
        done
    fi
done
