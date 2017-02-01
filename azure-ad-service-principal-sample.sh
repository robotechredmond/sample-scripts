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

# set bash script options

set -o nounset

# Initial Setup from Admin VM - Generate certificates, create Azure AD Service Principal, assign RBAC permissions, store secrets

# Generate certificate and create certificate files for Azure AD Service Principal - one per Target VM
# Copy certificate files to standard secured folders for certificates on target VM
# ie., /etc/pki/tls/certs and /etc/pki/tls/private for CentOS
#      /etc/ssl/certs and /etc/ssl/private for Ubuntu

cn="vmname.domain.com"
openssl req -x509 -days 3650 -newkey rsa:2048 -out cert.pem -nodes -subj "/CN=${cn}"
publicKey=$(tail -n +2 cert.pem | head -n -1)
publicKey=$(echo $pubkey|sed 's/ //g')
spCertFile="${cn}-spcert.pem"
cat privkey.pem cert.pem > ${spCertFile}

# Set Azure XPlat CLI Mode to Azure Resource Manager (ARM)

azure config mode arm

# Login as Admin (interactively) to create Azure AD Service Principal

azure login

# Select Azure Subscription

subscriptionName="subscription-name"
azure account set "${subscriptionName}"
subscriptionId=$(azure account show --json | jq -r '. [].id')
tenantId=$(azure account show --json | jq -r '. [].tenantId')

# Create Azure Service Principal - one per target VM

spnId=$(azure ad sp create -n ${cn} --cert-value ${publicKey} --json | jq -r '.objectId')
spnName="http://${cn}"

# Create Azure Key Vault (if not yet provisioned)

rgName="key-vault-resource-group"
location="azure-region-name"
kvName="key-vault-name"
kvSku="Standard" # Standard or Premium
azure provider register Microsoft.KeyVault # only need to do this once per subscription
azure group create ${rgName} ${location}
azure keyvault create --vault-name ${kvName} --resource-group ${rgName} --location ${location} --sku ${kvSku}

# Assign get access to Azure Key Vault for Azure AD Service Principal(s)

azure keyvault set-policy --vault-name ${kvName} --spn ${spnName} --perms-to-secrets '["get"]'

# Save secret to Azure Key Vault 

rgName="storage-account-resource-group"
storageAccountName="storage-account-name"
storageAccountKey=$(azure storage account keys list --resource-group ${rgName} --json ${storageAccountName} | jq -r '. [0].value')
azure keyvault secret set --vault-name ${kvName} --secret-name ${storageAccountName} --value ${storageAccountKey}

# (optional) Assign other Azure RBAC Roles to Azure AD Service Principal(s) for each Target VM

azure role assignment create --spn ${spnName} -o Reader -c /subscriptions/${subscriptionId}/

# Target VM - Get secret for accessing a resource

# Login to Azure using Azure AD Service Principal and Certificate

cn=$(hostname -f)
spnName="http://${cn}"
tenantId="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
spCertFile="${cn}-spcert.pem"
spCertThumbprint=$(openssl x509 -in "${spCertFile}" -fingerprint -noout | sed 's/SHA1 Fingerprint=//g'  | sed 's/://g')
azure login --service-principal --tenant ${tenantId} -u ${spnName} --certificate-file ${spCertFile} --thumbprint ${spCertThumbprint}

# Get secret from Azure Key Vault

kvName="key-vault-name"
storageAccountName="storage-account-name"
storageAccountKey=$(azure keyvault secret show --vault-name ${kvName} --secret-name ${storageAccountName} --json | jq -r '.value')

# Use retrieved secret to perform Azure Storage Blob API operations ...

azure storage blob list --account-name ${storageAccountName} --account-key ${storageAccountKey} --container "vhds"
