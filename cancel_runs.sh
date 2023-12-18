#!/bin/bash

# Source the master configuration
source ./config.sh

# Serialize the configuration
serialized_config=$(declare -p NODES LOG_DIR_ROOT LOG_DIR_PREFIX)

# SSH into the root node to perform operations on each node
ssh "$ROOT_NODE" bash -s <<EOF

# Re-initialize the configuration in the remote shell
$serialized_config

kill_pid_and_children() {
    local pid=\$1
    local node=\$2

    # Execute the kill commands and check their success
    ssh "\$node" bash -c "'pkill -P \$pid; kill -9 \$pid'"
    local kill_status=\$?

    # Report success or failure
        echo "Successfully killed PID \$pid and its children on \$node."
    else
        echo "Failed to kill PID \$pid and its children on \$node. Status: \$kill_status"
    fi
}

# Find the latest log directory
latest_log_dir=\$(ls -d $LOG_DIR_ROOT/$LOG_DIR_PREFIX* | tail -n 1)
echo "Latest log dir: \$latest_log_dir"

if [[ -z "\$latest_log_dir" ]]; then
    echo "No logs directory found."
    exit 1
fi

echo "Using latest log directory: \$latest_log_dir"

# Cancel jobs for each node
for node in "\${NODES[@]}"; do
    pid_file="\$latest_log_dir/pids_\$node.txt"
    if [[ -f "\$pid_file" ]]; then
        echo "Cancelling jobs on \$node..."

        while IFS= read -r -u 3 pid; do
            if [[ -n "\$pid" ]]; then
                # Check if the PID exists
                if ssh "\$node" ps -p \$pid > /dev/null 2>&1; then
                    kill_pid_and_children "\$pid" "\$node"
                else
                    echo "PID \$pid does not exist on \$node."
                fi
            fi
        done 3< "\$pid_file"
    else
        echo "No PID file found for \$node."
    fi
done

EOF
