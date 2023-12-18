#!/bin/bash

source ./config.sh

mkdir -p $LOCAL_LOG_DIR

echo "Pulling log directories from $ROOT_NODE..."
rsync -avz --ignore-existing "$ROOT_NODE:$LOG_DIR_ROOT/" "$LOCAL_LOG_DIR/"

echo "Log directories have been pulled to local directory: $LOCAL_LOG_DIR"
