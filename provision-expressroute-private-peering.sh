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

# Sample Azure XPlat CLI commands for configuring ExpressRoute Private Peering with UltraPerformance VNET Gateways

# Authenticate to Azure via Azure AD credentials
azure login

# Set config mode to ARM
azure config mode arm

# Select Azure Subscription
azure account set "subscription-name"

# Create new Resource Group for ExpressRoute circuit
azure group create "expressroute-rg" --location "azure-region"

# List the ExpressRoute providers to determine provider name, peering location and circuit bandwidth
azure network express-route provider list

# Provision ExpressRoute circuit
azure network express-route circuit create "expressroute-circuit" --resource-group "expressroute-rg" --location "azure-region" --service-provider-name "expressroute-provider" --peering-location "peering-location" --bandwidth-in-mbps <bandwidth> --sku-family "Metereddata" --sku-tier "Standard"

# Share "Service Key" value with provider for provisioning circuit ... wait for confirmation from Service Provider before continuing

# Get properties of ExpressRoute circuit - when "Provisioning state" equals "Provisioned" move forward with next step
azure network express-route circuit show "expressroute-circuit" --resource-group "expressroute-rg"

# Configure Azure Private Peering for ExpressRoute circuit
azure network express-route peering create "azure-private-peering" --resource-group "expressroute-rg" --circuit-name "expressroute-circuit" --type "AzurePrivatePeering" --peer-asn <peer-asn-number> --primary-address-prefix "x.x.x.x/x" --secondary-address-prefix "x.x.x.x/x" --vlan-id <vlan_id> --shared-key "optional-MD5-hash-shared-key"

# Get properties of Azure Private Peering
azure network express-route peering "azure-private-peering" --resource-group "expressroute-rg" --circuit-name "expressroute-circuit"

# Provision UltraPerformance ExpressRoute VNET Gateway
azure group deployment create "gw-deployment-1" --resource-group "vnet-resource-group" --template-uri "https://raw.githubusercontent.com/robotechredmond/sample-templates/master/azure-expressroute-gw-ultraperf.json"

# Link ExpressRoute circuit to VNET Gateway in same subscription
azure network vpn-connection create "vpn-connection-1" --resource-group "vnet-resource-group" --location "azure-region" --type "ExpressRoute" --vnet-gateway1 "vnet-gateway" --vnet-gateway1-group "vnet-resource-group" --peer-name "azure-private-peering" --peer-group "expressroute-rg"

# Link ExpressRoute circuit to VNET Gateway in different subscription
azure network express-route authorization create "expressroute-auth-1" --resource-group "expressroute-rg" --circuit-name "expressroute-circuit" --key "key-value"
azure network express-route authorization show "expressroute-auth-1" --resource-group "expressroute-rg" --circuit-name "expressroute-circuit" 
azure network vpn-connection create "vpn-connection-1" --resource-group "vnet-resource-group" --location "azure-region" --type "ExpressRoute" --vnet-gateway1 "vnet-gateway" --vnet-gateway1-group "vnet-resource-group" --peer-name "azure-private-peering" --peer-group "expressroute-rg" --authorization-key "auth-key"