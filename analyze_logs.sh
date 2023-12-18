#!/bin/bash

source ./config.sh

# Navigate to the LOCAL_LOG_DIR
cd "$LOCAL_LOG_DIR" || { echo "Failed to enter directory $LOCAL_LOG_DIR"; exit 1; }

# Find the latest directory with the prefix "logs"
LATEST_LOG_DIR=$(ls -d logs* | sort -r | head -n 1)

if [ -n "$LATEST_LOG_DIR" ]; then
    echo "Processing in directory: $LATEST_LOG_DIR"
    cd "$LATEST_LOG_DIR" || { echo "Failed to enter directory $LATEST_LOG_DIR"; exit 1; }

    for log_file in *.log1; do
        yml_file="${log_file}.yml"
        if [ ! -f "$yml_file" ]; then
            echo "Converting $log_file to YAML..."
            "$LOG2YML_BINARY" "$log_file"
        else
            echo "YAML file already exists for $log_file, skipping..."
        fi
    done

    echo "Running YML2STATS_BINARY on the latest log directory..."
    "$YML2STATS_BINARY" "$LOCAL_LOG_DIR/$LATEST_LOG_DIR"

else
    echo "No logs directory found."
fi
