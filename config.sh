#!/bin/bash

# If anything is changed in this file, variables that should be sent to remote
# should be added to the serialization list in run_experiments.sh as well.

ROOT_NODE="name@server.com"        # Root node hostname

# Nodes to split the work onto. ssh into $ROOT_NODE first, then ssh into each and
# make sure there are no ongoing jobs before starting new ones.
NODES=("lc2" "lc3" "lc4" "lc5")             # Work nodes

# run-list script to execute on remote.
RUN_LIST_SCRIPT="/remote/path/to/run-list"

# Jar file to be copied to remote.  E.g., the output of an 'sbt assembly' jar file.
LOCAL_JAR_PATH="/local/path/to/jar"  

# Should be the same as the one specified at remote run-list.
# ssh into $RUN_LIST_SCRIPT and make sure they match.
REMOTE_JAR_PATH="/remote/path/to/jar"

# Timeout parameter for run-list script
TIMEOUT=60

# Email to be passed to the run-list script.
EMAIL="name@email.com"

# Full path on remote to file containing full benchmark paths, one per line.
FILE_LIST_PATH="/remote/path/to/file-list"

 # Number of splits to split above file
NUM_SPLITS=1

# Sleep duration between remote job starts
SLEEP_DURATION=1

# Local directory to pull resulting logs (which is a directory).
# This is used by get_results.sh, which should be called manually after experiments conclude.
LOCAL_LOG_DIR="/local/path/to/logdir"

# Timestamp for directory naming on remote
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

LOG_DIR_ROOT="/remote/path/to/log/dir"
LOG_DIR_PREFIX="logs"
LOG_DIR="$LOG_DIR_ROOT"/"$LOG_DIR_PREFIX"-"$TIMESTAMP"

# - Analysis -
LOG2YML_BINARY="/local/path/to/log2yml"

YML2STATS_BINARY="/local/path/to/yml2stats"
