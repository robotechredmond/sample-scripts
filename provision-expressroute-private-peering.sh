#!/bin/bash

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

# Sample step-by-step Azure CLI 2.0 commands for configuring ExpressRoute Private Peering with UltraPerformance VNET Gateways

# Install Azure CLI 2.0
curl -L https://aka.ms/InstallAzureCli | bash

# Restart shell after initial installation of CLI 2.0
exec -l $SHELL

# Authenticate to Azure via Azure AD credentials
az login

# Select Azure Subscription
az account set --subscription "subscription-name-or-id"

# Create new Resource Group for ExpressRoute circuit
az group create --name "expressroute-rg" --location "azure-region"

# List the ExpressRoute providers to determine provider name, peering location and circuit bandwidth
az network express-route list-service-providers 

# Provision ExpressRoute circuit
az network express-route create --name "expressroute-circuit" --resource-group "expressroute-rg" --location "azure-region" --provider "expressroute-provider" --peering-location "peering-location" --bandwidth <bandwidth-in-mbps> --sku-family "MeteredData" --sku-tier "Standard"

# Get properties of the new ExpressRoute circuit
# Share "serviceKey" value with provider for provisioning circuit
# When "serviceProviderProvisioningState" equals "Provisioned" move forward with next step
az network express-route show --name "expressroute-circuit" --resource-group "expressroute-rg"

# Configure Azure Private Peering for ExpressRoute circuit - once per ExpressRoute circuit
az network express-route peering create --peering-type "AzurePrivatePeering" --circuit-name "expressroute-circuit" --resource-group "expressroute-rg" --peer-asn <peer-asn-number> --primary-peer-subnet "x.x.x.x/30" --secondary-peer-subnet "x.x.x.x/30" --vlan-id <vlan_id> --shared-key "optional-key-for-generating-MD5-hash"

# Get properties of Azure Private Peering - once per ExpressRoute circuit
az network express-route peering show --name "AzurePrivatePeering" --circuit-name "expressroute-circuit" --resource-group "expressroute-rg"

# Create GatewaySubnet with /27 CIDR block on each VNET - once per VNET
az network vnet subnet create --name "GatewaySubnet" --vnet-name "vnet-name" --resource-group "vnet-resource-group" --address-prefix "x.x.x.x/27"

# Provision UltraPerformance ExpressRoute VNET Gateway on each VNET - once per VNET
az network public-ip create --name "vnet-gateway-1-ip" --resource-group "vnet-resource-group" --location "azure-region"
az network vnet-gateway create --name "vnet-gateway-1" --resource-group "vnet-resource-group" --location "azure-region" --public-ip-address "vnet-gateway-1-ip" --vnet "vnet-name" --gateway-type "ExpressRoute" --sku "UltraPerformance"

# Link ExpressRoute circuit to VNET Gateway in same subscription - once per ExpressRoute circuit-to-VNET combination
az network vpn-connection create --name "vpn-connection-1" --resource-group "vnet-resource-group" --location "azure-region" --vnet-gateway1 "vnet-gateway" --express-route-circuit2 "expressroute-circuit-resource-id"

# Link ExpressRoute circuit to VNET Gateway in different subscription - once per ExpressRoute circuit-to-VNET combination
az network express-route auth create --name "expressroute-auth-1" --circuit-name "expressroute-circuit" --resource-group "expressroute-rg"
az network express-route auth show --name "expressroute-auth-1" --resource-group "expressroute-rg" --circuit-name "expressroute-circuit" 
az account set --subscription "vnet-subscription-name-or-id"
az network vpn-connection create --name "vpn-connection-1" --resource-group "vnet-resource-group" --location "azure-region" --vnet-gateway1 "vnet-gateway" --express-route-circuit2 "expressroute-circuit-resource-id" --authorization-key "authorization-key"