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

# sign-in to azure

azure login

# select azure subscription

azure account set "subscription-name"

# specify source premium storage account name & get key

sourceAccountRGName="resource-group"
sourceAccountName="source-storage-account"
sourceContainerName="vhds"
sourceAccountUri=$(azure storage account show --resource-group ${sourceAccountRGName} --json ${sourceAccountName} | jq -r '.primaryEndpoints.blob')
sourceAccountKey=$(azure storage account keys list --resource-group ${sourceAccountRGName} --json ${sourceAccountName} | jq -r '. [0].value')

# specify backup standard storage account enabled for RA-GRS & get key

backupAccountRGName="resource-group"
backupAccountName="backup-storage-account"
backupContainerName="vhd-backup"
backupAccountUri=$(azure storage account show --resource-group ${backupAccountRGName} --json ${backupAccountName} | jq -r '.primaryEndpoints.blob')
backupAccountKey=$(azure storage account keys list --resource-group ${backupAccountRGName} --json ${backupAccountName} | jq -r '. [0].value')

# specify source page blob (VHD) with at least one snapshot

sourceBlobName=$(azure storage blob list --account-name ${sourceAccountName} --account-key ${sourceAccountKey} --container ${sourceContainerName} --json | jq -r '. [0].name')
backupBlobName="${sourceBlobName}"

# create a new page blob (VHD) snapshot in source premium storage account

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

# construct URIs for most recent source snapshot and previous snapshot

sourceSnapshotCurrent=$(azure storage blob list --account-name ${sourceAccountName} --account-key ${sourceAccountKey} --container ${sourceContainerName} ${sourceBlobName} --json | jq -r 'sort_by(.snapshot) | reverse | . [0].snapshot')
sourceSnapshotPrevious=$(azure storage blob list --account-name ${sourceAccountName} --account-key ${sourceAccountKey} --container ${sourceContainerName} ${sourceBlobName} --json | jq -r 'sort_by(.snapshot) | reverse | . [1].snapshot')

if [[ "$sourceSnapshotPrevious" == "null" ]]; then
    echo "Only one snapshot currently exists - performing Full Backup Copy"
    backupType="full"
else
    echo "Previous snapshot currently exists - performing Incremental Backup Copy"
    backupType="incremental"
fi

# create backup container if it doesn't exist 

containerList=$(azure storage container list --account-name ${backupAccountName} --account-key ${backupAccountKey} --json ${backupContainerName} | jq -r '. [0].name')

if [[ "$containerList" == "null" ]]; then
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

# perform backup

if [[ "$backupType" == "full" ]]; then

    # full backup copy

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
            echo "Full backup copy and snapshot completed for ${backupBlobName} to ${backupAccountUri}${backupContainerName}"
            break
        else
            echo "Error creating backup snapshot due to API limit ... waiting 10-minutes before retry ..."
            sleep 10m
        fi
    done

elif [[ "$backupType" == "incremental" ]]; then
    
    # incremental backup copy

    while true
    do
        ./azure_vhd_snapshot_incremental_copy.py ${sourceAccountName} ${sourceAccountKey} ${sourceContainerName} ${sourceBlobName} ${backupAccountName} ${backupAccountKey} ${backupContainerName} ${backupBlobName} ${sourceSnapshotCurrent} ${sourceSnapshotPrevious}
        if [[ $? == 0 ]]; then
            while true
            do
                azure storage blob snapshot --account-name ${backupAccountName} --account-key ${backupAccountKey} --container ${backupContainerName} ${backupBlobName} 
                if [[ $? == 0 ]]; then
                    echo "Incremental backup copy and snapshot completed for ${backupBlobName} to ${backupAccountUri}${backupContainerName}"
                    break 2
                else
                    echo "Error creating backup snapshot due to API limit ... waiting 10-minutes before retry ..."
                    sleep 10m
                fi
            done
        else
            echo "Error copying incremental snapshot changes to backup storage account ... waiting 1-minute before retry ..."
            sleep 1m
        fi
    done

fi