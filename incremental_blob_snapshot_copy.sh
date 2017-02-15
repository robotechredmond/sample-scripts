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

# Sign-in to Azure

azure login

# Select Azure Subscription

azure account set "subscription-name"

# Specify source Premium Storage Account Name & Get Key

sourceAccountRGName="kemrg02"
sourceAccountName="kemtestadstor"
sourceContainerName="vhds"
sourceAccountUri=$(azure storage account show --resource-group ${sourceAccountRGName} --json ${sourceAccountName} | jq -r '.primaryEndpoints.blob')
sourceAccountKey=$(azure storage account keys list --resource-group ${sourceAccountRGName} --json ${sourceAccountName} | jq -r '. [0].value')

# Specify backup Standard Storage Account enabled for RA-GRS & Get Key

backupAccountRGName="kemrg02"
backupAccountName="kemback01"
backupContainerName="vhd-backup"
backupAccountUri=$(azure storage account show --resource-group ${backupAccountRGName} --json ${backupAccountName} | jq -r '.primaryEndpoints.blob')
backupAccountKey=$(azure storage account keys list --resource-group ${backupAccountRGName} --json ${backupAccountName} | jq -r '. [0].value')

# Specify source page blob (VHD) with at least one snapshot

sourceBlobName=$(azure storage blob list --account-name ${sourceAccountName} --account-key ${sourceAccountKey} --container ${sourceContainerName} --json | jq -r '. [0].name')
backupBlobName="${sourceBlobName}"

# Create a new page blob (VHD) snapshot in source Premium Storage Account

while true
do
    azure storage blob snapshot --account-name ${sourceAccountName} --account-key ${sourceAccountKey} --container ${sourceContainerName} ${sourceBlobName} 
    if [[ $? == 0 ]]; then
        break
    else
        echo "Error creating source snapshot due to API limit ... waiting 10-minutes before retry ..."
        sleep 10m
    fi
done

# Construct URIs for most recent source snapshot and previous snapshot

sourceSnapshotCurrent=$(azure storage blob list --account-name ${sourceAccountName} --account-key ${sourceAccountKey} --container ${sourceContainerName} --json ${sourceBlobName} | jq -r '. [0].snapshot')
sourceSnapshotPrevious=$(azure storage blob list --account-name ${sourceAccountName} --account-key ${sourceAccountKey} --container ${sourceContainerName} --json ${sourceBlobName} | jq -r '. [1].snapshot')

sourceSnapshotCurrentUri="${sourceAccountUri}${sourceContainerName}/${sourceBlobName}?snapshot=${sourceSnapshotCurrent}"

if [[ $sourceSnapshotPrevious -eq "null" ]]; then
    echo "Only one snapshot currently exists - defaulting to Full Backup Copy"
    backupType="full"
else
    sourceSnapshotPreviousUri="${sourceAccountUri}${sourceContainerName}/${sourceBlobName}?snapshot=${sourceSnapshotPrevious}"
    backupType="incremental"
fi

# Create backup container if it doesn't exist 

containerList=$(azure storage container list --account-name ${backupAccountName} --account-key ${backupAccountKey} --json ${backupContainerName} | jq -r '. [0].name')

if [[ $containerList -eq "null" ]]; then
    while true
    do
        azure storage container create --account-name ${backupAccountName} --account-key ${backupAccountKey} ${backupContainerName}
        if [[ $? == 0 ]]; then
            break
        else
            Echo "Error creating container in backup storage account ... retrying ..."
            sleep 10s
        fi
    done
fi

# Perform Backup

if [[ "$backupType" == "full" ]]; then

    # copy latest snapshot to backup account

    while true
    do
        azure storage blob copy start --account-name ${sourceAccountName} --account-key ${sourceAccountKey} --source-container ${sourceContainerName} --source-blob ${sourceBlobName} --snapshot ${sourceSnapshotCurrent} --dest-account-name ${backupAccountName} --dest-account-key ${backupAccountKey} --dest-container ${backupContainerName} --dest-blob ${backupBlobName}
        if [[ $? == 0 ]]; then
            break
        else
            Echo "Error copying source blob to backup storage account ... retrying ..."
            sleep 10s
        fi
    done

    # wait for copy to complete

    copyStatus="pending"

    while [[ "${copyStatus}" != "success" ]]
    do
        copyStatus=$(azure storage blob copy show --account-name ${backupAccountName} --account-key ${backupAccountKey} --container ${backupContainerName} --blob ${backupBlobName} --json | jq -r '.copy.status')
        sleep 10s
    done

    # snapshot copy in backup account

    while true
    do
        azure storage blob snapshot --account-name ${backupAccountName} --account-key ${backupAccountKey} --container ${backupContainerName} ${backupBlobName} 
        if [[ $? == 0 ]]; then
            echo "Backup copy and snapshot completed for ${backupBlobName} to ${backupAccountUri}${backupContainerName}"
            break
        else
            echo "Error creating backup snapshot due to API limit ... waiting 10-minutes before retry ..."
            sleep 10m
        fi
    done

elif [[ "$backupType" == "incremental" ]]; then

fi