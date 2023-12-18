#!/bin/bash

source ./config.sh

echo "You are about to push local changes from $LOCAL_LOG_DIR to $ROOT_NODE:$LOG_DIR_ROOT."
read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo    # Move to a new line

if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

# Define backup directory and backup name with date
backup_root="${LOG_DIR_ROOT}_backups"
date_stamp=$(date +"%Y%m%d-%H%M%S")
backup_dir="$backup_root/backup_$date_stamp"

# Step 1: Create a backup at the remote server
echo "Creating a backup at $ROOT_NODE:$backup_dir..."
ssh "$ROOT_NODE" "mkdir -p $backup_root && mv $LOG_DIR_ROOT $backup_dir && mkdir -p $LOG_DIR_ROOT"
echo "Backup created at $ROOT_NODE:$backup_dir"

# Step 2: Push local changes, including deletions, to the remote server
echo "Pushing local changes to the remote server..."
rsync -avz --delete "$LOCAL_LOG_DIR/" "$ROOT_NODE:$LOG_DIR_ROOT/"

echo "Local changes have been pushed to the remote server."

echo "Previous version can be found at $ROOT_NODE:$backup_dir"
