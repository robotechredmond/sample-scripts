#!/bin/bash

# Login with Azure AD credentials

az login

# Register ASG feature (one time only)

az feature register \
  --name AllowApplicationSecurityGroups \
  --namespace Microsoft.Network

az provider register \
  --namespace Microsoft.Network

az feature show \
  --name AllowApplicationSecurityGroups \
  --namespace Microsoft.Network

# Define resource name values

resourceGroup="asg01-rg"
location="westcentralus"
nsgName="nsg01"
vnetName="vnet01"
nicName="nic01"
vmName="vm01"
adminUser="azureadmin"

# Create a new Resource Group

az group create \
  --name $resourceGroup \
  --location $location

# Create Application Security Groups

az network asg create \
  --resource-group $resourceGroup \
  --name WebServers \
  --location $location  

az network asg create \
  --resource-group $resourceGroup \
  --name LinuxServers \
  --location $location

az network asg create \
  --resource-group $resourceGroup \
  --name WinServers \
  --location $location

# Create a Network Security Group

az network nsg create \
  --resource-group $resourceGroup \
  --name $nsgName \
  --location $location

# Create NSG Rules

az network nsg rule create \
  --resource-group $resourceGroup \
  --nsg-name $nsgName \
  --name WebRule \
  --priority 200 \
  --access "Allow" \
  --direction "inbound" \
  --source-address-prefixes "Internet" \
  --destination-asgs "WebServers" \
  --destination-port-ranges 80 \
  --protocol "TCP"

az network nsg rule create \
  --resource-group $resourceGroup \
  --nsg-name $nsgName \
  --name LinuxRule \
  --priority 300 \
  --access "Allow" \
  --direction "inbound" \
  --source-address-prefixes "Internet" \
  --destination-asgs "LinuxServers" \
  --destination-port-ranges 22 \
  --protocol "TCP"  

az network nsg rule create \
  --resource-group $resourceGroup \
  --nsg-name $nsgName \
  --name WinRule \
  --priority 400 \
  --access "Allow" \
  --direction "inbound" \
  --source-address-prefixes "Internet" \
  --destination-asgs "WinServers" \
  --destination-port-ranges 3389 \
  --protocol "TCP"

# Create new Azure VNET

az network vnet create \
  --name $vnetName \
  --resource-group $resourceGroup \
  --subnet-name default \
  --address-prefix 10.0.0.0/16 \
  --location $location 

# Assign NSG to subnet within new VNET

az network vnet subnet update \
  --name default \
  --resource-group $resourceGroup \
  --vnet-name $vnetName \
  --network-security-group $nsgName

# Create new NIC resource and assign to Application Security Groups - up to 10 ASGs per ipConfig

az network nic create \
  --resource-group $resourceGroup \
  --name $nicName \
  --vnet-name $vnetName \
  --subnet default \
  --location $location \
  --application-security-groups "WebServers" "WinServers"

# Create new VM

az vm create \
  --resource-group $resourceGroup \
  --name $vmName \
  --location $location \
  --nics $nicName \
  --image win2016datacenter \
  --admin-username $adminUser

# Clean-up - delete resource group and contained resources

# az group delete \
#  --name $resourceGroup \
#  --yes
