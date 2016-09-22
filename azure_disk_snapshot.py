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

import argparse
from azure.storage.blob import PageBlobService

# Parse command line arguments

parser = argparse.ArgumentParser()
parser.add_argument("account", help="storage account name")
parser.add_argument("key", help="storage account key")
parser.add_argument("container", help="blob container")
parser.add_argument("blob", help="blob name")
parser.add_argument("-s", "--snapshot", help="create a new snapshot", action="store_true")
parser.add_argument("-d", "--delete", help="delete a snapshot")
parser.add_argument("-r", "--restore", help="restore a snapshot to a new blob")
args = parser.parse_args()

# Connect to Storage Account Blob Service

source_blob_service = PageBlobService(args.account, args.key)

# Perform actions based on arguments

if args.snapshot == True:
  print '# Creating a new snapshot...'
  source_blob_service.snapshot_blob(args.container, args.blob)
  print 'OK.'

if args.delete:
  print '# Deleting snapshot...'
  source_blob_service.delete_blob(args.container, args.blob, snapshot=args.delete)
  print "Deleted", args.delete

if args.restore:
  print '# Restoring snapshot to a new blob...'
  src = "https://" + args.account + ".blob.core.windows.net/" + args.container + "/" + args.blob + "?snapshot=" + args.restore
  dst = args.blob + "_restore"
  source_blob_service.copy_blob(args.container, dst, src)
  print "Restored", src, "to", dst

print '# List of snapshots:'

for blob in source_blob_service.list_blobs(args.container, include='snapshots'):
  if blob.name == args.blob:
    print blob.name, blob.snapshot
