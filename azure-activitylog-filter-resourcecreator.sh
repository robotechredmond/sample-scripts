#!/usr/bin/bash

az login

outFile="./activitylog.json"

truncate -s 0 $outFile

for rgName in $(az group list | jq -r '.[] | .name')
do
    az monitor activity-log list --resource-group ${rgName} --status Succeeded | jq '.[] | select(.properties | .statusCode | contains("Created"))' >>${outFile}
done