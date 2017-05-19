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
parser.add_argument("account", help="storage account name")
parser.add_argument("key", help="storage account key")
parser.add_argument("container", help="blob container")
parser.add_argument("blob", help="blob name")
args = parser.parse_args()

# Calculate size of name
blob_size_in_bytes = 124 + len(args.blob) * 2

# Calculate size of metadata + data
try:
    # Connect to storage account
    blob_service = PageBlobService(args.account, args.key)
    # Calculate size of metadata
    metadata = blob_service.get_blob_metadata(args.container, args.blob)
    for key, value in metadata.items():
        blob_size_in_bytes += 3 + len(key) + len(value)
    # Calculate size of data
    ranges = blob_service.get_page_ranges(args.container, args.blob)
    for range in ranges:
        blob_size_in_bytes += 12 + range.end - range.start 
    print(blob_size_in_bytes)
except:
    sys.exit(1)
else:
    sys.exit(0)