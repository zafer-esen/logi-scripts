#!/bin/bash

source ./config.sh

# --- Default settings ---
chosen_note=""
chosen_timeout=$TIMEOUT
chosen_splits=$(( ${#NODES[@]} * 2 ))

use_force=0
while getopts "f" opt; do
    case $opt in
        f) use_force=1 ;;
        *) echo "Usage: $0 [-f]" >&2; exit 1 ;;
    esac
done

# --- Utility functions ---
run_on_root_and_check_node() {
    local node=$1
    ssh -o ConnectTimeout=2 "$ROOT_NODE" ssh "$node" "$2"
}

compare_and_copy_jar() {
    local local_jar_checksum
    local remote_jar_checksum

    # Calculate checksum of the local JAR file
    local_jar_checksum=$(md5sum "$LOCAL_JAR_PATH" | awk '{ print $1 }')

    # Calculate checksum of the remote JAR file
    remote_jar_checksum=$(ssh "$ROOT_NODE" "md5sum '$REMOTE_JAR_PATH' 2>/dev/null || echo 'none'" | awk '{ print $1 }')

    if [ "$local_jar_checksum" == "$remote_jar_checksum" ]; then
        echo "Local and remote JAR files are identical. No need to copy."
        if [[ $use_force -eq 0 ]]; then
            read -p "Press any key to continue..." -n 1 -s
            echo
        fi
    else
        echo "Local and remote JAR files are different."
        if [[ $use_force -eq 1 ]]; then
            scp "$LOCAL_JAR_PATH" "$ROOT_NODE:$REMOTE_JAR_PATH"
            echo "JAR file copied to remote server."
        else
            read -p "Do you want to overwrite the remote JAR file with the local one? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                scp "$LOCAL_JAR_PATH" "$ROOT_NODE:$REMOTE_JAR_PATH"
                echo "JAR file copied to remote server."
            fi
        fi
    fi
}

# Function to display top processes on a node
display_top_processes() {
    local node=$1

    echo "Fetching top processes on $node..."
    local top_processes=$(run_on_root_and_check_node "$node" "ps -eo pid,ppid,%cpu,%mem,cmd --sort=-%cpu,-%mem | head -n 6")
    echo "$top_processes"
}

# Function to check if a node is connectable and idle
check_node_status() {
    local node=$1
    
    # Check connectivity by attempting a simple SSH command via the root node
    if ! run_on_root_and_check_node "$node" "exit 0"; then
        echo "Cannot connect to $node."
        non_connectable_nodes+=("$node")
        return
    fi

    # Display top processes regardless of node being idle or not
    display_top_processes "$node"

    # Check if the node is idle (CPU usage)
    local load_avg=$(run_on_root_and_check_node "$node" "uptime | awk -F 'load average: ' '{print \$2}' | cut -d, -f1")
    echo "$node Load Average: $load_avg"

    # Based on load average, categorize the node
    if (( $(echo "$load_avg < 1.0" | bc -l) )); then
        idle_nodes+=("$node")
    else
        non_idle_nodes+=("$node")
    fi
}

# --- Node status checking ---
idle_nodes=()
non_idle_nodes=()
non_connectable_nodes=()
for node in "${NODES[@]}"; do
    check_node_status "$node"
done

# Display node status
[ ${#idle_nodes[@]} -gt 0 ] && echo "Idle nodes: ${idle_nodes[*]}"
[ ${#non_idle_nodes[@]} -gt 0 ] && echo "Available but non-idle nodes: ${non_idle_nodes[*]}"
[ ${#non_connectable_nodes[@]} -gt 0 ] && echo "Non-connectable nodes: ${non_connectable_nodes[*]}"

# Exit if no nodes are available
if [ ${#idle_nodes[@]} -eq 0 ] && [ ${#non_idle_nodes[@]} -eq 0 ]; then
    echo "No connectable nodes available. Exiting."
    exit 1
else
    echo "Some nodes are non-connectable."
    if [[ $use_force -eq 0 ]]; then
      read -p "Do you want to proceed with available nodes only? (y/n) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          echo "Exiting."
          exit 1
      fi
    fi
    echo "Proceeding with connectable nodes only."
fi

# Node selection and job distribution
if [[ $use_force -eq 1 ]]; then
    # Force mode: Use default values and idle nodes
    NODES=("${idle_nodes[@]}")
    NUM_SPLITS=$chosen_splits
else
    # Interactive mode: User inputs for notes, timeout, and node selection
    read -p "Enter notes for -notes argument of run-list (leave empty if none): " chosen_note
    echo
    read -p "Enter new timeout, or press enter to keep default ($TIMEOUT s): " user_timeout
    echo
    if [[ -n "$user_timeout" ]]; then
        chosen_timeout=$user_timeout
    fi

    # Node selection based on idle status
    if [ ${#non_idle_nodes[@]} -gt 0 ]; then
        read -p "Use only idle nodes? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            NODES=("${idle_nodes[@]}")
        else
            NODES=("${idle_nodes[@]}" "${non_idle_nodes[@]}")
        fi
    else
        NODES=("${idle_nodes[@]}")
    fi

    # User input for number of splits
    echo "Default number of jobs per node: $chosen_splits"
    read -p "Enter number of jobs per node, or press enter for default: " user_splits
    NUM_SPLITS=${user_splits:-$chosen_splits}
fi

# --- Compare and copy JAR file ---
echo "Sending $LOCAL_JAR_PATH to $ROOT_NODE:$REMOTE_JAR_PATH..."
compare_and_copy_jar

# Function to run commands on a node
run_on_node() {
    local node=$1
    local start_index=$2
    local end_index=$3
    local pid_file="$LOG_DIR/pids_$node.txt"

    echo "Connecting to $node..."
    ssh "$node" bash -s <<EOF

    echo "cd $LOG_DIR"
    if ! cd "$LOG_DIR"; then
        echo "Error changing to log directory $LOG_DIR on $node"
        exit 1
    fi
    for i in \$(seq $start_index $end_index); do
        echo "Running command on $node:"
        command="$RUN_LIST_SCRIPT ${FILE_LIST_PATH}_\${i} -twall $chosen_timeout -mail $EMAIL"
        if [[ -n "$chosen_note" ]]; then
            command+=" -notes $chosen_note"
        fi
        echo "nohup \$command > nohup\${i} &"
        nohup \$command > "nohup\${i}" &
        echo \$! >> "$pid_file"
        sleep $SLEEP_DURATION
    done
EOF
}

# Function to calculate and distribute the tasks among the nodes
distribute_tasks() {
    local num_nodes=${#NODES[@]}

    echo "Using $NUM_SPLITS file splits across the nodes."

    local splits_per_node=$((NUM_SPLITS / num_nodes))
    echo "Splits per node: $splits_per_node"

    local remaining_splits=$((NUM_SPLITS % num_nodes))
    echo "Remaining splits: $remaining_splits"

    local start_index=0
    local end_index=0

    for node in "${NODES[@]}"; do
        end_index=$((start_index + splits_per_node + (remaining_splits > 0 ? 1 : 0) - 1))
        remaining_splits=$((remaining_splits - 1))

        run_on_node "$node" $start_index $end_index

        start_index=$((end_index + 1))
    done
}

# --- Serialize settings for remote execution ---
serialize_settings() {
    local serialized_vars=$(declare -p NODES NUM_SPLITS LOG_DIR RUN_LIST_SCRIPT TIMEOUT EMAIL FILE_LIST_PATH SLEEP_DURATION LOG_DIR_PREFIX chosen_note chosen_timeout)
    local serialized_fns=$(declare -f run_on_node distribute_tasks)
    echo "$serialized_vars"
    echo "$serialized_fns"
}

serialized_settings=$(serialize_settings)

# --- Remote execution ---
echo "Connecting to $ROOT_NODE..."
ssh "$ROOT_NODE" bash -s <<EOF
$serialized_settings

# Create log directory and prepare file splits
mkdir -p "$LOG_DIR"
echo "Removing existing file splits..."
rm -f "${FILE_LIST_PATH}_"*
echo "Splitting $FILE_LIST_PATH into $NUM_SPLITS files..."
random-split "$FILE_LIST_PATH" $NUM_SPLITS

distribute_tasks
EOF

echo
echo "Experiments configuration:"
echo "Nodes used: ${NODES[*]}"
echo "Jobs per node: $NUM_SPLITS"
echo "Timeout per job: $chosen_timeout seconds"
echo "Notes: $chosen_note"
echo
echo "Starting experiments on selected nodes..."
echo "Logs can be found in $LOG_DIR."