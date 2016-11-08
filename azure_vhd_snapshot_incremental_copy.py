#!/usr/bin/python

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

# Tested with azure.storage module v 0.33.0 from Azure Python SDK

import sys
import argparse
from azure.storage.blob import PageBlobService

# Parse command line arguments

parser = argparse.ArgumentParser()
parser.add_argument("sourceaccount", help="source storage account name")
parser.add_argument("sourcekey", help="source storage account key")
parser.add_argument("sourcecontainer", help="source blob container")
parser.add_argument("sourceblob", help="source blob name")
parser.add_argument("backupaccount", help="backup storage account name")
parser.add_argument("backupkey", help="backup storage account key")
parser.add_argument("backupcontainer", help="backup blob container")
parser.add_argument("backupblob", help="backup blob name")
parser.add_argument("snapshotcurrent", help="latest page blob snapshot")
parser.add_argument("snapshotprevious", help="previous page blob snapshot")
args = parser.parse_args()

# Define maximum page range (in bytes) for each update operation - 4MB is the maximum supported limit

max_range = 4194304

# Connect to Page Blob Service for Storage Accounts

source_blob_service = PageBlobService(args.sourceaccount, args.sourcekey)
backup_blob_service = PageBlobService(args.backupaccount, args.backupkey)

# Find page differences between snapshots and update backup blob with changes

try:
    ranges = source_blob_service.get_page_ranges_diff(args.sourcecontainer, args.sourceblob, args.snapshotprevious, args.snapshotcurrent)
    for range in ranges:
        if range.is_cleared == True:
            print('clearing page range: ({}, {}) '.format(range.start, range.end))
            backup_blob_service.clear_page(args.backupcontainer, args.backupblob, range.start, range.end)
        else:
            byte_offset = 0
            last_range = False
            while True:
                start_range = range.start + byte_offset
                end_range = start_range + max_range - 1
                if end_range >= range.end:
                    end_range = range.end
                    last_range = True
                print('updating page range: ({}, {}, {} bytes) '.format(start_range, end_range, end_range - start_range + 1))
                page = source_blob_service.get_blob_to_bytes(args.sourcecontainer, args.sourceblob, args.snapshotcurrent, start_range, end_range)
                backup_blob_service.update_page(args.backupcontainer, args.backupblob, page.content, start_range, end_range) 
                if last_range:
                    break
                byte_offset = byte_offset + max_range
except:
    sys.exit(1)
else:
    sys.exit(0)