#!/usr/bin/env bash

#
# Example of using CLI v2 to create managed disk snapshot 
# and start copy to storage account
#

# managed disk to shapshot
DISK_NAME="vm2-datadisk1"
RESOURCE_GROUP="mongo-md-centos"
#snapshot SKUs values: Premium_LRS or Standard_LRS
SNAPSHOT_SKU=Premium_LRS

# storage account and container in DR region
# 
# NOTE: this storage account can NOT have SSE (storage service encryption) enabled
#
DEST_ACCOUNT="mongodrsnapshots"
DEST_CONTAINER="mongo-cluster-1"

SNAPSHOT_NAME=${DISK_NAME}_$(date -u "+%Y.%m.%d-%H.%M.%S")_${SNAPSHOT_SKU}
ACCESS_DURATION=$(( 60 * 60 * 24 )) # 24 hrs as seconds

# create local snapshot
echo "creating snapshot ${SNAPSHOT_NAME} for disk $DISK_NAME in resource-group $RESOURCE_GROUP"
time result=$(az snapshot create \
  --name ${SNAPSHOT_NAME} \
  --resource-group $RESOURCE_GROUP \
  --source $DISK_NAME \
  --sku $SNAPSHOT_SKU )
echo "snapshot ${SNAPSHOT_NAME} created. result:$result"

# get access to the snapshot via time limited URL
# returns:
# URL:{
#  "accessSas": "https://xxx.blob.core.windows.net/lvprlcr2dtk1/abcd?sv=xxxxxx
# }
echo "getting acccess URL for snapshot $SNAPSHOT_NAME  .."
time SNAPSHOT_URL=$(az snapshot grant-access \
  --duration-in-seconds $ACCESS_DURATION \
  --name $SNAPSHOT_NAME \
  --resource-group $RESOURCE_GROUP \
  --query accessSas | tr -d '"'
)
echo "SNAPSHOT_URL:$SNAPSHOT_URL"

# Get access token for DR site storeage acccount
EXPIRY_DATE=$(date -u -d '86400 seconds' +'%Y-%m-%dT%H:%MZ')
echo "getting access token for target storage account ..."
DEST_SAS=$(az storage account generate-sas \
  --expiry $EXPIRY_DATE \
  --permissions aclpruw \
  --resource-types sco \
  --services b \
  --account-name $DEST_ACCOUNT \
  --https-only | tr -d '"') 

# start copy to DR site storage account 
# the copy is async and managed by the blob service on best effort basis (i.e. no SLA)
echo "DEST_SAS: $DEST_SAS"
echo "starting cross region copy of snapshot ..."
time COPY_REQUEST_ID=$(az storage blob copy start \
  --source-uri $SNAPSHOT_URL \
  --account-name $DEST_ACCOUNT \
  --sas-token $DEST_SAS \
  --destination-container $DEST_CONTAINER \
  --destination-blob ${SNAPSHOT_NAME}.vhd \
  --query id | tr -d '"')
echo "copy id (needed to track/cancel copy):$COPY_REQUEST_ID"
